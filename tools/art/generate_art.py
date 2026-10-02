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


# --- Shared helpers for the newer cuisines ------------------------------------

def bowl(top, rim="#f0f0f0", extra=""):
    """A bowl seen from the side with something in it."""
    return "\n".join([
        shadow(rx=46),
        path("M16,62 L112,62 Q108,110 64,110 Q20,110 16,62 Z", rim),
        ellipse(64, 62, 48, 14, top),
        extra,
        hatch(92, 76, 86, 100, 3),
    ])


def sack(fill, mark):
    return svg(
        shadow(),
        path("M30,40 Q26,100 36,108 L92,108 Q102,100 98,40 Q82,30 64,34 Q46,30 30,40 Z", fill),
        path("M42,30 Q64,16 86,30 L80,42 Q64,36 48,42 Z", fill, 4),
        hatch(78, 60, 72, 100, 3),
        mark,
    )


def drumstick(meat, bone="#fdf6e3"):
    return "\n".join([
        shadow(rx=44),
        path("M70,58 L100,28", "none", 14), f'<path d="M70,58 L100,28" stroke="{bone}" stroke-width="8" stroke-linecap="round"/>',
        circle(104, 24, 8, bone, 4), circle(96, 18, 7, bone, 4),
        path("M24,90 C10,62 34,34 60,44 C78,52 82,74 70,88 C58,104 32,108 24,90 Z", meat),
        shine(40, 62, 6, 12, -30),
        hatch(60, 80, 54, 98, 3),
    ])


def disc(fill, spots="", rx=52, ry=30, cy=74):
    return "\n".join([shadow(rx=52), ellipse(64, cy, rx, ry, fill), spots])


def skewer(pieces, colors):
    out = [shadow(rx=50), '<path d="M10,104 L118,20" stroke="#1d1a2f" stroke-width="9" stroke-linecap="round"/>',
           '<path d="M10,104 L118,20" stroke="#d9b07a" stroke-width="4" stroke-linecap="round"/>']
    for i in range(pieces):
        x, y = 34 + i * 22, 86 - i * 17
        out.append(rect(x - 13, y - 13, 26, 26, colors[i % len(colors)], 7, 4, rot=-38))
    return "\n".join(out)


def cob(fill, kernel, burnt=None, angle=20):
    """A corn cob (rotated as one piece so the kernels stay on it)."""
    kernels = []
    for row in range(8):
        for col in range(3):
            color = burnt if burnt and (row + col) % 3 == 0 else kernel
            kernels.append(circle(55 + col * 9, 28 + row * 9.5, 3.4, color, 1.5))
    return (f'<g transform="rotate({angle} 64 64)">' + rect(46, 18, 36, 92, fill, 18) + "\n".join(kernels) + "</g>")


GREEN = "#3fae49"
MEXICAN_ITEMS = {
    "corn_flour": sack("#f6d860", '<path d="M64,58 L64,96" stroke="#c49a3c" stroke-width="5" stroke-linecap="round"/>' + "\n" + ellipse(64, 76, 10, 18, "#f7b32b", 3)),
    "beef": svg(shadow(rx=46), path("M18,72 C18,40 70,30 100,44 C120,56 112,92 80,98 C50,104 18,96 18,72 Z", "#c8303a"),
                '<path d="M30,70 C48,58 76,56 98,64" stroke="#fde8e0" stroke-width="7" fill="none" stroke-linecap="round"/>', shine(46, 52, 6, 12, -60)),
    "onion": svg(shadow(rx=36), path("M64,22 C80,40 104,52 100,80 C96,104 32,104 28,80 C24,52 48,40 64,22 Z", "#a35bb5"),
                 '<path d="M64,30 Q48,64 54,100 M64,30 Q80,64 74,100" stroke="#7b3a8c" stroke-width="3" fill="none"/>', path("M60,24 L64,10 L68,24 Z", "#7b3a8c", 4), shine(46, 66, 5, 12)),
    "avocado": svg(shadow(rx=40), path("M64,14 C88,14 104,52 104,78 C104,100 86,112 64,112 C42,112 24,100 24,78 C24,52 40,14 64,14 Z", "#2e6b2f"),
                   path("M64,26 C82,26 94,56 94,78 C94,96 80,104 64,104 C48,104 34,96 34,78 C34,56 46,26 64,26 Z", "#cde77f", 3), circle(64, 78, 15, "#8a5a2e", 4), shine(58, 72, 4, 6, 0)),
    "cheese_block": svg(shadow(rx=46), path("M14,84 L94,40 L114,62 L114,94 L14,94 Z", "#f6c94c"), path("M14,84 L94,40 L114,62 L34,98 Z", "#fbe08a", 3),
                        circle(60, 82, 6, "#e0a830", 3), circle(90, 76, 5, "#e0a830", 3), circle(76, 60, 4, "#e0a830", 3)),
    "corn_cob": svg(shadow(rx=46), leaf(30, 104, 64, -62, GREEN, 5), cob("#f6d860", "#f7b32b"), leaf(98, 106, 60, -118, "#4cc457", 5)),
    "chili": svg(shadow(rx=44), path("M30,40 C70,30 108,60 104,96 C100,108 92,104 90,94 C84,70 62,56 30,52 Z", "#e5352b"), path("M30,46 L16,34", "none", 8),
                 '<path d="M30,46 L16,34" stroke="#3a9d3f" stroke-width="7" stroke-linecap="round"/>', shine(66, 52, 4, 12, -60)),
    "chocolate": svg(shadow(rx=46), rect(22, 30, 84, 70, "#6b3a1e", 8, rot=-8), '<path d="M50,34 L56,98 M76,30 L82,94 M28,62 L102,54" stroke="#4a2410" stroke-width="4"/>', shine(40, 44, 10, 3, -8)),
    "masa_mix": svg(shadow(), path("M16,100 Q30,52 64,48 Q98,52 112,100 Z", "#f6d860"), ellipse(64, 76, 22, 10, "#5ab4ea", 4), hatch(88, 74, 82, 96, 3)),
    "masa_dough": svg(shadow(rx=44), path("M20,96 C14,60 44,40 64,40 C84,40 114,60 108,96 Z", "#f3cf6a"), hatch(88, 66, 80, 92, 3), shine(46, 60, 8, 12)),
    "raw_tortilla": svg(disc("#f6e3a6")),
    "tortilla": svg(disc("#f0cf86", blobs([(44, 68), (70, 80), (84, 66), (56, 86), (90, 82)], 4, "#b8823c", 2))),
    "chopped_beef": svg(shadow(rx=44), cubes([(40, 80), (62, 72), (84, 82), (50, 96), (74, 98), (58, 56), (80, 58)], 18, "#c8303a")),
    "cooked_beef": svg(shadow(rx=44), cubes([(40, 80), (62, 72), (84, 82), (50, 96), (74, 98), (58, 56), (80, 58)], 18, "#7a4422")),
    "chopped_onion": svg(shadow(rx=40), cubes([(44, 84), (62, 76), (82, 86), (54, 100), (74, 102), (66, 60)], 15, "#e7c6ef")),
    "salsa": svg(bowl("#d9361f", extra=blobs([(48, 60), (64, 64), (80, 58)], 4, "#e7c6ef", 2) + "\n" + blobs([(56, 56), (74, 66)], 3, GREEN, 2))),
    "mashed_avocado": svg(bowl("#b5d96a", rim="#c9b59a")),
    "grated_cheese": svg(shadow(rx=42), '\n'.join(f'<path d="M{30 + i * 7},{96 - (i % 4) * 8} q6,-14 12,-24" stroke="#1d1a2f" stroke-width="8" fill="none" stroke-linecap="round"/>' for i in range(10)),
                         '\n'.join(f'<path d="M{30 + i * 7},{96 - (i % 4) * 8} q6,-14 12,-24" stroke="#f6c94c" stroke-width="4" fill="none" stroke-linecap="round"/>' for i in range(10))),
    "raw_quesadilla": svg(shadow(rx=50), path("M14,88 A50,50 0 0 1 114,88 Z", "#f6e3a6"), path("M22,88 A42,42 0 0 1 106,88", "none", 3),
                          '<path d="M24,84 L104,84" stroke="#f6c94c" stroke-width="6"/>'),
    "quesadilla": svg(shadow(rx=50), path("M14,88 A50,50 0 0 1 114,88 Z", "#e8a85a"), '<path d="M30,84 L104,84" stroke="#f6c94c" stroke-width="7"/>',
                      '<path d="M40,60 l20,-14 M58,66 l24,-16 M78,70 l20,-14" stroke="#9c5a1c" stroke-width="5" stroke-linecap="round"/>'),
    "grilled_corn": svg(shadow(rx=46), cob("#e8b840", "#f7b32b", burnt="#7a4422")),
    "mole_mix": svg(shadow(rx=44), path("M30,60 C60,52 92,66 90,90 C88,98 82,96 80,90 C76,74 58,66 30,70 Z", "#e5352b"), rect(54, 76, 40, 26, "#6b3a1e", 5, rot=12)),
    "mole_sauce": svg(bowl("#5a2a14", extra=blobs([(50, 60), (66, 58), (80, 62), (60, 66)], 2.5, "#fdf6e3", 1))),
    "chicken": svg(drumstick("#f4b8a8")),
    "cooked_chicken": svg(drumstick("#d9893a")),
    "beef_taco": svg(shadow(rx=50), path("M14,96 C14,40 114,40 114,96 Z", "#f0cf86"), blobs([(36, 66), (52, 58), (70, 56), (88, 60)], 9, "#7a4422", 3),
                     blobs([(44, 54), (64, 50), (82, 54)], 6, "#d9361f", 2.5), leaf(60, 50, 12, -30, GREEN, 3), path("M14,96 C14,52 114,52 114,96", "none", 5),
                     blobs([(46, 80), (76, 86)], 4, "#b8823c", 2)),
    "guacamole": svg(bowl("#8cc43c", rim="#c9b59a", extra=path("M88,40 L112,20 L118,46 Z", "#f6c94c", 4) + "\n" + path("M24,44 L10,22 L40,30 Z", "#f6c94c", 4)
                                                                + "\n" + blobs([(52, 60), (74, 62)], 4, "#d9361f", 2))),
    "elote": svg(shadow(rx=46), '<path d="M34,114 L50,90" stroke="#1d1a2f" stroke-width="10" stroke-linecap="round"/><path d="M34,114 L50,90" stroke="#d9b07a" stroke-width="5" stroke-linecap="round"/>',
                 cob("#e8b840", "#f7b32b", burnt="#7a4422", angle=28),
                 blobs([(62, 34), (74, 50), (64, 64), (80, 70), (70, 84)], 4.5, "#fdf6e3", 2),
                 '\n'.join(circle(58 + (i % 3) * 8, 44 + (i // 3) * 12, 2, "#e5352b", 0.5) for i in range(9))),
    "chicken_mole": svg(shadow(rx=54, cy=110), plate(), ellipse(64, 74, 38, 16, "#5a2a14", 3), path("M38,80 C30,60 48,48 64,54 C76,58 80,70 72,80 C64,90 44,92 38,80 Z", "#d9893a", 3),
                        blobs([(54, 66), (68, 62), (60, 76)], 2.5, "#fdf6e3", 1)),
}

JAPANESE_ITEMS = {
    "rice": sack("#f7f4ee", '\n'.join(ellipse(52 + (i % 3) * 12, 66 + (i // 3) * 12, 4, 7, "#e5dccb", 2) for i in range(6))),
    "salmon": svg(shadow(rx=48), path("M12,80 C20,48 90,40 116,60 C106,86 40,104 12,80 Z", "#f48a4a"),
                  '<path d="M36,62 C44,74 46,86 44,92 M58,56 C66,68 68,82 66,92 M80,52 C88,64 90,76 88,86" stroke="#fde3cf" stroke-width="4" fill="none"/>', shine(60, 56, 10, 3, -10)),
    "nori": svg(shadow(rx=46), rect(20, 26, 88, 78, "#1f3d2b", 6), '<path d="M24,46 L104,46 M24,66 L104,66 M24,86 L104,86" stroke="#2f5a3e" stroke-width="3"/>'),
    "cucumber": svg(shadow(rx=50), rect(14, 52, 100, 30, "#3a9d3f", 15, rot=-20), blobs([(40, 74), (60, 66), (80, 58), (98, 52)], 2.5, "#a8e08a", 1)),
    "ramen_noodles": svg(shadow(rx=46), rect(22, 34, 84, 66, "#f6d860", 10),
                         '\n'.join(f'<path d="M28,{44 + i * 10} q10,-8 20,0 t20,0 t20,0 t14,0" stroke="#c49a3c" stroke-width="3" fill="none"/>' for i in range(5))),
    "miso_paste": svg(shadow(rx=44), path("M24,46 L104,46 L96,106 L32,106 Z", "#f7f4ee"), ellipse(64, 46, 40, 10, "#c8873a"), rect(34, 64, 60, 20, "#e5352b", 3, 3)),
    "green_onion": svg(shadow(rx=50), rect(10, 56, 108, 16, GREEN, 8, rot=-25), rect(80, 30, 34, 16, "#f4efe2", 8, rot=-25),
                       '<path d="M108,24 l10,-6 M110,30 l12,-2" stroke="#1d1a2f" stroke-width="3" stroke-linecap="round"/>'),
    "cooked_rice": svg(bowl("#fdfbf5", rim="#3f6fb5", extra=blobs([(48, 54), (62, 50), (76, 54), (56, 58), (70, 58)], 6, "#fdfbf5", 2))),
    "sliced_salmon": svg(shadow(rx=50), '\n'.join(rect(18 + i * 30, 48, 30, 44, "#f48a4a", 6, rot=-12) for i in range(3)),
                         '\n'.join(f'<path d="M{26 + i * 30},{58} l14,22" stroke="#fde3cf" stroke-width="3"/>' for i in range(3))),
    "cucumber_sticks": svg(shadow(rx=44), '\n'.join(rect(24 + i * 18, 40 + (i % 2) * 6, 14, 60, "#a8e08a", 4, 4, rot=-10) for i in range(5)),
                           '\n'.join(f'<path d="M{26 + i * 18},{42 + (i % 2) * 6} l-2,58" stroke="#3a9d3f" stroke-width="4"/>' for i in range(5))),
    "raw_maki": svg(shadow(rx=46), rect(20, 26, 88, 78, "#1f3d2b", 6), rect(26, 32, 76, 66, "#fdfbf5", 4, 3), rect(30, 58, 68, 14, "#a8e08a", 4, 3)),
    "cooked_noodles": svg(shadow(rx=46),
                          '\n'.join(f'<path d="M{24 + i * 6},{60 + (i % 3) * 8} q10,-16 20,0 t20,0 t20,0" stroke="#1d1a2f" stroke-width="8" fill="none" stroke-linecap="round"/>' for i in range(6)),
                          '\n'.join(f'<path d="M{24 + i * 6},{60 + (i % 3) * 8} q10,-16 20,0 t20,0 t20,0" stroke="#f8e28a" stroke-width="4" fill="none" stroke-linecap="round"/>' for i in range(6))),
    "miso_mix": svg(bowl("#a7d8f0", extra=ellipse(64, 62, 20, 7, "#c8873a", 3))),
    "miso_broth": svg(bowl("#c8873a", rim="#5a2a14")),
    "chopped_green_onion": svg(shadow(rx=40), '\n'.join(circle(36 + (i % 4) * 18, 60 + (i // 4) * 20, 8, GREEN, 3) for i in range(8)),
                               '\n'.join(circle(36 + (i % 4) * 18, 60 + (i // 4) * 20, 3, "#a8e08a", 1) for i in range(8))),
    "boiled_egg": svg(shadow(rx=40), path("M20,70 C20,40 108,40 108,70 C108,100 20,100 20,70 Z", "#fdf6e3"), circle(64, 70, 18, "#f7b32b", 3), shine(52, 62, 5, 3, 0)),
    "grilled_chicken": svg(skewer(3, ["#d9893a"])),
    "salmon_nigiri": svg(shadow(rx=50), rect(20, 64, 88, 34, "#fdfbf5", 16), path("M14,66 C30,36 98,36 116,62 C100,74 30,78 14,66 Z", "#f48a4a"),
                         '<path d="M40,52 C46,60 48,66 46,70 M64,48 C70,56 72,64 70,70 M88,50 C94,58 96,64 94,68" stroke="#fde3cf" stroke-width="4" fill="none"/>'),
    "cucumber_maki": svg(shadow(rx=50), '\n'.join(circle(30 + i * 34, 72, 17, "#1f3d2b", 4) for i in range(3)),
                         '\n'.join(circle(30 + i * 34, 72, 11, "#fdfbf5", 2) for i in range(3)), '\n'.join(circle(30 + i * 34, 72, 4, "#3a9d3f", 1.5) for i in range(3))),
    "miso_ramen": svg(bowl("#c8873a", rim="#e5352b", extra="\n".join([
        '\n'.join(f'<path d="M{30 + i * 10},{64} q6,-10 12,0" stroke="#f8e28a" stroke-width="4" fill="none" stroke-linecap="round"/>' for i in range(6)),
        path("M64,52 C64,42 90,42 90,52 C90,62 64,62 64,52 Z", "#fdf6e3", 3), circle(77, 52, 6, "#f7b32b", 2),
        blobs([(42, 56), (50, 52), (100, 58)], 4, GREEN, 2),
        '<path d="M96,10 L76,60 M108,14 L84,62" stroke="#c49a3c" stroke-width="5" stroke-linecap="round"/>']))),
    "yakitori": svg(skewer(4, ["#a8521c", "#3fae49"])),
    "miso_soup": svg(bowl("#c8873a", rim="#5a2a14", extra=cubes([(52, 60), (70, 62)], 10, "#fdfbf5", 2) + "\n" + blobs([(60, 54), (80, 58), (44, 64)], 3, GREEN, 1.5))),
}

MORE_EQUIPMENT = {
    "comal": svg(shadow(rx=56), ellipse(58, 74, 50, 22, "#2b2523"), ellipse(58, 70, 42, 16, "#3d3532", 3),
                 '<path d="M104,70 L124,62" stroke="#1d1a2f" stroke-width="12" stroke-linecap="round"/><path d="M104,70 L124,62" stroke="#8a4b24" stroke-width="6" stroke-linecap="round"/>',
                 path("M36,104 Q46,92 52,104 Q58,90 66,104 Q72,92 80,104 Z", "#ff9f1c", 3)),
    "tortilla_press": svg(shadow(rx=50), ellipse(56, 92, 44, 14, "#9aa5b1"), ellipse(56, 76, 44, 14, "#c5ced8"),
                          '<path d="M96,80 L120,30" stroke="#1d1a2f" stroke-width="10" stroke-linecap="round"/><path d="M96,80 L120,30" stroke="#e3463a" stroke-width="5" stroke-linecap="round"/>'),
    "molcajete": svg(shadow(rx=46), path("M16,56 L112,56 Q108,100 64,100 Q20,100 16,56 Z", "#6e6a66"), ellipse(64, 56, 48, 12, "#4d4945"),
                     rect(30, 96, 10, 14, "#6e6a66", 3, 3), rect(88, 96, 10, 14, "#6e6a66", 3, 3), rect(60, 98, 10, 12, "#6e6a66", 3, 3),
                     rect(76, 14, 18, 50, "#8a8580", 8, rot=30), blobs([(40, 74), (60, 84), (82, 74)], 2, "#4d4945", 1)),
    "grater": svg(shadow(rx=40), path("M38,20 L90,20 L104,108 L24,108 Z", "#c5ced8"), rect(52, 6, 24, 18, "#2b2523", 6, 4),
                  '\n'.join(f'<path d="M{40 + (i % 4) * 14},{40 + (i // 4) * 16} l6,4" stroke="#1d1a2f" stroke-width="3" stroke-linecap="round"/>' for i in range(16))),
    "rice_cooker": svg(shadow(rx=50), path("M18,56 Q18,30 64,30 Q110,30 110,56 L106,104 L22,104 Z", "#f7f4ee"), ellipse(64, 40, 40, 10, "#e5dccb", 3),
                       rect(56, 20, 16, 12, "#2b2523", 4, 3), rect(48, 68, 32, 16, "#3f6fb5", 4, 3), circle(56, 76, 3, "#e5352b", 1)),
    "sushi_mat": svg(shadow(rx=50), rect(14, 30, 100, 76, "#d9b07a", 4),
                     '\n'.join(f'<path d="M{20 + i * 10},32 L{20 + i * 10},104" stroke="#a8823c" stroke-width="4"/>' for i in range(10))),
    "grill": svg(shadow(rx=56), path("M10,58 L118,58 L108,104 L20,104 Z", "#2b2523"), path("M18,62 Q40,48 50,62 Q60,46 74,62 Q86,48 110,62 Z", "#ff6b1c", 3),
                 '\n'.join(f'<path d="M{16 + i * 12},50 L{16 + i * 12},64" stroke="#c5ced8" stroke-width="4"/>' for i in range(9)),
                 '<path d="M12,52 L116,52" stroke="#c5ced8" stroke-width="6" stroke-linecap="round"/>'),
}

ITEMS.update(MEXICAN_ITEMS)
ITEMS.update(JAPANESE_ITEMS)
EQUIPMENT.update(MORE_EQUIPMENT)


def main():
    for folder, table in (("items", ITEMS), ("equipment", EQUIPMENT)):
        os.makedirs(os.path.join(OUT, folder), exist_ok=True)
        for name, content in table.items():
            with open(os.path.join(OUT, folder, name + ".svg"), "w") as f:
                f.write(content)
    print(f"wrote {len(ITEMS)} items and {len(EQUIPMENT)} equipment pictures")


if __name__ == "__main__":
    main()
