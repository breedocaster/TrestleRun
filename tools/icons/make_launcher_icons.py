#!/usr/bin/env python3
"""Launcher icons from the game icon (icon.svg's shapes, redrawn here).

Writes, into assets/icon/:
  launcher_foreground_432.png  rider, bike (transparent around them)
  launcher_background_432.png  sky, sun, horizon, ground and trestle deck, full bleed
  launcher_monochrome_432.png  one-colour silhouette for Android 13+ themed icons
and store/play_icon_512.png, the 512 x 512 hi-res icon Play Console asks for.

Adaptive icons are 108 dp layers of which a launcher shows the middle 72 dp (through
its own mask), so the icon's 32 x 32 art is drawn 9 px a unit with (0, 0) at (72, 72)
and the background bands run on past the edges. Godot's default puts the whole square
icon on the 108 dp layer, so a launcher shows a zoomed-in crop (deck and wheels cut).

  python3 tools/icons/make_launcher_icons.py
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SS = 4  # supersampling for smooth circle edges

# icon.svg, as (layer, shape, args, colour). Units are the SVG's 32 x 32 grid.
BACK = [
    ("rect", (-20, -20, 52, 14), "#2b1b3d"),  # sky
    ("circle", (23, 9, 4), "#fff1c1"),  # sun
    ("rect", (-20, 14, 52, 20), "#a8445a"),  # horizon
    ("rect", (-20, 20, 52, 52), "#3a1c2e"),  # ground
    ("rect", (-20, 25, 52, 27), "#c08a4a"),  # deck
    ("rect", (-20, 25, 52, 26), "#f0c27a"),  # deck top
    ("rect", (5, 27, 7, 52), "#6b3f2a"),  # posts
    ("rect", (21, 27, 23, 52), "#6b3f2a"),
    ("rect", (-11, 27, -9, 52), "#6b3f2a"),  # (the next posts along, past the edge)
    ("rect", (37, 27, 39, 52), "#6b3f2a"),
]
FORE = [
    ("circle", (9, 21.5, 3.5), "#17121a"),  # wheels
    ("circle", (9, 21.5, 1.5), "#9aa3ad"),
    ("circle", (23, 21.5, 3.5), "#17121a"),
    ("circle", (23, 21.5, 1.5), "#9aa3ad"),
    ("rect", (12, 17, 19, 21), "#6b6f78"),  # engine
    ("poly", [(13, 14), (19, 14), (21, 17), (12, 18)], "#c8323c"),  # tank
    ("rect", (7, 14, 13, 16), "#2a1e1e"),  # seat
    ("poly", [(4, 14), (8, 14), (8, 16), (6, 16)], "#7a1c2a"),  # fender
    ("rect", (21, 15, 23, 17), "#ffe9a8"),  # headlight
    ("rect", (10, 9, 13, 15), "#2f3b52"),  # rider
    ("rect", (12, 11, 19, 13), "#2f3b52"),  # arm
    ("circle", (13, 7, 2.6), "#e8e2d0"),  # helmet
    ("rect", (13, 6, 16, 8), "#2b4c6f"),  # visor
]
# Silhouette: holes punched for the hubs and the visor so it still reads as a rider.
MONO = [
    ("circle", (23, 9, 4), 1),
    ("rect", (6, 25, 26, 27), 1),
    ("circle", (9, 21.5, 3.5), 1), ("circle", (9, 21.5, 1.5), 0),
    ("circle", (23, 21.5, 3.5), 1), ("circle", (23, 21.5, 1.5), 0),
    ("rect", (12, 17, 19, 21), 1),
    ("poly", [(13, 14), (19, 14), (21, 17), (12, 18)], 1),
    ("rect", (7, 14, 13, 16), 1),
    ("poly", [(4, 14), (8, 14), (8, 16), (6, 16)], 1),
    ("rect", (21, 15, 23, 17), 1),
    ("rect", (10, 9, 13, 15), 1),
    ("rect", (12, 11, 19, 13), 1),
    ("circle", (13, 7, 2.6), 1), ("rect", (13, 6, 16, 8), 0),
]


def draw(shapes, size, scale, off, mode="RGBA", bg=(0, 0, 0, 0)):
    big = Image.new(mode, (size * SS, size * SS), bg)
    d = ImageDraw.Draw(big)
    s = scale * SS
    o = off * SS

    def p(x, y):
        return (o + x * s, o + y * s)

    for kind, a, col in shapes:
        if mode == "L":
            col = 255 if col else 0
        if kind == "rect":
            x0, y0 = p(a[0], a[1])
            x1, y1 = p(a[2], a[3])
            d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=col)
        elif kind == "circle":
            cx, cy = p(a[0], a[1])
            r = a[2] * s
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
        else:
            d.polygon([p(x, y) for x, y in a], fill=col)
    return big.resize((size, size), Image.LANCZOS)


def main():
    out = os.path.join(ROOT, "assets", "icon")
    os.makedirs(out, exist_ok=True)
    draw(FORE, 432, 9, 72).save(os.path.join(out, "launcher_foreground_432.png"))
    draw(BACK, 432, 9, 72, "RGB", (0, 0, 0)).save(os.path.join(out, "launcher_background_432.png"))
    a = draw(MONO, 432, 9, 72, "L", 0)
    mono = Image.new("RGBA", (432, 432), (255, 255, 255, 0))
    mono.putalpha(a)
    mono.save(os.path.join(out, "launcher_monochrome_432.png"))
    # Play's hi-res icon: the square icon, edge to edge (Play rounds the corners).
    store = os.path.join(ROOT, "store")
    os.makedirs(store, exist_ok=True)
    icon = draw(BACK, 512, 16, 0, "RGB", (0, 0, 0))
    icon.paste(draw(FORE, 512, 16, 0), (0, 0), draw(FORE, 512, 16, 0))
    icon.save(os.path.join(store, "play_icon_512.png"))
    print("wrote", out, "and", store)


if __name__ == "__main__":
    main()
