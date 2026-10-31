"""Turn a bounce from a DAW (Pro Tools, Ardour, ...) into a game-ready Ogg in assets/audio.

    python3 tools/audio/import_audio.py SRC TARGET [--copies=N] [--crossfade=S]
                                        [--start=S] [--seconds=S] [--lufs=X] [--dry-run]

SRC is any file ffmpeg reads (WAV/AIFF from Pro Tools, FLAC/WAV from Ardour).
TARGET is the path under assets/audio, e.g. music/windfall.ogg. If that file already
exists, the new one takes its loudness (LUFS) and channel count from it, so it lands in
the mix exactly where the old one sat and the game needs no code change.

How the loop is made (pick one; one-shot sound effects need neither):
  --copies=N     SRC is the loop bounced N times back to back (3 is right). The middle
                 copy is kept, so reverb and delay tails from the copy before it are
                 already in its first bar and the seam is seamless. The loop's length
                 comes from --seconds, or for music from the manifest's bpm and bars
                 (32 bars of 4/4 at the tempo of the track it replaces).
  --crossfade=S  SRC is one long recording (ambience, an engine held at a steady RPM).
                 A --seconds long stretch from --start is cut and its last S seconds
                 are blended into its head.

The manifest entry is marked "imported", and build.py leaves imported files alone.
"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from dsp import SR, loop_xfade, lufs, read_audio, write_ogg  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
# Vorbis quality per folder, the same as build.py: about 160 kbps for music and effects,
# engines a step higher (they're pitched up and down), ambience a step lower.
QUALITY = {"music": 5, "sfx": 5, "engines": 6, "ambience": 4}
# Levels for a new file with nothing to match (the middle of what build.py makes).
DEFAULT_LUFS = {"music": -16.0, "sfx": -22.0, "engines": -21.0, "ambience": -30.0}
LOOPED_SFX = ("deck_roll", "zipline", "plane", "grind", "saucer")


def opt(name, default=None, cast=float):
    for a in sys.argv[1:]:
        if a.startswith(f"--{name}="):
            return cast(a.split("=", 1)[1])
    return default


def channels(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=channels",
                          "-of", "csv=p=0", path], capture_output=True, text=True, check=True)
    return int(out.stdout.split()[0])


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        sys.exit(__doc__)
    src, rel = args
    folder = rel.split("/")[0]
    if folder not in QUALITY or not rel.endswith(".ogg"):
        sys.exit(f"TARGET must be <{'|'.join(QUALITY)}>/<name>.ogg, got {rel}")
    dst = os.path.join(OUT, rel)
    mpath = os.path.join(OUT, "manifest.json")
    manifest = json.load(open(mpath))
    old = manifest.get(rel, {})
    name = os.path.basename(rel)[:-4]
    loop = folder != "sfx" or name in LOOPED_SFX

    nch = channels(dst) if os.path.exists(dst) else (1 if folder == "engines" else 2)
    x = read_audio(src, mono=nch == 1)
    if x.ndim == 1 and nch == 2:
        x = np.stack([x, x], axis=1)

    copies = opt("copies", None, int)
    xfade = opt("crossfade")
    seconds = opt("seconds")
    if copies:
        if seconds is None and folder == "music":
            bpm, bars = float(old.get("bpm", 0)), int(old.get("bars", 32))
            if not bpm:
                sys.exit("new music: give --seconds (bars x 4 x 60 / bpm)")
            seconds = bars * 4 * 60.0 / bpm
        if seconds is None:
            seconds = x.shape[0] / SR / copies
        n = int(round(seconds * SR))
        start = n * (copies // 2)
        if copies * n > x.shape[0] + int(0.05 * SR):
            sys.exit(f"SRC is {x.shape[0] / SR:.2f} s; {copies} copies of {seconds:.3f} s need "
                     f"{copies * seconds:.2f} s. Bounce from the first bar of the first copy.")
        y = x[start:start + n].copy()
    elif xfade:
        if seconds is None:
            sys.exit("--crossfade needs --seconds (how long the loop is)")
        start = opt("start", 0.0)
        if (start + seconds + xfade) * SR > x.shape[0]:
            sys.exit("SRC is too short for --start + --seconds + --crossfade")
        y = loop_xfade(x, start, seconds, xfade)
    else:
        y = x.copy()
        if loop:
            print(f"warning: {rel} loops in the game; without --copies or --crossfade the seam "
                  "is wherever the bounce starts and ends")

    target = opt("lufs", old.get("lufs", DEFAULT_LUFS[folder]))
    gain = 10 ** ((target - lufs(y)) / 20.0)
    y = y * gain
    peak = 20 * np.log10(np.max(np.abs(y)) + 1e-12)
    if peak > -1.0:
        # Pull it down rather than clip; the mix will sit a little lower.
        y *= 10 ** ((-1.0 - peak) / 20.0)
        print(f"warning: peak would be {peak:+.1f} dBFS at {target} LUFS; turned down to "
              f"-1 dBFS ({lufs(y):.1f} LUFS). Compress or limit it in the DAW to hit the level.")

    entry = {"seconds": round(y.shape[0] / SR, 3), "lufs": round(float(lufs(y)), 1),
             "peak_db": round(float(20 * np.log10(np.max(np.abs(y)) + 1e-12)), 1),
             "loop": loop, "imported": True, "source": os.path.basename(src)}
    for k in ("bpm", "bars"):
        if k in old:
            entry[k] = old[k]
    print(f"{rel}: {entry['seconds']:.3f} s, {entry['lufs']} LUFS (target {target}), "
          f"peak {entry['peak_db']} dBFS, {'mono' if nch == 1 else 'stereo'}, q{QUALITY[folder]}")
    if "--dry-run" in sys.argv:
        return
    write_ogg(dst, y, QUALITY[folder])
    entry["kb"] = round(os.path.getsize(dst) / 1024, 1)
    manifest[rel] = entry
    with open(mpath, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    print(f"wrote {dst} ({entry['kb']} KB) and updated manifest.json")


if __name__ == "__main__":
    main()
