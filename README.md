# Pass the Plate! (working title)

[![CI](https://github.com/wesely1996/cooking-game/actions/workflows/ci.yml/badge.svg)](https://github.com/wesely1996/cooking-game/actions/workflows/ci.yml)
[![Release](https://github.com/wesely1996/cooking-game/actions/workflows/release.yml/badge.svg)](https://github.com/wesely1996/cooking-game/releases)

A cooperative 1–4 player Android cooking game. Each player owns part of the
kitchen on their own phone. Players prepare ingredients with gesture mini-games
and throw them to each other to serve customers around the world.

- **Download:** [latest release](https://github.com/wesely1996/cooking-game/releases)
  (Android APK, Windows, Linux, Web)
- **Design and plan:** [docs/GAME_PLAN.md](docs/GAME_PLAN.md)
- **Builds and releases:** [docs/RELEASING.md](docs/RELEASING.md) · [CHANGELOG.md](CHANGELOG.md)
- **Engine:** Godot 4.7.2, GDScript, landscape, GL Compatibility renderer

## Status

| Milestone | State |
|---|---|
| M0: project setup, test runner, CI | done (Android export comes with M2) |
| M1: core game rules, Italian content, bots | done |
| M2: playable solo kitchen (Italy levels, arcade) | done |
| CI/CD: tests, smoke test, Android/desktop builds, releases | done |
| M4 (part 1): 2-player LAN for story and arcade | done (v0.3.0) |
| M3: polish, real playtests · M4: 3–4 players | next |

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
  net/             LAN: state snapshots (shift_sync), host and client sessions
data/
  packs/           cuisine packs (JSON): ingredients, recipes, role splits
  levels/          levels (JSON)
  story/           world map (regions, star requirements)
tests/             headless tests (tests/unit/test_*.gd)
tools/             test runner script, balancing report
game/              the playable game: kitchen screen, mini-games, effects, sound,
                   net/net.gd (ENet transport, handshake, LAN discovery)
ui/                menus: title, world map, lobby, recipe book, results
art/               fonts and the generated SVG pictures (tools/art/generate_art.py)
```

## How to play (solo)

- **Tap a crate** to take an ingredient (or drag it onto a counter spot).
- **Tap food** to select it: everything it can go to glows. Then tap (or drag
  the food onto) a tool, an appliance, other food, the serving window or the bin.
- **Tools open a mini-game:** swipe down to chop, tap to knead, swipe side to
  side to roll, draw circles to stir.
- **Ovens and pots cook on their own.** Take food out while the ring is green
  for a PERFECT bonus. Wait too long and it burns.
- **With a friend (LAN):** both phones on the same Wi-Fi → *Play with a
  friend*. One hosts, the other joins (the kitchen shows up by itself, or type
  the host's address). Each of you owns half the kitchen: drag food onto your
  friend's portrait to throw it to them.
- The first time you make a new dish, a **NEW DISH TIP** and arrows show
  every step. After you've served it once, you're on your own, but the
  **recipe book** remembers how.

## Running

Download [Godot 4.7.2](https://godotengine.org/download) and open `project.godot`,
or from the command line:

```sh
# all tests (GODOT defaults to "godot" on PATH)
GODOT=/path/to/godot tools/run_tests.sh

# only tests whose name contains "kitchen"
GODOT=/path/to/godot tools/run_tests.sh kitchen

# smoke test: runs the real screens with taps, drags and swipes (uses xvfb-run
# when available, saving screenshots to build/screenshots)
GODOT=/path/to/godot tools/smoke_test.sh

# LAN test: two copies of the game cook together over real sockets
# (uses xvfb-run when available; screenshots in build/lan_screenshots)
GODOT=/path/to/godot tools/lan_test.sh

# balancing: how bots of different speeds do on each level
/path/to/godot --headless --path . --script res://tools/balance_report.gd -- italy_01
```

## Adding content

Cuisines, recipes and levels are JSON files, so most content needs no code:

1. Add ingredients, processes and assemblies to a pack in `data/packs/`.
2. Add levels to `data/levels/` and list them on the map in `data/story/world_map.json`.
3. Run the tests. They check that every recipe can be made, that every level
   works with 1–4 players, and that bots can actually finish it.
