# Cooking Game – Design & Development Plan

Working title: **"Pass the Plate!"** (placeholder)

A cooperative 1–4 player Android cooking game. Each player uses their own phone and
owns only part of the kitchen: some ingredients and some equipment. Players have to
prepare ingredients with short gesture mini-games and **throw** them to each other's
phones to finish the dishes and serve customers before they run out of patience.

---

## 1. Design pillars

1. **You can't do it alone (in multiplayer).** Every recipe has to cross at least two
   players' kitchens. Talking and coordinating is the core of the game.
2. **Hands-on, not button-mashing.** Every action is a short (about 1–4 s) gesture
   mini-game: swipe to chop, tap to knead, circle to stir, flick to throw.
3. **Readable chaos.** There's time pressure, but the screen always shows clearly
   what's needed, who has it, and how much time is left.
4. **Small menus, big pool.** The game has a large ingredient and recipe library,
   but each challenge uses only 2–4 related recipes that share base ingredients.
5. **Comic punch.** The art is a 2.5D cel-shaded comic/anime style with thick ink
   outlines, halftone shading, onomatopoeia bubbles ("WHOOSH!", "CHOP!", "DING!")
   and matching sound effects.

---

## 2. Core gameplay loop

```
Customer arrives at window  ->  Order ticket appears on top bar (all players see it)
        |
Players pull raw ingredients from their crates onto their counter slots
        |
Process ingredients with gesture mini-games (chop, knead, roll, stir, bake...)
        |
Throw intermediate items to the teammate who owns the next step
        |
Assemble the dish -> final cook (oven/pot) -> flick to the serving window
        |
Customer pays (+ tip for speed)  or  leaves angry when patience runs out
```

A round (a "shift") lasts **3–4 minutes**. At the end you get a score and **1–3 stars**,
based on dishes served, tips, and how many customers left angry.

### 2.1 Customers & orders
- Customers queue at the serving window. Each one has an **order ticket** on the top bar:
  - dish icon and name
  - small icons for the required ingredients/components (they tick off as they're added)
  - a **patience bar** under the customer: green → yellow → red, then they leave
- Patience depends on the dish's complexity and the number of players (see §7).
- Serving the wrong dish loses points and the ticket stays open.
- Fast serve: bonus tip. Combo: serve several in a row without losing a customer.

### 2.2 Failure states that keep tension
- **Burning:** oven/pot items have a "perfect" window, then they burn (burnt items are trashed).
- **Full counter:** you can't throw to a teammate whose counter slots are all full
  (their portrait shows a red ✕). This forces players to clear their space.
- **Angry customers:** a lost customer costs score. Losing too many fails the level
  (optional for easy levels).

---

## 3. The player's screen (landscape)

Landscape orientation: phones are held in two hands like a handheld console, and it
gives room for the top bar, sidebar and counter.

```
+---------------------------------------------------------------------------+
| [Ticket 1: Pizza]   [Ticket 2: Pasta]   [Ticket 3: Bruschetta]   ⏱ 2:41  |  <- ORDER BAR
|  🍕 base+sauce+🧀    🍝 pasta+sauce+🌿   🍞 bread+🍅+🧄              ★ 340  |
|  [██████░░] patience [████████░] patience [███░░░░░] patience            |
+---------------+-----------------------------------------------------------+
|  MY KITCHEN   |                                                 (P2 face) |  <- teammate
|  ------------ |        2.5D kitchen counter in perspective                |     portraits
|  🍅 Tomatoes  |                                                           |     = throw
|  🧄 Garlic    |   [slot 1]  [slot 2]  [slot 3]  [slot 4]  [slot 5]       | (P3 face)    targets
|  🌿 Basil     |    🍅chop    🍲sauce    (empty)   (empty)   🍞             |
|  ------------ |                                                           |
|  🔪 Knife     |                                                 (P4 face) |
|  🍲 Pot  [▓▓] |                                                           |
|  🗑 Trash     |   [ quick call: "Need sauce!" "Ready!" "Hurry!" ]         |
+---------------+-----------------------------------------------------------+
```

- **Top: order bar.** Upcoming and active tickets, with the required components and a
  patience bar under each customer. It is shared and identical on every phone.
- **Left sidebar: my kitchen.** This player's ingredient crates (infinite supply),
  tools (knife, rolling pin) and appliances (pot, oven, pasta maker), with progress
  bars for appliances that are cooking.
- **Center: the counter.** 5 slots in front of the player (4 on small screens). Items
  sit here to be worked on, and items thrown by teammates land in the first free slot.
- **Right edge: teammates.** A portrait per teammate, labelled with what they own
  ("Dough", "Oven"). These are throw targets. The serving window appears here for
  whoever owns the pass.
- **Quick calls.** One-tap callouts shown as speech bubbles on the other phones, for
  players who aren't in the same room or can't hear each other.

### 3.1 Interaction model
| Intent | Gesture |
|---|---|
| Take an ingredient | Drag from a crate in the sidebar to a free slot (or tap the crate to fill the first free slot) |
| Use a tool on an item | Tap an item to select it (valid tools glow), then tap the tool. Or drag the tool onto the item. The mini-game then plays on that slot. |
| Put an item into an appliance | Drag the item onto the appliance in the sidebar |
| Combine items | Drag one item onto another (sauce onto pizza base). Invalid combinations bounce back with a "NOPE!" bubble. |
| Throw to a teammate | Flick an item toward a teammate portrait (the nearest portrait in the flick direction is chosen) |
| Serve | Flick the finished dish to the serving window |
| Trash | Drag to the bin |

Only valid actions are ever highlighted, so new players are never stuck guessing.

---

## 4. Action mini-games

All mini-games share one framework: a gesture recognizer feeds progress 0 → 1. Each
mini-game has a target length (about 1–4 s for a competent player) and a visual and
audio beat on every successful input.

| Action | Gesture | Target | Feedback |
|---|---|---|---|
| **Chop** (knife) | Swipe down across the item, ×4–6 | ~1.5 s | "CHOP!" bubble per swipe, item visibly splits |
| **Mash / Knead** (bowl) | Tap rapidly, ×10–15 | ~2 s | dough squashes and stretches, "SQUISH!" |
| **Roll** (rolling pin) | Swipe left-right back and forth, ×3 | ~1.5 s | dough flattens into a disc |
| **Stir** (pot) | Draw circles, ×3 | ~2 s | "SWIRL!", steam puffs |
| **Crank** (pasta maker) | Circular crank, ×2 | ~1.5 s | pasta sheets come out |
| **Grate / Slice** (cheese) | Swipe up and down repeatedly | ~1.5 s | shavings fall |
| **Pour / Sprinkle** | Press and hold, release in a target zone | ~1 s | adds a timing skill element |
| **Bake / Boil** (oven, pot) | Passive timer, pull out during the green window | 6–10 s | the item cooks while you do other things. "DING!" when ready, smoke when burning |
| **Throw** | Flick | 0.4–0.6 s flight | "WHOOSH!" on the sender, "THWACK!" on the receiver |
| **Serve** | Flick to the window | – | "DING DING!" and a coin burst |

Rules:
- Mini-games can be **interrupted**: progress is kept on the item, so you can switch
  to something urgent and come back.
- **Passive** actions (bake, boil) are the main multitasking hooks.
- Haptic tick on every successful input, stronger buzz on completion.
- Accessibility options: "hold instead of rapid tap", and a slider for mini-game length.

---

## 5. Content model (data-driven)

All content lives in data files (JSON), not code, so the ingredient and recipe pool
can grow without touching gameplay logic.

### 5.1 Concepts
- **Ingredient**: a raw item from a crate (`tomato`, `flour`, `egg`, `mozzarella`).
- **Item**: anything on a counter. It has an `id` and optionally a set of `contents`
  for assembled items (`pizza_base{sauce, cheese}`).
- **Equipment**: a tool (`knife`, `rolling_pin`) or an appliance (`oven`, `pot`,
  `pasta_maker`), with capacity and an action type.
- **Transformation**: `inputs + equipment + action -> output`. Every recipe is a graph
  of these.
- **Dish**: a final item that can be ordered, plus its required contents.
- **Cuisine pack**: a themed set of ingredients, equipment, transformations and dishes.
- **Challenge (level)**: a pack, a subset of 2–4 dishes, length, difficulty, and
  authored **role splits** for 1, 2, 3 and 4 players.

### 5.2 Example: Italian pack

Shared bases are what make the challenge interesting: flour feeds both pizza and
pasta, and tomato sauce feeds both pizza and pasta.

```
flour + water   --(bowl: knead)-->        pizza_dough --(rolling_pin: roll)--> pizza_base
flour + egg     --(bowl: knead)-->        pasta_dough --(pasta_maker: crank)--> fresh_pasta
fresh_pasta     --(boil_pot: boil 6s)-->  cooked_pasta
tomato          --(knife: chop)-->        chopped_tomato
chopped_tomato  --(sauce_pot: stir)-->    tomato_sauce
garlic          --(knife: chop)-->        chopped_garlic
mozzarella      --(knife: slice)-->       sliced_mozzarella
bread           --(oven: toast 4s)-->     toast

pizza_base + tomato_sauce + sliced_mozzarella   = raw_pizza  --(oven: bake 8s)--> PIZZA MARGHERITA
cooked_pasta + tomato_sauce + basil             = PASTA POMODORO (plated)
toast + chopped_tomato + chopped_garlic + basil = BRUSCHETTA
```

Example JSON shape:

```json
{
  "transformations": [
    { "id": "knead_pizza_dough", "inputs": ["flour", "water"], "equipment": "mixing_bowl",
      "action": "knead", "difficulty": 12, "output": "pizza_dough" },
    { "id": "bake_pizza", "inputs": ["raw_pizza"], "equipment": "oven",
      "action": "bake", "cook_time": 8.0, "perfect_window": 4.0, "output": "pizza_margherita",
      "burns_to": "burnt_food" }
  ],
  "dishes": [
    { "id": "pizza_margherita", "base_patience": 70, "price": 30 }
  ]
}
```

### 5.3 Role splits (who owns what)

Each challenge has a hand-authored split per player count, so it always feels
designed rather than random. The Italian challenge with 3 players matches the
original idea:

| Player | Owns | Job |
|---|---|---|
| **P1 – Dough** | flour, water, eggs, mixing bowl, rolling pin, pasta maker | makes pizza bases and fresh pasta |
| **P2 – Sauce** | tomatoes, garlic, basil, knife, sauce pot | makes sauce, toppings, assembles pizzas and pasta |
| **P3 – Oven & Pass** | mozzarella, bread, oven, boil pot, serving window | cooks, finishes and serves |

Pizza flow: P1 kneads and rolls the base → throws it to P2 → P2 adds sauce and throws
it to P3 → P3 slices and adds cheese, bakes, serves.

- **2 players:** merge roles, e.g. Dough+Oven / Sauce+Pass.
- **4 players:** split further, e.g. a separate "Cheese & Bread" station.
- **1 player (solo):** owns everything. See §7.

A **level validator**, run in tests and at load time, checks that for every player
count every dish is reachable, every required ingredient and equipment is owned by
someone, and multiplayer recipes cross at least two players.

### 5.4 Planned content pool
| Pack | Dishes (examples) | Shared bases |
|---|---|---|
| Italian | Pizza margherita, pasta pomodoro, bruschetta, lasagna, carbonara | dough, tomato sauce, cheese |
| Mexican | Tacos, burrito, quesadilla, nachos, guacamole | tortillas, salsa, beans, cheese |
| Burger diner | Burger, cheeseburger, fries, hot dog, milkshake | buns, patties, potatoes |
| Japanese | Maki roll, nigiri, onigiri, ramen, tempura | rice, fish, nori, batter |
| Breakfast | Pancakes, omelette, toast, smoothies | eggs, batter, fruit |
| Bakery/Desserts | Cake, cookies, croissant | flour, butter, sugar |
| Indian, Chinese, Greek, French … | added over time | – |

Each pack has 3–5 challenges that introduce dishes gradually, for example
"Pizza only" → "Pizza + Bruschetta" → "Full Trattoria".

Alongside the real-world cuisines, there are **imaginary cuisines** that use the same
system with silly customers and twisted ingredients:

| Imaginary pack | Customers | Dishes (examples) | Twist |
|---|---|---|---|
| Penguin Iceberg | penguins | fish sushi, frozen fish skewers, krill bowls | slippery counters: thrown items slide to a random slot |
| Monster Diner | friendly monsters | slime burgers, eyeball soup | some customers change their order halfway |
| Space Station | aliens | moon-cheese pizza, zero-g noodles | low gravity: throws arc slowly |
| Pirate Galley | pirates and parrots | ship biscuits, fish stew | the kitchen rocks; items occasionally shift slots |

These packs give the story mode set-piece levels and let the content grow beyond what
is realistic.

---

## 5A. Game modes

### 5A.1 Story mode: "World Food Tour"
- **Premise:** the players are a ragtag food-truck crew (later a flying food-ship)
  touring the world to feed everyone. A light, comic-book storyline is told in short
  comic-panel cutscenes between regions: a page or two of panels with speech bubbles,
  skippable, in the same art style as the game.
- **World map:** a stylized, hand-drawn globe/map. The crew's vehicle travels along a
  route between **regions**, and each region is one cuisine pack:
  Italy → Mexico → USA diner → Japan → … → imaginary detours (an iceberg with
  penguins, a monster island, a pirate sea, outer space).
- **Region structure:** each region is a cluster of 3–5 level nodes on the map (the
  pack's challenges), ending with a **boss shift**: a special customer such as a food
  critic, the Penguin King, or a hungry kraken, with a tougher combination of the
  region's dishes.
- **Progression:** stars from each level unlock the route onward. Optional bonus
  nodes need a certain number of stars. New equipment and dishes are introduced one
  region at a time, so the tutorial continues naturally through the story.
- **Co-op progress:** story progress is saved on each player's device. In
  multiplayer, the host's map is used, and every player who finishes a level
  gets credit for it.
- **Rewards:** stars unlock regions; completing regions unlocks cosmetic chef outfits,
  food-truck skins and portrait frames.

### 5A.2 Arcade mode: high score
- **Choose your cuisine:** the players pick any **unlocked** cuisine pack (real or
  imaginary). Optionally there's a "Mixed" option with a random selection of dishes.
- **Endless shift:** customers keep coming and the pace slowly increases (shorter
  patience, more simultaneous orders, harder dishes rotated in). The run ends after
  **3 angry customers** ("3 strikes").
- **Score:** points per dish, tips for speed, and a **combo multiplier** for serving
  without losing anyone.
- **Leaderboards:** local high scores per cuisine and per player count (1/2/3/4). They
  become online leaderboards once internet play exists.
- Optional variant: **Timed Rush**, a fixed 5-minute score attack per cuisine.

### 5A.3 Other entry points
- **Quick Play:** replay any unlocked story level directly.
- **Tutorial:** the first story level doubles as the tutorial.

---

## 6. Art & audio direction

### 6.1 Visual style: "2.5D comic kitchen"
- **Everything is 2D sprites**, staged to look 3D:
  - the counter and kitchen are drawn in perspective (slight top-down, about 30°)
  - several parallax layers (back wall, shelves, counter, foreground items)
  - soft drop shadows under items, which also shrink during throw arcs to sell height
  - items scale along the throw arc, so they look like they're flying at the camera
- **Borderlands / comic look:**
  - thick, slightly uneven black ink outlines, drawn into the art and reinforced by
    a Godot outline shader
  - cel shading with 2–3 flat tones per material, and hatching/halftone dots in the shadows
  - saturated, warm palette, with each player color-coded (red/blue/green/yellow)
- **Characters:** anime-ish chibi chefs as player portraits, with expressions that
  react to events (panic when a customer is about to leave, cheer on a serve).
  Customers are expressive caricatures whose faces get angrier as patience drops.
- **Juice:** onomatopoeia bubbles (comic lettering, random tilt, pop-in), screen shake
  on impacts, squash & stretch, particle bursts (flour puffs, steam, coins), speed
  lines on throws.
- **Readability rules:** icons are always shown on a light "ticket paper" background,
  and item states differ in shape (whole / chopped / sauce), not only in color, which
  also helps color-blind players.

### 6.2 Art pipeline
- Vector art in Inkscape or Krita, exported as PNG atlases at 2× resolution.
- Shaders in Godot: ink outline, halftone shadow, "hit flash".
- Placeholder art: flat-color shapes with outlines, good enough to playtest from day one.
- If needed, buy or commission a character/food icon set later. The data-driven design
  means art can be swapped in without code changes.

### 6.3 Audio
- A short SFX per action (chop, squish, sizzle, whoosh, thwack, ding, angry grumble),
  from CC0 libraries (freesound, Kenney) or made with sfxr/jsfxr.
- Light upbeat music per pack (e.g. mandolin/accordion for Italian) that **speeds up**
  in the last 30 seconds.
- Haptics through the Android vibration API.

---

## 7. Single-player & scaling

**Solo mode:**
- The player owns all equipment. The sidebar groups it into **station tabs** (Dough /
  Sauce / Oven). Tapping a tab switches the counter view, and each station keeps its
  own slots.
- "Throwing" becomes dragging an item onto another station's tab, which keeps the
  same mental model.
- Longer patience and fewer simultaneous customers.

**Scaling by player count** (starting values, tuned in playtests):

| Players | Max active orders | Patience multiplier | Spawn interval |
|---|---|---|---|
| 1 | 2 | ×1.8 | long |
| 2 | 3 | ×1.3 | medium |
| 3 | 3 | ×1.1 | medium |
| 4 | 4 | ×1.0 | short |

---

## 8. Technology choices

### 8.1 Engine: **Godot 4 (latest stable 4.x), GDScript**
Why Godot:
- Free and open source, with no royalties or runtime fees.
- Very strong 2D tooling: sprites, shaders, particles, tweens, animation, parallax.
- First-class Android export. It also exports to desktop, which makes testing several
  players on one PC easy.
- Built-in **high-level multiplayer** (ENet over UDP for LAN; WebSocket and WebRTC
  peers for internet play) with RPCs and a scene replication system.
- Light APK size and runs well on low-end phones.
- Headless mode for automated tests and a possible dedicated relay or server later.

Alternatives considered: Unity (heavier toolchain, licensing churn), Flutter + Flame
(weaker game tooling and multiplayer), Defold (smaller ecosystem). Godot is the best
fit for a 2D networked mobile game.

### 8.2 Architecture

```
res://
  data/                   # JSON content: ingredients, equipment, transformations, dishes, packs, levels
  core/                   # pure game logic, no rendering
    content_db.gd         #   loads + validates data
    recipe_engine.gd      #   "what can this item become with this equipment/action?"
    order_system.gd       #   customer spawning, patience, scoring
    kitchen_state.gd      #   authoritative state: players, slots, appliances, items
    level_validator.gd
  net/
    net_session.gd        # host/join, peer list, message routing (transport-agnostic)
    transport_lan.gd      # ENetMultiplayerPeer + UDP broadcast discovery
    transport_online.gd   # (later) WebSocket/WebRTC through a relay server
    protocol.gd           # message definitions + (de)serialization
  gameplay/
    kitchen_view.tscn     # counter, slots, sidebar, teammate portraits
    order_bar.tscn
    minigames/            # chop, knead, roll, stir, crank, bake...
    gestures/             # swipe / flick / tap-rate / circle / hold recognizers
  fx/                     # onomatopoeia bubbles, particles, shaders, screen shake
  ui/                     # main menu, lobby, results, settings, world map, arcade picker
  story/                  # world map data, region/level nodes, comic cutscene scripts
  audio/
  tests/                  # GUT unit tests + headless simulation
```

**Key principle:** game logic (`core/`) is separate from presentation and transport.
The same `KitchenState` runs in solo, LAN and online play.

### 8.3 Multiplayer model: host-authoritative
- In LAN mode, one phone **hosts** and runs the authoritative `KitchenState`. It also
  plays as a normal player.
- Clients send **intents**: `spawn_ingredient`, `start_action`, `complete_action`,
  `combine`, `throw(item, target_player)`, `serve(item, ticket)`, `trash`.
- The host validates each intent (does the player own that equipment? is the slot
  free? is the transformation valid?), applies it, and broadcasts **events/state
  deltas** to everyone.
- **Mini-games run locally** on the player's phone for instant response. Only the
  start and completion are sent, so latency never makes a gesture feel laggy. The host
  sanity-checks durations.
- **Throws hide latency:** the sender's item animates out immediately. The receiver's
  item lands when the host confirms, and the 0.4–0.6 s flight time covers network delay.
- Join and reconnect: the host sends a full snapshot. A player who drops can rejoin
  their seat by room code within a timeout.
- Order timers and patience run on the host clock. Clients interpolate display only.

### 8.4 LAN discovery
- The host broadcasts a small UDP beacon (game name, room code, player count,
  version) on the local network every second.
- The "Join" screen lists found games. Manual IP entry as a fallback, since some
  routers block broadcast.
- Requires Android `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` and
  `CHANGE_WIFI_MULTICAST_STATE` (for the multicast lock).

### 8.5 Internet play (final version)
Mobile networks and NAT make direct peer-to-peer connections unreliable, so the plan is:
- **A small relay server** (Godot headless or a lightweight Node/Go service) with
  **room codes**. The host phone stays authoritative; the relay only forwards packets
  over WebSockets.
- The `NetSession` / transport interface means only `transport_online.gd` is new.
  Game logic is unchanged.
- Later optional upgrade: WebRTC peer-to-peer with a signaling server and TURN
  fallback, or a dedicated authoritative server for anti-cheat and leaderboards.
- Hosting: a cheap VPS or Fly.io. A friends-only co-op game has very low bandwidth.

---

## 9. Development milestones

Each milestone ends with something playable or testable.

### M0 – Project setup
- Godot 4 project, folder structure, `.gitignore`, Android export preset.
- GitHub Actions: run the headless test suite, and build a debug APK as an artifact.
- GUT (Godot Unit Test) installed.

### M1 – Core logic (headless, fully tested)
- Content DB plus JSON schema for ingredients, equipment, transformations, dishes, levels.
- Recipe engine (valid actions and combinations, item states, burning).
- Order system (spawning, patience, scoring, stars).
- Kitchen state with intents and events.
- Level validator.
- Italian pack data: pizza, pasta, bruschetta.
- Unit tests and a "bot" simulation that plays a full shift headlessly.

### M2 – Single-player vertical slice (placeholder art)
- Landscape kitchen screen: order bar, sidebar, 5 counter slots, station tabs.
- Gesture recognizers and the first mini-games: **chop, knead, roll, bake**.
- Drag/flick interactions, combining, trash, serving.
- One playable challenge: "Pizza only", solo.
- **Goal: find out whether the moment-to-moment feel is fun.** Tune timings here.

### M3 – Full action set & Italian pack
- Stir, crank, slice, boil, pour mini-games.
- All three Italian dishes, three challenges, results screen, stars, simple progression.
- Basic SFX and onomatopoeia bubbles (placeholder lettering).

### M4 – LAN multiplayer (2–4 players)
- Lobby (host/join, discovery, room code, ready-up, role reveal screen).
- Host-authoritative networking, throws between phones, teammate portraits.
- Quick-call emotes.
- Reconnect handling.
- Role splits for 2/3/4 players with the validator passing.
- Playtest on real phones on the same Wi-Fi.

### M5 – Art & audio pass
- Comic/anime art for kitchen, food items, characters and customers.
- Outline and halftone shaders, parallax kitchen, throw arcs with shadows.
- Full SFX set, music per pack, haptics, screen shake, particles.
- Main menu and UI skin.

### M6 – Story mode, arcade mode & content
- **World map** screen with route, level nodes, region unlocks via stars, and save data.
- **Comic-panel cutscene** player (data-driven: panels, speech bubbles, transitions).
- First story arc: Italy (with tutorial) → Mexico → Penguin Iceberg (first imaginary
  region), each with a boss shift.
- **Arcade mode:** cuisine picker, endless escalating shift, 3-strike rule, combo
  scoring, local high scores per cuisine and player count.
- Mexican, Burger and Penguin packs; 3–5 challenges each.
- Settings and accessibility options.

### M7 – Internet play
- Relay server with room codes, `transport_online.gd`, latency and disconnect
  handling, invite via share link or code.
- Online arcade leaderboards.
- More story regions (Japan, Monster Diner, Space Station, …) ship as content updates.

### M8 – Release polish
- Performance on low-end Android, battery/thermal checks, different screen ratios
  and notches.
- Google Play listing, signing, privacy policy, closed beta.

---

## 10. Testing strategy
- **Unit tests (GUT):** recipe engine, order system, scoring, level validator, protocol
  serialization.
- **Content tests:** every level is solvable for 1–4 players (validator run in CI).
- **Headless simulation:** bots play full shifts, to catch soft-locks and to balance
  timers (e.g. "can 3 average bots serve 70% of customers?").
- **Network tests:** run 2–4 desktop instances locally, with artificial latency and
  packet loss.
- **Device playtests:** after M2, M4 and M5, on real phones.

---

## 11. Risks & mitigations
| Risk | Mitigation |
|---|---|
| Gestures feel fiddly on small screens | Prototype in M2 before building content; generous hit areas; tunable thresholds |
| Gesture conflicts (flick vs. swipe-chop) | Mini-games are modal on their slot; flicks only start from an idle item |
| LAN discovery blocked by router | Manual IP / QR-code join fallback |
| Network desync | Single authoritative host, idempotent events, snapshot resync |
| Art workload | Data-driven content and placeholder art first; consistent simple style; possible asset packs |
| Players overwhelmed | 2–4 dishes per challenge, highlighted valid actions, gradual tutorial |
| Solo mode less fun than co-op | Station tabs, tuned patience, own solo star thresholds |

---

## 12. Open questions for the project owner
1. **Engine:** OK with Godot 4 + GDScript? (Alternative: C# in Godot.)
2. **Orientation:** landscape (recommended) or portrait?
3. **Throw targets:** can anyone throw to anyone, or only to "neighbours" around a
   virtual table (harder and more chaotic)?
4. **Failure:** should challenges be failable (too many angry customers ends the
   shift), or always finish with a star rating?
5. **Story:** who is the crew, and what are they travelling in (food truck, flying
   ship, train)? Is there a goal for the tour (a world cooking championship, finding
   a legendary recipe)?
6. **Monetization:** free, paid, or free with cosmetic chef skins? This affects
   accounts and backend for online play.
7. **Art:** will you or someone on the team draw the art, or should the plan assume
   asset packs plus commissioned key art?

---

## 13. Immediate next steps (once the plan is approved)
1. M0: create the Godot project skeleton, CI, Android export preset.
2. M1: implement and test the content model and recipe engine with the Italian pack.
3. M2: build the solo "Pizza only" vertical slice to test the feel of the gestures.
