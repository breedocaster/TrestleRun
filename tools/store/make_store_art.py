#!/usr/bin/env python3
"""Play Console store art from the game itself.

Writes into store/play/:
  feature_graphic_1024x500.png   the title scene with the logo (24-bit PNG, no alpha)
  screenshot_<n>_<name>.png      1920 x 1080 gameplay and menu shots (24-bit PNG)
and keeps store/play_icon_512.png (tools/icons/make_launcher_icons.py) as the icon.

Every picture is the game's own frame (480 x 270, or 553 x 270 for the feature graphic)
blown up with hard edges: x4 for the screenshots, x2 (after a crop to 512 x 250) for the
feature graphic. The runs use a throwaway save (an override.cfg points user:// at
~/.local/share/trestle-run-store for the run), so your own save and its cheats,
coins and unlocks stay out of the pictures; the override is removed afterwards.

  python3 tools/store/make_store_art.py [--godot godot] [--sample]

--sample renders every trail in SAMPLE at a row of positions instead, into
store/play/sample/, for picking the moments in SHOTS.
"""
import argparse
import os
import shutil
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "store", "play")
USER_DIR = "trestle-run-store"
OVERRIDE = """[application]

config/use_custom_user_dir=true
config/custom_user_dir_name="%s"

[display]

window/size/window_width_override=%d
window/size/window_height_override=%d
"""

# name, shot spec, extra flags (rig = rider:bike:paint), x to capture at (None = as is)
# (0.10 swapped Copper Canyon's arches and Skyline Pass's forest for SUMMIT and GAUNTLET;
# those two show the touch pedals, as on a phone.)
SHOTS = [
    ("loop", "game:hoodoo_loops:x0", "--cond=day:clear --rig=dusty:scrambler:stock", 3600),
    ("summit", "drive_screen:summit:5:3500", "--pedals --rig=granny:spark:flame", None),
    ("boss", "game:s4_boss:x0", "--rig=bones:scrambler:chrome", 1800),
    ("gauntlet", "drive_screen:gauntlet:9:300", "--pedals --rig=zorp:dirt:swamp", None),
    ("wall_of_death", "game:s4_drome:x0", "--rig=bandit:scrambler:midnight", 2400),
    ("endless", "game:endless:x0", "--rig=finn:scrambler:tan", 2400),
    ("challenges", "challenges", "--chal-demo --money=2480", None),
    ("garage", "garage:bike", "--own-all --money=2480 --rig=robo:dirt:flame", None),
]

SAMPLE = ["copper_canyon", "hoodoo_loops", "skyline_pass", "quarry_cliffs", "rocket_ridge",
          "night_trestle", "s1_boss", "s2_boss", "s3_boss", "s4_boss", "s2_siding",
          "s3_apple_row", "s4_drome", "endless"]


def godot(args, godot_bin, window):
    cfg = os.path.join(ROOT, "override.cfg")
    if os.path.exists(cfg):
        sys.exit("override.cfg already exists in the project; move it out of the way first")
    with open(cfg, "w") as f:
        f.write(OVERRIDE % (USER_DIR, window[0], window[1]))
    try:
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24", godot_bin, "--path", ROOT, "--"] + args
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        for line in r.stdout.splitlines():
            if line.startswith("SHOT") or "SCRIPT ERROR" in line:
                print("  ", line)
    finally:
        os.remove(cfg)


def fresh_save():
    shutil.rmtree(os.path.expanduser("~/.local/share/" + USER_DIR), ignore_errors=True)


def x4(src, dst):
    im = Image.open(src).convert("RGB")
    assert im.size == (480, 270), (src, im.size)
    im.resize((1920, 1080), Image.NEAREST).save(dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--sample", action="store_true")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    raw = os.path.join(OUT, "raw")
    os.makedirs(raw, exist_ok=True)

    if a.sample:
        sd = os.path.join(OUT, "sample")
        os.makedirs(sd, exist_ok=True)
        xs = ",".join(str(x) for x in range(600, 7201, 600))
        for lv in SAMPLE:
            fresh_save()
            print(lv)
            godot(["--shot=game:%s:x0" % lv, "--store", "--no-streak", "--cond=day:clear",
                   "--xs=" + xs, "--out=" + os.path.join(sd, lv + ".png")], a.godot, (1440, 810))
        return

    # Feature graphic: 553 x 270 at 2x in a 1106 x 540 window, cropped to 512 x 250.
    fresh_save()
    print("feature graphic")
    godot(["--shot=feature", "--store", "--no-streak", "--frames=205",
           "--out=" + os.path.join(raw, "feature.png")], a.godot, (1106, 540))
    im = Image.open(os.path.join(raw, "feature.png")).convert("RGB")
    w, h = im.size
    left = (w - 512) // 2
    top = h - 250 - 4  # keep the deck, lose a strip of sky
    im = im.crop((left, top, left + 512, top + 250)).resize((1024, 500), Image.NEAREST)
    im.save(os.path.join(OUT, "feature_graphic_1024x500.png"))

    for i, (name, spec, flags, x) in enumerate(SHOTS, 1):
        fresh_save()
        print(name)
        args = ["--shot=" + spec, "--store", "--no-streak"] + flags.split()
        out = os.path.join(raw, name + ".png")
        if x is not None:
            args.append("--xs=%d" % x)
        godot(args + ["--out=" + out], a.godot, (1440, 810))
        src = out if x is None else out[:-4] + "_x%d.png" % x
        x4(src, os.path.join(OUT, "screenshot_%d_%s.png" % (i, name)))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
