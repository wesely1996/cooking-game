# Changelog

All notable changes to Pass the Plate! are listed here. Versions follow
[semantic versioning](https://semver.org). To release a version, add its
section here, set `config/version` in `project.godot`, and push a tag
`v<version>` (see docs/RELEASING.md).

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
