# v0.6 design: the comic-page kitchen

Agreed with the project owner on 2026-10-11. v0.6 rebuilds the kitchen as a
3D comic page and simplifies recipes in the style of Overcooked. It replaces
parts of GAME_PLAN.md §3 (screen), §4 (mini-games), §5 (content model) and
§6 (art). Everything around the kitchen stays as it is: regions with four
shifts, a festival and a competition; stars that scale with the number of
players; unlocking the next region by winning the competition; an arcade
mode per cuisine; 2-player LAN (3–4 players later); and the settings.

## Delivery

- One release, **v0.6.0**. The finished v0.5 work (USA, Spain, France, the
  LATER button, bigger plates) ships with it and is never released alone.
- Work lands as staged pull requests merged into `main` when green, with no
  release until everything is done:
  1. v0.5 and a 7-day limit on dev builds;
  2. the new cooking rules;
  3. the 3D kitchen and comic panels;
  4. content: Italy first as the template, then the other five cuisines;
  5. comic menus.
- Progress is reset (name, chef look and settings are kept), with a one-time
  "The kitchen got a makeover!" note.

## Look

- **Real low-poly 3D** with a comic shader: ink outlines, halftone shadows,
  flat light, Spider-Verse print colors. Godot's Compatibility renderer, so
  mid-range Android phones from about 2019 run it at 30–60 fps.
- **Focus like in comics and anime:** backgrounds are muted and simpler; the
  main actors get full detail and pop in saturated colors (hot magenta, cyan,
  yellow, with a glow and offset color layers): the chefs, the food being
  handled, what can be tapped now, valid drop targets while dragging, ready or
  perfect food, food about to burn, orders about to run out, and the
  teammate's panel while holding food.
- **Models:** CC0 packs (Kenney Food Kit, Kenney Furniture Kit, Quaternius
  kitchen props and characters), recolored by the shader; anything missing
  is built from Godot primitives in code. Credited in CREDITS.md.
- **2D pictures** (order captions, recipe book, crate labels, menu icons) are
  rendered from the 3D models with the same shader. The old SVG pictures go.
- **Chefs** are 3D; the profile's skin, hair, hair colour, hat and apron
  become colors and parts on the model, shown as a turning 3D portrait.
  **Customers** are simple 3D figures with a look per region.

## The comic page

- Each phone shows **one landscape comic page** with irregular panels (the
  busiest panel is the biggest). Three panels hold the player's stations; the
  fourth shows the teammate:
  - **Solo:** pantry (crates), prep (boards, bowl, free spots), cooking (pot,
    pan, oven, fryer, grill) and the pass (plate stack, serving window,
    customers).
  - **2 players:** each role's stations are spread over its own three panels,
    e.g. P1 pantry/prep/cooking and P2 pantry/plating/pass. Panel 4 shows the
    teammate: dropping food on it throws it to them, and on their phone it
    flies in from their teammate panel.
  - **3–4 players:** panel 4 holds stacked inset panels, one per teammate.
  - **Competitions:** the rival's kitchen takes the teammate slot (solo: the
    whole panel 4; with teammates: an extra inset), with a dish counter,
    taunt balloons and "DONE!" splashes.
- **No counter strip:** food sits on spots inside the panels (crates, boards,
  cookware, plates, plus 1–3 free spots per panel).
- **Orders** are caption boxes across the top of the page (dish, its plated
  ingredients, a patience fuse). **Customers** stand at the serving window in
  the pass panel, with speech balloons, getting angrier as the fuse burns.
- **Controls stay direct touch:** tap or drag the food. The player's chef
  appears in the panel where the action happens and plays a short grab, chop
  or throw animation.
- **Mini-games** burst out as a big, tilted **splash panel** over the page,
  its frame breaking over the other panels, the camera punched in on the
  work. LATER, or a tap outside, shrinks it back; the progress is kept.
- **4th-wall gags in v0.6:** food flies across the gutters, over panel
  borders; sound effects break out of the panels; page-turn transitions
  between levels and menus. Later: chefs reaching out of their panel. Not
  planned: narrator captions, customers knocking on the border.
- **Menus are comic pages:** the title screen is a cover; each World Tour
  region is an "issue" with its levels as pages; results are the last panel
  of the issue with a star-rating splash; profile, settings and the recipe
  book are inner pages.
- **Recipe book:** each dish is a small comic strip, one panel per step
  (ingredient, tool, gesture), ending with the plated dish. Undiscovered
  dishes are covered panels; future cuisines say "Coming soon in issue #7!".

## Cooking rules

- **Shared gear for every cuisine:** board (chop), mixing bowl, pot, pan,
  oven, fryer, grill, an unlimited plate stack, bin and serving window.
- **Signature gadgets:** Italy pasta machine (crank: circles), Mexico
  tortilla press (tap), Japan sushi mat (roll: side to side), USA blender
  (circles). Spain and France have none. The other old gadgets go (comal,
  molcajete, grater, rice cooker, griddle, paella pan, crêpe pan, frying pan).
- **Gestures** only for the board, the mixing bowl and signature gadgets.
- **Cookware is hands-off:** it cooks on a timer, has a "perfect" window,
  then burns. Burnt food is binned and frees the cookware. No fire.
- **Contents decide the result:** cookware takes up to 3 items, and only
  items that can still lead to a valid recipe (otherwise NOPE). It starts
  cooking as soon as its contents make a valid recipe; adding an item that
  turns it into another valid recipe resets the timer.
- **Plating in any order:** dishes are put together on a plate and served.
  Cooked food goes from the cookware onto a plate (drag the pot onto the
  plate; the pot stays). Plates can be moved, thrown and served. A pizza
  dough works like a plate: toppings on, then into the oven.
- **Every cuisine:** 4–5 dishes of 2–4 steps each.
- **Italy, the template:**

  | Dish | Steps |
  |---|---|
  | Caprese (first shift, no cooking) | chop tomato, chop mozzarella, basil as is → plate |
  | Bruschetta | chop bread → toast on the grill; chop tomato → plate with basil |
  | Pasta al pomodoro | dough through the pasta machine → pot; chop tomato → pan (sauce) → plate both |
  | Pizza Margherita | flour + water → knead into dough; chopped tomato + chopped mozzarella on the dough → oven → plate |

  Festival (Festa della Pizza): caprese and bruschetta. Competition: pizza,
  pasta and bruschetta.

## New-dish tutorial

- **Prologue before the clock:** each dish in the level that hasn't been
  made yet gets one tutorial order first, one at a time. The clock, patience
  and the rival wait; caption-box tips in the panel of the next step, with
  bright arrows across the gutters, guide every step. Serving it discovers
  the dish and scores nothing. Then a "COOK!" splash starts the real shift.
- In **every level type**: shifts, festivals, competitions and arcade.
- **LAN:** if either player hasn't made a dish, both play its tutorial order
  together, and it counts as discovered for both.
- **SKIP** jumps to the real shift (the dish stays undiscovered, so tips
  still show). Turning off "New-dish tips" in Settings skips prologues.

## Builds

- CI artifacts (dev builds, screenshots) are kept for 7 days, and the daily
  "Clean up old builds" workflow deletes older ones. Release downloads stay.
