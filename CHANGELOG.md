# Changelog

All notable changes to Pass the Plate! are listed here. Versions follow
[semantic versioning](https://semver.org). To release a version, add its
section here, set `config/version` in `project.godot`, and push a tag
`v<version>` (see docs/RELEASING.md).

## [0.5.0] - 2026-10-02

### Added
- **Three new cuisines, each with its own World Tour region:**
  - **USA:** cheeseburgers, fries and milkshakes, with a griddle, a deep fryer
    and a blender (draw circles to blend). The *County Fair* festival (hot dogs
    and fries) and the *Smoke & Fire Championship* against Big Earl, a grill
    showman who sometimes burns things.
  - **Spain:** tortilla española, patatas bravas, paella and gazpacho, with a
    paella pan and a frying pan (whisk eggs with circles). The *Fiesta del
    Tomate* festival (churros and gazpacho) and the *Copa de la Paella*
    against Abuela Carmen.
  - **France:** chocolate crêpes, French onion soup and ratatouille, with a
    crêpe pan. The *Fête de la Gastronomie* festival (croissants and pain
    perdu) and the *Golden Toque World Final* against Chef Céleste, the best
    chef in the world.
  - Arcade for all three, LAN play, 50 new food pictures and 6 new pieces of
    kitchen gear.
  - Recipes share ingredients across cuisines: cut potatoes become fries or go
    into a tortilla, fries with hot sauce become patatas bravas, and Italian
    tomato sauce goes into ratatouille.
- **Pause work and finish it later:** leave a mini-game with the LATER button,
  or just tap anywhere else in the kitchen (the tap still does its job). The
  food keeps its progress ring and gets a tool badge: tap the badge to carry
  on where you stopped. The progress stays with the food when you move it or
  throw it to a teammate.

### Changed
- Food on the counter is **50% bigger**. When the counter is too narrow for
  one row of big plates, it uses two rows.
- The World Tour now goes Italy → Mexico → USA → Spain → Japan → France.
  Regions you already have results in stay open, so a v0.4 save keeps Japan.
- The arcade picker shows the cuisines in two rows.

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
