# Branding: Night Forge Software Company

Every Night Forge project carries the same studio signature. This page is the
brand kit: copy it (with `art/brand/`) into a new project and follow the
checklist.

## The signature
- **Name:** Night Forge Software Company (short: Night Forge). The company is
  not registered yet, so don't add "Ltd", "Inc." or a ™/® sign.
- **Logo:** `art/brand/night_forge_logo.png`: 400×400 PNG with a transparent
  background. It shows an anvil, an arrow, a crescent and a star, with "NIGHT
  FORGE / SOFTWARE COMPANY" under it. The glow is cyan and the lettering
  white, so always show it on a dark background, never on white or light
  paper.
- **Colours:**
  | Use | Colour |
  |---|---|
  | Night (background) | `#0a0f1e` |
  | Glow (accent) | `#85eef4` |
  | Lettering | `#ffffff` |

## Where it goes
1. **Bootup screen:** the logo, centred on Night, is the first thing the app
   shows.
   - Godot shows it while the engine starts (in `project.godot`, under
     `[application]`: `boot_splash/image`, `boot_splash/bg_color` and
     `boot_splash/stretch_mode=0`).
   - A short studio intro scene then continues it until the game's own title
     screen is ready (here `ui/studio_intro.gd`, about 2 seconds; a tap skips
     it).
2. **Credits:** a "MADE BY" block with the logo on Night and the full name,
   in the game's credits or about screen (here in Settings, `ui/settings.gd`).
   It also goes at the top of `CREDITS.md` and in the README.
3. **Code:** the name, logo path and colours live in one place (here
   `game/brand.gd`, class `Brand`), so a project never spells them out twice.

## Rules
- Keep the logo's proportions; don't recolour, crop or redraw it.
- Leave clear space around it of at least a quarter of its width.
- The logo belongs to Night Forge. It is not covered by the licences of the
  free assets a project uses, so list it separately in the credits.
