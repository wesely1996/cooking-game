class_name Brand
extends RefCounted
## The studio's signature: Night Forge Software Company. Its logo opens the
## game (the boot splash and the studio intro) and signs the credits. See
## docs/BRANDING.md.

const NAME := "Night Forge Software Company"
const SHORT_NAME := "Night Forge"
const LOGO_PATH := "res://art/brand/night_forge_logo.png"
## The night sky behind the logo, and the cyan of its glow.
const NIGHT := Color("#0a0f1e")
const GLOW := Color("#85eef4")


static func logo() -> Texture2D:
	return load(LOGO_PATH) as Texture2D
