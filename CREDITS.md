# Credits

Pass the Plate! is made by **Night Forge Software Company**. The Night Forge
logo (`art/brand/night_forge_logo.png`) belongs to Night Forge and is not
covered by the asset licences below (see docs/BRANDING.md).

## Engine
- [Godot Engine](https://godotengine.org) 4.7.2, MIT license.

## Fonts
| File | Source | Author | License |
|---|---|---|---|
| `art/fonts/Bangers-Regular.ttf` | [Google Fonts](https://fonts.google.com/specimen/Bangers) | The Bangers Project Authors | SIL Open Font License 1.1 (`art/fonts/LICENSE-OFL.txt`) |
| `art/fonts/Fredoka-SemiBold.ttf` | [Google Fonts](https://fonts.google.com/specimen/Fredoka) | The Fredoka Project Authors | SIL Open Font License 1.1 (`art/fonts/LICENSE-OFL.txt`) |

## Art and audio
- 3D models from [Kenney](https://kenney.nl), CC0 1.0 (public domain); each
  pack's `License.txt` is kept next to its models:
  - `art/models/food`: [Food Kit](https://kenney.nl/assets/food-kit)
  - `art/models/furniture`: [Furniture Kit](https://kenney.nl/assets/furniture-kit)
  - `art/models/characters`: [Mini Characters](https://kenney.nl/assets/mini-characters-1)
- Some food (mozzarella, basil, dough, pasta) and stations (grill, fryer, pasta
  machine, serving window) are built from simple shapes in `game/look/models.gd`.
- The comic shaders (`art/shaders`) were written for this project.
- Food and station pictures (`art/icons`) are rendered from those models by
  `tools/art/render_icons.gd`.
- Sound effects are synthesized in code at start-up (`game/sfx.gd`).

Every third-party asset added later must be listed here with its source and
license (CC0 preferred).
