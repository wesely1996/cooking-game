#!/usr/bin/env python3
"""Generates the placeholder comic-style SVG art for items and equipment.

Every picture uses the same rules so the set looks consistent: a 128x128
canvas, thick dark ink outlines, flat fills, a light highlight and hatched
shadow lines. Run from the repository root:

    python3 tools/art/generate_art.py

The files land in art/items/<item id>.svg and art/equipment/<id>.svg, which is
where the game looks them up. Any file can later be replaced by hand-drawn art.
"""
import math
import os

INK = "#1d1a2f"
W = 5  # outline width
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art")


def svg(*parts):
    body = "\n".join(p for p in parts if p)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">\n'
            f'{body}\n</svg>\n')


def style(fill, width=W):
    return f'fill="{fill}" stroke="{INK}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"'


def path(d, fill, width=W):
    return f'<path d="{d}" {style(fill, width)}/>'


def circle(cx, cy, r, fill, width=W):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" {style(fill, width)}/>'


def ellipse(cx, cy, rx, ry, fill, width=W, rot=0):
    t = f' transform="rotate({rot} {cx} {cy})"' if rot else ""
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" {style(fill, width)}{t}/>'


def rect(x, y, w, h, fill, r=6, width=W, rot=0, cx=None, cy=None):
    t = f' transform="rotate({rot} {cx if cx is not None else x + w / 2} {cy if cy is not None else y + h / 2})"' if rot else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" {style(fill, width)}{t}/>'


def shine(cx, cy, rx, ry, rot=-30):
    """White highlight blob (no outline)."""
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#ffffff" fill-opacity="0.75" transform="rotate({rot} {cx} {cy})"/>'


def hatch(x0, y0, x1, y1, n=4, width=2.5):
    """A few parallel ink strokes for shading, Borderlands style."""
    out = []
    for i in range(n):
        dx = i * 7
        out.append(f'<line x1="{x0 + dx}" y1="{y0}" x2="{x1 + dx}" y2="{y1}" stroke="{INK}" stroke-width="{width}" stroke-linecap="round" stroke-opacity="0.55"/>')
    return "\n".join(out)


def shadow(cx=64, cy=112, rx=40, ry=8):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{INK}" fill-opacity="0.18"/>'


def leaf(cx, cy, length, angle, fill="#3fae49", width=4):
    a = math.radians(angle)
    ex, ey = cx + math.cos(a) * length, cy + math.sin(a) * length
    nx, ny = -math.sin(a) * length * 0.35, math.cos(a) * length * 0.35
    mx, my = (cx + ex) / 2, (cy + ey) / 2
    d = f"M{cx:.1f},{cy:.1f} Q{mx + nx:.1f},{my + ny:.1f} {ex:.1f},{ey:.1f} Q{mx - nx:.1f},{my - ny:.1f} {cx:.1f},{cy:.1f} Z"
    vein = f'<line x1="{cx:.1f}" y1="{cy:.1f}" x2="{mx:.1f}" y2="{my:.1f}" stroke="{INK}" stroke-width="2" stroke-opacity="0.6"/>'
    return path(d, fill, width) + "\n" + vein


def blobs(points, r, fill, width=3):
    return "\n".join(circle(x, y, r, fill, width) for x, y in points)


def cubes(points, size, fill, width=3):
    return "\n".join(rect(x - size / 2, y - size / 2, size, size, fill, 2, width, rot=(x * 7 + y * 3) % 30 - 15) for x, y in points)


def plate(cy=78, rx=54, ry=26):
    return ellipse(64, cy, rx, ry, "#f7f4ee") + "\n" + ellipse(64, cy - 2, rx - 14, ry - 8, "#ebe5da", 2.5)


def pizza_disc(crust, top, rx=52, ry=40, cy=68):
    return ellipse(64, cy, rx, ry, crust) + "\n" + ellipse(64, cy - 2, rx - 10, ry - 9, top, 3)


# --- Items -------------------------------------------------------------------

TOMATO_RED = "#e5352b"
CHEESE = "#fffaf0"
DOUGH = "#f3d9a4"
CRUST = "#e0a85a"
PASTA = "#f6d860"
BASIL = "#3fae49"

ITEMS = {
    "flour": svg(
        shadow(),
        path("M30,40 Q26,100 36,108 L92,108 Q102,100 98,40 Q82,30 64,34 Q46,30 30,40 Z", "#f2e6c9"),
        path("M42,30 Q64,16 86,30 L80,42 Q64,36 48,42 Z", "#e8d8b0", 4),
        hatch(78, 60, 72, 100, 3),
        '<path d="M64,62 L64,96 M64,70 l-8,-6 M64,70 l8,-6 M64,80 l-8,-6 M64,80 l8,-6 M64,90 l-8,-6 M64,90 l8,-6" stroke="#c49a3c" stroke-width="4" fill="none" stroke-linecap="round"/>',
    ),
    "water": svg(
        shadow(),
        path("M48,14 L80,14 L80,30 Q100,42 100,64 L100,100 Q100,110 90,110 L38,110 Q28,110 28,100 L28,64 Q28,42 48,30 Z", "#8fd3f4"),
        path("M30,70 L98,70 L98,100 Q98,108 90,108 L38,108 Q30,108 30,100 Z", "#3fa2e0", 0),
        path("M48,14 L80,14 L80,30 Q100,42 100,64 L100,100 Q100,110 90,110 L38,110 Q28,110 28,100 L28,64 Q28,42 48,30 Z", "none"),
        rect(46, 6, 36, 12, "#2f6fb5", 4, 4),
        shine(44, 56, 6, 14, 0),
    ),
    "egg": svg(
        shadow(rx=30),
        path("M64,14 C94,14 104,62 100,82 C96,104 80,112 64,112 C48,112 32,104 28,82 C24,62 34,14 64,14 Z", "#fdf6e3"),
        hatch(82, 74, 76, 100, 3),
        shine(50, 44, 8, 14),
    ),
    "tomato": svg(
        shadow(),
        circle(64, 68, 42, TOMATO_RED),
        hatch(86, 76, 78, 100, 3),
        path("M64,30 L72,22 L76,34 L90,32 L80,42 L64,38 L48,42 L38,32 L52,34 L56,22 Z", "#3a9d3f", 4),
        shine(46, 54, 8, 14),
    ),
    "garlic": svg(
        shadow(),
        path("M64,20 C70,36 100,44 100,76 C100,100 82,110 64,110 C46,110 28,100 28,76 C28,44 58,36 64,20 Z", "#f4efe2"),
        '<path d="M64,40 Q50,70 56,108 M64,40 Q78,70 72,108 M60,30 Q36,60 40,100 M68,30 Q92,60 88,100" stroke="#c9bfa5" stroke-width="3" fill="none"/>',
        path("M58,22 L64,8 L70,22 Z", "#e8dfc8", 4),
        shine(46, 66, 6, 12),
    ),
    "basil": svg(
        shadow(rx=34),
        leaf(64, 104, 62, -100, BASIL, 5),
        leaf(62, 100, 48, -145, "#4cc457", 5),
        leaf(66, 100, 48, -40, "#36a03f", 5),
    ),
    "mozzarella": svg(
        shadow(),
        circle(64, 68, 40, CHEESE),
        path("M40,92 Q64,108 92,88", "none", 3),
        hatch(80, 76, 74, 100, 3),
        shine(48, 52, 10, 14),
    ),
    "bread": svg(
        shadow(rx=50),
        path("M14,84 C14,48 114,40 114,74 C114,98 14,108 14,84 Z", "#d69a4a"),
        '<path d="M38,66 l10,16 M58,60 l10,16 M78,58 l10,16" stroke="#8a5a22" stroke-width="5" stroke-linecap="round"/>',
        shine(40, 62, 6, 16, -70),
    ),
    "whole_pizza": svg(
        shadow(rx=52),
        pizza_disc("#d9913f", "#e94b2c"),
        blobs([(50, 58), (78, 60), (64, 78), (44, 78), (84, 80)], 8, "#fff3cf"),
        leaf(60, 64, 14, -30, BASIL, 3), leaf(80, 74, 12, 160, BASIL, 3),
    ),
    "pizza_dough_mix": svg(
        shadow(),
        path("M16,100 Q30,52 64,48 Q98,52 112,100 Z", "#f2e6c9"),
        ellipse(64, 76, 22, 10, "#5ab4ea", 4),
        shine(58, 74, 8, 3, 0),
        hatch(88, 74, 82, 96, 3),
    ),
    "pizza_dough": svg(
        shadow(rx=44),
        path("M20,96 C14,60 44,40 64,40 C84,40 114,60 108,96 Z", DOUGH),
        hatch(88, 66, 80, 92, 3),
        shine(46, 60, 8, 12),
    ),
    "pizza_base": svg(
        shadow(rx=52),
        ellipse(64, 72, 54, 32, CRUST),
        ellipse(64, 70, 44, 24, DOUGH, 3),
        '<circle cx="50" cy="66" r="2" fill="#c49a5a"/><circle cx="74" cy="76" r="2" fill="#c49a5a"/><circle cx="68" cy="60" r="2" fill="#c49a5a"/>',
    ),
    "pasta_dough_mix": svg(
        shadow(),
        path("M16,100 Q30,52 64,48 Q98,52 112,100 Z", "#f2e6c9"),
        circle(64, 74, 13, "#f7b32b", 4),
        shine(60, 70, 4, 3, 0),
        hatch(88, 74, 82, 96, 3),
    ),
    "pasta_dough": svg(
        shadow(rx=44),
        path("M20,96 C14,60 44,40 64,40 C84,40 114,60 108,96 Z", "#f6c94c"),
        hatch(88, 66, 80, 92, 3),
        shine(46, 60, 8, 12),
    ),
    "fresh_pasta": svg(
        shadow(rx=46),
        '\n'.join(path(f"M{22 + i * 10},{40 + (i % 2) * 6} Q{40 + i * 8},{80} {30 + i * 12},{104}", "none", 9) for i in range(7)),
        '\n'.join(f'<path d="M{22 + i * 10},{40 + (i % 2) * 6} Q{40 + i * 8},{80} {30 + i * 12},{104}" stroke="{PASTA}" stroke-width="4" fill="none" stroke-linecap="round"/>' for i in range(7)),
    ),
    "cooked_pasta": svg(
        shadow(rx=54, cy=110),
        plate(),
        '\n'.join(f'<path d="M{34 + i * 6},{70 + (i % 3) * 4} q12,-14 24,0 t24,0" stroke="{INK}" stroke-width="8" fill="none" stroke-linecap="round"/>' for i in range(5)),
        '\n'.join(f'<path d="M{34 + i * 6},{70 + (i % 3) * 4} q12,-14 24,0 t24,0" stroke="#f8e28a" stroke-width="4" fill="none" stroke-linecap="round"/>' for i in range(5)),
    ),
    "chopped_tomato": svg(
        shadow(rx=44),
        cubes([(40, 80), (62, 72), (84, 82), (50, 96), (74, 98), (56, 56), (80, 58)], 20, TOMATO_RED),
        '<circle cx="62" cy="72" r="3" fill="#ffd166"/><circle cx="50" cy="96" r="3" fill="#ffd166"/>',
    ),
    "tomato_sauce": svg(
        shadow(rx=46),
        path("M18,62 L110,62 Q106,108 64,108 Q22,108 18,62 Z", "#f0f0f0"),
        ellipse(64, 62, 46, 14, "#d62d20"),
        shine(48, 58, 10, 3, 0),
        hatch(90, 76, 84, 98, 3),
    ),
    "chopped_garlic": svg(
        shadow(rx=40),
        cubes([(44, 84), (62, 76), (82, 86), (54, 100), (74, 102), (66, 60)], 16, "#f4efe2"),
    ),
    "sliced_mozzarella": svg(
        shadow(rx=50),
        ellipse(40, 84, 24, 14, CHEESE), ellipse(64, 72, 24, 14, CHEESE), ellipse(88, 60, 24, 14, CHEESE),
        shine(84, 56, 8, 3, 0),
    ),
    "toast": svg(
        shadow(rx=46),
        path("M24,96 L24,52 Q24,22 64,22 Q104,22 104,52 L104,96 Z", "#c97b2e"),
        path("M32,92 L32,54 Q32,30 64,30 Q96,30 96,54 L96,92 Z", "#f0c27a", 3),
        '<path d="M40,50 l40,30 M40,66 l30,22 M52,40 l40,30" stroke="#9c5a1c" stroke-width="5" stroke-linecap="round"/>',
    ),
    "raw_pizza_margherita": svg(
        shadow(rx=52),
        pizza_disc(DOUGH, "#e9503a"),
        blobs([(48, 60), (76, 58), (62, 76), (84, 78), (42, 80)], 9, CHEESE),
    ),
    "pizza_margherita": svg(
        shadow(rx=52),
        pizza_disc("#c97b2e", "#d9361f"),
        blobs([(48, 60), (76, 58), (62, 76), (84, 78), (42, 80)], 10, "#fff1c1"),
        '<circle cx="46" cy="58" r="3" fill="#e0a040"/><circle cx="80" cy="76" r="3" fill="#e0a040"/>',
        leaf(58, 62, 14, -20, BASIL, 3), leaf(76, 70, 13, 200, BASIL, 3), leaf(52, 82, 12, 30, BASIL, 3),
        hatch(96, 70, 92, 84, 2),
    ),
    "pasta_pomodoro": svg(
        shadow(rx=54, cy=110),
        plate(),
        '\n'.join(f'<path d="M{34 + i * 6},{72 + (i % 3) * 4} q12,-14 24,0 t24,0" stroke="{INK}" stroke-width="8" fill="none" stroke-linecap="round"/>' for i in range(5)),
        '\n'.join(f'<path d="M{34 + i * 6},{72 + (i % 3) * 4} q12,-14 24,0 t24,0" stroke="#f8e28a" stroke-width="4" fill="none" stroke-linecap="round"/>' for i in range(5)),
        ellipse(64, 66, 20, 10, "#d62d20", 4),
        leaf(62, 60, 14, -60, BASIL, 3), leaf(66, 60, 14, -120, "#4cc457", 3),
    ),
    "bruschetta": svg(
        shadow(rx=52),
        rect(14, 62, 56, 34, "#e8a85a", 10, rot=-8),
        rect(58, 56, 56, 34, "#e8a85a", 10, rot=8),
        cubes([(30, 70), (44, 76), (56, 68), (74, 64), (88, 70), (100, 66)], 11, TOMATO_RED, 2.5),
        cubes([(38, 82), (82, 80)], 8, "#f4efe2", 2),
        leaf(46, 66, 12, -40, BASIL, 3), leaf(92, 60, 12, -140, BASIL, 3),
    ),
    "pizza_slice": svg(
        shadow(rx=40),
        path("M24,40 Q64,20 104,40 L64,112 Z", "#e94b2c"),
        path("M24,40 Q64,20 104,40 Q64,28 24,40 Z", "#c97b2e", 6),
        blobs([(52, 52), (74, 50), (64, 72), (60, 92)], 7, "#fff1c1"),
        leaf(66, 58, 12, 20, BASIL, 3),
    ),
    "caprese_salad": svg(
        shadow(rx=54, cy=110),
        plate(),
        ellipse(36, 74, 14, 9, CHEESE, 3), ellipse(52, 70, 13, 9, TOMATO_RED, 3),
        ellipse(68, 74, 14, 9, CHEESE, 3), ellipse(84, 70, 13, 9, TOMATO_RED, 3),
        ellipse(96, 76, 12, 8, CHEESE, 3),
        leaf(44, 64, 12, -70, BASIL, 3), leaf(76, 62, 12, -110, BASIL, 3),
    ),
    "burnt_food": svg(
        shadow(rx=46),
        path("M20,96 C14,64 40,52 52,58 C58,40 86,44 90,60 C110,58 116,90 104,98 Z", "#2b2523"),
        '<path d="M40,70 l10,10 M70,64 l8,12 M88,78 l-8,8" stroke="#ff7b2b" stroke-width="3" stroke-linecap="round"/>',
        '<path d="M46,40 q-8,-10 0,-20 q8,-10 0,-18 M74,38 q-8,-10 0,-20 q8,-10 0,-18" stroke="#8a8a8a" stroke-width="5" fill="none" stroke-linecap="round" stroke-opacity="0.8"/>',
    ),
}

# --- Equipment ---------------------------------------------------------------

EQUIPMENT = {
    "knife": svg(
        shadow(rx=46),
        path("M18,92 L80,30 Q100,18 104,28 Q108,38 92,52 L36,100 Z", "#dfe6ee"),
        rect(10, 88, 34, 16, "#8a4b24", 5, rot=-45, cx=27, cy=96),
        shine(78, 40, 4, 16, 45),
    ),
    "mixing_bowl": svg(
        shadow(rx=52),
        path("M12,54 L116,54 Q110,108 64,108 Q18,108 12,54 Z", "#4f9de0"),
        ellipse(64, 54, 52, 12, "#9ccbf2"),
        hatch(92, 66, 84, 98, 3),
        shine(30, 70, 5, 12, 20),
    ),
    "rolling_pin": svg(
        shadow(rx=54),
        rect(30, 52, 68, 28, "#e3b06b", 14, rot=-15),
        rect(6, 64, 28, 12, "#a8672f", 6, rot=-15, cx=64, cy=66),
        rect(94, 48, 28, 12, "#a8672f", 6, rot=-15, cx=64, cy=66),
        shine(60, 58, 18, 3, -15),
    ),
    "sauce_pot": svg(
        shadow(rx=52),
        rect(4, 56, 22, 10, "#2b2523", 4),
        rect(102, 56, 22, 10, "#2b2523", 4),
        path("M22,50 L106,50 L100,104 Q64,112 28,104 Z", "#d94a3a"),
        ellipse(64, 50, 42, 10, "#4a2a26"),
        hatch(84, 64, 78, 98, 3),
    ),
    "boil_pot": svg(
        shadow(rx=54),
        rect(2, 50, 22, 10, "#2b2523", 4),
        rect(104, 50, 22, 10, "#2b2523", 4),
        path("M18,40 L110,40 L104,106 Q64,114 24,106 Z", "#b9c4cf"),
        ellipse(64, 40, 46, 11, "#5ab4ea"),
        '<path d="M44,28 q-6,-8 0,-16 M64,26 q-6,-8 0,-16 M84,28 q-6,-8 0,-16" stroke="#ffffff" stroke-width="4" fill="none" stroke-linecap="round"/>',
        hatch(86, 56, 80, 96, 3),
    ),
    "oven": svg(
        shadow(rx=58, cy=116),
        path("M8,112 L8,70 Q8,14 64,14 Q120,14 120,70 L120,112 Z", "#c0563a"),
        '<path d="M14,60 L114,60 M12,84 L116,84 M40,22 L40,60 M88,22 L88,60 M26,60 L26,84 M64,60 L64,84 M102,60 L102,84" stroke="#8a3424" stroke-width="3"/>',
        path("M34,112 L34,90 Q34,66 64,66 Q94,66 94,90 L94,112 Z", "#2b2523"),
        path("M44,112 Q50,92 58,104 Q62,86 70,102 Q78,90 84,112 Z", "#ff9f1c", 3),
    ),
    "pasta_maker": svg(
        shadow(rx=50),
        rect(22, 46, 70, 56, "#c5ced8", 8),
        rect(30, 56, 54, 14, "#7d8996", 4, 3),
        '<path d="M92,70 L110,70 L110,40" stroke="#1d1a2f" stroke-width="6" fill="none" stroke-linecap="round"/>',
        circle(110, 36, 8, "#e3463a", 4),
        hatch(70, 78, 64, 96, 3),
    ),
    "serving_window": svg(
        shadow(rx=46),
        path("M24,88 Q24,40 64,40 Q104,40 104,88 Z", "#f6c94c"),
        rect(16, 86, 96, 14, "#c9971c", 5),
        circle(64, 34, 7, "#f6c94c", 4),
        shine(48, 58, 6, 14, 30),
    ),
    "trash": svg(
        shadow(rx=40),
        path("M30,40 L98,40 L90,112 L38,112 Z", "#6c7a89"),
        rect(22, 28, 84, 14, "#4d5966", 5),
        rect(52, 18, 24, 12, "#4d5966", 4, 4),
        '<path d="M50,54 L54,100 M64,54 L64,100 M78,54 L74,100" stroke="#1d1a2f" stroke-width="4" stroke-linecap="round" stroke-opacity="0.6"/>',
    ),
    "crate": svg(
        rect(8, 20, 112, 96, "#c98c4a", 8),
        '<path d="M8,52 L120,52 M8,84 L120,84" stroke="#1d1a2f" stroke-width="4"/>',
        '<path d="M14,26 L114,110" stroke="#8a5a2a" stroke-width="6" stroke-opacity="0.5"/>',
    ),
}


def main():
    for folder, table in (("items", ITEMS), ("equipment", EQUIPMENT)):
        os.makedirs(os.path.join(OUT, folder), exist_ok=True)
        for name, content in table.items():
            with open(os.path.join(OUT, folder, name + ".svg"), "w") as f:
                f.write(content)
    print(f"wrote {len(ITEMS)} items and {len(EQUIPMENT)} equipment pictures")


if __name__ == "__main__":
    main()
