"""Build every game audio asset into assets/audio/ and write a manifest.

    python3 tools/audio/build.py <kenney+blanket source dir>

Sources (fetched with git, licenses verified):
  KenneyNL/Starter-Kit-* (CC0)        -> impact, land, break, UI clicks
  rafaelmardojai/blanket sounds       -> birds (CC0), crickets (PD), wind (CC0),
                                         rain (CC BY 4.0), creek (CC0)
Everything else (engines, chimes, whooshes, theme + variants, mine/yard/canyon/alpine
beds) is synthesized here.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import ambience  # noqa: E402
import engines  # noqa: E402
import sfx  # noqa: E402
import theme  # noqa: E402
from dsp import SR, lufs, write_ogg  # noqa: E402

ARGS = [a for a in sys.argv[1:] if not a.startswith("--only=")]
ONLY = next((a[7:].split(",") for a in sys.argv[1:] if a.startswith("--only=")), None)
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
            y, meta = engines.render(name, state)
            save(f"engines/{name}_{state}.ogg", y, q=4, loop=True, meta=meta, manifest=manifest)
    for name, y in (sfx.build(SRC).items() if want("sfx") else []):
        save(f"sfx/{name}.ogg", y, q=4, loop=name in ("deck_roll", "zipline", "plane"), manifest=manifest)
    if want("ambience"):
        amb, info = ambience.build(f"{SRC}/blanket/data/resources/sounds")
        for name, y in amb.items():
            # Beds at 22.05 kHz: nothing in them needs the top octave, and it buys APK room.
            save(f"ambience/{name}.ogg", y, q=0 if info[name].get("synth") else 1, loop=True,
                 meta=info[name], manifest=manifest, rate=22050)
    if want("music"):
        # One theme and two trail variants; q1 keeps all three in the APK budget.
        for name, cfg in theme.VARIANTS.items():
            y = theme.render_variant(name)
            save(f"music/{name}.ogg", y, q=1, loop=True,
                 meta={"bpm": cfg.get("bpm", 78.0), "bars": cfg.get("bars", 32)}, manifest=manifest)
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    total = sum(v["kb"] for v in manifest.values())
    print(f"total {total/1024:.2f} MB in {len(manifest)} files")


if __name__ == "__main__":
    main()
