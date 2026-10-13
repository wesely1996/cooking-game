# Changelog

All notable changes to Pass the Plate! are listed here. Versions follow
[semantic versioning](https://semver.org). To release a version, add its
section here, set `config/version` in `project.godot`, and push a tag
`v<version>` (see docs/RELEASING.md).

## [Unreleased]

### Added
- **Night Forge Software Company:** the studio's logo is the app's bootup
  screen, and the credits in Settings are signed "Made by Night Forge
  Software Company".

### Fixed
- Your chef is bigger than life in the kitchen and stands just behind the
  counters, so their face (and usually the hat) shows above them instead of
  only the top of the head. Picking food up is a reach, not a bend, so the
  chef's head never covers the counters.

## [0.6.3] - 2026-10-12

### Added
- **Recipes on the orders:** tap an order to pop its recipe out in a comic
  speech bubble, in short steps ("Chop TOMATO", "Bake RAW PIZZA in OVEN").
  It goes away after 5 seconds, or when you tap it.

### Changed
- Order tickets show the dish's raw ingredients along the bottom, and the
  whole dish name.
- Tips while learning a dish fit how you play: alone, they tell you when
  your food is cooking instead of asking you to wait for a teammate; with
  friends, they say whose turn it is and who is throwing you what.

### Fixed
- Food in the pantry is no taller than its shelf (the flour and the water
  no longer poke through the shelf above).

## [0.6.2] - 2026-10-12

### Changed
- **Fewer kinds of mini-game:** chopping, slicing and grating are tapped now,
  like kneading. The swipe-down mini-game is gone; tapping, side-to-side
  rolling and circles stay.

### Fixed
- Your chef no longer stands between the two rows of a panel, hiding the
  back row while working at the front: he always stands behind the back row.

## [0.6.1] - 2026-10-12

Less clunky: bigger things to tap, nothing in the way, clearer mini-games.

### Changed
- **The kitchen uses its space:** the page picks the panel layout that shows
  everything biggest for your kitchen (solo, team and competition kitchens
  get different layouts), the cameras zoom in on the counter tops instead of
  the cabinet fronts, and each panel is a tap target: a tap goes to the
  nearest station or crate in the panel, so the whole column is yours to hit.
- **Teammates stand one above the other**, each in a panel of their own.
- **The rival is a small status card:** what they're cooking, a progress bar
  and their dishes and points.
- **Tips, the "LEARNING" banner and customers' speech balloons go away when
  you tap them** (that tap does nothing else). A tip comes back at the next
  step. Teammate name tags are small and see-through.
- **Mini-games say what to do:** one huge word (SWIPE!, TAP!, ROLL!,
  CIRCLE!), a big animated arrow for the gesture, a trail behind your
  finger, what you're making ("CHOP THE TOMATO") and how many more to go.
- **Choose your chef:** pick one of 10 chefs, a hat (toque, cap, bandana or
  none), the hat's colour and the apron's colour. Your old chef carries over.

### Fixed
- The 0.6.0 notes listed old v0.5 menus that the new kitchen replaced.

## [0.6.0] - 2026-10-12

v0.6 rebuilds the kitchen as a 3D comic page with Overcooked-style recipes
(see docs/V06_DESIGN.md). It also carries the unreleased 0.5 work that still
fits the new kitchen (0.5.0 was never released on its own).

### Changed: Overcooked-style cooking
- **Multipurpose kitchen gear** shared by every cuisine: chopping board,
  mixing bowl, pot, pan, oven, grill and fryer, plus counter spots and a
  plate stack. Italy keeps one signature gadget, the pasta machine.
- **What's inside decides the result:** a pot or pan takes up to three things
  and cooks as soon as they make a recipe; it only takes things that can.
  Changing what's inside starts the cooking again.
- **Food sits where the work happens:** on boards, in bowls and pots, on
  counter spots. Boards, the bowl and gadgets are worked with gestures; pots,
  pans and ovens cook on their own.
- **Plating in any order:** dishes are put together on a plate, and dropping
  the pan on a plate moves just the sauce. A pizza dough works like a plate.
- **Italy's simpler menu:** caprese (no stove), bruschetta, pasta al
  pomodoro and pizza margherita, in four new shifts, the *Sagra in Piazza*
  festival and the *Gran Premio* competition.
- **The kitchen screen is a comic page** with panels for the pantry, prep,
  stove, the pass, your teammates and (in competitions) the rival.
- **All six cuisines on the new rules**, each with four dishes (the first
  needs no stove), one signature gadget, four shifts, a festival, a
  competition and an arcade kitchen:
  - Mexico (tortilla press): guacamole, elote, quesadilla, beef taco.
  - USA (blender): milkshake, fries, hot dog, cheeseburger.
  - Spain (paella pan): gazpacho, patatas bravas, tortilla española, paella.
  - Japan (sushi mat): salmon sashimi, salmon nigiri, cucumber maki, miso
    ramen.
  - France (crêpe pan): tartine, crêpe, French onion soup, ratatouille.
- Chicken mole, yakitori, miso soup, buffalo wings, churros, croissants and
  pain perdu are gone from the menus.

### Added
- **A 3D comic kitchen:** every panel is a live 3D view with a comic-book
  look: ink outlines, halftone shading and Spider-Verse colours. The
  background stays muted while food, chefs and the station you can use right
  now pop out. Models are Kenney's CC0 packs.
- **Chefs, customers and a rival on stage:** your chef walks to the station
  you use and works it, teammates react in the team panel, customers queue at
  the pass with speech balloons and cheer or storm off, and the rival cooks
  in their own panel.
- **Food flies across the panel gutters** when it moves between panels or
  is thrown to a teammate.
- **Menus are comic pages:** the title screen is a cover starring your
  chef in 3D; the World Tour is a series of issues (#1 Italy ... #6 France)
  whose levels are the panels of a page, locked ones covered; results are
  the issue's last panel with a star splash and "TO BE CONTINUED...";
  profile, settings, the play menu, the lobby and the recipe book are inner
  pages. Every screen change turns the page.
- **Recipes are comic strips:** one panel per step (what goes in, the tool,
  the gesture or cooking time, what comes out), ending with the plated dish.
  Undiscovered dishes are covered panels; future cuisines are "coming soon
  in issue #7".
- **Splash-panel mini-games:** chopping, kneading and stirring open a tilted
  comic splash panel with a close-up of the station.
- Food and station pictures (order cards, recipe book) are rendered from the
  3D models, so they match the kitchen.
- **New-dish tutorial:** before the clock starts, each dish you've never made
  is cooked once with tips, scoring nothing, then the real shift starts. In
  LAN games it runs when either chef is new to a dish. SKIP jumps straight
  in; turning tips off skips it.
- **The kitchen got a makeover:** saves from earlier versions keep the name,
  chef and settings but start the World Tour fresh, with a one-time note.

### Infrastructure
- Dev builds and screenshots from CI are kept for 7 days, and a daily
  cleanup workflow deletes older ones. Release downloads are kept forever.

### Also in this release
- **Pause work and finish it later:** leave a mini-game with the LATER button,
  or just tap anywhere else in the kitchen (the tap still does its job). The
  food keeps its progress, even when you move it or throw it to a teammate;
  tap it again to carry on.
- The World Tour goes Italy → Mexico → USA → Spain → Japan → France.

## [0.4.0] - 2026-10-02

### Added
- **Two new cuisines, each with its own World Tour region:**
  - **Mexico:** beef tacos, guacamole and quesadillas. New kitchen gear: a
    comal griddle, a tortilla press (tap to press), a molcajete (tap to mash)
    and a grater (swipe down). Four shifts, the *Feria del Mole* festival
    (elote and chicken mole) and the *Copa del Taco* competition against
    Doña Lupe, whose speed is unpredictable.
  - **Japan:** salmon nigiri, cucumber maki and miso ramen, with a rice
    cooker, a sushi mat and a grill. Four shifts, the *Natsu Matsuri*
    festival (yakitori and miso soup) and the *Sushi Grand Cup* against Master
    Kenji, who starts slowly and finishes fast.
  - Arcade for both cuisines, and LAN play for all of it.
- **Profile:** pick your name and how your chef looks (skin, hair, hair
  colour, hat, apron, or "Surprise me!"). It shows your **favourite cuisine**
  (the one you play most) and your **best cuisine** (highest average score),
  plus shifts played, dishes served, stars, recipes and regions reached.
  In LAN games your friend sees your name and chef on the teammate portrait.
- **Settings:** sound, vibration, new-dish tips, easy mini-games (every
  gesture counts double), reset progress, and credits.

### Changed
- **Cleaner menus:** the title screen has PLAY, PROFILE, RECIPE BOOK and
  SETTINGS. PLAY leads to the World Tour, Play with a friend and Arcade (with
  a cuisine picker).
- The World Tour has a tab per region. A locked region says which
  competition opens it.
- The LAN host picks levels grouped by region, plus arcade per cuisine.
- Water, tomatoes, eggs and chicken are shared basics that every cuisine can
  use.
- The kitchen sidebar switches to three smaller columns when a kitchen has
  many crates (e.g. the solo sushi bar).

## [0.3.0] - 2026-10-02

### Added
- **2-player LAN play** for the story levels and arcade: **Play with a
  friend** on the title screen. One phone hosts a kitchen, the other joins
  it on the same Wi-Fi. Kitchens nearby appear by themselves, or type the
  address shown on the host's phone.
- Each chef owns half the kitchen (e.g. *Dough & Oven* and *Sauce & Pass*).
  **Throw food** to your friend by dragging it onto their portrait, or tap the
  food and then the portrait. Portraits glow when your friend can use the
  food and show how much room their counter has.
- "WHOOSH!" when you throw and "CATCH!" when food lands on your counter.
- Pausing pauses the kitchen for both chefs. The host picks the level,
  retries or goes back to the lobby; the friend follows. Both phones save
  the stars and the new dishes.
- If a phone leaves, the other one returns to the lobby with a message.
- Arcade best scores are kept per player count.

### Technical
- The host runs the game rules and sends the friend's phone a snapshot of the
  kitchen 15 times a second; the friend's taps are sent to the host as
  actions, checked there, and answered. Both phones must run the same version.
- A LAN test runs two copies of the game on one computer in CI: discovery,
  joining, a pizza cooked across both kitchens with real drag gestures,
  results, lobby, arcade and a disconnect.

## [0.2.0] - 2026-10-01

### Added
- **Recipe book** (from the title screen and the world map): step-by-step
  instructions for every dish you have served, locked silhouettes for dishes
  you haven't made yet (with the level where you'll find them), and "?" cards
  for the cuisines still to come (Mexican, American, Spanish, Japanese,
  French, Penguin Iceberg).
- **NEW!** badge on tickets for dishes you have never made, and a big
  "NEW DISH!" moment the first time you serve one.

### Changed
- **Tips and arrows now appear only while you make a dish for the first
  time**, in any level, instead of on fixed levels.
- **Star targets depend on the number of players and get harder each level.**
  Solo: Pizza Night 70/140/200, Aperitivo 90/180/260, Pasta e Pizza
  110/220/320, Full Trattoria 140/290/420. With 2, 3 and 4 players the
  targets are about 1.35×, 1.65× and 1.9× higher.

## [0.1.0] - 2026-10-01

The first playable build: solo play in Italy.

### Added
- **Pizza Night and the Italy tour:** four shifts (pizza, bruschetta, pasta,
  the full trattoria), the *Festa della Pizza* festival and the *Gran Premio
  della Pizza* competition against the rival chef Bruno "Il Fulmine". Stars
  unlock the next levels.
- **Arcade mode (Italian):** an endless kitchen that gets faster until three
  customers leave angry. Best score is saved.
- **Kitchen screen:** customer tickets with patience bars, your crates and
  tools, ovens and pots with cooking timers, a counter with 8 spots, the
  serving window and the bin.
- **Gesture mini-games:** swipe down to chop and slice, tap to knead, swipe
  side to side to roll, draw circles to stir. Ovens and pots cook on their
  own; take food out in the green window for a PERFECT bonus, or it burns.
- **Tap or drag controls:** selecting food highlights everything it can go to.
- **Chef's tips** on the first two levels show the next step.
- Comic style: generated ink-outline art, onomatopoeia bubbles ("CHOP!",
  "DING!", "BURNT!"), synthesized sound effects and vibration.
- Title screen, world map, results with stars, save data, Android back button.

### Known limitations
- Solo only. LAN multiplayer for 2–4 phones comes next.
- Placeholder art and sounds; balance comes from bot simulations, not yet
  from real playtests.
