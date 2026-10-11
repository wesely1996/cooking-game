#!/usr/bin/env python3
"""Writes the shared kitchen pack (common.json), the Italian pack and the
Italian levels in the v0.6 cooking rules (see docs/V06_DESIGN.md).

Run from the repository root:

    python3 tools/content/make_italy.py

Balance numbers (spawn intervals, star thresholds) were tuned with
tools/balance_report.gd; edit them in LEVELS below.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import pack_format  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")


def manual(rid, station, inputs, action, work, output):
    return {"id": rid, "station": station, "inputs": inputs, "action": action, "work": work, "output": output}


def cook(rid, station, inputs, action, cook_time, window, burn, output):
    return {"id": rid, "station": station, "inputs": inputs, "action": action,
            "cook_time": cook_time, "perfect_window": window, "burn_time": burn, "output": output}


def role(name, crates, stations):
    return {"name": name, "crates": crates, "stations": stations}


COMMON = {
    "id": "common",
    "name": "Common kitchen",
    "items": {
        "plate": {"name": "Plate", "kind": "raw"},
        "water": {"name": "Water", "kind": "raw"},
        "tomato": {"name": "Tomato", "kind": "raw"},
        "chopped_tomato": {"name": "Chopped tomato"},
        "burnt_food": {"name": "Burnt food", "kind": "waste"},
    },
    # The shared gear every cuisine uses. Counters and boards hold anything;
    # bowls and cookware only take what can become one of their recipes.
    "stations": {
        "counter": {"name": "Counter", "kind": "counter", "capacity": 1},
        "board": {"name": "Chopping board", "kind": "manual", "capacity": 1, "holds_anything": True},
        "bowl": {"name": "Mixing bowl", "kind": "manual", "capacity": 3},
        "pot": {"name": "Pot", "kind": "cook", "capacity": 3},
        "pan": {"name": "Pan", "kind": "cook", "capacity": 3},
        "oven": {"name": "Oven", "kind": "cook", "capacity": 1},
        "fryer": {"name": "Fryer", "kind": "cook", "capacity": 2},
        "grill": {"name": "Grill", "kind": "cook", "capacity": 1},
        "serving_window": {"name": "Serving window", "kind": "pass", "capacity": 0},
    },
    "recipes": [
        manual("chop_tomato", "board", ["tomato"], "chop", 4, "chopped_tomato"),
    ],
}

ITALIAN = {
    "id": "italian",
    "name": "Italian",
    "items": {
        "flour": {"name": "Flour", "kind": "raw"},
        "mozzarella": {"name": "Mozzarella", "kind": "raw"},
        "basil": {"name": "Basil", "kind": "raw"},
        "bread": {"name": "Bread", "kind": "raw"},
        "sliced_mozzarella": {"name": "Sliced mozzarella"},
        "sliced_bread": {"name": "Sliced bread"},
        "toast": {"name": "Toast"},
        "dough": {"name": "Dough"},
        "fresh_pasta": {"name": "Fresh pasta"},
        "cooked_pasta": {"name": "Boiled pasta"},
        "tomato_sauce": {"name": "Tomato sauce"},
        "raw_pizza_margherita": {"name": "Raw pizza"},
        "whole_pizza": {"name": "Baked pizza"},
        "caprese_salad": {"name": "Caprese", "kind": "dish", "price": 14, "patience": 45},
        "bruschetta": {"name": "Bruschetta", "kind": "dish", "price": 20, "patience": 55},
        "pasta_pomodoro": {"name": "Pasta al Pomodoro", "kind": "dish", "price": 26, "patience": 65},
        "pizza_margherita": {"name": "Pizza Margherita", "kind": "dish", "price": 30, "patience": 70},
    },
    "stations": {
        # Italy's signature gadget: crank the dough into fresh pasta.
        "pasta_machine": {"name": "Pasta machine", "kind": "manual", "capacity": 1},
    },
    "recipes": [
        manual("slice_mozzarella", "board", ["mozzarella"], "slice", 3, "sliced_mozzarella"),
        manual("slice_bread", "board", ["bread"], "chop", 3, "sliced_bread"),
        manual("knead_dough", "bowl", ["flour", "water"], "knead", 8, "dough"),
        manual("crank_pasta", "pasta_machine", ["dough"], "crank", 3, "fresh_pasta"),
        cook("boil_pasta", "pot", ["fresh_pasta"], "boil", 6, 4, 10, "cooked_pasta"),
        cook("cook_sauce", "pan", ["chopped_tomato"], "simmer", 5, 4, 9, "tomato_sauce"),
        cook("toast_bread", "grill", ["sliced_bread"], "grill", 4, 3, 7, "toast"),
        cook("bake_pizza", "oven", ["raw_pizza_margherita"], "bake", 8, 4, 10, "whole_pizza"),
    ],
    "assemblies": [
        {"output": "raw_pizza_margherita", "base": "dough", "parts": ["chopped_tomato", "sliced_mozzarella"]},
        {"output": "caprese_salad", "base": "plate", "parts": ["chopped_tomato", "sliced_mozzarella", "basil"]},
        {"output": "bruschetta", "base": "plate", "parts": ["toast", "chopped_tomato", "basil"]},
        {"output": "pasta_pomodoro", "base": "plate", "parts": ["cooked_pasta", "tomato_sauce"]},
        {"output": "pizza_margherita", "base": "plate", "parts": ["whole_pizza"]},
    ],
    "role_presets": {
        # Caprese and bruschetta: no stove needed.
        "antipasti": {
            "1": [role("Chef", ["tomato", "mozzarella", "basil", "bread", "plate"],
                       {"counter": 4, "board": 2, "grill": 1, "serving_window": 1})],
            "2": [role("Prep", ["tomato", "mozzarella", "bread"], {"counter": 3, "board": 2, "grill": 1}),
                  role("Plating & Pass", ["basil", "plate"], {"counter": 4, "serving_window": 1})],
            "3": [role("Tomatoes", ["tomato"], {"counter": 3, "board": 1}),
                  role("Cheese & Bread", ["mozzarella", "bread"], {"counter": 3, "board": 1, "grill": 1}),
                  role("Plating & Pass", ["basil", "plate"], {"counter": 4, "serving_window": 1})],
            "4": [role("Tomatoes", ["tomato"], {"counter": 3, "board": 1}),
                  role("Cheese", ["mozzarella"], {"counter": 3, "board": 1}),
                  role("Bread & Basil", ["bread", "basil"], {"counter": 3, "board": 1, "grill": 1}),
                  role("Plating & Pass", ["plate"], {"counter": 4, "serving_window": 1})],
        },
        # The full menu. With two chefs it plays like this: P1 kneads the
        # dough and chops tomatoes, P2 tops the pizza with mozzarella and
        # throws it back, P1 bakes it, P2 plates it and serves.
        "trattoria": {
            "1": [role("Chef", ["tomato", "mozzarella", "basil", "bread", "flour", "water", "plate"],
                       {"counter": 4, "board": 2, "bowl": 1, "pasta_machine": 1, "pot": 1, "pan": 1, "oven": 1,
                        "grill": 1, "serving_window": 1})],
            "2": [role("Pantry & Stove", ["tomato", "bread", "flour", "water"],
                       {"counter": 3, "board": 1, "bowl": 1, "pasta_machine": 1, "pot": 1, "pan": 1, "oven": 1, "grill": 1}),
                  role("Toppings & Pass", ["mozzarella", "basil", "plate"], {"counter": 4, "board": 1, "serving_window": 1})],
            "3": [role("Prep", ["tomato", "mozzarella", "bread"], {"counter": 3, "board": 2}),
                  role("Stove", ["flour", "water"],
                       {"counter": 3, "bowl": 1, "pasta_machine": 1, "pot": 1, "pan": 1, "oven": 1, "grill": 1}),
                  role("Plating & Pass", ["basil", "plate"], {"counter": 4, "serving_window": 1})],
            "4": [role("Prep", ["tomato", "mozzarella"], {"counter": 3, "board": 2}),
                  role("Dough & Bread", ["flour", "water", "bread"], {"counter": 3, "board": 1, "bowl": 1, "pasta_machine": 1}),
                  role("Stove", [], {"counter": 3, "pot": 1, "pan": 1, "oven": 1, "grill": 1}),
                  role("Plating & Pass", ["basil", "plate"], {"counter": 4, "serving_window": 1})],
        },
    },
}

FESTIVAL_WAVES = [
    {"customers": {"1": 6, "2": 8, "3": 10, "4": 12},
     "spawn_interval": {"1": 7, "2": 6, "3": 5, "4": 4.5},
     "max_active": {"1": 3, "2": 3, "3": 4, "4": 4}},
    {"customers": {"1": 8, "2": 10, "3": 12, "4": 14},
     "spawn_interval": {"1": 6, "2": 5, "3": 4.5, "4": 4},
     "max_active": {"1": 3, "2": 4, "3": 4, "4": 5}},
    {"customers": {"1": 10, "2": 12, "3": 14, "4": 16},
     "spawn_interval": {"1": 5.5, "2": 4.5, "3": 4, "4": 3.5},
     "max_active": {"1": 4, "2": 4, "3": 5, "4": 5}},
]


def stars(tops):
    """Star thresholds per player count from the 3-star scores for 1-4 players."""
    out = {}
    for n, top in enumerate(tops, start=1):
        top = int(round(top / 10.0) * 10)
        out[str(n)] = [int(round(top * 0.35 / 10.0) * 10), int(round(top * 0.7 / 10.0) * 10), top]
    return out


def per_players(values):
    return {str(n): v for n, v in enumerate(values, start=1)}


# (file name, id, name, description, {dish: weight}, roles, duration, max_active, spawn_interval, 3-star scores for 1-4 players)
LEVELS = [
    ("italy_01_caprese_corner", "italy_01", "Caprese Corner",
     "Your first shift in Naples. Chop tomatoes and mozzarella, add basil, plate it. No stove yet!",
     {"caprese_salad": 1}, "antipasti", 180, [3, 3, 4, 4], [14, 11, 10, 9], [300, 400, 440, 470]),
    ("italy_02_aperitivo", "italy_02", "Aperitivo",
     "Evening drinks need snacks: caprese, and bruschetta toasted on the grill.",
     {"caprese_salad": 1, "bruschetta": 1}, "antipasti", 180, [3, 4, 4, 5], [13, 10, 9, 8], [400, 560, 640, 700]),
    ("italy_03_pasta_night", "italy_03", "Pasta Night",
     "Knead the dough, crank it into pasta, boil it, and cook a tomato sauce in the pan.",
     {"pasta_pomodoro": 1, "bruschetta": 1}, "trattoria", 210, [3, 4, 4, 5], [17, 13, 12, 11], [480, 650, 720, 800]),
    ("italy_04_pizzeria", "italy_04", "Pizzeria Napoli",
     "The real thing: pizza from the oven, pasta and caprese, all night long.",
     {"pizza_margherita": 2, "pasta_pomodoro": 1.5, "caprese_salad": 1}, "trattoria", 240, [3, 4, 4, 5], [16, 13, 12, 11],
     [560, 700, 840, 960]),
]


def write_level(name, level):
    path = os.path.join(ROOT, "data", "levels", name + ".json")
    lines = ["{"]
    keys = list(level.keys())
    for i, key in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        value = level[key]
        if key == "dishes" and value and isinstance(value[0], dict):
            lines.append('  "dishes": [')
            for j, d in enumerate(value):
                lines.append("    " + json.dumps(d, ensure_ascii=False) + ("," if j < len(value) - 1 else ""))
            lines.append("  ]" + comma)
        elif key == "waves":
            lines.append('  "waves": [')
            for j, wave in enumerate(value):
                lines.append("    " + json.dumps(wave) + ("," if j < len(value) - 1 else ""))
            lines.append("  ]" + comma)
        else:
            lines.append(f"  {json.dumps(key)}: {json.dumps(value, ensure_ascii=False)}{comma}")
    lines.append("}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def dishes(weights):
    return [{"id": d, "weight": w} for d, w in weights.items()]


def main():
    os.makedirs(os.path.join(ROOT, "data", "packs"), exist_ok=True)
    pack_format.write(os.path.join(ROOT, "data", "packs", "common.json"), COMMON)
    pack_format.write(os.path.join(ROOT, "data", "packs", "italian.json"), ITALIAN)
    for (fname, lid, name, desc, weights, roles, duration, max_active, interval, tops) in LEVELS:
        write_level(fname, {
            "id": lid, "name": name, "description": desc, "pack": "italian", "type": "normal",
            "dishes": dishes(weights), "roles": roles, "duration": duration, "first_spawn": 2,
            "max_active": per_players(max_active), "spawn_interval": per_players(interval), "stars": stars(tops),
        })
    write_level("italy_festival_sagra_in_piazza", {
        "id": "italy_festival", "name": "Sagra in Piazza",
        "description": "A food festival fills the town square. Caprese and bruschetta for a huge, hungry crowd!",
        "pack": "italian", "type": "festival", "dishes": dishes({"bruschetta": 2, "caprese_salad": 1}),
        "roles": "antipasti", "patience_multiplier": {"1": 1.3, "2": 1.15, "3": 1.05, "4": 1.0},
        "mood": {"start": 60, "served": 4, "lost": 15}, "wave_break": 6, "waves": FESTIVAL_WAVES,
        "stars": [0, 60, 85],
    })
    write_level("italy_competition_gran_premio", {
        "id": "italy_competition", "name": "Gran Premio della Pizza",
        "description": "Italy's great cooking championship. Bruno 'Il Fulmine' is fast, flashy... and burns things.",
        "pack": "italian", "type": "competition", "dishes": ["pizza_margherita", "pasta_pomodoro", "bruschetta"],
        "roles": "trattoria",
        "judges_orders": ["pizza_margherita", "bruschetta", "pasta_pomodoro", "pizza_margherita", "pasta_pomodoro",
                          "bruschetta", "pizza_margherita"],
        "max_active": 2, "time_limit": 360,
        "rival": {"name": "Bruno 'Il Fulmine'", "personality": "show_off", "speed": {"1": 0.7, "2": 1.0, "3": 1.3, "4": 1.5}},
    })
    write_level("arcade_italian", {
        "id": "arcade_italian", "name": "Arcade: Italian",
        "description": "Endless trattoria. Three angry customers and it's over.",
        "pack": "italian", "type": "arcade",
        "dishes": dishes({"pizza_margherita": 2, "pasta_pomodoro": 1.5, "bruschetta": 1, "caprese_salad": 1}),
        "roles": "trattoria", "first_spawn": 2, "max_active": per_players([2, 3, 3, 4]),
        "spawn_interval": per_players([30, 24, 20, 18]),
        "escalate_every": 30, "interval_factor": 0.93, "patience_factor": 0.95, "strikes": 3,
    })


if __name__ == "__main__":
    main()
