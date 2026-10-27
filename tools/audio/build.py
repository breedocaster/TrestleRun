"""Build every game audio asset into assets/audio/ and write a manifest.

    python3 tools/audio/build.py <kenney+blanket source dir> [--only=engines,sfx,ambience,music] [--track=a,b]

--only: rebuild just those groups (the manifest keeps the rest). --track: with music,
just those loops.

Sources (fetched with git, licenses verified):
  KenneyNL/Starter-Kit-* (CC0)        -> impact, land, break, UI clicks
  rafaelmardojai/blanket sounds       -> birds (CC0), crickets (PD), wind (CC0),
                                         rain (CC BY 4.0), creek (CC0)
Everything else (engines, chimes, whooshes, theme + variants, mine/yard/canyon/alpine/
collapse and story-area beds) is synthesized here.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import ambience  # noqa: E402
import electric  # noqa: E402
import engines  # noqa: E402
import sfx  # noqa: E402
import theme  # noqa: E402
from dsp import SR, lufs, write_ogg  # noqa: E402

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
ONLY = next((a[7:].split(",") for a in sys.argv[1:] if a.startswith("--only=")), None)
TRACKS = next((a[8:].split(",") for a in sys.argv[1:] if a.startswith("--track=")), None)
SRC = ARGS[0] if ARGS else "/home/claude/build/snd-src"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")


def save(rel, x, q=4, loop=False, meta=None, manifest=None, rate=None):
    path = os.path.join(OUT, rel)
    write_ogg(path, x, q, rate)
    entry = {"seconds": round(x.shape[0] / SR, 3), "lufs": round(float(lufs(x)), 1),
             "peak_db": round(float(20 * np.log10(np.max(np.abs(x)) + 1e-12)), 1),
             "loop": loop, "kb": round(os.path.getsize(path) / 1024, 1)}
    if meta:
        entry.update(meta)
    manifest[rel] = entry
    print(f"  {rel:34s} {entry['seconds']:7.2f}s {entry['lufs']:6.1f} LUFS {entry['kb']:7.1f} KB")


def want(part):
    return ONLY is None or part in ONLY


def main():
    mpath = os.path.join(OUT, "manifest.json")
    manifest = json.load(open(mpath)) if os.path.exists(mpath) and ONLY else {}
    if want("engines"):
        print("engines")
    for name in (engines.ENGINES if want("engines") else []):
        for state in ("idle", "cruise"):
            # 8 s loops (4 s before v0.8.2) so the combustion wander doesn't audibly repeat.
            y, meta = engines.render(name, state, target_s=8.0)
            save(f"engines/{name}_{state}.ogg", y, q=6, loop=True, meta=meta, manifest=manifest)
    # The battery bikes, e-bikes and electric unicycles (v0.10): motor whine instead of
    # combustion. --only=electric renders just these.
    for name in (electric.MOTORS if want("engines") or want("electric") else []):
        for state in ("idle", "cruise"):
            y, meta = electric.render(name, state, target_s=8.0)
            save(f"engines/{name}_{state}.ogg", y, q=6, loop=True, meta=meta, manifest=manifest)
    for name, y in (sfx.build(SRC).items() if want("sfx") else []):
        # q5 (about 160 kbps): clean chime tails and noise bursts. They were q2 for a
        # size cap before v0.8.2.
        save(f"sfx/{name}.ogg", y, q=5, loop=name in ("deck_roll", "zipline", "plane", "grind", "saucer"), manifest=manifest)
    if want("ambience"):
        amb, info = ambience.build(f"{SRC}/blanket/data/resources/sounds")
        for name, y in amb.items():
            # Stereo, 44.1 kHz, q4: the rain and leaves keep their top end (v0.8.1 had
            # them at 22 kHz mono, q0-q1, for a size cap).
            save(f"ambience/{name}.ogg", y, q=4, loop=True, meta=info[name], manifest=manifest)
    if want("music"):
        # The theme, two trail moods, four story areas and the boss, all at q5 (about
        # 160 kbps; they were q0-q1 for a size cap before v0.8.2).
        for name in TRACKS or theme.VARIANTS:
            cfg = theme.VARIANTS[name]
            y = theme.render_variant(name)
            save(f"music/{name}.ogg", y, q=5, loop=True,
                 meta={"bpm": cfg.get("bpm", 78.0), "bars": cfg.get("bars", 32)}, manifest=manifest)
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    total = sum(v["kb"] for v in manifest.values())
    print(f"total {total/1024:.2f} MB in {len(manifest)} files")


if __name__ == "__main__":
    main()
