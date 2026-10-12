class_name Art
extends RefCounted
## Looks up pictures and fonts. Food and station pictures are found by id
## (art/icons/items/<id>.png, art/icons/stations/<id>.png). They are rendered
## from the 3D models by tools/art/render_icons.gd, so they match the kitchen.

const INK := Color("#1d1a2f")
const PAPER := Color("#fffaf0")
const SUN := Color("#ffd75e")
const TOMATO := Color("#e5352b")
const LEAF := Color("#3fae49")
const SKY := Color("#5ab4ea")
const PLAYER_COLORS := [Color("#e5352b"), Color("#3f8fe0"), Color("#3fae49"), Color("#f2b632")]

static var _cache := {}
static var _comic_font: Font
static var _ui_font: Font


static func item(id: String) -> Texture2D:
	return _texture("res://art/icons/items/%s.png" % id)


static func equipment(id: String) -> Texture2D:
	return _texture("res://art/icons/stations/%s.png" % id)


static func comic_font() -> Font:
	if _comic_font == null:
		_comic_font = load("res://art/fonts/Bangers-Regular.ttf")
	return _comic_font


static func ui_font() -> Font:
	if _ui_font == null:
		_ui_font = load("res://art/fonts/Fredoka-SemiBold.ttf")
	return _ui_font


static func _texture(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
