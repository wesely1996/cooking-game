# Pass the Plate! (working title)

A cooperative 1–4 player Android cooking game. Each player owns part of the
kitchen on their own phone. Players prepare ingredients with gesture mini-games
and throw them to each other to serve customers around the world.

- **Design and plan:** [docs/GAME_PLAN.md](docs/GAME_PLAN.md)
- **Engine:** Godot 4.7.2, GDScript, landscape, GL Compatibility renderer

## Status

| Milestone | State |
|---|---|
| M0: project setup, test runner, CI | done (Android export comes with M2) |
| M1: core game rules, Italian content, bots | done |
| M2: playable solo vertical slice | next |

## Project layout

```
core/            game rules, no rendering (runs headless)
  content_db.gd    items, equipment, processes, assemblies (recipes)
  kitchen_state.gd players' counters, crates, appliances; all player intents
  shift.gd         one play session: kitchen + customers + score
  rules/           normal, festival (horde), competition (boss), arcade
  rival_chef.gd    the AI chef in competitions
  level_def.gd, level_validator.gd, progression.gd
  sim/kitchen_bot.gd  bot that plays levels through the same intents as players
data/
  packs/           cuisine packs (JSON): ingredients, recipes, role splits
  levels/          levels (JSON)
  story/           world map (regions, star requirements)
tests/             headless tests (tests/unit/test_*.gd)
tools/             test runner script, balancing report
ui/                scenes (only a placeholder start screen so far)
```

## Running

Download [Godot 4.7.2](https://godotengine.org/download) and open `project.godot`,
or from the command line:

```sh
# all tests (GODOT defaults to "godot" on PATH)
GODOT=/path/to/godot tools/run_tests.sh

# only tests whose name contains "kitchen"
GODOT=/path/to/godot tools/run_tests.sh kitchen

# balancing: how bots of different speeds do on each level
/path/to/godot --headless --path . --script res://tools/balance_report.gd -- italy_01
```

## Adding content

Cuisines, recipes and levels are JSON files, so most content needs no code:

1. Add ingredients, processes and assemblies to a pack in `data/packs/`.
2. Add levels to `data/levels/` and list them on the map in `data/story/world_map.json`.
3. Run the tests. They check that every recipe can be made, that every level
   works with 1–4 players, and that bots can actually finish it.
