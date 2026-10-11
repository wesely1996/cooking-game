#!/usr/bin/env python3
"""Writes the American, Spanish and French cuisine packs and their levels.

These cuisines reuse ingredients from the other packs (potatoes for fries and
for the Spanish tortilla, tomato sauce for pizza and for ratatouille...), so
related recipes share their bases. Run from the repository root:

    python3 tools/content/make_v05_cuisines.py

Balance numbers (spawn intervals, star thresholds) were tuned with
tools/balance_report.gd; edit them in LEVEL_TUNING below.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import pack_format  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")


def proc(pid, inp, eq, action, out, work=None, cook=None, window=None, burn=None):
    p = {"id": pid, "input": inp, "equipment": eq, "action": action}
    if work is not None:
        p["work"] = work
    if cook is not None:
        p["cook_time"] = cook
        p["perfect_window"] = window
        p["burn_time"] = burn
    p["output"] = out
    return p


def role(name, crates, equipment, slots=None):
    r = {"name": name}
    if slots:
        r["slots"] = slots
    r["crates"] = crates
    r["equipment"] = equipment
    return r


AMERICAN = {
    "id": "american",
    "name": "American",
    "items": {
        "bun": {"name": "Burger bun", "kind": "raw"},
        "potato": {"name": "Potato", "kind": "raw"},
        "lettuce": {"name": "Lettuce", "kind": "raw"},
        "ice_cream": {"name": "Ice cream", "kind": "raw"},
        "milk": {"name": "Milk", "kind": "raw"},
        "sausage": {"name": "Sausage", "kind": "raw"},
        "raw_patty": {"name": "Raw patty"},
        "cooked_patty": {"name": "Burger patty"},
        "cheese_slice": {"name": "Cheese slice"},
        "shredded_lettuce": {"name": "Shredded lettuce"},
        "cut_potato": {"name": "Cut potatoes"},
        "shake_mix": {"name": "Shake mix"},
        "cooked_sausage": {"name": "Grilled sausage"},
        "fried_chicken": {"name": "Fried chicken"},
        "hot_sauce": {"name": "Hot sauce"},
        "cheeseburger": {"name": "Cheeseburger", "kind": "dish", "price": 32, "patience": 75},
        "fries": {"name": "Fries", "kind": "dish", "price": 10, "patience": 30},
        "milkshake": {"name": "Milkshake", "kind": "dish", "price": 14, "patience": 40},
        "hot_dog": {"name": "Hot Dog", "kind": "dish", "price": 12, "patience": 30},
        "buffalo_wings": {"name": "Buffalo Wings", "kind": "dish", "price": 22, "patience": 50},
    },
    "equipment": {
        "griddle": {"name": "Griddle", "kind": "appliance", "capacity": 2},
        "fryer": {"name": "Deep fryer", "kind": "appliance", "capacity": 2},
        "blender": {"name": "Blender", "kind": "tool"},
    },
    "processes": [
        proc("shape_patty", "beef", "mixing_bowl", "knead", "raw_patty", work=6),
        proc("sizzle_patty", "raw_patty", "griddle", "sizzle", "cooked_patty", cook=5, window=4, burn=8),
        proc("slice_cheese", "cheese_block", "knife", "slice", "cheese_slice", work=3),
        proc("shred_lettuce", "lettuce", "knife", "chop", "shredded_lettuce", work=3),
        proc("cut_potato", "potato", "knife", "slice", "cut_potato", work=4),
        proc("fry_potato", "cut_potato", "fryer", "fry", "fries", cook=5, window=4, burn=8),
        proc("blend_shake", "shake_mix", "blender", "blend", "milkshake", work=6),
        proc("sizzle_sausage", "sausage", "griddle", "sizzle", "cooked_sausage", cook=4, window=4, burn=8),
        proc("fry_chicken", "chicken", "fryer", "fry", "fried_chicken", cook=6, window=4, burn=9),
        proc("blend_hot_sauce", "chili", "blender", "blend", "hot_sauce", work=4),
    ],
    "assemblies": [
        {"output": "cheeseburger", "base": "bun", "parts": ["cooked_patty", "cheese_slice", "shredded_lettuce"]},
        {"output": "shake_mix", "base": "ice_cream", "parts": ["milk"]},
        {"output": "hot_dog", "base": "bun", "parts": ["cooked_sausage"]},
        {"output": "buffalo_wings", "base": "fried_chicken", "parts": ["hot_sauce"]},
    ],
    "role_presets": {
        "diner": {
            "1": [role("Chef", ["bun", "beef", "cheese_block", "lettuce", "potato", "ice_cream", "milk", "chicken", "chili"],
                       ["mixing_bowl", "griddle", "knife", "fryer", "blender", "serving_window"], 8)],
            "2": [role("Grill & Prep", ["bun", "beef", "cheese_block", "potato", "ice_cream", "chili"], ["mixing_bowl", "griddle", "knife"]),
                  role("Fryer & Pass", ["lettuce", "milk", "chicken"], ["knife", "fryer", "blender", "serving_window"])],
            "3": [role("Grill", ["beef", "bun"], ["mixing_bowl", "griddle"]),
                  role("Prep", ["cheese_block", "lettuce", "potato", "chili", "ice_cream"], ["knife"]),
                  role("Fryer & Pass", ["chicken", "milk"], ["fryer", "blender", "serving_window"])],
            "4": [role("Grill", ["beef"], ["mixing_bowl", "griddle"]),
                  role("Prep", ["cheese_block", "lettuce", "bun"], ["knife"]),
                  role("Fryer", ["potato", "chicken", "ice_cream"], ["knife", "fryer"]),
                  role("Shakes & Pass", ["milk", "chili"], ["blender", "serving_window"])],
        },
        "county_fair": {
            "1": [role("Chef", ["bun", "sausage", "potato"], ["griddle", "knife", "fryer", "serving_window"], 8)],
            "2": [role("Grill & Knife", ["sausage", "potato"], ["griddle", "knife"]),
                  role("Fryer & Pass", ["bun"], ["fryer", "serving_window"])],
            "3": [role("Sausages", ["sausage"], ["griddle"]),
                  role("Fries", ["potato"], ["knife", "fryer"]),
                  role("Buns & Pass", ["bun"], ["serving_window"])],
            "4": [role("Sausages", ["sausage"], ["griddle"]),
                  role("Cutter", ["potato"], ["knife"]),
                  role("Fryer", ["potato"], ["knife", "fryer"]),
                  role("Buns & Pass", ["bun"], ["serving_window"])],
        },
    },
}

SPANISH = {
    "id": "spanish",
    "name": "Spanish",
    "items": {
        "saffron": {"name": "Saffron", "kind": "raw"},
        "churro_dough": {"name": "Churro dough", "kind": "raw"},
        "chopped_chicken": {"name": "Chopped chicken"},
        "paella_mix": {"name": "Paella mix"},
        "beaten_egg": {"name": "Beaten egg"},
        "tortilla_mix": {"name": "Tortilla mix"},
        "gazpacho_mix": {"name": "Gazpacho mix"},
        "paella": {"name": "Paella", "kind": "dish", "price": 34, "patience": 80},
        "tortilla_espanola": {"name": "Tortilla Española", "kind": "dish", "price": 24, "patience": 60},
        "gazpacho": {"name": "Gazpacho", "kind": "dish", "price": 16, "patience": 45},
        "patatas_bravas": {"name": "Patatas Bravas", "kind": "dish", "price": 18, "patience": 45},
        "churros": {"name": "Churros", "kind": "dish", "price": 8, "patience": 25},
    },
    "equipment": {
        "paella_pan": {"name": "Paella pan", "kind": "appliance", "capacity": 2},
        "frying_pan": {"name": "Frying pan", "kind": "appliance", "capacity": 2},
    },
    "processes": [
        proc("chop_chicken", "chicken", "knife", "chop", "chopped_chicken", work=4),
        proc("simmer_paella", "paella_mix", "paella_pan", "simmer", "paella", cook=8, window=5, burn=12),
        proc("whisk_egg", "egg", "mixing_bowl", "whisk", "beaten_egg", work=5),
        proc("fry_tortilla", "tortilla_mix", "frying_pan", "fry", "tortilla_espanola", cook=6, window=4, burn=9),
        proc("blend_gazpacho", "gazpacho_mix", "blender", "blend", "gazpacho", work=5),
        proc("fry_churros", "churro_dough", "fryer", "fry", "churros", cook=4, window=4, burn=8),
    ],
    "assemblies": [
        {"output": "paella_mix", "base": "rice", "parts": ["chopped_chicken", "saffron"]},
        {"output": "tortilla_mix", "base": "beaten_egg", "parts": ["cut_potato", "chopped_onion"]},
        {"output": "gazpacho_mix", "base": "chopped_tomato", "parts": ["cucumber_sticks"]},
        {"output": "patatas_bravas", "base": "fries", "parts": ["hot_sauce"]},
    ],
    "role_presets": {
        "tapas_bar": {
            "1": [role("Chef", ["egg", "potato", "onion", "chili", "rice", "chicken", "saffron", "tomato", "cucumber"],
                       ["mixing_bowl", "knife", "frying_pan", "fryer", "blender", "paella_pan", "serving_window"], 8)],
            "2": [role("Tortillas & Fryer", ["egg", "potato", "onion", "chili", "rice"], ["mixing_bowl", "knife", "frying_pan", "fryer", "blender"]),
                  role("Paella & Pass", ["chicken", "saffron", "tomato", "cucumber"], ["knife", "paella_pan", "serving_window"])],
            "3": [role("Tortillas", ["egg", "onion", "potato"], ["mixing_bowl", "knife", "frying_pan"]),
                  role("Fryer & Blender", ["chili", "rice", "cucumber"], ["knife", "fryer", "blender"]),
                  role("Paella & Pass", ["chicken", "saffron", "tomato"], ["knife", "paella_pan", "serving_window"])],
            "4": [role("Tortillas", ["egg", "onion"], ["mixing_bowl", "knife", "frying_pan"]),
                  role("Fryer", ["potato", "chili"], ["knife", "fryer", "blender"]),
                  role("Paella", ["rice", "chicken", "saffron", "cucumber"], ["knife", "paella_pan"]),
                  role("Gazpacho & Pass", ["tomato"], ["knife", "blender", "serving_window"])],
        },
        "fiesta": {
            "1": [role("Chef", ["churro_dough", "tomato", "cucumber"], ["fryer", "knife", "blender", "serving_window"], 8)],
            "2": [role("Churros", ["churro_dough", "cucumber"], ["fryer", "knife"]),
                  role("Gazpacho & Pass", ["tomato"], ["knife", "blender", "serving_window"])],
            "3": [role("Churros", ["churro_dough"], ["fryer"]),
                  role("Chopping", ["cucumber"], ["knife"]),
                  role("Blender & Pass", ["tomato"], ["knife", "blender", "serving_window"])],
            "4": [role("Churros", ["churro_dough"], ["fryer"]),
                  role("Blender & Fryer", ["churro_dough"], ["fryer", "blender"]),
                  role("Cucumbers", ["cucumber"], ["knife"]),
                  role("Tomatoes & Pass", ["tomato"], ["knife", "serving_window"])],
        },
    },
}

FRENCH = {
    "id": "french",
    "name": "French",
    "items": {
        "eggplant": {"name": "Eggplant", "kind": "raw"},
        "zucchini": {"name": "Zucchini", "kind": "raw"},
        "croissant_dough": {"name": "Croissant dough", "kind": "raw"},
        "crepe_mix": {"name": "Crêpe mix"},
        "crepe_batter": {"name": "Crêpe batter"},
        "plain_crepe": {"name": "Plain crêpe"},
        "chocolate_sauce": {"name": "Chocolate sauce"},
        "caramelized_onion": {"name": "Caramelized onion"},
        "raw_onion_soup": {"name": "Onion soup (to bake)"},
        "chopped_eggplant": {"name": "Chopped eggplant"},
        "sliced_zucchini": {"name": "Sliced zucchini"},
        "ratatouille_mix": {"name": "Ratatouille (to bake)"},
        "pain_perdu_mix": {"name": "Soaked bread"},
        "crepe": {"name": "Chocolate Crêpe", "kind": "dish", "price": 20, "patience": 50},
        "onion_soup": {"name": "French Onion Soup", "kind": "dish", "price": 34, "patience": 80},
        "ratatouille": {"name": "Ratatouille", "kind": "dish", "price": 30, "patience": 70},
        "croissant": {"name": "Croissant", "kind": "dish", "price": 8, "patience": 25},
        "pain_perdu": {"name": "Pain Perdu", "kind": "dish", "price": 12, "patience": 35},
    },
    "equipment": {
        "crepe_pan": {"name": "Crêpe pan", "kind": "appliance", "capacity": 2},
    },
    "processes": [
        proc("whisk_crepe_batter", "crepe_mix", "mixing_bowl", "whisk", "crepe_batter", work=5),
        proc("cook_crepe", "crepe_batter", "crepe_pan", "cook", "plain_crepe", cook=4, window=3, burn=7),
        proc("melt_chocolate", "chocolate", "sauce_pot", "stir", "chocolate_sauce", work=3),
        proc("caramelize_onion", "chopped_onion", "sauce_pot", "stir", "caramelized_onion", work=4),
        proc("bake_onion_soup", "raw_onion_soup", "oven", "bake", "onion_soup", cook=6, window=4, burn=9),
        proc("chop_eggplant", "eggplant", "knife", "chop", "chopped_eggplant", work=4),
        proc("slice_zucchini", "zucchini", "knife", "slice", "sliced_zucchini", work=4),
        proc("bake_ratatouille", "ratatouille_mix", "oven", "bake", "ratatouille", cook=7, window=4, burn=10),
        proc("bake_croissant", "croissant_dough", "oven", "bake", "croissant", cook=5, window=4, burn=8),
        proc("fry_pain_perdu", "pain_perdu_mix", "frying_pan", "fry", "pain_perdu", cook=5, window=4, burn=8),
    ],
    "assemblies": [
        {"output": "crepe_mix", "base": "milk", "parts": ["egg", "flour"]},
        {"output": "crepe", "base": "plain_crepe", "parts": ["chocolate_sauce"]},
        {"output": "raw_onion_soup", "base": "caramelized_onion", "parts": ["toast", "grated_cheese"]},
        {"output": "ratatouille_mix", "base": "chopped_eggplant", "parts": ["sliced_zucchini", "tomato_sauce"]},
        {"output": "pain_perdu_mix", "base": "bread", "parts": ["beaten_egg"]},
    ],
    "role_presets": {
        "bistro": {
            "1": [role("Chef", ["milk", "egg", "flour", "chocolate", "onion", "bread", "cheese_block", "eggplant", "zucchini", "tomato"],
                       ["mixing_bowl", "crepe_pan", "sauce_pot", "knife", "oven", "grater", "serving_window"], 8)],
            "2": [role("Crêpes & Veg", ["milk", "egg", "flour", "onion", "tomato"], ["mixing_bowl", "crepe_pan", "sauce_pot", "knife"]),
                  role("Oven & Pass", ["bread", "cheese_block", "eggplant", "zucchini", "chocolate"], ["knife", "grater", "sauce_pot", "oven", "serving_window"])],
            "3": [role("Crêpes", ["milk", "egg", "flour"], ["mixing_bowl", "crepe_pan"]),
                  role("Sauces & Veg", ["chocolate", "onion", "eggplant", "zucchini", "tomato"], ["knife", "sauce_pot"]),
                  role("Oven & Pass", ["bread", "cheese_block"], ["grater", "oven", "serving_window"])],
            "4": [role("Crêpes", ["milk", "egg"], ["mixing_bowl", "crepe_pan"]),
                  role("Sauces", ["chocolate", "tomato", "onion"], ["knife", "sauce_pot"]),
                  role("Vegetables & Flour", ["eggplant", "zucchini", "flour"], ["knife"]),
                  role("Oven & Pass", ["bread", "cheese_block"], ["grater", "oven", "serving_window"])],
        },
        "fete": {
            "1": [role("Chef", ["croissant_dough", "bread", "egg"], ["oven", "mixing_bowl", "frying_pan", "serving_window"], 8)],
            "2": [role("Bakery & Eggs", ["croissant_dough", "egg"], ["oven", "mixing_bowl"]),
                  role("Pan & Pass", ["bread"], ["frying_pan", "serving_window"])],
            "3": [role("Bakery", ["croissant_dough"], ["oven"]),
                  role("Eggs", ["egg"], ["mixing_bowl"]),
                  role("Pan & Pass", ["bread"], ["frying_pan", "serving_window"])],
            "4": [role("Bakery", ["croissant_dough"], ["oven"]),
                  role("Second oven", ["croissant_dough"], ["oven"]),
                  role("Eggs", ["egg"], ["mixing_bowl"]),
                  role("Pan & Pass", ["bread"], ["frying_pan", "serving_window"])],
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

PLAYER_FACTORS = [1.0, 1.35, 1.65, 1.9]


def stars(three_star):
    """Star thresholds per player count. `three_star` is the 3-star score for
    1-4 players, or just the solo one (more players then scale it up)."""
    tops = three_star if isinstance(three_star, list) else [three_star * f for f in PLAYER_FACTORS]
    out = {}
    for n, top in enumerate(tops, start=1):
        top = int(round(top / 10.0) * 10)
        out[str(n)] = [int(round(top * 0.35 / 10.0) * 10), int(round(top * 0.7 / 10.0) * 10), top]
    return out


def per_players(values):
    return {str(n): v for n, v in enumerate(values, start=1)}


# (id, file suffix, name, description, dishes {id: weight}, duration, max_active, spawn_interval, 3-star scores for 1-4 players)
REGIONS = [
    {
        "region": "usa", "region_name": "USA", "pack": "american", "preset": "diner", "festival_preset": "county_fair",
        "levels": [
            ("usa_01", "burger_joint", "Burger Joint", "New York! Shape the patties, sizzle them on the griddle and stack a cheeseburger.",
             {"cheeseburger": 1}, 180, [3, 4, 4, 5], [20, 16, 14, 13], [330, 450, 540, 620]),
            ("usa_02", "fries_with_that", "Fries With That?", "Every burger wants fries. Slice the potatoes and keep the fryer busy.",
             {"cheeseburger": 1, "fries": 1}, 180, [3, 4, 4, 5], [15, 12, 11, 10], [370, 500, 600, 690]),
            ("usa_03", "shake_it_up", "Shake It Up", "Ice cream, milk, blender: the diner's famous milkshakes.",
             {"cheeseburger": 1, "milkshake": 1}, 210, [3, 4, 4, 5], [15, 12, 11, 10], [430, 580, 700, 800]),
            ("usa_04", "route_66", "Route 66 Diner", "Truckers, tourists and a jukebox. The whole diner menu, all night long.",
             {"cheeseburger": 2, "fries": 1.5, "milkshake": 1}, 240, [3, 4, 4, 5], [13, 11, 10, 9], [520, 700, 850, 970]),
        ],
        "festival": ("usa_festival", "county_fair", "County Fair",
                     "A state fair with a Ferris wheel and a never-ending line for hot dogs and fries.",
                     {"hot_dog": 2, "fries": 1}),
        "competition": ("usa_competition", "smoke_and_fire", "Smoke & Fire Championship",
                        "Memphis-style cook-off. Big Earl grills like a showman, and showmen burn things.",
                        ["cheeseburger", "buffalo_wings", "fries"],
                        ["cheeseburger", "buffalo_wings", "fries", "cheeseburger", "buffalo_wings", "cheeseburger", "fries"],
                        {"name": "Big Earl", "personality": "show_off", "speed": {"1": 0.8, "2": 1.1, "3": 1.4, "4": 1.6}}),
        "arcade": ("arcade_american", "Arcade: American", "Endless diner. Three angry customers and it's over.",
                   {"cheeseburger": 2, "fries": 1.5, "milkshake": 1}, [2, 3, 3, 4], [26, 21, 18, 17]),
    },
    {
        "region": "spain", "region_name": "Spain", "pack": "spanish", "preset": "tapas_bar", "festival_preset": "fiesta",
        "levels": [
            ("spain_01", "tortilla_time", "Tortilla Time", "Madrid! Whisk the eggs, add potatoes and onion, fry a golden tortilla.",
             {"tortilla_espanola": 1}, 180, [3, 4, 4, 5], [18, 15, 13, 12], [380, 470, 520, 560]),
            ("spain_02", "tapas_bar", "Tapas Bar", "Little plates, big crowd: tortilla and spicy patatas bravas.",
             {"tortilla_espanola": 1, "patatas_bravas": 1}, 180, [3, 4, 4, 5], [15, 12, 11, 10], [430, 520, 600, 660]),
            ("spain_03", "paella_sunday", "Paella Sunday", "Sunday in Valencia: a big pan of paella and cold gazpacho.",
             {"paella": 1, "gazpacho": 1}, 210, [3, 4, 4, 5], [16, 13, 12, 11], [500, 640, 740, 820]),
            ("spain_04", "la_bodega", "La Bodega", "Late dinner, Spanish style. Paella, tortilla and bravas until midnight.",
             {"paella": 1.5, "tortilla_espanola": 1, "patatas_bravas": 1}, 240, [3, 4, 4, 5], [15, 12, 11, 10], [600, 800, 940, 1060]),
        ],
        "festival": ("spain_festival", "fiesta_del_tomate", "Fiesta del Tomate",
                     "A tomato-throwing street party! Cold gazpacho and hot churros for the soaked crowd.",
                     {"churros": 2, "gazpacho": 1}),
        "competition": ("spain_competition", "copa_de_la_paella", "Copa de la Paella",
                        "The paella cup of Sueca. Abuela Carmen has cooked paella for sixty years and never hurries.",
                        ["paella", "tortilla_espanola", "gazpacho"],
                        ["paella", "tortilla_espanola", "gazpacho", "paella", "tortilla_espanola", "paella", "gazpacho"],
                        {"name": "Abuela Carmen", "personality": "steady", "speed": {"1": 0.8, "2": 1.1, "3": 1.4, "4": 1.6}}),
        "arcade": ("arcade_spanish", "Arcade: Spanish", "Endless tapas bar. Three angry customers and it's over.",
                   {"paella": 1.5, "tortilla_espanola": 1, "patatas_bravas": 1}, [2, 3, 3, 4], [26, 21, 18, 17]),
    },
    {
        "region": "france", "region_name": "France", "pack": "french", "preset": "bistro", "festival_preset": "fete",
        "levels": [
            ("france_01", "cafe_de_paris", "Café de Paris", "Paris! Whisk the batter, cook thin crêpes, pour on chocolate.",
             {"crepe": 1}, 180, [3, 4, 4, 5], [14, 11, 10, 9], [420, 450, 480, 520]),
            ("france_02", "le_bistro", "Le Bistro", "Caramelized onions, toast and cheese, baked into a bubbling onion soup.",
             {"crepe": 1, "onion_soup": 1}, 210, [3, 4, 4, 5], [15, 12, 11, 10], [480, 600, 680, 760]),
            ("france_03", "provence", "Provence", "Lavender fields and ratatouille: eggplant, zucchini and tomato sauce.",
             {"ratatouille": 1, "crepe": 1}, 210, [3, 4, 4, 5], [15, 12, 11, 10], [520, 680, 760, 840]),
            ("france_04", "le_grand_restaurant", "Le Grand Restaurant", "White tablecloths and food critics. The whole French menu, perfectly.",
             {"onion_soup": 1.5, "ratatouille": 1, "crepe": 1}, 240, [3, 4, 4, 5], [14, 12, 11, 10], [620, 800, 880, 960]),
        ],
        "festival": ("france_festival", "fete_de_la_gastronomie", "Fête de la Gastronomie",
                     "Lyon's food festival fills the streets. Croissants and pain perdu for everyone!",
                     {"croissant": 2, "pain_perdu": 1}),
        "competition": ("france_competition", "golden_toque", "Golden Toque World Final",
                        "The world final in Lyon. Chef Céleste is the best in the world: beat her and so are you.",
                        ["onion_soup", "ratatouille", "crepe"],
                        ["crepe", "onion_soup", "ratatouille", "crepe", "onion_soup", "ratatouille", "crepe", "onion_soup"],
                        {"name": "Chef Céleste", "personality": "perfectionist", "speed": {"1": 1.0, "2": 1.4, "3": 1.75, "4": 2.0}}),
        "arcade": ("arcade_french", "Arcade: French", "Endless bistro. Three angry customers and it's over.",
                   {"onion_soup": 1.5, "ratatouille": 1, "crepe": 1}, [2, 3, 3, 4], [26, 21, 18, 17]),
    },
]


def dishes(weights):
    return [{"id": d, "weight": w} for d, w in weights.items()]


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
                lines.append("    {")
                wk = list(wave.keys())
                for k, wkey in enumerate(wk):
                    lines.append(f'      "{wkey}": {json.dumps(wave[wkey])}' + ("," if k < len(wk) - 1 else ""))
                lines.append("    }" + ("," if j < len(value) - 1 else ""))
            lines.append("  ]" + comma)
        elif key == "mood":
            lines.append('  "mood": {')
            mk = list(value.keys())
            for k, mkey in enumerate(mk):
                lines.append(f'    "{mkey}": {json.dumps(value[mkey])}' + ("," if k < len(mk) - 1 else ""))
            lines.append("  }" + comma)
        else:
            lines.append(f"  {json.dumps(key)}: {json.dumps(value, ensure_ascii=False)}{comma}")
    lines.append("}")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    for pack in (AMERICAN, SPANISH, FRENCH):
        pack_format.write(os.path.join(ROOT, "data", "packs", pack["id"] + ".json"), pack)
    for region in REGIONS:
        pack = region["pack"]
        for (lid, suffix, name, desc, weights, duration, max_active, interval, solo3) in region["levels"]:
            write_level(f"{lid}_{suffix}", {
                "id": lid, "name": name, "description": desc, "pack": pack, "type": "normal",
                "dishes": dishes(weights), "roles": region["preset"], "duration": duration, "first_spawn": 2,
                "max_active": per_players(max_active), "spawn_interval": per_players(interval), "stars": stars(solo3),
            })
        fid, fsuffix, fname, fdesc, fweights = region["festival"]
        write_level(f"{fid}_{fsuffix}", {
            "id": fid, "name": fname, "description": fdesc, "pack": pack, "type": "festival",
            "dishes": dishes(fweights), "roles": region["festival_preset"],
            "patience_multiplier": {"1": 1.3, "2": 1.15, "3": 1.05, "4": 1.0},
            "mood": {"start": 60, "served": 4, "lost": 15}, "wave_break": 6, "waves": FESTIVAL_WAVES,
            "stars": [0, 60, 85],
        })
        cid, csuffix, cname, cdesc, cdishes, orders, rival = region["competition"]
        write_level(f"{cid}_{csuffix}", {
            "id": cid, "name": cname, "description": cdesc, "pack": pack, "type": "competition",
            "dishes": cdishes, "roles": region["preset"], "judges_orders": orders, "max_active": 2,
            "time_limit": 360, "rival": rival,
        })
        aid, aname, adesc, aweights, amax, aint = region["arcade"]
        write_level(aid, {
            "id": aid, "name": aname, "description": adesc, "pack": pack, "type": "arcade",
            "dishes": dishes(aweights), "roles": region["preset"], "first_spawn": 2,
            "max_active": per_players(amax), "spawn_interval": per_players(aint),
            "escalate_every": 30, "interval_factor": 0.93, "patience_factor": 0.95, "strikes": 3,
        })


if __name__ == "__main__":
    main()
