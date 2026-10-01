extends Control
## Title screen.

var _time := 0.0


func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	column.add_child(UiStyle.title("PASS THE PLATE!", 110, Art.SUN))
	var tagline := UiStyle.title("A WORLD COOKING TOUR · 1–4 CHEFS", 30, Color.WHITE)
	column.add_child(tagline)
	column.add_child(_spacer(20))

	var story := UiStyle.button("WORLD TOUR", Art.SUN, 40)
	story.pressed.connect(func(): Game.goto(Game.SCENE_LEVEL_SELECT))
	column.add_child(_centered(story))

	var arcade := UiStyle.button("ARCADE: ITALIAN", Color("#7fc8f8"), 32)
	arcade.pressed.connect(func(): Game.start_level("arcade_italian"))
	column.add_child(_centered(arcade))

	var best := int(Game.best_arcade.get("arcade_italian", 0))
	if best > 0:
		column.add_child(UiStyle.text("Arcade best: %d" % best, 20, Color.WHITE))

	var sound := UiStyle.button(_sound_label(), Art.PAPER, 22)
	sound.pressed.connect(func():
		Game.settings.sound = not Game.settings.sound
		Game.save()
		sound.text = _sound_label())
	column.add_child(_centered(sound))

	var version := UiStyle.text("v%s" % ProjectSettings.get_setting("application/config/version", "dev"), 16, Color(1, 1, 1, 0.8))
	version.autowrap_mode = TextServer.AUTOWRAP_OFF
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -160
	version.offset_right = -16
	version.offset_top = -34
	version.offset_bottom = -8
	add_child(version)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	UiStyle.draw_halftone(self, Rect2(Vector2.ZERO, size), Art.TOMATO, Color("#f0604a"), 22.0)
	# Rotating comic sunburst behind the title.
	var center := Vector2(size.x * 0.5, size.y * 0.3)
	for i in 16:
		var a := _time * 0.15 + TAU * i / 16.0
		var b := a + TAU / 32.0
		draw_colored_polygon(PackedVector2Array([center, center + Vector2(cos(a), sin(a)) * 1400.0, center + Vector2(cos(b), sin(b)) * 1400.0]), Color(1, 1, 1, 0.07))
	for i in 5:
		var item := Art.item(["pizza_margherita", "tomato", "basil", "pasta_pomodoro", "mozzarella"][i])
		if item:
			var pos := Vector2(size.x * (0.08 + i * 0.21), size.y - 120 + sin(_time * 2.0 + i) * 10.0)
			draw_texture_rect(item, Rect2(pos, Vector2(110, 110)), false)


func _sound_label() -> String:
	return "SOUND: ON" if Game.settings.sound else "SOUND: OFF"


func _centered(control: Control) -> Control:
	var box := CenterContainer.new()
	box.add_child(control)
	return box


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
