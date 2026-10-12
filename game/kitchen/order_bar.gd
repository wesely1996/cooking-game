class_name OrderBar
extends Control
## The top bar: one ticket per waiting customer (their face, the dish, what
## goes into it along the bottom, and a patience bar), plus the clock and the
## score. In competitions it also shows the rival chef's progress. Tapping a
## ticket pops its recipe out of it in a comic speech bubble for a few
## seconds.

const TICKET_W := 168.0
const TICKET_GAP := 12.0
## How long a recipe bubble stays out.
const RECIPE_SECONDS := 5.0
const BUBBLE_W := 520.0
const BUBBLE_PAD := 20.0
const BUBBLE_TAIL := 30.0
const STEP_FONT := 20

var shift: Shift
## Optional func(dish: String) -> bool: shows a NEW! badge on the ticket.
var is_new: Callable
var _x := {}  # order uid -> current x, for the slide-in animation
# The recipe bubble: whose ticket it comes out of, its lines and how long it
# has been out.
var _recipe_uid := -1
var _recipe_lines: Array[String] = []
var _recipe_age := 0.0
var _bubble_rect := Rect2()


## A tap on a ticket pops its recipe out (or puts it back); a tap on the
## bubble puts it away. Returns true if the tap hit either.
func tap(pos: Vector2) -> bool:
	if _recipe_uid >= 0 and _bubble_rect.has_point(pos):
		hide_recipe()
		return true
	var uid := ticket_at(pos)
	if uid < 0:
		return false
	if uid == _recipe_uid:
		hide_recipe()
	else:
		show_recipe(uid)
	return true


## The uid of the order whose ticket is at pos, or -1.
func ticket_at(pos: Vector2) -> int:
	if shift == null:
		return -1
	for order in shift.orders.orders:
		if _ticket_rect(order).has_point(pos):
			return int(order.uid)
	return -1


func show_recipe(uid: int) -> void:
	var order := _order(uid)
	if order.is_empty():
		return
	_recipe_uid = uid
	_recipe_lines = RecipeText.short_steps(shift.db, str(order.dish))
	_recipe_age = 0.0
	queue_redraw()


func hide_recipe() -> void:
	_recipe_uid = -1
	_bubble_rect = Rect2()
	queue_redraw()


## The uid of the order whose recipe is out, or -1.
func recipe_shown() -> int:
	return _recipe_uid


func bubble_rect() -> Rect2:
	return _bubble_rect


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
	if _recipe_uid >= 0:
		_recipe_age += delta
		if _recipe_age >= RECIPE_SECONDS or _order(_recipe_uid).is_empty():
			hide_recipe()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2b2340"))
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Art.INK, 6.0)
	if shift == null:
		return
	for order in shift.orders.orders:
		_draw_ticket(order, _ticket_rect(order).position)
	_draw_status()
	_draw_recipe_bubble()


func _ticket_rect(order: Dictionary) -> Rect2:
	return Rect2(Vector2(_x.get(order.uid, size.x), 8), Vector2(TICKET_W, size.y - 16))


func _order(uid: int) -> Dictionary:
	if shift:
		for order in shift.orders.orders:
			if int(order.uid) == uid:
				return order
	return {}


func _draw_ticket(order: Dictionary, pos: Vector2) -> void:
	var font := Art.ui_font()
	var rect := Rect2(pos, Vector2(TICKET_W, size.y - 16))
	draw_rect(rect, Art.PAPER)
	draw_rect(rect, Art.INK, false, 4.0)
	var fraction := OrderBook.patience_fraction(order)
	# Customer face.
	var face_center := pos + Vector2(24, 26)
	var mood := Art.LEAF if fraction > 0.5 else (Art.SUN if fraction > 0.25 else Art.TOMATO)
	if order.max_patience < 0.0:
		mood = Color("#b48ce0")  # a judge
	draw_circle(face_center, 17, mood)
	draw_arc(face_center, 17, 0, TAU, 24, Art.INK, 3.0, true)
	draw_circle(face_center + Vector2(-6, -4), 2.5, Art.INK)
	draw_circle(face_center + Vector2(6, -4), 2.5, Art.INK)
	var mouth := 6.0 * (fraction - 0.4)
	draw_polyline(PackedVector2Array([face_center + Vector2(-7, 7 - mouth), face_center + Vector2(0, 7 + mouth), face_center + Vector2(7, 7 - mouth)]), Art.INK, 2.5, true)
	# The dish and its name, small enough that every word fits.
	var dish_texture := Art.item(order.dish)
	if dish_texture:
		draw_texture_rect(dish_texture, Rect2(pos + Vector2(38, -4), Vector2(62, 62)), false)
	var dish_name := shift.db.item_name(order.dish)
	var name_w := TICKET_W - 102.0
	var name_size := 14
	for word in dish_name.split(" "):
		while name_size > 9 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > name_w:
			name_size -= 1
	draw_multiline_string(font, pos + Vector2(98, 20), dish_name, HORIZONTAL_ALIGNMENT_LEFT, name_w, name_size, 3, Art.INK)
	# Its ingredients, along the bottom of the ticket.
	var strip := Rect2(pos + Vector2(5, 54), Vector2(TICKET_W - 10, 30))
	draw_rect(strip, Color("#ece3cf"))
	var parts := ingredients(shift.db, order.dish)
	var icon_size := 40.0
	var step := minf(icon_size - 8.0, strip.size.x / maxf(parts.size(), 1))
	var left := strip.position.x + (strip.size.x - step * parts.size()) * 0.5
	for i in parts.size():
		var icon := Art.item(parts[i])
		if icon:
			var center := Vector2(left + (i + 0.5) * step, strip.get_center().y)
			draw_texture_rect(icon, Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), false)
	# It's open: the recipe is coming out of it.
	if int(order.uid) == _recipe_uid:
		draw_rect(rect.grow(2), Comic.YELLOW, false, 4.0)
	if is_new.is_valid() and is_new.call(order.dish):
		var badge := Rect2(pos + Vector2(-6, -8), Vector2(56, 24))
		draw_rect(badge, Art.TOMATO)
		draw_rect(badge, Art.INK, false, 3.0)
		draw_string(Art.comic_font(), badge.position + Vector2(0, 19), "NEW!", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 20, Color.WHITE)
	# Patience bar.
	if order.max_patience > 0.0:
		var bar := Rect2(pos + Vector2(8, rect.size.y - 15), Vector2(TICKET_W - 16, 9))
		draw_rect(bar, Color("#ddd5c4"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), mood)
		draw_rect(bar, Art.INK, false, 2.5)


## The recipe of a tapped ticket, in a comic speech bubble whose tail
## comes out of the ticket. It pops out, and shrinks back into the ticket
## when its time is up.
func _draw_recipe_bubble() -> void:
	var order := _order(_recipe_uid)
	if order.is_empty():
		_bubble_rect = Rect2()
		return
	var ticket := _ticket_rect(order)
	var font := Art.ui_font()
	var title_font := Art.comic_font()
	# As wide as the longest step (or the dish's name) needs.
	var title := shift.db.item_name(order.dish).to_upper()
	var widest := title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x - 30.0
	for line in _recipe_lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, STEP_FONT).x)
	var width := minf(maxf(widest + 4.0 + BUBBLE_PAD * 2.0 + 30.0, 240.0), minf(BUBBLE_W, size.x - 32.0))
	var text_w := width - BUBBLE_PAD * 2.0 - 30.0
	var heights: Array[float] = []
	var height := BUBBLE_PAD * 2.0 + 34.0
	for line in _recipe_lines:
		var h := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, text_w, STEP_FONT).y
		heights.append(h)
		height += h + 8.0
	var tip := Vector2(ticket.get_center().x, ticket.end.y - 6.0)
	var top := ticket.end.y + BUBBLE_TAIL
	var left := clampf(tip.x - width * 0.35, 16.0, size.x - width - 16.0)
	var rect := Rect2(left, top, width, height)
	_bubble_rect = rect
	# Pop out of the ticket, and shrink back into it at the end.
	var grow := clampf(_recipe_age / 0.15, 0.0, 1.0)
	var shrink := clampf((RECIPE_SECONDS - _recipe_age) / 0.25, 0.0, 1.0)
	var s := minf(0.6 + 0.4 * grow, 1.0) * shrink
	if s <= 0.01:
		return
	draw_set_transform(tip * (1.0 - s), 0.0, Vector2(s, s))
	# The tail first, then the bubble over its base, then the tail's white
	# inside over the bubble's outline, so they read as one shape.
	var base_x := clampf(tip.x, rect.position.x + 44.0, rect.end.x - 44.0)
	var lean := clampf((tip.x - base_x) * 0.4, -20.0, 20.0)
	draw_colored_polygon(PackedVector2Array([tip, Vector2(base_x - 22.0 + lean, top + 6.0), Vector2(base_x + 18.0 + lean, top + 6.0)]), Art.INK)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.border_color = Art.INK
	box.set_border_width_all(5)
	box.set_corner_radius_all(34)
	box.corner_detail = 10
	box.anti_aliasing = true
	box.shadow_color = Color(Art.INK, 0.35)
	box.shadow_offset = Vector2(6, 6)
	box.shadow_size = 1
	draw_style_box(box, rect)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 9), Vector2(base_x - 15.0 + lean, top + 8.0), Vector2(base_x + 11.0 + lean, top + 8.0)]), Color.WHITE)
	# The dish, then the numbered steps.
	var x := rect.position.x + BUBBLE_PAD
	var y := rect.position.y + BUBBLE_PAD + 24.0
	draw_string(title_font, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, text_w + 30.0, 26, Comic.MAGENTA)
	y += 14.0
	for i in _recipe_lines.size():
		var ascent := font.get_ascent(STEP_FONT)
		draw_string(title_font, Vector2(x, y + ascent), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, 26.0, 20, Art.INK)
		draw_multiline_string(font, Vector2(x + 30.0, y + ascent), _recipe_lines[i], HORIZONTAL_ALIGNMENT_LEFT, text_w, STEP_FONT, -1, Art.INK)
		y += heights[i] + 8.0
	# Time left, as a shrinking line along the bottom.
	var left_frac := clampf(1.0 - _recipe_age / RECIPE_SECONDS, 0.0, 1.0)
	var line_y := rect.end.y - 12.0
	draw_line(Vector2(rect.position.x + 34.0, line_y), Vector2(rect.position.x + 34.0 + (width - 68.0) * left_frac, line_y), Color(Art.INK, 0.25), 4.0)
	draw_set_transform(Vector2.ZERO)


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


## The raw ingredients of a dish, in the order the recipe uses them (the
## plate isn't one).
static func ingredients(db: ContentDB, dish: String) -> Array:
	var result := []
	for step in db.recipe_steps(dish):
		var inputs: Array = step.inputs if step.kind == "recipe" else [step.base] + step.parts
		for id in inputs:
			if id != ContentDB.PLATE and db.producer(id).is_empty() and not result.has(id):
				result.append(id)
	return result
