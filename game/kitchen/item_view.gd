class_name ItemView
extends Node2D
## Shows one KitchenItem: its picture, a shadow, the parts already added to it
## (for half-built assemblies) and a work progress ring. It glides towards
## `target` every frame, so moves and throws animate on their own.

const SIZE := 92.0

var uid := 0
var target := Vector2.ZERO
var display_scale := 1.0
var held := false  # being dragged: follow the finger instead of the target
var selected := false
var progress := 0.0  # manual work progress 0..1 (0 = hide ring)
var perfect := false

var _type := ""
var _parts: Array = []
var _texture: Texture2D
var _bounce := 0.0
var _db: ContentDB


func setup(db: ContentDB, item: KitchenItem, start: Vector2) -> void:
	_db = db
	uid = item.uid
	position = start
	target = start
	update_item(item)
	scale = Vector2(0.3, 0.3)


func update_item(item: KitchenItem) -> void:
	var effective := _db.effective_id(item.type, item.contents)
	var shown := effective if not effective.is_empty() and Art.item(effective) else item.type
	if shown != _type or item.contents != _parts:
		if not _type.is_empty():
			_bounce = 1.0
		_type = shown
		_parts = item.contents.duplicate() if shown == item.type else []
		_texture = Art.item(_type)
	perfect = item.perfect
	var proc: Dictionary = _db.processes.get(item.work_process, {})
	progress = item.work / proc.work if not proc.is_empty() and proc.work > 0.0 else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not held:
		position = position.lerp(target, 1.0 - exp(-delta * 16.0))
	var wanted := display_scale * (1.15 if held else 1.0)
	var s := lerpf(scale.x, wanted, 1.0 - exp(-delta * 14.0))
	if _bounce > 0.0:
		_bounce = maxf(_bounce - delta * 4.0, 0.0)
		var squash := sin(_bounce * PI * 3.0) * _bounce * 0.25
		scale = Vector2(s * (1.0 + squash), s * (1.0 - squash))
	else:
		scale = Vector2(s, s)
	z_index = 30 if held else 10


func _draw() -> void:
	var half := SIZE * 0.5
	draw_set_transform(Vector2(0, half * 0.75), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, half * 0.8, Color(Art.INK, 0.25))
	draw_set_transform(Vector2.ZERO)
	if selected:
		draw_circle(Vector2.ZERO, half + 8.0, Color(Art.SUN, 0.55))
		draw_arc(Vector2.ZERO, half + 8.0, 0.0, TAU, 48, Art.INK, 3.0, true)
	if _texture:
		draw_texture_rect(_texture, Rect2(-half, -half, SIZE, SIZE), false)
	else:
		draw_circle(Vector2.ZERO, half * 0.7, Art.PAPER)
		draw_arc(Vector2.ZERO, half * 0.7, 0.0, TAU, 32, Art.INK, 3.0, true)
		draw_string(Art.comic_font(), Vector2(-half * 0.6, 8), _type.substr(0, 6), HORIZONTAL_ALIGNMENT_CENTER, SIZE * 0.6, 18, Art.INK)
	for i in _parts.size():
		var icon := Art.item(_parts[i])
		var pos := Vector2(-half + 4.0 + i * 30.0, -half - 10.0)
		draw_circle(pos + Vector2(14, 14), 17.0, Art.PAPER)
		draw_arc(pos + Vector2(14, 14), 17.0, 0.0, TAU, 24, Art.INK, 2.5, true)
		if icon:
			draw_texture_rect(icon, Rect2(pos, Vector2(28, 28)), false)
	if progress > 0.0 and progress < 1.0:
		draw_arc(Vector2.ZERO, half + 2.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, Art.LEAF, 7.0, true)
	if perfect:
		_draw_star(Vector2(half * 0.75, -half * 0.75), 12.0)


func _draw_star(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + TAU * i / 10.0
		var r := radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, Art.SUN)
	points.append(points[0])
	draw_polyline(points, Art.INK, 2.0, true)
