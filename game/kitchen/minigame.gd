class_name Minigame
extends Control
## The gesture mini-game shown while working an item: tap to chop or knead,
## swipe side to side to roll, draw circles to stir. Each
## recognised gesture is one unit of work (the process's "work" value says
## how many are needed). The KitchenScreen forwards input here.
##
## It is drawn as a tilted comic "splash" panel over the page, with a 3D
## close-up of the station (a camera into the kitchen's world) in the middle.
##
## Work can be paused at any time with the LATER button (or by tapping
## outside the panel): the food keeps its progress and can be finished later.

signal work_done(units: int)
signal paused  # the player left before the work was done
signal closed

const KIND_TAP := "tap"
const KIND_SWIPE_SIDE := "swipe_side"
const KIND_CIRCLE := "circle"

const TILT := -0.04  # radians: the splash panel sits a little crooked
const SIDE_DISTANCE := 70.0

const ACTION_KINDS := {
	"chop": KIND_TAP, "slice": KIND_TAP, "grate": KIND_TAP,
	"knead": KIND_TAP, "press": KIND_TAP, "mash": KIND_TAP,
	"roll": KIND_SWIPE_SIDE,
	"stir": KIND_CIRCLE, "crank": KIND_CIRCLE, "whisk": KIND_CIRCLE, "blend": KIND_CIRCLE,
}
## The one big word that says what to do.
const HINTS := {
	KIND_TAP: "TAP!",
	KIND_SWIPE_SIDE: "ROLL!",
	KIND_CIRCLE: "CIRCLE!",
}
const ARROW_COLOR := Color("#ff2fa4")
const TRAIL_POINTS := 24

var action := ""
var kind := KIND_TAP
var needed := 1.0
var done := 0.0
var item_texture: Texture2D
var tool_texture: Texture2D

var _pressed := false
var _anchor := Vector2.ZERO
var _last_angle := 0.0
var _angle_sum := 0.0
var _time := 0.0
var _finished := false
var _caption := ""  # e.g. "CHOP THE TOMATO"
var _trail: Array[Vector2] = []  # the finger's last positions (panel coordinates)
var _trail_fade := 0.0
var _view: SubViewportContainer
var _viewport: SubViewport
var _front: Control  # the gesture hint, drawn over the 3D close-up


func _init() -> void:
	_view = SubViewportContainer.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.stretch = true
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.transparent_bg = false
	_view.add_child(_viewport)
	add_child(_view)
	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	add_child(_front)


## camera and world: a close-up of the station; without them the food's
## picture is shown instead.
func open(p_action: String, p_needed: float, p_done: float, p_item: Texture2D, p_tool: Texture2D,
		camera: Camera3D = null, world: World3D = null, caption: String = "") -> void:
	action = p_action
	kind = ACTION_KINDS.get(action, KIND_TAP)
	_caption = caption.to_upper()
	_trail.clear()
	needed = p_needed
	done = p_done
	item_texture = p_item
	tool_texture = p_tool
	_finished = false
	_pressed = false
	visible = true
	var view_rect := view_rect()
	for rect_owner in [_view, _front]:
		rect_owner.position = view_rect.position
		rect_owner.size = view_rect.size
	for child in _viewport.get_children():
		child.queue_free()
	_view.visible = camera != null
	if camera:
		_viewport.world_3d = world
		_viewport.add_child(camera)
		camera.current = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pivot_offset = size * 0.5
	rotation = TILT * 3.0
	scale = Vector2(0.7, 0.7)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation", TILT, 0.16).set_trans(Tween.TRANS_BACK)
	queue_redraw()


## Where the close-up sits inside the panel.
func view_rect() -> Rect2:
	return Rect2(22, 96, size.x - 44, size.y - 96 - 62)


## Called by the kitchen when the work has been applied.
func set_progress(p_done: float) -> void:
	done = p_done
	queue_redraw()


func finish() -> void:
	_finished = true
	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.1)
	tween.tween_callback(func():
		_hide()
		closed.emit())


func _hide() -> void:
	visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func close_rect() -> Rect2:
	return Rect2(size.x - 158, 10, 148, 54)


## Leaves the mini-game; the progress so far stays on the food.
func pause() -> void:
	if not visible:
		return
	_hide()
	if not _finished:
		paused.emit()
	closed.emit()


## Handles a pointer event in this control's local coordinates. Returns true
## if the event was used.
func handle_input(event: InputEvent, local: Vector2) -> bool:
	if _finished:
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if close_rect().has_point(local):
				pause()
				return true
			_pressed = true
			_trail = [local]
			_trail_fade = 1.0
			_anchor = local
			_last_angle = (local - size * 0.5).angle()
			if kind == KIND_TAP:
				work_done.emit(1)
		else:
			_pressed = false
		return true
	if event is InputEventMouseMotion and _pressed:
		_trail.append(local)
		if _trail.size() > TRAIL_POINTS:
			_trail.remove_at(0)
		_trail_fade = 1.0
		match kind:
			KIND_SWIPE_SIDE:
				if absf(local.x - _anchor.x) >= SIDE_DISTANCE:
					_anchor = local
					work_done.emit(1)
			KIND_CIRCLE:
				var angle := (local - size * 0.5).angle()
				_angle_sum += absf(wrapf(angle - _last_angle, -PI, PI))
				_last_angle = angle
				if _angle_sum >= TAU * 0.9:
					_angle_sum = 0.0
					work_done.emit(1)
		return true
	return false


func _process(delta: float) -> void:
	if visible:
		_time += delta
		if not _pressed:
			_trail_fade = maxf(_trail_fade - delta * 2.5, 0.0)
		queue_redraw()
		_front.queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# A splash panel: an ink shadow, a yellow burst border, paper inside.
	draw_rect(Rect2(rect.position + Vector2(10, 12), rect.size), Color(Art.INK, 0.55))
	draw_rect(rect.grow(8), Art.INK)
	draw_rect(rect.grow(4), Comic.YELLOW)
	draw_rect(rect, Art.PAPER)
	draw_rect(rect, Art.INK, false, 5.0)
	var font := Art.comic_font()
	# What this is for, e.g. "CHOP THE TOMATO".
	var caption := _caption if not _caption.is_empty() else str(action).to_upper()
	draw_string_outline(font, Vector2(24, 54), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 210, 40, 8, Color.WHITE)
	draw_string(font, Vector2(24, 54), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 210, 40, Comic.MAGENTA)
	draw_string(Art.ui_font(), Vector2(26, 84), "Busy? Tap LATER: the work is kept.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Art.INK, 0.65))
	# LATER (pause) button.
	var close := close_rect()
	draw_rect(close, Comic.CYAN)
	draw_rect(close, Art.INK, false, 4.0)
	draw_rect(Rect2(close.position + Vector2(16, 14), Vector2(8, 26)), Art.INK)
	draw_rect(Rect2(close.position + Vector2(30, 14), Vector2(8, 26)), Art.INK)
	draw_string(font, Vector2(close.position.x + 46, close.end.y - 14), "LATER", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Art.INK)
	# The close-up's frame (the 3D view is a child, drawn over the fill).
	var view := view_rect()
	draw_rect(view, Color("#3b3157"))
	# Progress pips.
	var count := int(ceil(needed))
	var pip_size := minf(28.0, (size.x - 60.0) / maxf(count, 1) - 6.0)
	var total := count * (pip_size + 6.0)
	for i in count:
		var pos := Vector2(size.x * 0.5 - total * 0.5 + i * (pip_size + 6.0), size.y - pip_size - 16.0)
		var pip := Rect2(pos, Vector2(pip_size, pip_size))
		draw_rect(pip, Comic.CYAN if i < int(done) else Color.WHITE)
		draw_rect(pip, Art.INK, false, 3.0)
	var left := count - int(done)
	if left > 0 and not _finished:
		var more := "%d MORE!" % left if left > 1 else "LAST ONE!"
		draw_string(font, Vector2(size.x * 0.5 + total * 0.5 + 12, size.y - 20), more, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Art.INK)


## Over the close-up: the food (when there is no 3D view), the big word and
## the animated arrow that show the gesture, the finger's trail, and the
## view's ink frame.
func _draw_front() -> void:
	var c := _front
	var center := c.size * 0.5 + Vector2(0, 14)
	if item_texture and not _view.visible:
		var s := minf(150.0, c.size.y - 20.0) * (1.0 + 0.04 * sin(_time * 8.0))
		c.draw_texture_rect(item_texture, Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	if not _finished:
		_draw_gesture(c, center)
		var word: String = HINTS.get(kind, "")
		var pulse := 1.0 + 0.06 * sin(_time * 6.0)
		UiStyle.draw_print_title(c, Vector2(0, 66), word, int(64 * pulse), Comic.YELLOW, c.size.x)
	# The finger's trail, so you can see the gesture land.
	if _trail.size() > 1 and _trail_fade > 0.0:
		var offset := view_rect().position
		var points := PackedVector2Array()
		for point in _trail:
			points.append(point - offset)
		c.draw_polyline(points, Color(Art.INK, 0.6 * _trail_fade), 16.0, true)
		c.draw_polyline(points, Color(Comic.YELLOW, 0.9 * _trail_fade), 10.0, true)
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Art.INK, false, 5.0)


## A big animated arrow (or rings, for taps) that shows the gesture.
func _draw_gesture(c: Control, center: Vector2) -> void:
	var reach := minf(c.size.y * 0.32, 90.0)
	match kind:
		KIND_SWIPE_SIDE:
			var shift := sin(_time * 5.0) * reach * 0.35
			_arrow(c, center + Vector2(shift, 0), center + Vector2(shift + reach * 1.1, 0), 1.0)
			_arrow(c, center + Vector2(shift, 0), center + Vector2(shift - reach * 1.1, 0), 1.0)
		KIND_CIRCLE:
			var start := _time * 4.0
			var radius := reach * 0.9
			c.draw_arc(center, radius, start, start + PI * 1.5, 40, Art.INK, 22.0, true)
			c.draw_arc(center, radius, start, start + PI * 1.5, 40, ARROW_COLOR, 14.0, true)
			var end_angle := start + PI * 1.5
			var tip := center + Vector2(cos(end_angle), sin(end_angle)) * radius
			var along := Vector2(-sin(end_angle), cos(end_angle))
			_arrow_head(c, tip, along)
		_:
			# Taps: rings growing out of a fingertip.
			for i in 3:
				var grow := fmod(_time * 1.6 + i / 3.0, 1.0)
				c.draw_arc(center, 18.0 + grow * reach, 0, TAU, 40, Color(ARROW_COLOR, 1.0 - grow), 8.0, true)
			var press := 1.0 - absf(sin(_time * 6.0)) * 0.25
			c.draw_circle(center, 26.0 * press + 4.0, Art.INK)
			c.draw_circle(center, 26.0 * press, Color.WHITE)


func _arrow(c: Control, from: Vector2, to: Vector2, alpha: float) -> void:
	var dir := (to - from).normalized()
	var shaft_end := to - dir * 26.0
	c.draw_line(from, shaft_end, Color(Art.INK, alpha), 24.0, true)
	c.draw_line(from, shaft_end, Color(ARROW_COLOR, alpha), 16.0, true)
	_arrow_head(c, to, dir, alpha)


func _arrow_head(c: Control, tip: Vector2, dir: Vector2, alpha: float = 1.0) -> void:
	var side := dir.orthogonal()
	var head := PackedVector2Array([tip + dir * 8.0, tip - dir * 34.0 + side * 28.0, tip - dir * 34.0 - side * 28.0])
	c.draw_colored_polygon(head, Color(Art.INK, alpha))
	var inner := PackedVector2Array([tip, tip - dir * 28.0 + side * 20.0, tip - dir * 28.0 - side * 20.0])
	c.draw_colored_polygon(inner, Color(ARROW_COLOR, alpha))
