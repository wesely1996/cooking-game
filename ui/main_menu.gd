extends Control
## Title screen: Play, Profile, Recipe book, Settings.

var _time := 0.0


func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	column.add_child(UiStyle.title("PASS THE PLATE!", 104, Art.SUN))
	column.add_child(UiStyle.title("A WORLD COOKING TOUR · 1–4 CHEFS", 30, Color.WHITE))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	column.add_child(spacer)

	var play := UiStyle.button("PLAY", Art.SUN, 60)
	play.custom_minimum_size = Vector2(360, 0)
	play.name = "Play"
	play.pressed.connect(func(): Game.goto(Game.SCENE_PLAY))
	column.add_child(UiStyle.centered(play))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for entry in [["PROFILE", Color("#e3b7f0"), Game.SCENE_PROFILE], ["RECIPE BOOK", Color("#ffd1e8"), Game.SCENE_RECIPE_BOOK], ["SETTINGS", Art.PAPER, Game.SCENE_SETTINGS]]:
		var button := UiStyle.button(entry[0], entry[1], 28)
		button.name = str(entry[0]).replace(" ", "_")
		var scene: String = entry[2]
		button.pressed.connect(func():
			if scene == Game.SCENE_RECIPE_BOOK:
				Game.open_recipe_book(Game.SCENE_MENU)
			else:
				Game.goto(scene))
		row.add_child(button)
	column.add_child(row)

	# The player's chef in the corner, as a shortcut to the profile.
	var chip := Button.new()
	chip.flat = true
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(240, 110)
	chip.position = Vector2(16, 12)
	chip.pressed.connect(func(): Game.goto(Game.SCENE_PROFILE))
	var portrait := ChefPortrait.new()
	portrait.look = Game.profile.look
	portrait.custom_minimum_size = Vector2(90, 100)
	portrait.size = Vector2(90, 100)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(portrait)
	var name_label := UiStyle.title(Game.profile.name.to_upper(), 28, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.position = Vector2(96, 34)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(name_label)
	add_child(chip)

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
	var foods := ["pizza_margherita", "beef_taco", "salmon_nigiri", "guacamole", "miso_ramen"]
	for i in foods.size():
		var item := Art.item(foods[i])
		if item:
			var pos := Vector2(size.x * (0.08 + i * 0.21), size.y - 120 + sin(_time * 2.0 + i) * 10.0)
			draw_texture_rect(item, Rect2(pos, Vector2(110, 110)), false)
