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
- Serving a dish nobody ordered doesn't count: it bounces back with a "NOPE!" bubble.
- Fast serve: bonus tip. Combo: serve several in a row without losing a customer.

### 2.2 Failure states that keep tension
- **Burning:** oven/pot items have a "perfect" window, then they burn (burnt items are trashed).
- **Full counter:** you can't throw to a teammate whose counter slots are all full
  (their portrait shows a red ✕). This forces players to clear their space.
- **Angry customers:** a lost customer costs score.
- **Normal levels can't be failed.** They always end with a 0–3★ rating. Only
  **festival (horde)** and **competition (boss)** levels can be lost (see §5A.2).

### 2.3 Throwing to anyone
- **Every player can throw to every other player.** With 4 players, each screen has 3
  teammate portraits on the right edge, plus the serving window for whoever owns it.
- The extra choice is deliberate: players have to agree on who needs what. To keep it
  readable:
  - each portrait shows that player's role ("Dough", "Sauce", "Oven") and how many of
    their slots are free
  - when you pick up an item, the portraits of teammates who **can use it** glow; you
    can still throw to anyone
  - flicks resolve to the nearest portrait along the flick direction, and portraits
    are spaced far apart so they're hard to mix up

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
- **Premise:** four chefs who have never cooked together team up with one goal: to
  become **the best chefs in the world**. They travel the world to learn each region's
  cuisine from the locals, cook at its biggest food festival, and win its most famous
  cooking competition. The imaginary regions (penguins, monsters, pirates, space) are
  detours along the way. The story is told in short, skippable comic-panel cutscenes
  between regions: a page or two of panels with speech bubbles, in the game's art style.
- **The crew:** four chefs, one per player color, each with a simple personality for
  the cutscenes, e.g. the hot-headed one, the calm perfectionist, the clumsy optimist
  and the show-off. In solo play the player controls the whole crew. Names and designs
  come later.
- **World map:** a stylized, hand-drawn globe/map. The crew travels along a route
  between **regions**, and each region is one cuisine pack:
  Italy → Mexico → USA → Spain → Japan → France (the finale), with imaginary detours in
  between (an iceberg with penguins, a monster island, a pirate sea, outer space).
- **Region structure:** a region is a cluster of level nodes on the map:
  1. 3–5 **normal levels** that introduce the region's dishes one at a time
  2. 1 **festival (horde) level**, unlocked by stars
  3. 1 **competition (boss) level** against a rival AI chef, unlocked by stars, which
     opens the route to the next region when you win it
- **Progression:** **stars unlock levels.** Each node needs a total number of stars
  (e.g. the festival needs 6★ from the region, the competition 9★). Replaying levels for
  more stars is how stuck players progress. New equipment and dishes are introduced one
  region at a time, so the tutorial continues naturally through the story.
- **Co-op progress:** story progress is saved on each player's device. In
  multiplayer, the host's map is used, and every player who finishes a level
  gets credit for it.
- **Rewards:** completing regions unlocks cosmetic chef outfits, kitchen themes and
  portrait frames (see §5A.5).

### 5A.2 Level types

| | Normal level | Festival (horde) level | Competition (boss) level |
|---|---|---|---|
| **Length** | 3–4 min | 6–8 min, in waves | 4–5 min, in rounds |
| **Recipes** | 2–4 dishes of the region | 1–2 **simple** dishes (1–3 steps) | the region's signature dishes, the hardest combination |
| **Customers** | normal queue | a **huge crowd**: many customers, short gaps, waves that build up | a **judges' table** with a fixed list of orders |
| **Can you fail?** | No. Always ends with 0–3★ | **Yes.** A **crowd mood meter** drops when customers leave hungry; when it's empty, the festival is a flop | **Yes.** You lose if the rival AI chef finishes first or gets the higher score |
| **Feel** | learning and mastering | an endurance grind: fast, repetitive, rhythmic | a tense race against an opponent you can see |

**Festival (horde) levels**
- Based on real food festivals in each region (see §5A.4). Lots of characters,
  bunting and music in the background.
- The crowd comes in **waves**, with a short breather between them. Each wave is bigger
  and faster than the last.
- Recipes are deliberately simple, e.g. "pizza slice", "taco", "ramen bowl". The
  challenge is volume and stamina, not complexity.
- The **crowd mood meter** goes up a little with every served customer and down
  sharply with every lost one. When it's empty, the level fails. If you survive every
  wave you clear the level, and stars are based on the final mood and the score.

**Competition (boss) levels**
- Based on real cooking competitions in each region (see §5A.4), with a fictional name,
  a judging panel, and a host announcer in the cutscenes.
- **The rival AI chef cooks the same dishes** at the same time. A rival panel on the
  top bar shows the rival's portrait, which dish they are on, a progress bar per dish,
  and how many dishes they have finished.
- The judges' order list is the same for both kitchens. The rival is a simulation that
  runs through the same recipe steps with its own timing. It doesn't need fake
  gestures; it just steps through the recipe at a set pace.
- **Rival personalities** make each boss different:
  - *steady*: a constant pace, the baseline
  - *show-off*: very fast but sometimes burns something and has to redo it
  - *perfectionist*: slow start, speeds up near the end
  - *chaotic*: unpredictable bursts
- **Win condition:** finish the judges' list before the rival, or have the higher
  **judges' score** when time runs out. The score counts dishes finished, perfect
  cooks (taken out during the green window), and no burnt dishes.
- **Difficulty scales with player count**, so that 1 player and 4 players get an
  equally fair fight.
- **Taunts:** the rival shouts comic speech bubbles ("Too slow!", "Is that burnt?!"),
  and the crowd reacts when you overtake.

### 5A.3 Arcade mode: high score
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

### 5A.4 Region plan with real-world references

In-game events get **fictional names** inspired by the real ones, so we avoid trademark
issues (e.g. Bocuse d'Or®, World Sushi Cup®, MasterChef®).

| Region | Festival (horde) inspired by | Competition (boss) inspired by |
|---|---|---|
| **Italy** | Napoli Pizza Village: Naples' seafront pizza festival with 600k+ visitors → *"Festa della Pizza"* (pizza slices, simple pasta) | World Pizza Championship (Campionato Mondiale della Pizza), Parma → *"Gran Premio della Pizza"*; it even has a "fastest pizza maker" category |
| **Mexico** | Feria Nacional del Mole, San Pedro Atocpan (every October) → *"Feria del Mole"* (tacos and simple mole plates) | No single famous competition, so a fictional Iron-Chef-style *"Copa del Taco"* |
| **USA** | A Fourth-of-July cookout / state fair → *"County Fair"* (hot dogs, burgers) | Memphis in May World Championship Barbecue Cooking Contest → *"Smoke & Fire BBQ Championship"* (ribs, wings, sauce) |
| **Spain** | La Tomatina–style street festival → *"Fiesta del Tomate"* (tapas) | International Valencian Paella Competition of Sueca (since 1961) → *"Copa de la Paella"* |
| **Japan** | Tokyo Ramen Festa (Komazawa Olympic Park) → *"Ramen Matsuri"* | World Sushi Cup Japan, Tokyo → *"Sushi Grand Cup"* |
| **France (finale)** | Lyon street-food festival → *"Fête de la Gastronomie"* | Bocuse d'Or and the World Pastry Cup (Coupe du Monde de la Pâtisserie), both at SIRHA in Lyon → *"Golden Toque World Final"*: the last boss, the best AI chef in the world |
| **Penguin Iceberg** (imaginary) | *"Krill Carnival"*: a colony of hungry penguins | *"The Penguin King's Feast"*: the king's personal chef as the rival |
| **Monster Island** (imaginary) | *"Monster Mash Night"* | *"Fright Chef"* |

### 5A.5 Free-to-play model
- The game is **free**, and **all gameplay content** is earned by playing (stars,
  regions, arcade cuisines).
- Possible later revenue, only **cosmetic**: chef outfits, kitchen themes, portrait
  frames, throw-trail effects. No energy timers, no pay-to-win, no paid boosts.
- Optional rewarded ads only (e.g. "watch an ad for a bonus cosmetic"), never forced
  ads during a level.
- Decided later, but the code keeps a clear separation between "unlocked by progress"
  and "owned cosmetics" so a store can be added.

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

### 5A.6 Other entry points
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
**Phase 1 (now): generated art.** Claude makes the art:
- Food items, equipment, UI and portraits are hand-written **SVG files** in a
  consistent comic style: flat colors, thick dark outlines, a highlight and a shadow
  tone. Godot imports SVG directly, and they scale cleanly to any screen.
- A few effects are drawn in code: onomatopoeia bubbles, the patience bars, and
  particles.
- Shaders: ink outline, halftone shadow, "hit flash".
- **Free assets** fill the gaps, but only clearly licensed ones (CC0 preferred: Kenney,
  OpenGameArt CC0, freesound CC0 for audio). Every third-party file is listed in
  `CREDITS.md` with its source and license.
- Each item's art is chosen by its id in the data files (`art/items/<id>.svg`), so any
  file can be replaced later without touching code.

**Phase 2 (later):** replace the generated art with commissioned or hand-drawn art,
starting with the most visible things: characters, customers, the hero dishes.

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

### 8.1 Engine: **Godot 4.7.2 (stable), GDScript**
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
  tests/                  # headless unit tests + bot simulations (own small runner)
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

### M0 – Project setup ✅
- Godot 4.7.2 project, folder structure, `.gitignore`, placeholder start screen.
- A small headless test runner (`tests/run_tests.gd`, `tools/run_tests.sh`), so no
  test add-on is needed.
- GitHub Actions runs the test suite on every push.
- The Android export preset and debug-APK build in CI move to M2, when there is
  something to play on a phone.

### M1 – Core logic (headless, fully tested) ✅
- Content DB plus JSON schema for ingredients, equipment, transformations, dishes, levels.
- Recipe engine (valid actions and combinations, item states, burning).
- Order system (spawning, patience, scoring, stars).
- Kitchen state with intents and events.
- Level validator.
- Level types: normal (star rating), festival (waves and crowd mood meter), and
  competition (rival AI chef simulation with personalities and a judges' score).
- Italian pack data: pizza, pasta, bruschetta, plus the "Festa della Pizza" festival
  and the "Gran Premio della Pizza" competition.
- Unit tests and a "bot" simulation that plays a full shift headlessly.

**M1 results and notes**
- All content is data: `data/packs/*.json` (items, equipment, processes, assemblies,
  role presets), `data/levels/*.json`, and `data/story/world_map.json`.
- An assembly keeps its base item and lists the parts added to it. An item counts as
  the assembly it completes (e.g. pizza base + sauce + cheese = raw pizza margherita),
  so "drop sauce onto the base" and "drop the base onto the sauce" both work.
- Every player action is a plain Dictionary *intent* (`take`, `work`, `insert`,
  `work_appliance`, `remove`, `combine`, `move`, `throw`, `serve`, `trash`,
  `trash_appliance`), and every change is an *event* Dictionary. That is exactly
  what the LAN and online layers will send.
- `KitchenBot` plays any level through those intents. The tests check that bots can
  finish every Italian level with 1, 2, 3 and 4 players.
- `tools/balance_report.gd` runs bots at different speeds. The first spawn rates,
  patience values and star thresholds come from it: 1★ is a slow bot team, 2★ an
  average one, 3★ a good one. Bots don't spend time reading orders or talking, so
  **these numbers must be re-tuned with real players in M2.**

### M2 – Single-player vertical slice (placeholder art) ✅ (v0.1.0)
- Landscape kitchen screen: order bar, sidebar, 5 counter slots, station tabs.
- Gesture recognizers and the first mini-games: **chop, knead, roll, bake**.
- Drag/flick interactions, combining, trash, serving.
- One playable challenge: "Pizza only", solo.
- **Goal: find out whether the moment-to-moment feel is fun.** Tune timings here.

**M2 results:** every Italy level and arcade are playable solo, with tap or
drag controls, all gesture mini-games (chop, slice, knead, roll, stir, crank),
cooking timers with a perfect window, chef's tips on the first levels, comic
bubbles, synthesized sounds and vibration. The art is generated SVG
(`tools/art/generate_art.py`). CI/CD builds Android, Windows, Linux and Web
on every push and publishes tagged releases (docs/RELEASING.md).

**v0.2.0:** recipe book (known recipes step by step, locked dishes, "?" for
future cuisines), tips only while making a dish for the first time, and star
targets that depend on the player count and rise level by level.

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

**v0.3.0 (M4, part 1):** 2-player LAN for story levels and arcade, as
planned in §8.3–8.4: the host phone runs the rules (`core/net/host_session.gd`),
the other phone mirrors it from snapshots sent 15× per second and sends its
actions as intents (`core/net/client_session.gd`); ENet on port 24568, UDP
discovery beacons on port 24569, manual IP as a fallback, version handshake,
shared pause, disconnect handling. Throwing works by dragging food onto the
teammate's portrait. Still to do for M4: 3–4 players (more portraits, a lobby
for up to 3 guests) and reconnecting to a running game.

**v0.4.0:** Mexico (taqueria + *Feria del Mole* + *Copa del Taco*) and Japan
(sushi bar + *Natsu Matsuri* + *Sushi Grand Cup*) regions with arcade modes.
For now Japan comes right after Mexico; USA and Spain will slot in between
later. Also a profile (name, chef look, favourite cuisine = most played, best
cuisine = highest average score), a settings screen, and a Play menu that
holds the World Tour, LAN and arcade.

**v0.5.0:** USA (diner + *County Fair* + *Smoke & Fire Championship*), Spain
(tapas bar + *Fiesta del Tomate* + *Copa de la Paella*) and France (bistro +
*Fête de la Gastronomie* + *Golden Toque World Final*, the last boss for now).
The World Tour order is now Italy → Mexico → USA → Spain → Japan → France, as
in §5A.4; a region with saved results stays open, so v0.4 players keep Japan.
The new cuisines share bases with the old ones (cut potatoes make fries and
the Spanish tortilla, fries plus hot sauce make patatas bravas, Italian tomato
sauce goes into ratatouille, Mexican grated cheese tops the onion soup).
Kitchen changes: food on the counter is 50% bigger (two rows when the counter
is narrow), and mini-game work can be paused (LATER, or tap anywhere else) and
resumed from a tool badge on the food; the progress travels with the food,
even when it's thrown to a teammate.

### M5 – Art & audio pass
- Comic/anime art for kitchen, food items, characters and customers.
- Outline and halftone shaders, parallax kitchen, throw arcs with shadows.
- Full SFX set, music per pack, haptics, screen shake, particles.
- Main menu and UI skin.

### M6 – Story mode, arcade mode & content
- **World map** screen with route, level nodes, region unlocks via stars, and save data.
- **Comic-panel cutscene** player (data-driven: panels, speech bubbles, transitions).
- First story arc: Italy (with tutorial) → Mexico → Penguin Iceberg (first imaginary
  region), each with a festival and a competition.
- Rival chef presentation: rival panel, taunt bubbles, and a judges' results screen.
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
- **Unit tests:** recipe engine, order system, scoring, level validator, protocol
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

## 12. Decisions made by the project owner
| Question | Decision |
|---|---|
| Engine | **Godot 4 + GDScript** (pinned to Godot 4.7.2) |
| Orientation | **Landscape** |
| Throw targets | **Anyone can throw to anyone** (§2.3) |
| Failure | Normal levels: **star rating only**. Festival (horde) and competition (boss) levels **can be failed** (§5A.2) |
| Progression | **Stars unlock new levels** and regions (§5A.1) |
| Story | **Four chefs** who want to become the best in the world, travelling the world to learn its cuisines (§5A.1) |
| Boss levels | Competitions inspired by **real cooking contests**, against a **rival AI chef cooking the same dishes** (§5A.2, §5A.4) |
| Horde levels | **Festivals**: huge crowds, longer, simpler recipes (§5A.2) |
| Monetization | **Free to play**; cosmetic-only if anything (§5A.5) |
| Art | **Claude generates the art** (SVG) for now, plus clearly licensed free assets; replaced later (§6.2) |

Still open, not blocking: the chefs' names and looks, and the name of the game.

---

## 13. Immediate next steps
1. M0: create the Godot project skeleton, CI, Android export preset.
2. M1: implement and test the content model, recipe engine, level types (normal,
   festival, competition with rival AI) and the Italian pack.
3. M2: build the solo "Pizza only" vertical slice to test the feel of the gestures.
