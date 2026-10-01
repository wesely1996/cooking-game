class_name ComicBubble
extends Node2D
## An onomatopoeia burst ("CHOP!", "WHOOSH!") that pops in, wobbles and fades.

var text := "POW!"
var fill := Color.WHITE
var text_color := Art.INK
var font_size := 34
var _points := PackedVector2Array()


static func spawn(parent: Node, pos: Vector2, p_text: String, p_fill: Color = Color.WHITE, size: int = 34) -> ComicBubble:
	var bubble := ComicBubble.new()
	bubble.text = p_text
	bubble.fill = p_fill
	bubble.font_size = size
	bubble.position = pos
	parent.add_child(bubble)
	return bubble


func _ready() -> void:
	z_index = 50
	var font := Art.comic_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var rx := width * 0.5 + 22.0
	var ry := font_size * 0.5 + 16.0
	var spikes := 14
	for i in spikes * 2:
		var angle := TAU * i / (spikes * 2)
		var r := 1.0 if i % 2 == 0 else 0.72 + randf() * 0.1
		_points.append(Vector2(cos(angle) * rx * r, sin(angle) * ry * r))
	rotation = randf_range(-0.25, 0.25)
	scale = Vector2(0.2, 0.2)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.09).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(self, "position:y", position.y - 26.0, 0.6)
	tween.tween_interval(0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var outline := _points.duplicate()
	outline.append(_points[0])
	draw_colored_polygon(_points, fill)
	draw_polyline(outline, Art.INK, 4.0, true)
	var font := Art.comic_font()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(-size.x * 0.5, font_size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color.WHITE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
