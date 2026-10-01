class_name UiStyle
extends RefCounted
## Shared look for menus: chunky comic buttons with ink outlines.


static func button(text: String, color: Color = Art.SUN, font_size: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Art.comic_font())
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, Art.INK)
	b.add_theme_color_override("font_disabled_color", Color(Art.INK, 0.4))
	b.add_theme_stylebox_override("normal", box(color))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 2))
	b.add_theme_stylebox_override("disabled", box(Color("#b9b2a4")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Sfx.play("pop"))
	return b


static func box(color: Color, shadow: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Art.INK
	style.set_border_width_all(5)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(Art.INK, 0.6)
	style.shadow_offset = Vector2(shadow, shadow)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func title(text: String, font_size: int = 72, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Art.comic_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Art.INK)
	label.add_theme_constant_override("outline_size", maxi(font_size / 6, 6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func text(value: String, font_size: int = 22, color: Color = Art.INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", Art.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Comic halftone background shared by the menus.
static func draw_halftone(canvas: CanvasItem, rect: Rect2, base: Color, dots: Color, spacing: float = 18.0) -> void:
	canvas.draw_rect(rect, base)
	var rows := int(rect.size.y / spacing) + 2
	var cols := int(rect.size.x / spacing) + 2
	for row in rows:
		var y := rect.position.y + row * spacing
		var radius := lerpf(1.0, spacing * 0.32, float(row) / rows)
		for col in cols:
			var x := rect.position.x + col * spacing + (spacing * 0.5 if row % 2 else 0.0)
			canvas.draw_circle(Vector2(x, y), radius, dots)
