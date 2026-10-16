#!/usr/bin/env python3
"""Fill in PLAY_IDS in scripts/achievements.gd from Play Console's resource file.

Play Console makes its own achievement ids ("CgkI..."). After importing the
achievements: Play Console > Grow > Play Games Services > Setup and management >
Achievements > Get resources, copy the Android XML into a file (games-ids.xml),
then run:

    python3 tools/store/play_ids.py games-ids.xml          # print the dictionary
    python3 tools/store/play_ids.py games-ids.xml --write  # and put it in achievements.gd

It matches each <string name="achievement_..."> to an achievement by name (Play makes
the resource name from the achievement name), and prints the Game ID (app_id) you
need in the Android export preset.
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACH = ROOT / "scripts" / "achievements.gd"


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]", "", s.lower())


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    tree = ET.parse(sys.argv[1])
    res = {e.get("name", ""): (e.text or "").strip() for e in tree.getroot().iter("string")}
    src = ACH.read_text()
    # LIST rows: ["id", "NAME", ...
    ours = re.findall(r'^\s*\["([a-z0-9_]+)", "([^"]+)"', src, re.M)
    by_name = {norm(name): aid for aid, name in ours}
    found, missing = {}, []
    for key, val in res.items():
        if key.startswith("achievement_"):
            aid = by_name.get(norm(key[len("achievement_"):]))
            if aid:
                found[aid] = val
            else:
                missing.append(key)
    lines = ["const PLAY_IDS := {"]
    for aid, _ in ours:
        if aid in found:
            lines.append('\t"%s": "%s",' % (aid, found[aid]))
    lines.append("}")
    block = "\n".join(lines)
    print(block)
    print("\nGame ID (Android export preset > GodotPlayGameServices > game_id): %s" % res.get("app_id", "?"))
    not_matched = [aid for aid, _ in ours if aid not in found]
    if not_matched:
        print("No Play id for: " + ", ".join(not_matched))
    if missing:
        print("Play resources that match no achievement here: " + ", ".join(missing))
    if "--write" in sys.argv:
        new, n = re.subn(r"const PLAY_IDS := \{[^}]*\}", block, src, count=1)
        if n != 1:
            print("couldn't find PLAY_IDS in achievements.gd")
            return 1
        ACH.write_text(new)
        print("wrote %d ids into %s" % (len(found), ACH.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
