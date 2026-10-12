class_name PageTurn
extends CanvasLayer
## The page-turn transition between screens: a picture of the old screen is
## taken just before the scene changes, then it turns away around the spine
## on the left, like a comic page, showing the new screen underneath.

const SECONDS := 0.4

var _page: Texture2D
var _turn := 1.0  # 0 = flat, 1 = turned away
var _canvas: Control


func _init() -> void:
	layer = 100
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_page)
	add_child(_canvas)


## Takes the picture of the screen as it is now. Call before changing scene.
func capture(viewport: Viewport) -> void:
	_page = null
	if DisplayServer.get_name() == "headless":
		return
	var image := viewport.get_texture().get_image()
	if image and not image.is_empty():
		_page = ImageTexture.create_from_image(image)


## Turns the captured page away.
func play() -> void:
	if _page == null:
		return
	_turn = 0.0
	_canvas.queue_redraw()
	var tween := create_tween()
	tween.tween_method(func(t: float):
		_turn = t
		_canvas.queue_redraw(), 0.0, 1.0, SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_page = null
		_canvas.queue_redraw())


func _draw_page() -> void:
	if _page == null or _turn >= 1.0:
		return
	var size := _canvas.size
	# The page rotates around the left edge: it gets narrower, and its far
	# edge grows a little taller as it lifts towards the reader.
	var angle := _turn * PI * 0.5
	var width := size.x * cos(angle)
	var lift := size.y * 0.06 * sin(angle * 2.0)
	# The shadow it throws on the new page.
	var shadow := Color(0.11, 0.1, 0.18, 0.35 * (1.0 - _turn))
	_canvas.draw_rect(Rect2(width, 0, minf(60.0, size.x - width), size.y), shadow)
	var points := PackedVector2Array([Vector2(0, 0), Vector2(width, -lift), Vector2(width, size.y + lift), Vector2(0, size.y)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var shade := 1.0 - 0.45 * _turn
	var colors := PackedColorArray([Color(shade, shade, shade), Color(shade * 0.85, shade * 0.85, shade * 0.85),
		Color(shade * 0.85, shade * 0.85, shade * 0.85), Color(shade, shade, shade)])
	_canvas.draw_polygon(points, colors, uvs, _page)
	_canvas.draw_line(Vector2(width, -lift), Vector2(width, size.y + lift), Color(0.11, 0.1, 0.18), 3.0, true)
