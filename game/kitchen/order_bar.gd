class_name OrderBar
extends Control
## The top bar: one ticket per waiting customer (their face, the dish, what
## goes into it, and a patience bar), plus the clock and the score. In
## competitions it also shows the rival chef's progress.

const TICKET_W := 168.0
const TICKET_GAP := 12.0

var shift: Shift
var _x := {}  # order uid -> current x, for the slide-in animation


func _process(delta: float) -> void:
	if shift == null:
		return
	var x := 12.0
	var alive := {}
	for order in shift.orders.orders:
		alive[order.uid] = true
		var current: float = _x.get(order.uid, size.x)
		_x[order.uid] = lerpf(current, x, 1.0 - exp(-delta * 10.0))
		x += TICKET_W + TICKET_GAP
	for uid in _x.keys():
		if not alive.has(uid):
			_x.erase(uid)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2b2340"))
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Art.INK, 6.0)
	if shift == null:
		return
	for order in shift.orders.orders:
		_draw_ticket(order, Vector2(_x.get(order.uid, size.x), 8))
	_draw_status()


func _draw_ticket(order: Dictionary, pos: Vector2) -> void:
	var font := Art.ui_font()
	var rect := Rect2(pos, Vector2(TICKET_W, size.y - 16))
	draw_rect(rect, Art.PAPER)
	draw_rect(rect, Art.INK, false, 4.0)
	var fraction := OrderBook.patience_fraction(order)
	# Customer face.
	var face_center := pos + Vector2(26, 28)
	var mood := Art.LEAF if fraction > 0.5 else (Art.SUN if fraction > 0.25 else Art.TOMATO)
	if order.max_patience < 0.0:
		mood = Color("#b48ce0")  # a judge
	draw_circle(face_center, 18, mood)
	draw_arc(face_center, 18, 0, TAU, 24, Art.INK, 3.0, true)
	draw_circle(face_center + Vector2(-6, -4), 2.5, Art.INK)
	draw_circle(face_center + Vector2(6, -4), 2.5, Art.INK)
	var mouth := 6.0 * (fraction - 0.4)
	draw_polyline(PackedVector2Array([face_center + Vector2(-7, 7 - mouth), face_center + Vector2(0, 7 + mouth), face_center + Vector2(7, 7 - mouth)]), Art.INK, 2.5, true)
	# Dish.
	var dish_texture := Art.item(order.dish)
	if dish_texture:
		draw_texture_rect(dish_texture, Rect2(pos + Vector2(48, 2), Vector2(62, 62)), false)
	draw_string(font, pos + Vector2(8, 80), shift.db.item_name(order.dish), HORIZONTAL_ALIGNMENT_LEFT, TICKET_W - 12, 14, Art.INK)
	# What goes into it.
	var parts := recipe_hint(shift.db, order.dish)
	for i in parts.size():
		var icon := Art.item(parts[i]) if shift.db.items.has(parts[i]) else Art.equipment(parts[i])
		if icon:
			draw_texture_rect(icon, Rect2(pos + Vector2(112 + (i % 2) * 26, 4 + (i / 2) * 26), Vector2(26, 26)), false)
	# Patience bar.
	if order.max_patience > 0.0:
		var bar := Rect2(pos + Vector2(8, rect.size.y - 18), Vector2(TICKET_W - 16, 11))
		draw_rect(bar, Color("#ddd5c4"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), mood)
		draw_rect(bar, Art.INK, false, 2.5)


func _draw_status() -> void:
	var font := Art.comic_font()
	var right := size.x - 16.0
	var clock := _clock_text()
	draw_string_outline(font, Vector2(right - 300, 52), clock, HORIZONTAL_ALIGNMENT_RIGHT, 160, 44, 8, Art.INK)
	draw_string(font, Vector2(right - 300, 52), clock, HORIZONTAL_ALIGNMENT_RIGHT, 160, 44, Color.WHITE)
	var score := "★ %d" % shift.score
	draw_string_outline(font, Vector2(right - 130, 52), score, HORIZONTAL_ALIGNMENT_RIGHT, 130, 44, 8, Art.INK)
	draw_string(font, Vector2(right - 130, 52), score, HORIZONTAL_ALIGNMENT_RIGHT, 130, 44, Art.SUN)
	var sub := _sub_status()
	if not sub.is_empty():
		draw_string(Art.ui_font(), Vector2(right - 300, 88), sub, HORIZONTAL_ALIGNMENT_RIGHT, 300, 18, Color.WHITE)


func _clock_text() -> String:
	var seconds := shift.time
	match shift.level.type:
		LevelDef.TYPE_NORMAL:
			seconds = maxf(float(shift.level.value("duration", shift.player_count, 180.0)) - shift.time, 0.0)
		LevelDef.TYPE_COMPETITION:
			seconds = maxf(float(shift.level.value("time_limit", shift.player_count, 300.0)) - shift.time, 0.0)
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _sub_status() -> String:
	if shift.rules is FestivalRules:
		var rules: FestivalRules = shift.rules
		return "Wave %d · Crowd mood %d%%" % [rules.wave + 1, int(rules.mood)]
	if shift.rival:
		return "%s: %d/%d dishes" % [shift.rival.name, shift.rival.done_count, shift.rival.dishes.size()]
	if shift.level.type == LevelDef.TYPE_ARCADE:
		return "Strikes: %d/%d" % [shift.stats.lost, int(shift.level.value("strikes", shift.player_count, 3))]
	return ""


## The pieces that go into a dish, for the ticket: the parts of the last
## assembly in its recipe, plus the appliance that finishes it.
static func recipe_hint(db: ContentDB, dish: String) -> Array:
	var finishing := []
	var id := dish
	for i in 8:
		var prod := db.producer(id)
		if prod.is_empty():
			break
		if prod.kind == "assembly":
			var asm: Dictionary = db.assemblies[prod.id]
			return ([asm.base] + asm.parts + finishing).slice(0, 4)
		var proc: Dictionary = db.processes[prod.id]
		if finishing.is_empty():
			finishing.append(proc.equipment)
		id = proc.input
	return [id] + finishing
