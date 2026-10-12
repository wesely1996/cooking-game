#!/usr/bin/env python3
"""Writes all game content in the v0.6 cooking rules (see docs/V06_DESIGN.md):
the shared kitchen (common.json), the six cuisine packs, their levels, the
world map and the recipe book's "coming soon" list.

Run from the repository root:

    python3 tools/content/make_content.py

Every cuisine follows the Italy template: four dishes (the first needs no
stove), shared gear plus at most one signature gadget, plating in any order,
four shifts, a festival, a competition and an arcade level.

Star thresholds are set from the bot's scores; see STAR_TOPS.
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


def plated(output, *parts):
    return {"output": output, "base": "plate", "parts": list(parts)}


def role(name, crates, counter=3, **stations):
    """A role: its crates and stations. Counter spots default to 3."""
    return {"name": name, "crates": crates, "stations": dict({"counter": counter}, **stations)}


def server(name, crates, counter=4, **stations):
    """The role that owns the serving window."""
    return role(name, crates, counter, **stations, serving_window=1)


def raw(name):
    return {"name": name, "kind": "raw"}


def made(name):
    return {"name": name}


def dish(name, price, patience):
    return {"name": name, "kind": "dish", "price": price, "patience": patience}


COMMON = {
    "id": "common",
    "name": "Common kitchen",
    "items": {
        "plate": raw("Plate"),
        "water": raw("Water"),
        "tomato": raw("Tomato"),
        "flour": raw("Flour"),
        "bread": raw("Bread"),
        "egg": raw("Egg"),
        "milk": raw("Milk"),
        "rice": raw("Rice"),
        "potato": raw("Potato"),
        "cheese": raw("Cheese"),
        "cucumber": raw("Cucumber"),
        "strawberry": raw("Strawberry"),
        "chopped_tomato": made("Chopped tomato"),
        "dough": made("Dough"),
        "sliced_bread": made("Sliced bread"),
        "toast": made("Toast"),
        "tomato_sauce": made("Tomato sauce"),
        "chopped_potato": made("Potato sticks"),
        "fries": made("Fries"),
        "grated_cheese": made("Grated cheese"),
        "chopped_cucumber": made("Sliced cucumber"),
        "cooked_rice": made("Cooked rice"),
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
        manual("slice_bread", "board", ["bread"], "chop", 3, "sliced_bread"),
        manual("chop_potato", "board", ["potato"], "chop", 4, "chopped_potato"),
        manual("grate_cheese", "board", ["cheese"], "grate", 3, "grated_cheese"),
        manual("slice_cucumber", "board", ["cucumber"], "slice", 3, "chopped_cucumber"),
        manual("knead_dough", "bowl", ["flour", "water"], "knead", 8, "dough"),
        cook("cook_sauce", "pan", ["chopped_tomato"], "simmer", 5, 4, 9, "tomato_sauce"),
        cook("toast_bread", "grill", ["sliced_bread"], "grill", 4, 3, 7, "toast"),
        cook("fry_potato", "fryer", ["chopped_potato"], "fry", 6, 4, 9, "fries"),
        cook("cook_rice", "pot", ["rice", "water"], "boil", 6, 5, 11, "cooked_rice"),
    ],
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

# Shift pacing by position in the region (1-4): duration, max_active and
# spawn_interval per player count. Italy's numbers, shared by every cuisine.
PACING = [
    (180, [3, 3, 4, 4], [14, 11, 10, 9]),
    (180, [3, 4, 4, 5], [13, 10, 9, 8]),
    (210, [3, 4, 4, 5], [17, 13, 12, 11]),
    (240, [3, 4, 4, 5], [16, 13, 12, 11]),
]


# --- Italy ---------------------------------------------------------------------

ITALIAN = {
    "id": "italian",
    "name": "Italian",
    "items": {
        "mozzarella": raw("Mozzarella"),
        "basil": raw("Basil"),
        "sliced_mozzarella": made("Sliced mozzarella"),
        "fresh_pasta": made("Fresh pasta"),
        "cooked_pasta": made("Boiled pasta"),
        "raw_pizza_margherita": made("Raw pizza"),
        "whole_pizza": made("Baked pizza"),
        "caprese_salad": dish("Caprese", 14, 45),
        "bruschetta": dish("Bruschetta", 20, 55),
        "pasta_pomodoro": dish("Pasta al Pomodoro", 26, 65),
        "pizza_margherita": dish("Pizza Margherita", 30, 70),
    },
    "stations": {
        # Italy's signature gadget: crank the dough into fresh pasta.
        "pasta_machine": {"name": "Pasta machine", "kind": "manual", "capacity": 1},
    },
    "recipes": [
        manual("slice_mozzarella", "board", ["mozzarella"], "slice", 3, "sliced_mozzarella"),
        manual("crank_pasta", "pasta_machine", ["dough"], "crank", 3, "fresh_pasta"),
        cook("boil_pasta", "pot", ["fresh_pasta"], "boil", 6, 4, 10, "cooked_pasta"),
        cook("bake_pizza", "oven", ["raw_pizza_margherita"], "bake", 8, 4, 10, "whole_pizza"),
    ],
    "assemblies": [
        {"output": "raw_pizza_margherita", "base": "dough", "parts": ["chopped_tomato", "sliced_mozzarella"]},
        plated("caprese_salad", "chopped_tomato", "sliced_mozzarella", "basil"),
        plated("bruschetta", "toast", "chopped_tomato", "basil"),
        plated("pasta_pomodoro", "cooked_pasta", "tomato_sauce"),
        plated("pizza_margherita", "whole_pizza"),
    ],
    "role_presets": {
        # Caprese and bruschetta: no stove needed.
        "antipasti": {
            "1": [server("Chef", ["tomato", "mozzarella", "basil", "bread", "plate"], board=2, grill=1)],
            "2": [role("Prep", ["tomato", "mozzarella", "bread"], board=2, grill=1),
                  server("Plating & Pass", ["basil", "plate"])],
            "3": [role("Tomatoes", ["tomato"], board=1),
                  role("Cheese & Bread", ["mozzarella", "bread"], board=1, grill=1),
                  server("Plating & Pass", ["basil", "plate"])],
            "4": [role("Tomatoes", ["tomato"], board=1),
                  role("Cheese", ["mozzarella"], board=1),
                  role("Bread & Basil", ["bread", "basil"], board=1, grill=1),
                  server("Plating & Pass", ["plate"])],
        },
        # The full menu. With two chefs it plays like this: P1 kneads the
        # dough and chops tomatoes, P2 tops the pizza with mozzarella and
        # throws it back, P1 bakes it, P2 plates it and serves.
        "trattoria": {
            "1": [server("Chef", ["tomato", "mozzarella", "basil", "bread", "flour", "water", "plate"],
                         board=2, bowl=1, pasta_machine=1, pot=1, pan=1, oven=1, grill=1)],
            "2": [role("Pantry & Stove", ["tomato", "bread", "flour", "water"],
                       board=1, bowl=1, pasta_machine=1, pot=1, pan=1, oven=1, grill=1),
                  server("Toppings & Pass", ["mozzarella", "basil", "plate"], board=1)],
            "3": [role("Prep", ["tomato", "mozzarella", "bread"], board=2),
                  role("Stove", ["flour", "water"], bowl=1, pasta_machine=1, pot=1, pan=1, oven=1, grill=1),
                  server("Plating & Pass", ["basil", "plate"])],
            "4": [role("Prep", ["tomato", "mozzarella"], board=2),
                  role("Dough & Bread", ["flour", "water", "bread"], board=1, bowl=1, pasta_machine=1),
                  role("Stove", [], pot=1, pan=1, oven=1, grill=1),
                  server("Plating & Pass", ["basil", "plate"])],
        },
    },
}

ITALY = {
    "pack": ITALIAN, "file": "italy", "region": ("italy", "Italy"),
    "levels": [
        ("caprese_corner", "Caprese Corner",
         "Your first shift in Naples. Chop tomatoes and mozzarella, add basil, plate it. No stove yet!",
         {"caprese_salad": 1}, "antipasti"),
        ("aperitivo", "Aperitivo",
         "Evening drinks need snacks: caprese, and bruschetta toasted on the grill.",
         {"caprese_salad": 1, "bruschetta": 1}, "antipasti"),
        ("pasta_night", "Pasta Night",
         "Knead the dough, crank it into pasta, boil it, and cook a tomato sauce in the pan.",
         {"pasta_pomodoro": 1, "bruschetta": 1}, "trattoria"),
        ("pizzeria", "Pizzeria Napoli",
         "The real thing: pizza from the oven, pasta and caprese, all night long.",
         {"pizza_margherita": 2, "pasta_pomodoro": 1.5, "caprese_salad": 1}, "trattoria"),
    ],
    "festival": ("sagra_in_piazza", "Sagra in Piazza",
                 "A food festival fills the town square. Caprese and bruschetta for a huge, hungry crowd!",
                 {"bruschetta": 2, "caprese_salad": 1}, "antipasti"),
    "competition": ("gran_premio", "Gran Premio della Pizza",
                    "Italy's great cooking championship. Bruno 'Il Fulmine' is fast, flashy... and burns things.",
                    ["pizza_margherita", "pasta_pomodoro", "bruschetta"], "trattoria",
                    ["pizza_margherita", "bruschetta", "pasta_pomodoro", "pizza_margherita", "pasta_pomodoro",
                     "bruschetta", "pizza_margherita"],
                    {"name": "Bruno 'Il Fulmine'", "personality": "show_off", "speed": {"1": 0.7, "2": 1.0, "3": 1.3, "4": 1.5}}),
    "arcade": ({"pizza_margherita": 2, "pasta_pomodoro": 1.5, "bruschetta": 1, "caprese_salad": 1}, "trattoria"),
}


# --- Mexico --------------------------------------------------------------------

MEXICAN = {
    "id": "mexican",
    "name": "Mexican",
    "items": {
        "avocado": raw("Avocado"),
        "corn": raw("Corn"),
        "beef": raw("Beef"),
        "chopped_avocado": made("Chopped avocado"),
        "guac_mix": made("Mashed avocado"),
        "grilled_corn": made("Grilled corn"),
        "grilled_beef": made("Grilled beef"),
        "tortilla": made("Tortilla"),
        "hot_quesadilla": made("Hot quesadilla"),
        "guacamole": dish("Guacamole", 14, 45),
        "elote": dish("Elote", 20, 55),
        "quesadilla": dish("Quesadilla", 26, 65),
        "beef_taco": dish("Beef Taco", 32, 80),
    },
    "stations": {
        # Mexico's signature gadget: press a ball of dough into a tortilla.
        "tortilla_press": {"name": "Tortilla press", "kind": "manual", "capacity": 1},
    },
    "recipes": [
        manual("chop_avocado", "board", ["avocado"], "chop", 3, "chopped_avocado"),
        manual("mash_guacamole", "bowl", ["chopped_avocado", "chopped_tomato"], "mash", 4, "guac_mix"),
        manual("press_tortilla", "tortilla_press", ["dough"], "press", 3, "tortilla"),
        cook("grill_corn", "grill", ["corn"], "grill", 5, 4, 9, "grilled_corn"),
        cook("grill_beef", "grill", ["beef"], "grill", 6, 4, 9, "grilled_beef"),
        cook("cook_quesadilla", "pan", ["grated_cheese", "tortilla"], "fry", 5, 4, 9, "hot_quesadilla"),
    ],
    "assemblies": [
        plated("guacamole", "guac_mix"),
        plated("elote", "grilled_corn", "grated_cheese"),
        plated("quesadilla", "hot_quesadilla"),
        plated("beef_taco", "tortilla", "grilled_beef", "chopped_tomato", "grated_cheese"),
    ],
    "role_presets": {
        # Guacamole and elote: no stove but the grill.
        "antojitos": {
            "1": [server("Chef", ["avocado", "tomato", "corn", "cheese", "plate"], board=2, bowl=1, grill=1)],
            "2": [role("Prep", ["avocado", "tomato", "corn"], board=2, bowl=1, grill=1),
                  server("Cheese & Pass", ["cheese", "plate"], board=1)],
            "3": [role("Avocados", ["avocado"], board=1, bowl=1),
                  role("Tomatoes & Corn", ["tomato", "corn"], board=1, grill=1),
                  server("Cheese & Pass", ["cheese", "plate"], board=1)],
            "4": [role("Avocados", ["avocado"], board=1),
                  role("Tomatoes & Corn", ["tomato", "corn"], board=1, grill=1),
                  role("Bowl & Cheese", ["cheese"], board=1, bowl=1),
                  server("Plating & Pass", ["plate"])],
        },
        # The full menu: P1 makes the tortillas and grills, P2 tops and serves.
        "taqueria": {
            "1": [server("Chef", ["avocado", "tomato", "corn", "cheese", "flour", "water", "beef", "plate"],
                         board=2, bowl=1, tortilla_press=1, pan=1, grill=1)],
            "2": [role("Tortillas & Grill", ["flour", "water", "beef", "corn", "avocado"],
                       board=1, bowl=1, tortilla_press=1, pan=1, grill=1),
                  server("Toppings & Pass", ["tomato", "cheese", "plate"], board=1)],
            "3": [role("Prep", ["avocado", "tomato", "cheese"], board=2, bowl=1),
                  role("Tortillas & Grill", ["flour", "water", "beef", "corn"], bowl=1, tortilla_press=1, pan=1, grill=1),
                  server("Plating & Pass", ["plate"])],
            "4": [role("Prep", ["avocado", "tomato"], board=2, bowl=1),
                  role("Tortillas", ["flour", "water", "cheese"], board=1, bowl=1, tortilla_press=1),
                  role("Stove", ["beef", "corn"], pan=1, grill=1),
                  server("Plating & Pass", ["plate"])],
        },
    },
}

MEXICO = {
    "pack": MEXICAN, "file": "mexico", "region": ("mexico", "Mexico"),
    "levels": [
        ("guac_attack", "Guac Attack",
         "Welcome to Mexico City! Everybody wants guacamole: chop avocado and tomato, then mash them in the bowl.",
         {"guacamole": 1}, "antojitos"),
        ("mercado", "Mercado",
         "A busy market stall: guacamole, and corn grilled on the cob with grated cheese.",
         {"guacamole": 1, "elote": 1}, "antojitos"),
        ("quesadilla_rush", "Quesadilla Rush",
         "Knead the dough, press tortillas, fill them with cheese and fry them golden.",
         {"quesadilla": 1, "elote": 1}, "taqueria"),
        ("la_cantina", "La Cantina",
         "Taco Tuesday on a loud night: tacos, quesadillas and guacamole for everyone.",
         {"beef_taco": 2, "quesadilla": 1.5, "guacamole": 1}, "taqueria"),
    ],
    "festival": ("feria_del_elote", "Feria del Elote",
                 "The corn fair fills the plaza. Grilled elote and guacamole for a huge crowd!",
                 {"elote": 2, "guacamole": 1}, "antojitos"),
    "competition": ("copa_del_taco", "Copa del Taco",
                    "Mexico's taco cup. Doña Lupe cooks in wild bursts: sometimes slow, sometimes lightning fast.",
                    ["beef_taco", "quesadilla", "elote"], "taqueria",
                    ["beef_taco", "elote", "quesadilla", "beef_taco", "quesadilla", "elote", "beef_taco"],
                    {"name": "Doña Lupe", "personality": "chaotic", "speed": {"1": 0.75, "2": 1.05, "3": 1.35, "4": 1.55}}),
    "arcade": ({"beef_taco": 2, "quesadilla": 1.5, "elote": 1, "guacamole": 1}, "taqueria"),
}


# --- USA -----------------------------------------------------------------------

AMERICAN = {
    "id": "american",
    "name": "American",
    "items": {
        "ice_cream": raw("Ice cream"),
        "sausage": raw("Sausage"),
        "bun": raw("Bun"),
        "ketchup": raw("Ketchup"),
        "patty": raw("Patty"),
        "cheddar": raw("Cheddar slice"),
        "lettuce": raw("Lettuce"),
        "shake": made("Shake"),
        "grilled_sausage": made("Grilled sausage"),
        "grilled_patty": made("Grilled patty"),
        "chopped_lettuce": made("Chopped lettuce"),
        "milkshake": dish("Milkshake", 14, 45),
        "french_fries": dish("Fries", 20, 55),
        "hot_dog": dish("Hot Dog", 24, 60),
        "cheeseburger": dish("Cheeseburger", 32, 80),
    },
    "stations": {
        # The diner's signature gadget: the milkshake blender.
        "blender": {"name": "Blender", "kind": "manual", "capacity": 3},
    },
    "recipes": [
        manual("blend_shake", "blender", ["ice_cream", "milk", "strawberry"], "blend", 4, "shake"),
        manual("chop_lettuce", "board", ["lettuce"], "chop", 3, "chopped_lettuce"),
        cook("grill_sausage", "grill", ["sausage"], "grill", 5, 4, 9, "grilled_sausage"),
        cook("grill_patty", "grill", ["patty"], "grill", 6, 4, 9, "grilled_patty"),
    ],
    "assemblies": [
        plated("milkshake", "shake"),
        plated("french_fries", "fries"),
        plated("hot_dog", "bun", "grilled_sausage", "ketchup"),
        plated("cheeseburger", "bun", "grilled_patty", "cheddar", "chopped_lettuce", "chopped_tomato"),
    ],
    "role_presets": {
        # Milkshakes and fries.
        "diner_counter": {
            "1": [server("Chef", ["ice_cream", "milk", "strawberry", "potato", "plate"], board=1, blender=1, fryer=1)],
            "2": [role("Kitchen", ["ice_cream", "potato"], board=1, fryer=1, blender=1),
                  server("Counter & Pass", ["milk", "strawberry", "plate"])],
            "3": [role("Ice Cream & Fries", ["ice_cream", "potato"], board=1, fryer=1),
                  role("Blender", ["milk"], blender=1),
                  server("Counter & Pass", ["strawberry", "plate"])],
            "4": [role("Ice Cream", ["ice_cream"]),
                  role("Fries", ["milk", "potato"], board=1, fryer=1),
                  role("Blender", ["strawberry"], blender=1),
                  server("Counter & Pass", ["plate"])],
        },
        # Hot dogs and fries.
        "fair": {
            "1": [server("Chef", ["potato", "sausage", "bun", "ketchup", "plate"], board=1, fryer=1, grill=1)],
            "2": [role("Grill & Fryer", ["potato", "sausage"], board=1, fryer=1, grill=1),
                  server("Buns & Pass", ["bun", "ketchup", "plate"])],
            "3": [role("Fryer", ["potato"], board=1, fryer=1),
                  role("Grill", ["sausage"], grill=1),
                  server("Buns & Pass", ["bun", "ketchup", "plate"])],
            "4": [role("Potatoes", ["potato"], board=1),
                  role("Fryer", [], fryer=1),
                  role("Grill", ["sausage"], grill=1),
                  server("Buns & Pass", ["bun", "ketchup", "plate"])],
        },
        # Burgers, hot dogs and fries.
        "grill_house": {
            "1": [server("Chef", ["potato", "sausage", "bun", "ketchup", "patty", "cheddar", "lettuce", "tomato", "plate"],
                         board=2, fryer=1, grill=2)],
            "2": [role("Grill & Fryer", ["potato", "sausage", "patty", "lettuce"], board=1, fryer=1, grill=2),
                  server("Buns & Pass", ["bun", "ketchup", "cheddar", "tomato", "plate"], board=1)],
            "3": [role("Prep", ["potato", "lettuce", "tomato"], board=2),
                  role("Grill & Fryer", ["sausage", "patty"], grill=2, fryer=1),
                  server("Buns & Pass", ["bun", "ketchup", "cheddar", "plate"])],
            "4": [role("Prep", ["potato", "lettuce", "tomato"], board=2),
                  role("Grill", ["sausage", "patty"], grill=2),
                  role("Fryer", [], fryer=1),
                  server("Buns & Pass", ["bun", "ketchup", "cheddar", "plate"])],
        },
        # The whole diner menu.
        "diner": {
            "1": [server("Chef", ["ice_cream", "milk", "strawberry", "potato", "sausage", "bun", "ketchup", "patty",
                                  "cheddar", "lettuce", "tomato", "plate"], board=2, blender=1, fryer=1, grill=2)],
            "2": [role("Kitchen", ["potato", "sausage", "patty", "lettuce", "ice_cream"], board=1, fryer=1, grill=2, blender=1),
                  server("Counter & Pass", ["bun", "ketchup", "cheddar", "tomato", "milk", "strawberry", "plate"], board=1)],
            "3": [role("Prep", ["potato", "lettuce", "tomato", "strawberry"], board=2),
                  role("Grill & Fryer", ["sausage", "patty"], grill=2, fryer=1),
                  server("Shakes & Pass", ["ice_cream", "milk", "bun", "ketchup", "cheddar", "plate"], blender=1)],
            "4": [role("Prep", ["potato", "lettuce", "tomato", "strawberry"], board=2),
                  role("Grill", ["sausage", "patty"], grill=2),
                  role("Fryer & Blender", ["ice_cream", "milk"], fryer=1, blender=1),
                  server("Buns & Pass", ["bun", "ketchup", "cheddar", "plate"])],
        },
    },
}

USA = {
    "pack": AMERICAN, "file": "usa", "region": ("usa", "USA"),
    "levels": [
        ("shake_it_up", "Shake It Up",
         "New York! Ice cream, milk and strawberries in the blender: the diner's famous milkshakes.",
         {"milkshake": 1}, "diner_counter"),
        ("fries_with_that", "Fries With That?",
         "Every shake wants fries. Cut the potatoes and keep the fryer busy.",
         {"milkshake": 1, "french_fries": 1}, "diner_counter"),
        ("hot_dog_stand", "Hot Dog Stand",
         "Sausages on the grill, buns and ketchup, and a mountain of fries.",
         {"hot_dog": 1, "french_fries": 1}, "fair"),
        ("route_66_diner", "Route 66 Diner",
         "Truckers, tourists and a jukebox. Cheeseburgers, hot dogs and fries all night long.",
         {"cheeseburger": 2, "hot_dog": 1.5, "french_fries": 1}, "grill_house"),
    ],
    "festival": ("county_fair", "County Fair",
                 "A state fair with a Ferris wheel and a never-ending line for hot dogs and fries.",
                 {"hot_dog": 2, "french_fries": 1}, "fair"),
    "competition": ("smoke_and_fire", "Smoke & Fire Championship",
                    "Memphis-style cook-off. Big Earl grills like a showman, and showmen burn things.",
                    ["cheeseburger", "hot_dog", "french_fries"], "grill_house",
                    ["cheeseburger", "french_fries", "hot_dog", "cheeseburger", "hot_dog", "french_fries", "cheeseburger"],
                    {"name": "Big Earl", "personality": "show_off", "speed": {"1": 0.8, "2": 1.1, "3": 1.4, "4": 1.6}}),
    "arcade": ({"cheeseburger": 2, "hot_dog": 1.5, "french_fries": 1, "milkshake": 1}, "diner"),
}


# --- Spain ---------------------------------------------------------------------

SPANISH = {
    "id": "spanish",
    "name": "Spanish",
    "items": {
        "chicken": raw("Chicken"),
        "cold_soup": made("Cold tomato soup"),
        "potato_omelette": made("Potato omelette"),
        "paella_rice": made("Paella rice"),
        "gazpacho": dish("Gazpacho", 14, 45),
        "patatas_bravas": dish("Patatas Bravas", 20, 55),
        "tortilla_espanola": dish("Tortilla Española", 26, 65),
        "paella": dish("Paella", 32, 80),
    },
    "stations": {
        # Spain's signature gadget: the wide, flat paella pan.
        "paella_pan": {"name": "Paella pan", "kind": "cook", "capacity": 3},
    },
    "recipes": [
        manual("stir_gazpacho", "bowl", ["chopped_cucumber", "chopped_tomato", "sliced_bread"], "stir", 5, "cold_soup"),
        cook("cook_omelette", "pan", ["chopped_potato", "egg"], "fry", 6, 4, 9, "potato_omelette"),
        cook("cook_paella", "paella_pan", ["chicken", "chopped_tomato", "rice"], "simmer", 9, 5, 11, "paella_rice"),
    ],
    "assemblies": [
        plated("gazpacho", "cold_soup"),
        plated("patatas_bravas", "fries", "tomato_sauce"),
        plated("tortilla_espanola", "potato_omelette"),
        plated("paella", "paella_rice"),
    ],
    "role_presets": {
        # Gazpacho and patatas bravas.
        "tapas": {
            "1": [server("Chef", ["tomato", "cucumber", "bread", "potato", "plate"], board=2, bowl=1, fryer=1, pan=1)],
            "2": [role("Prep & Stove", ["tomato", "cucumber", "potato"], board=2, fryer=1, pan=1),
                  server("Bread & Pass", ["bread", "plate"], board=1, bowl=1)],
            "3": [role("Vegetables", ["tomato", "cucumber"], board=2),
                  role("Stove", ["potato"], board=1, fryer=1, pan=1),
                  server("Bread & Pass", ["bread", "plate"], board=1, bowl=1)],
            "4": [role("Tomatoes", ["tomato"], board=1),
                  role("Cucumber & Bread", ["cucumber", "bread"], board=2),
                  role("Stove", ["potato"], board=1, fryer=1, pan=1),
                  server("Bowl & Pass", ["plate"], bowl=1)],
        },
        # The full menu.
        "bodega": {
            "1": [server("Chef", ["tomato", "cucumber", "bread", "potato", "egg", "rice", "chicken", "plate"],
                         board=2, bowl=1, fryer=1, pan=2, paella_pan=1)],
            "2": [role("Prep & Stove", ["tomato", "cucumber", "potato", "rice", "chicken"], board=2, fryer=1, pan=2, paella_pan=1),
                  server("Bread, Eggs & Pass", ["bread", "egg", "plate"], board=1, bowl=1)],
            "3": [role("Prep", ["tomato", "cucumber", "potato", "bread"], board=2, bowl=1),
                  role("Stove", ["egg", "rice", "chicken"], fryer=1, pan=2, paella_pan=1),
                  server("Plating & Pass", ["plate"])],
            "4": [role("Vegetables", ["tomato", "cucumber", "bread"], board=2, bowl=1),
                  role("Potatoes", ["potato", "egg"], board=1, fryer=1, pan=1),
                  role("Paella", ["rice", "chicken"], pan=1, paella_pan=1),
                  server("Plating & Pass", ["plate"])],
        },
    },
}

SPAIN = {
    "pack": SPANISH, "file": "spain", "region": ("spain", "Spain"),
    "levels": [
        ("hot_day_in_seville", "Hot Day in Seville",
         "Andalusia in July: chop tomato and cucumber, stir them with bread into cold gazpacho.",
         {"gazpacho": 1}, "tapas"),
        ("tapas_bar", "Tapas Bar",
         "Little plates, big crowd: gazpacho, and fried potatoes with spicy tomato sauce.",
         {"gazpacho": 1, "patatas_bravas": 1}, "tapas"),
        ("tortilla_time", "Tortilla Time",
         "Madrid! Fry potatoes and eggs into a golden tortilla, with bravas on the side.",
         {"tortilla_espanola": 1, "patatas_bravas": 1}, "bodega"),
        ("paella_sunday", "Paella Sunday",
         "Sunday in Valencia: a big pan of paella, tortilla and cold gazpacho until midnight.",
         {"paella": 2, "tortilla_espanola": 1.5, "gazpacho": 1}, "bodega"),
    ],
    "festival": ("fiesta_del_tomate", "Fiesta del Tomate",
                 "A tomato-throwing street party! Cold gazpacho and patatas bravas for the soaked crowd.",
                 {"gazpacho": 2, "patatas_bravas": 1}, "tapas"),
    "competition": ("copa_de_la_paella", "Copa de la Paella",
                    "The paella cup of Sueca. Abuela Carmen has cooked paella for sixty years and never hurries.",
                    ["paella", "tortilla_espanola", "patatas_bravas"], "bodega",
                    ["paella", "patatas_bravas", "tortilla_espanola", "paella", "tortilla_espanola", "patatas_bravas", "paella"],
                    {"name": "Abuela Carmen", "personality": "steady", "speed": {"1": 0.8, "2": 1.1, "3": 1.4, "4": 1.6}}),
    "arcade": ({"paella": 2, "tortilla_espanola": 1.5, "patatas_bravas": 1, "gazpacho": 1}, "bodega"),
}


# --- Japan ---------------------------------------------------------------------

JAPANESE = {
    "id": "japanese",
    "name": "Japanese",
    "items": {
        "salmon": raw("Salmon"),
        "nori": raw("Nori"),
        "noodles": raw("Noodles"),
        "miso": raw("Miso"),
        "spring_onion": raw("Spring onion"),
        "sliced_salmon": made("Sliced salmon"),
        "maki_roll": made("Maki roll"),
        "cut_maki": made("Cut maki"),
        "noodle_soup": made("Noodle soup"),
        "boiled_egg": made("Boiled egg"),
        "chopped_spring_onion": made("Chopped spring onion"),
        "salmon_sashimi": dish("Salmon Sashimi", 14, 45),
        "salmon_nigiri": dish("Salmon Nigiri", 20, 55),
        "cucumber_maki": dish("Cucumber Maki", 26, 70),
        "miso_ramen": dish("Miso Ramen", 32, 80),
    },
    "stations": {
        # Japan's signature gadget: the bamboo mat that rolls maki.
        "sushi_mat": {"name": "Sushi mat", "kind": "manual", "capacity": 3},
    },
    "recipes": [
        manual("slice_salmon", "board", ["salmon"], "slice", 3, "sliced_salmon"),
        manual("chop_spring_onion", "board", ["spring_onion"], "chop", 3, "chopped_spring_onion"),
        manual("roll_maki", "sushi_mat", ["chopped_cucumber", "cooked_rice", "nori"], "roll", 4, "maki_roll"),
        manual("cut_maki_roll", "board", ["maki_roll"], "slice", 3, "cut_maki"),
        cook("cook_noodle_soup", "pot", ["miso", "noodles", "water"], "boil", 7, 5, 11, "noodle_soup"),
        cook("boil_egg", "pot", ["egg", "water"], "boil", 5, 5, 10, "boiled_egg"),
    ],
    "assemblies": [
        plated("salmon_sashimi", "sliced_salmon", "chopped_cucumber"),
        plated("salmon_nigiri", "cooked_rice", "sliced_salmon"),
        plated("cucumber_maki", "cut_maki"),
        plated("miso_ramen", "noodle_soup", "chopped_spring_onion", "boiled_egg"),
    ],
    "role_presets": {
        # Sashimi and nigiri.
        "sushi_bar": {
            "1": [server("Chef", ["salmon", "cucumber", "rice", "water", "plate"], board=2, pot=1)],
            "2": [role("Fish & Cucumber", ["salmon", "cucumber"], board=2),
                  server("Rice & Pass", ["rice", "water", "plate"], pot=1)],
            "3": [role("Fish", ["salmon"], board=1),
                  role("Cucumber & Rice", ["cucumber", "rice", "water"], board=1, pot=1),
                  server("Plating & Pass", ["plate"])],
            "4": [role("Fish", ["salmon"], board=1),
                  role("Cucumber & Rice", ["cucumber", "rice", "water"], board=1, pot=1),
                  role("Knife", [], board=1),
                  server("Plating & Pass", ["plate"])],
        },
        # The full menu.
        "izakaya": {
            "1": [server("Chef", ["salmon", "cucumber", "rice", "water", "nori", "noodles", "miso", "egg", "spring_onion",
                                  "plate"], board=2, pot=2, sushi_mat=1)],
            "2": [role("Rice & Pots", ["rice", "water", "noodles", "miso", "egg", "cucumber"], board=1, pot=2, sushi_mat=1),
                  server("Knife & Pass", ["salmon", "nori", "spring_onion", "plate"], board=1)],
            "3": [role("Knife", ["salmon", "cucumber", "spring_onion"], board=2),
                  role("Pots", ["rice", "water", "noodles", "miso", "egg"], pot=2),
                  server("Rolls & Pass", ["nori", "plate"], sushi_mat=1)],
            "4": [role("Fish", ["salmon", "cucumber"], board=2),
                  role("Rice & Rolls", ["rice", "water", "nori"], pot=1, sushi_mat=1),
                  role("Ramen", ["noodles", "miso", "egg", "spring_onion", "water"], board=1, pot=2),
                  server("Plating & Pass", ["plate"])],
        },
    },
}

JAPAN = {
    "pack": JAPANESE, "file": "japan", "region": ("japan", "Japan"),
    "levels": [
        ("sushi_counter", "Sushi Counter",
         "Tokyo! Slice the salmon, slice the cucumber, lay them on the plate: sashimi.",
         {"salmon_sashimi": 1}, "sushi_bar"),
        ("nigiri_night", "Nigiri Night",
         "Boil the rice and put sliced salmon on top: nigiri, with sashimi on the side.",
         {"salmon_sashimi": 1, "salmon_nigiri": 1}, "sushi_bar"),
        ("maki_time", "Maki Time",
         "Rice, nori and cucumber, rolled on the sushi mat and sliced into maki.",
         {"cucumber_maki": 1, "salmon_nigiri": 1}, "izakaya"),
        ("izakaya", "Izakaya",
         "After work everyone wants ramen: noodles in miso broth, spring onion and an egg. And sushi, of course.",
         {"miso_ramen": 2, "cucumber_maki": 1.5, "salmon_sashimi": 1}, "izakaya"),
    ],
    "festival": ("natsu_matsuri", "Natsu Matsuri",
                 "A summer festival with lanterns and fireworks. Nigiri and sashimi for everyone!",
                 {"salmon_nigiri": 2, "salmon_sashimi": 1}, "sushi_bar"),
    "competition": ("sushi_grand_cup", "Sushi Grand Cup",
                    "The great sushi cup in Tokyo. Master Kenji starts slowly and finishes like a storm.",
                    ["miso_ramen", "cucumber_maki", "salmon_nigiri"], "izakaya",
                    ["salmon_nigiri", "cucumber_maki", "miso_ramen", "salmon_nigiri", "miso_ramen", "cucumber_maki", "miso_ramen"],
                    {"name": "Master Kenji", "personality": "perfectionist", "speed": {"1": 0.85, "2": 1.15, "3": 1.35, "4": 1.4}}),
    "arcade": ({"miso_ramen": 2, "cucumber_maki": 1.5, "salmon_nigiri": 1, "salmon_sashimi": 1}, "izakaya"),
}


# --- France --------------------------------------------------------------------

FRENCH = {
    "id": "french",
    "name": "French",
    "items": {
        "butter": raw("Butter"),
        "jam": raw("Jam"),
        "onion": raw("Onion"),
        "zucchini": raw("Zucchini"),
        "eggplant": raw("Eggplant"),
        "batter": made("Crêpe batter"),
        "thin_crepe": made("Crêpe"),
        "chopped_strawberry": made("Sliced strawberries"),
        "chopped_onion": made("Chopped onion"),
        "onion_broth": made("Onion broth"),
        "soup_to_bake": made("Soup with cheese"),
        "baked_soup": made("Baked onion soup"),
        "chopped_zucchini": made("Sliced zucchini"),
        "chopped_eggplant": made("Diced eggplant"),
        "vegetable_stew": made("Vegetable stew"),
        "tartine": dish("Tartine", 14, 45),
        "crepe": dish("Crêpe", 22, 60),
        "onion_soup": dish("French Onion Soup", 34, 90),
        "ratatouille": dish("Ratatouille", 28, 70),
    },
    "stations": {
        # France's signature gadget: a flat crêpe pan.
        "crepe_pan": {"name": "Crêpe pan", "kind": "cook", "capacity": 1},
    },
    "recipes": [
        manual("whisk_batter", "bowl", ["egg", "flour", "milk"], "whisk", 5, "batter"),
        manual("slice_strawberry", "board", ["strawberry"], "slice", 3, "chopped_strawberry"),
        manual("chop_onion", "board", ["onion"], "chop", 4, "chopped_onion"),
        manual("slice_zucchini", "board", ["zucchini"], "slice", 3, "chopped_zucchini"),
        manual("dice_eggplant", "board", ["eggplant"], "chop", 3, "chopped_eggplant"),
        cook("cook_crepe", "crepe_pan", ["batter"], "fry", 4, 4, 8, "thin_crepe"),
        cook("simmer_onions", "pot", ["chopped_onion", "water"], "simmer", 6, 5, 11, "onion_broth"),
        cook("bake_soup", "oven", ["soup_to_bake"], "bake", 5, 4, 9, "baked_soup"),
        cook("cook_ratatouille", "pan", ["chopped_eggplant", "chopped_tomato", "chopped_zucchini"], "simmer", 7, 5, 10,
             "vegetable_stew"),
    ],
    "assemblies": [
        plated("tartine", "sliced_bread", "butter", "jam"),
        plated("crepe", "thin_crepe", "chopped_strawberry"),
        {"output": "soup_to_bake", "base": "onion_broth", "parts": ["sliced_bread", "grated_cheese"]},
        plated("onion_soup", "baked_soup"),
        plated("ratatouille", "vegetable_stew"),
    ],
    "role_presets": {
        # Tartines and crêpes.
        "cafe": {
            "1": [server("Chef", ["bread", "butter", "jam", "flour", "egg", "milk", "strawberry", "plate"],
                         board=2, bowl=1, crepe_pan=1)],
            "2": [role("Bread & Batter", ["bread", "flour", "egg", "milk"], board=1, bowl=1, crepe_pan=1),
                  server("Toppings & Pass", ["butter", "jam", "strawberry", "plate"], board=1)],
            "3": [role("Bread & Flour", ["bread", "flour"], board=2, bowl=1),
                  role("Crêpes", ["egg", "milk", "butter"], crepe_pan=1),
                  server("Toppings & Pass", ["jam", "strawberry", "plate"], board=1)],
            "4": [role("Bread", ["bread"], board=1),
                  role("Butter & Batter", ["butter", "flour"], bowl=1),
                  role("Crêpes", ["egg", "milk", "jam"], crepe_pan=1),
                  server("Fruit & Pass", ["strawberry", "plate"], board=1)],
        },
        # Crêpes and onion soup.
        "bistro": {
            "1": [server("Chef", ["flour", "egg", "milk", "strawberry", "onion", "water", "bread", "cheese", "plate"],
                         board=2, bowl=1, crepe_pan=1, pot=1, oven=1)],
            "2": [role("Stove", ["flour", "egg", "milk", "onion", "water"], board=1, bowl=1, crepe_pan=1, pot=1, oven=1),
                  server("Toppings & Pass", ["strawberry", "bread", "cheese", "plate"], board=1)],
            "3": [role("Prep", ["onion", "bread", "cheese", "strawberry"], board=2),
                  role("Stove", ["flour", "egg", "milk", "water"], bowl=1, crepe_pan=1, pot=1, oven=1),
                  server("Plating & Pass", ["plate"])],
            "4": [role("Prep", ["onion", "bread", "cheese"], board=2),
                  role("Crêpes", ["flour", "egg", "milk", "strawberry"], board=1, bowl=1, crepe_pan=1),
                  role("Soup", ["water"], pot=1, oven=1),
                  server("Plating & Pass", ["plate"])],
        },
        # Ratatouille, onion soup and tartines.
        "provence": {
            "1": [server("Chef", ["tomato", "zucchini", "eggplant", "onion", "water", "bread", "cheese", "butter", "jam",
                                  "plate"], board=2, pan=1, pot=1, oven=1)],
            "2": [role("Vegetables & Stove", ["tomato", "zucchini", "eggplant", "onion", "water", "bread"],
                       board=2, pan=1, pot=1, oven=1),
                  server("Toppings & Pass", ["cheese", "butter", "jam", "plate"], board=1)],
            "3": [role("Vegetables", ["tomato", "zucchini", "eggplant"], board=2, pan=1),
                  role("Soup", ["onion", "water", "bread", "cheese"], board=1, pot=1, oven=1),
                  server("Toppings & Pass", ["butter", "jam", "plate"])],
            "4": [role("Vegetables", ["tomato", "zucchini", "eggplant"], board=2, pan=1),
                  role("Soup", ["onion", "water"], board=1, pot=1, oven=1),
                  role("Bread & Cheese", ["bread", "cheese"], board=1),
                  server("Toppings & Pass", ["butter", "jam", "plate"])],
        },
        # Crêpes, onion soup and ratatouille.
        "grand_restaurant": {
            "1": [server("Chef", ["flour", "egg", "milk", "strawberry", "onion", "water", "bread", "cheese", "tomato",
                                  "zucchini", "eggplant", "plate"], board=2, bowl=1, crepe_pan=1, pot=1, oven=1, pan=1)],
            "2": [role("Stove", ["flour", "egg", "milk", "onion", "water", "tomato", "zucchini", "eggplant"],
                       board=1, bowl=1, crepe_pan=1, pot=1, oven=1, pan=1),
                  server("Toppings & Pass", ["strawberry", "bread", "cheese", "plate"], board=1)],
            "3": [role("Prep", ["onion", "tomato", "zucchini", "eggplant", "bread", "cheese"], board=2),
                  role("Stove", ["flour", "egg", "milk", "water"], bowl=1, crepe_pan=1, pot=1, oven=1, pan=1),
                  server("Fruit & Pass", ["strawberry", "plate"], board=1)],
            "4": [role("Vegetables", ["tomato", "zucchini", "eggplant", "onion"], board=2, pan=1),
                  role("Crêpes", ["flour", "egg", "milk", "strawberry"], board=1, bowl=1, crepe_pan=1),
                  role("Soup", ["water", "bread", "cheese"], board=1, pot=1, oven=1),
                  server("Plating & Pass", ["plate"])],
        },
    },
}

FRANCE = {
    "pack": FRENCH, "file": "france", "region": ("france", "France"),
    "levels": [
        ("cafe_de_paris", "Café de Paris",
         "Paris! Breakfast at the café: sliced baguette with butter and jam.",
         {"tartine": 1}, "cafe"),
        ("creperie", "La Crêperie",
         "Whisk the batter, cook thin crêpes on the crêpe pan, add sliced strawberries.",
         {"tartine": 1, "crepe": 1}, "cafe"),
        ("le_bistro", "Le Bistro",
         "Onions simmered in the pot, topped with bread and cheese and baked into a bubbling soup.",
         {"onion_soup": 1, "crepe": 1}, "bistro"),
        ("provence", "Provence",
         "Lavender fields and ratatouille: eggplant, zucchini and tomato in the pan. And onion soup for the critics.",
         {"ratatouille": 2, "onion_soup": 1.5, "tartine": 1}, "provence"),
    ],
    "festival": ("fete_de_la_gastronomie", "Fête de la Gastronomie",
                 "Lyon's food festival fills the streets. Crêpes and tartines for everyone!",
                 {"crepe": 2, "tartine": 1}, "cafe"),
    "competition": ("golden_toque", "Golden Toque World Final",
                    "The world final in Lyon. Chef Céleste is the best in the world: beat her and so are you.",
                    ["onion_soup", "crepe", "ratatouille"], "grand_restaurant",
                    ["crepe", "ratatouille", "onion_soup", "crepe", "onion_soup", "ratatouille", "onion_soup"],
                    {"name": "Chef Céleste", "personality": "perfectionist", "speed": {"1": 0.9, "2": 1.2, "3": 1.5, "4": 1.65}}),
    "arcade": ({"onion_soup": 1, "ratatouille": 1.5, "crepe": 1.5}, "grand_restaurant"),
}


# The order of the World Tour.
CUISINES = [ITALY, MEXICO, USA, SPAIN, JAPAN, FRANCE]

# The 3-star score for 1-4 players of each region's shifts 1-4. Set from the
# bot's scores (the bot simulation test prints them): the bot plays much
# better than a person, so each cuisine's tops use Italy's ratio of top score
# to bot score for the same shift and player count, and rise by at least 30
# for each player added.
STAR_TOPS = {
    "italy": [[300, 400, 440, 470], [400, 560, 640, 700], [480, 650, 720, 800], [560, 700, 840, 960]],
    "mexico": [[270, 310, 340, 370], [430, 630, 660, 690], [520, 780, 870, 1020], [600, 840, 990, 1070]],
    "usa": [[410, 440, 520, 550], [470, 560, 630, 770], [600, 810, 840, 880], [680, 980, 1130, 1160]],
    "spain": [[200, 230, 260, 300], [330, 470, 500, 650], [550, 650, 680, 800], [600, 680, 870, 900]],
    "japan": [[360, 420, 450, 480], [500, 600, 630, 700], [520, 660, 730, 860], [620, 750, 890, 920]],
    "france": [[360, 520, 630, 740], [420, 660, 720, 860], [530, 760, 840, 930], [600, 780, 910, 980]],
}


def stars(tops):
    """Star thresholds per player count from the 3-star scores for 1-4 players."""
    out = {}
    for n, top in enumerate(tops, start=1):
        top = int(round(top / 10.0) * 10)
        out[str(n)] = [int(round(top * 0.35 / 10.0) * 10), int(round(top * 0.7 / 10.0) * 10), top]
    return out


def per_players(values):
    return {str(n): v for n, v in enumerate(values, start=1)}


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


def write_cuisine(c, tops):
    pack = c["pack"]
    pid = pack["id"]
    prefix = c["file"]
    pack_format.write(os.path.join(ROOT, "data", "packs", pid + ".json"), pack)
    region_levels = []
    for i, (slug, name, desc, weights, roles) in enumerate(c["levels"]):
        duration, max_active, interval = PACING[i]
        lid = "%s_%02d" % (prefix, i + 1)
        write_level("%s_%s" % (lid, slug), {
            "id": lid, "name": name, "description": desc, "pack": pid, "type": "normal",
            "dishes": dishes(weights), "roles": roles, "duration": duration, "first_spawn": 2,
            "max_active": per_players(max_active), "spawn_interval": per_players(interval), "stars": stars(tops[i]),
        })
        region_levels.append({"id": lid, "stars_required": i * 2})
    slug, name, desc, weights, roles = c["festival"]
    write_level("%s_festival_%s" % (prefix, slug), {
        "id": prefix + "_festival", "name": name, "description": desc, "pack": pid, "type": "festival",
        "dishes": dishes(weights), "roles": roles,
        "patience_multiplier": {"1": 1.3, "2": 1.15, "3": 1.05, "4": 1.0},
        "mood": {"start": 60, "served": 4, "lost": 15}, "wave_break": 6, "waves": FESTIVAL_WAVES,
        "stars": [0, 60, 85],
    })
    region_levels.append({"id": prefix + "_festival", "stars_required": 8})
    slug, name, desc, menu, roles, judges, rival = c["competition"]
    write_level("%s_competition_%s" % (prefix, slug), {
        "id": prefix + "_competition", "name": name, "description": desc, "pack": pid, "type": "competition",
        "dishes": menu, "roles": roles, "judges_orders": judges, "max_active": 2, "time_limit": 360, "rival": rival,
    })
    region_levels.append({"id": prefix + "_competition", "stars_required": 10})
    weights, roles = c["arcade"]
    write_level("arcade_" + pid, {
        "id": "arcade_" + pid, "name": "Arcade: " + pack["name"],
        "description": "Endless %s kitchen. Three angry customers and it's over." % pack["name"],
        "pack": pid, "type": "arcade", "dishes": dishes(weights), "roles": roles, "first_spawn": 2,
        "max_active": per_players([2, 3, 3, 4]), "spawn_interval": per_players([30, 24, 20, 18]),
        "escalate_every": 30, "interval_factor": 0.93, "patience_factor": 0.95, "strikes": 3,
    })
    region_id, region_name = c["region"]
    return {"id": region_id, "name": region_name, "pack": pid, "boss": prefix + "_competition", "levels": region_levels}


def write_json(path, data):
    with open(os.path.join(ROOT, path), "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def main():
    os.makedirs(os.path.join(ROOT, "data", "packs"), exist_ok=True)
    pack_format.write(os.path.join(ROOT, "data", "packs", "common.json"), COMMON)
    regions = []
    for c in CUISINES:
        region_id = c["region"][0]
        regions.append(write_cuisine(c, STAR_TOPS[region_id]))
    write_json("data/story/world_map.json", {"regions": regions})
    write_json("data/recipe_book.json", {
        "comment": "Cuisines that are planned but not in the game yet. The recipe book shows a '?' card for each future dish.",
        "coming_soon": [
            {"cuisine": "Penguin Iceberg", "region": "The Iceberg", "dishes": 3},
            {"cuisine": "Monster Island", "region": "Monster Island", "dishes": 3},
        ],
    })


if __name__ == "__main__":
    main()
