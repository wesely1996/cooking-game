class_name ChefLook
extends RefCounted
## A player's chef, drawn in the comic style: skin tone, hair, hat and apron.
## A look is a small Dictionary of option indexes, so it can be saved and
## sent to the other phone in a LAN game.

const SKINS := [Color("#f6d2b0"), Color("#eab88f"), Color("#c98e62"), Color("#9a6440"), Color("#6b4428")]
const HAIR_STYLES := ["Short", "Curly", "Long", "Mohawk", "Bald"]
const HAIR_COLORS := [Color("#2b2523"), Color("#7a4422"), Color("#e0a830"), Color("#c0563a"), Color("#e8e4dc"), Color("#4f6fd8")]
const HATS := ["Toque", "Cap", "Bandana", "No hat"]
const APRONS := [Color("#e5352b"), Color("#3f8fe0"), Color("#3fae49"), Color("#f2b632"), Color("#b48ce0"), Color("#2b2523")]

## The editable parts, with their option lists and display names.
const PARTS := {
	"skin": {"label": "Skin", "count": 5},
	"hair": {"label": "Hair", "count": 5},
	"hair_color": {"label": "Hair colour", "count": 6},
	"hat": {"label": "Hat", "count": 4},
	"apron": {"label": "Apron", "count": 6},
}


static func default_look() -> Dictionary:
	return {"skin": 0, "hair": 0, "hair_color": 0, "hat": 0, "apron": 0}


## A valid look from any (saved or received) Dictionary.
static func sanitize(look: Variant) -> Dictionary:
	var result := default_look()
	if look is Dictionary:
		for part in PARTS:
			result[part] = posmod(int(look.get(part, 0)), PARTS[part].count)
	return result


static func option_name(part: String, index: int) -> String:
	match part:
		"hair":
			return HAIR_STYLES[index]
		"hat":
			return HATS[index]
	return "%d" % (index + 1)


static func option_color(part: String, index: int) -> Variant:
	match part:
		"skin":
			return SKINS[index]
		"hair_color":
			return HAIR_COLORS[index]
		"apron":
			return APRONS[index]
	return null


## Draws the chef's head and shoulders, `size` pixels tall, centred on `center`.
static func draw(c: CanvasItem, center: Vector2, size: float, look: Dictionary, mood: float = 1.0) -> void:
	look = sanitize(look)
	var s := size / 200.0
	var ink := Art.INK
	var skin: Color = SKINS[look.skin]
	var hair_color: Color = HAIR_COLORS[look.hair_color]
	var apron: Color = APRONS[look.apron]
	var head := center + Vector2(0, -10) * s
	var w := 7.0 * s

	# Shoulders: white chef jacket with a coloured apron and neckerchief.
	var body := center + Vector2(0, 70) * s
	var jacket := PackedVector2Array([body + Vector2(-78, 30) * s, body + Vector2(-66, -22) * s, body + Vector2(66, -22) * s, body + Vector2(78, 30) * s])
	c.draw_colored_polygon(jacket, Color.WHITE)
	_outline(c, jacket, ink, w)
	var bib := PackedVector2Array([body + Vector2(-32, 30) * s, body + Vector2(-26, -8) * s, body + Vector2(26, -8) * s, body + Vector2(32, 30) * s])
	c.draw_colored_polygon(bib, apron)
	_outline(c, bib, ink, w * 0.7)
	var scarf := PackedVector2Array([body + Vector2(-22, -24) * s, body + Vector2(22, -24) * s, body + Vector2(0, -2) * s])
	c.draw_colored_polygon(scarf, apron.lightened(0.25))
	_outline(c, scarf, ink, w * 0.6)

	# Long hair goes behind the head.
	if look.hair == 2:
		c.draw_rect(Rect2(head + Vector2(-50, -10) * s, Vector2(100, 80) * s), hair_color)
		c.draw_rect(Rect2(head + Vector2(-50, -10) * s, Vector2(100, 80) * s), ink, false, w * 0.7)

	# Head.
	c.draw_circle(head, 48 * s, skin)
	c.draw_arc(head, 48 * s, 0, TAU, 40, ink, w, true)
	c.draw_circle(head + Vector2(-48, 6) * s, 9 * s, skin)
	c.draw_circle(head + Vector2(48, 6) * s, 9 * s, skin)

	# Hair on top.
	match look.hair:
		0:  # short
			c.draw_arc(head, 44 * s, PI * 1.08, PI * 1.92, 20, hair_color, 18 * s, true)
		1:  # curly
			for i in 7:
				var a := PI * (1.05 + i * 0.15)
				c.draw_circle(head + Vector2(cos(a), sin(a)) * 42 * s, 13 * s, hair_color)
		2:  # long, fringe
			c.draw_arc(head, 42 * s, PI * 1.05, PI * 1.95, 20, hair_color, 20 * s, true)
		3:  # mohawk
			var crest := PackedVector2Array([head + Vector2(-12, -40) * s, head + Vector2(0, -80) * s, head + Vector2(12, -40) * s])
			c.draw_colored_polygon(crest, hair_color)
			_outline(c, crest, ink, w * 0.6)

	# Face: eyes, brows, mouth that follows the mood (1 happy .. 0 grumpy).
	for side in [-1, 1]:
		c.draw_circle(head + Vector2(18 * side, 2) * s, 6 * s, ink)
		c.draw_circle(head + Vector2(18 * side + 2, 0) * s, 2 * s, Color.WHITE)
		c.draw_line(head + Vector2(10 * side, -12 + (1.0 - mood) * 4 * side) * s, head + Vector2(26 * side, -14) * s, ink, 4 * s, true)
	var curve := (mood - 0.4) * 14.0
	c.draw_polyline(PackedVector2Array([head + Vector2(-14, 20 - curve * 0.3) * s, head + Vector2(0, 22 + curve) * s, head + Vector2(14, 20 - curve * 0.3) * s]), ink, 4.5 * s, true)
	c.draw_circle(head + Vector2(-28, 16) * s, 6 * s, Color(1, 0.4, 0.4, 0.35))
	c.draw_circle(head + Vector2(28, 16) * s, 6 * s, Color(1, 0.4, 0.4, 0.35))

	# Hat.
	match look.hat:
		0:  # tall chef's toque
			var band := Rect2(head + Vector2(-38, -58) * s, Vector2(76, 22) * s)
			for p in [Vector2(-26, -80), Vector2(0, -92), Vector2(26, -80)]:
				c.draw_circle(head + p * s, 26 * s, Color.WHITE)
				c.draw_arc(head + p * s, 26 * s, PI * 0.9, PI * 2.1, 20, ink, w * 0.8, true)
			c.draw_rect(Rect2(head + Vector2(-34, -84) * s, Vector2(68, 30) * s), Color.WHITE)
			c.draw_rect(band, Color.WHITE)
			c.draw_rect(band, ink, false, w * 0.8)
		1:  # cap
			c.draw_arc(head + Vector2(0, -16) * s, 44 * s, PI, TAU, 24, apron, 24 * s, true)
			c.draw_rect(Rect2(head + Vector2(0, -30) * s, Vector2(64, 12) * s), apron.darkened(0.2))
			c.draw_rect(Rect2(head + Vector2(0, -30) * s, Vector2(64, 12) * s), ink, false, w * 0.6)
		2:  # bandana
			c.draw_arc(head + Vector2(0, -6) * s, 46 * s, PI * 1.1, PI * 1.9, 20, apron, 20 * s, true)
			c.draw_circle(head + Vector2(46, -24) * s, 9 * s, apron)


static func _outline(c: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	c.draw_polyline(closed, color, width, true)
