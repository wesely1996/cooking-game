class_name Minigame
extends Control
## The gesture mini-game shown while working an item: swipe down to chop,
## tap to knead, swipe side to side to roll, draw circles to stir. Each
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

const KIND_SWIPE_DOWN := "swipe_down"
const KIND_TAP := "tap"
const KIND_SWIPE_SIDE := "swipe_side"
const KIND_CIRCLE := "circle"

const TILT := -0.04  # radians: the splash panel sits a little crooked
const SWIPE_DISTANCE := 55.0
const SIDE_DISTANCE := 70.0

const ACTION_KINDS := {
	"chop": KIND_SWIPE_DOWN, "slice": KIND_SWIPE_DOWN, "grate": KIND_SWIPE_DOWN,
	"knead": KIND_TAP, "press": KIND_TAP, "mash": KIND_TAP,
	"roll": KIND_SWIPE_SIDE,
	"stir": KIND_CIRCLE, "crank": KIND_CIRCLE, "whisk": KIND_CIRCLE, "blend": KIND_CIRCLE,
}
const HINTS := {
	KIND_SWIPE_DOWN: "SWIPE DOWN!",
	KIND_TAP: "TAP TAP TAP!",
	KIND_SWIPE_SIDE: "SWIPE ← →",
	KIND_CIRCLE: "STIR IN CIRCLES!",
}

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
var _view: SubViewportContainer
var _viewport: SubViewport
var _front: Control  # the gesture hint, drawn over the 3D close-up


func _ready() -> void:
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
		camera: Camera3D = null, world: World3D = null) -> void:
	action = p_action
	kind = ACTION_KINDS.get(action, KIND_TAP)
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
			_anchor = local
			_last_angle = (local - size * 0.5).angle()
			if kind == KIND_TAP:
				work_done.emit(1)
		else:
			_pressed = false
		return true
	if event is InputEventMouseMotion and _pressed:
		match kind:
			KIND_SWIPE_DOWN:
				if local.y - _anchor.y >= SWIPE_DISTANCE and absf(local.x - _anchor.x) < local.y - _anchor.y:
					_anchor = local
					work_done.emit(1)
				elif local.y < _anchor.y:
					_anchor = local
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
	var title: String = HINTS.get(kind, "")
	draw_string_outline(font, Vector2(24, 54), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, 8, Color.WHITE)
	draw_string(font, Vector2(24, 54), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Comic.MAGENTA)
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


## Over the close-up: the food (when there is no 3D view), the moving tool
## that shows the gesture, and the view's ink frame.
func _draw_front() -> void:
	var c := _front
	var center := c.size * 0.5 + Vector2(0, 10)
	if item_texture and not _view.visible:
		var s := minf(150.0, c.size.y - 20.0) * (1.0 + 0.04 * sin(_time * 8.0))
		c.draw_texture_rect(item_texture, Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	if tool_texture:
		c.draw_texture_rect(tool_texture, Rect2(center + _tool_offset(), Vector2(84, 84)), false, Color(1, 1, 1, 0.9))
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Art.INK, false, 5.0)


func _tool_offset() -> Vector2:
	var t := fmod(_time, 1.0)
	match kind:
		KIND_SWIPE_DOWN:
			return Vector2(30, -110 + t * 120)
		KIND_SWIPE_SIDE:
			return Vector2(-42 + sin(_time * 6.0) * 90.0, -20)
		KIND_CIRCLE:
			return Vector2(cos(_time * 5.0), sin(_time * 5.0)) * 70.0 - Vector2(42, 42)
	return Vector2(40, -90 + absf(sin(_time * 10.0)) * 30.0)
