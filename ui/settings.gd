extends Control
## Settings: sound, vibration, tips, easier mini-games, resetting progress,
## and the credits.

const TOGGLES := [
	["sound", "Sound effects", "All the CHOPs, DINGs and WHOOSHes."],
	["haptics", "Vibration", "A little buzz on every gesture."],
	["tips", "New-dish tips", "Arrows and tips while you make a dish for the first time."],
	["easy_minigames", "Easy mini-games", "Every swipe, tap or circle counts double."],
]

var _reset_button: Button
var _reset_armed := false


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(UiStyle.header("SETTINGS", _on_back))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(UiStyle.margin(body, 18, 18, 0, 18))

	var options := UiStyle.panel()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	options.add_child(list)
	for toggle in TOGGLES:
		list.add_child(_toggle_row(toggle[0], toggle[1], toggle[2]))
	list.add_child(HSeparator.new())
	_reset_button = UiStyle.button("RESET PROGRESS", Color("#ffd1e8"), 24)
	_reset_button.pressed.connect(_on_reset)
	var reset_row := HBoxContainer.new()
	reset_row.add_theme_constant_override("separation", 14)
	reset_row.add_child(_reset_button)
	var reset_note := UiStyle.left_text("Clears stars, recipes, arcade scores and stats. Your name and chef stay.", 16)
	reset_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_row.add_child(reset_note)
	list.add_child(reset_row)
	body.add_child(options)

	var about := UiStyle.panel(Color("#e8e2d6"))
	about.custom_minimum_size = Vector2(380, 0)
	var about_list := VBoxContainer.new()
	about_list.add_theme_constant_override("separation", 8)
	about.add_child(about_list)
	about_list.add_child(UiStyle.title("PASS THE PLATE!", 34, Art.TOMATO))
	about_list.add_child(UiStyle.text("Version %s" % Net.version(), 18))
	for line in [
		"Made with the Godot Engine (MIT licence).",
		"Fonts: Bangers and Fredoka, SIL Open Font License.",
		"Food art and sounds made for this game.",
		"LAN play uses ports 24568 and 24569 on your Wi-Fi.",
	]:
		about_list.add_child(UiStyle.text(line, 16))
	body.add_child(about)


func _toggle_row(key: String, label: String, help: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var button := UiStyle.button(_toggle_text(key), Art.LEAF if Game.settings[key] else Color("#b9b2a4"), 22)
	button.custom_minimum_size = Vector2(110, 0)
	button.name = "Toggle_" + key
	row.add_child(button)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiStyle.left_text(label, 22))
	texts.add_child(UiStyle.left_text(help, 15, Color(Art.INK, 0.75)))
	row.add_child(texts)
	button.pressed.connect(func():
		Game.settings[key] = not Game.settings[key]
		Game.save()
		button.text = _toggle_text(key)
		var color: Color = Art.LEAF if Game.settings[key] else Color("#b9b2a4")
		button.add_theme_stylebox_override("normal", UiStyle.box(color))
		button.add_theme_stylebox_override("hover", UiStyle.box(color.lightened(0.15))))
	return row


func _toggle_text(key: String) -> String:
	return "ON" if Game.settings[key] else "OFF"


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "TAP AGAIN TO RESET"
		return
	Game.reset_progress()
	_reset_armed = false
	_reset_button.text = "PROGRESS RESET ✓"
	Sfx.play("thud")


func _on_back() -> void:
	Game.goto(Game.SCENE_MENU)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _draw() -> void:
	UiStyle.draw_halftone(self, Rect2(Vector2.ZERO, size), Color("#4d5966"), Color("#5c6977"), 22.0)
