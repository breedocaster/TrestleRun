"""Calibrate the league's rivals (dev): distances they reach on endless lines built like
Endless.endless_plan, for a range of slip rates (see Challenges.RIVAL_SLIP) and numbers of tries.

    python3 tools/endless/league_calibrate.py check_*.log

Reads the --endless-check lines directly (same data as endless_table.gd). Mirrors
Challenges.rival_best; the lines are sampled with Python's RNG, so they're like the
game's, not the same ones.
"""
import json
import math
import random
import statistics
import sys

TIERS = [118, 130, 142, 154, 166]
STEP = 4
MIN_WINDOW = 75
PX_PER_M = 8.0


def load(paths):
    t = {}
    native = {}
    for p in paths:
        for line in open(p):
            if line.startswith("ENDLESS {"):
                r = json.loads(line[8:])
                t.setdefault(r["key"], {})[r["tier"]] = r
    return t


NATIVE = {"dusty_trail": 118, "copper_canyon": 122, "rustyard": 126, "night_trestle": 130, "mesa_springs": 134,
          "lantern_mine": 138, "hoodoo_loops": 142, "hoist_yard": 146, "skyline_pass": 150, "quarry_cliffs": 154,
          "rocket_ridge": 156, "last_trestle": 158, "s1_hayfield": 116, "s1_clothesline": 120, "s1_powerlines": 124,
          "s2_siding": 126, "s2_chutes": 130, "s2_roundhouse": 134, "s3_apple_row": 132, "s3_creek": 136,
          "s3_hollow_oak": 140, "s4_fairgrounds": 140, "s4_drome": 144, "s4_grandstand": 148}


def plan(table, rng, n=90):
    out, recent = [], []
    for i in range(n):
        tier = TIERS[min(i // STEP, len(TIERS) - 1)]
        keys, ws = [], []
        for k, by in table.items():
            e = by.get(tier)
            if not e or not e["ok"][0] or e["min"] < MIN_WINDOW:
                continue
            w = math.exp(-abs(NATIVE[k.split("/")[0]] - tier) / 14.0)
            if k in recent:
                w *= 0.05
            keys.append(k)
            ws.append(w)
        if not keys:
            continue
        k = rng.choices(keys, ws)[0]
        out.append((k, tier))
        recent = (recent + [k])[-14:]
    return out


def rival_best(table, pl, slip, rng, tries):
    best = 0
    for _ in range(tries):
        x = 0.0
        for k, tier in pl:
            e = table[k][tier]
            len_m = e["len"] / PX_PER_M
            fell = -1.0
            ws = e["w"]
            for j, w in enumerate(ws):
                f = 75.0 / max(16.0, w)
                if rng.random() < min(0.9, slip * f):
                    fell = min(1.0, (j + rng.random()) / (len(ws) + 1))
                    break
            if fell < 0 and rng.random() < 0.004:
                fell = rng.random()
            if fell >= 0:
                x += len_m * fell
                break
            x += len_m + 30.0
        best = max(best, int(x))
    return best


def main(paths):
    table = load(paths)
    print(len(table), "stretches")
    rng = random.Random(1)
    lines = [plan(table, rng) for _ in range(6)]
    for slip in [0.06, 0.08, 0.1, 0.13, 0.17, 0.22, 0.28, 0.35, 0.45, 0.6]:
        for tries in [1, 4, 7]:
            ds = [rival_best(table, pl, slip, rng, tries) for pl in lines for _ in range(30)]
            q = statistics.quantiles(ds, n=4)
            print(f"slip {slip:5.3f} tries {tries:2d}: median {statistics.median(ds):6.0f} m  quartiles {q[0]:6.0f} {q[2]:6.0f}")


if __name__ == "__main__":
    main(sys.argv[1:])
