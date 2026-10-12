extends Control
## The title screen is the cover of the comic: the masthead, the issue box,
## the player's chef in 3D as the cover star, dishes from every cuisine,
## and cover blurbs that lead to Play, the profile, the recipe book and the
## settings.

const COVER_DISHES := ["pizza_margherita", "beef_taco", "cheeseburger", "paella", "miso_ramen", "crepe"]

var _time := 0.0
var _chef: ChefView
var _play: Button


func _ready() -> void:
	_chef = ChefView.new()
	_chef.look = Game.profile.look
	_chef.name = "CoverChef"
	add_child(_chef)

	_play = _burst_button("PLAY!", 64)
	_play.name = "Play"
	_play.pressed.connect(func(): Game.goto(Game.SCENE_PLAY))
	add_child(_play)

	var blurbs := VBoxContainer.new()
	blurbs.name = "Blurbs"
	blurbs.add_theme_constant_override("separation", 14)
	add_child(blurbs)
	for entry in [["PROFILE", "MY CHEF", Color("#e3b7f0"), Game.SCENE_PROFILE],
			["RECIPE BOOK", "RECIPE BOOK", Color("#ffd1e8"), Game.SCENE_RECIPE_BOOK],
			["SETTINGS", "SETTINGS", Art.PAPER, Game.SCENE_SETTINGS]]:
		var button := UiStyle.button(entry[1], entry[2], 30)
		button.name = str(entry[0]).replace(" ", "_")
		button.custom_minimum_size = Vector2(270, 0)
		var scene: String = entry[3]
		button.pressed.connect(func():
			if scene == Game.SCENE_RECIPE_BOOK:
				Game.open_recipe_book(Game.SCENE_MENU)
			else:
				Game.goto(scene))
		blurbs.add_child(button)

	# "Starring" caption under the cover star, a shortcut to the profile.
	var star := Button.new()
	star.name = "Starring"
	star.focus_mode = Control.FOCUS_NONE
	var chef_name := Game.profile.name.strip_edges().to_upper()
	star.text = "STARRING YOU!" if chef_name.is_empty() or chef_name == "CHEF" else "STARRING CHEF %s!" % chef_name
	star.add_theme_font_override("font", Art.comic_font())
	star.add_theme_font_size_override("font_size", 26)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		star.add_theme_color_override(state, Art.INK)
	var style := UiStyle.panel_box(Comic.YELLOW, 4)
	style.content_margin_top = 2
	style.content_margin_bottom = 0
	for state in ["normal", "hover", "pressed"]:
		star.add_theme_stylebox_override(state, style)
	star.pressed.connect(func(): Game.goto(Game.SCENE_PROFILE))
	add_child(star)

	resized.connect(_layout)
	_layout()
	if Game.show_makeover_note:
		_show_makeover_note()


func _layout() -> void:
	var w := size.x
	var h := size.y
	_chef.size = Vector2(h * 0.62, h * 0.7)
	_chef.position = Vector2(w * 0.27 - _chef.size.x * 0.5, h * 0.27)
	_play.size = Vector2(300, 150)
	_play.position = Vector2(w * 0.72 - 150, h * 0.36)
	var blurbs: Control = get_node("Blurbs")
	blurbs.position = Vector2(w * 0.72 - 135, h * 0.6)
	var star: Control = get_node("Starring")
	star.reset_size()
	star.position = Vector2(w * 0.27 - star.size.x * 0.5, h - 70)


## A big yellow starburst with lettering, the cover's main blurb.
func _burst_button(text: String, font_size: int) -> Button:
	# The lettering is drawn with the burst, over it (a Button draws its own
	# text first).
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = text
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.draw.connect(func():
		var pulse := 1.0 + 0.04 * sin(_time * 5.0)
		var center := button.size * 0.5
		UiStyle.draw_burst(button, center + Vector2(6, 6), button.size.y * 0.62 * pulse, Art.INK, 16, _time * 0.3, 0.0)
		UiStyle.draw_burst(button, center, button.size.y * 0.62 * pulse, Comic.YELLOW, 16, _time * 0.3, 5.0)
		UiStyle.draw_print_title(button, Vector2(0, center.y + font_size * 0.36), text, font_size, Color.WHITE, button.size.x))
	button.pressed.connect(func(): Sfx.play("pop"))
	return button


## Shown once after an old save was reset for the v0.6 kitchen.
func _show_makeover_note() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Art.INK, 0.75)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.name = "MakeoverNote"
	add_child(shade)
	var panel := UiStyle.panel(Comic.YELLOW)
	panel.custom_minimum_size = Vector2(640, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UiStyle.title("THE KITCHEN GOT A MAKEOVER!", 40, Color.WHITE))
	var text := UiStyle.text("New recipes, new tools, a new kitchen. Your stars and dishes from the old kitchen " +
		"don't fit any more, so the World Tour starts fresh. Your name and chef stayed!", 22)
	text.custom_minimum_size = Vector2(580, 0)
	column.add_child(text)
	var ok := UiStyle.button("LET'S COOK!", Art.PAPER, 32)
	ok.name = "MakeoverOk"
	ok.pressed.connect(func():
		Game.show_makeover_note = false
		shade.queue_free())
	column.add_child(UiStyle.centered(ok))
	var center := UiStyle.centered(panel)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	_play.queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Cover art: a hot magenta-to-violet print with halftone and sun rays
	# behind the cover star.
	UiStyle.draw_halftone(self, Rect2(Vector2.ZERO, size), Color("#d6336c"), Color("#e8508a"), 20.0)
	var center := Vector2(w * 0.27, h * 0.62)
	for i in 18:
		var a := _time * 0.12 + TAU * i / 18.0
		var b := a + TAU / 36.0
		draw_colored_polygon(PackedVector2Array([center, center + Vector2(cos(a), sin(a)) * 1500.0,
			center + Vector2(cos(b), sin(b)) * 1500.0]), Color(Comic.YELLOW, 0.13))
	UiStyle.draw_burst(self, center, h * 0.3, Color(Comic.CYAN, 0.9), 18, -_time * 0.1, 5.0)
	# Dishes from every cuisine circle the star.
	for i in COVER_DISHES.size():
		var icon := Art.item(COVER_DISHES[i])
		if icon == null:
			continue
		var a := -PI * 0.95 + PI * 0.9 * i / (COVER_DISHES.size() - 1)
		var pos := center + Vector2(cos(a) * h * 0.4, sin(a) * h * 0.3 - 20) + Vector2(0, sin(_time * 2.0 + i) * 6.0)
		draw_texture_rect(icon, Rect2(pos - Vector2(48, 48), Vector2(96, 96)), false)

	# The masthead.
	draw_rect(Rect2(0, 0, w, 150), Art.INK)
	UiStyle.draw_print_title(self, Vector2(0, 118), "PASS THE PLATE!", 112, Comic.YELLOW, w)
	draw_rect(Rect2(0, 150, w, 34), Comic.YELLOW)
	draw_line(Vector2(0, 150), Vector2(w, 150), Art.INK, 4.0)
	draw_line(Vector2(0, 184), Vector2(w, 184), Art.INK, 4.0)
	draw_string(Art.comic_font(), Vector2(0, 177), "A WORLD COOKING TOUR  ·  6 CUISINES  ·  1–4 CHEFS", HORIZONTAL_ALIGNMENT_CENTER, w, 28, Art.INK)
	# The issue box (top left) and the price corner (top right).
	var issue := Rect2(18, 18, 120, 112)
	draw_rect(issue, Art.PAPER)
	draw_rect(issue, Comic.YELLOW, false, 5.0)
	draw_string(Art.comic_font(), issue.position + Vector2(0, 40), "ISSUE", HORIZONTAL_ALIGNMENT_CENTER, issue.size.x, 30, Art.INK)
	draw_string(Art.comic_font(), issue.position + Vector2(0, 96), "#6", HORIZONTAL_ALIGNMENT_CENTER, issue.size.x, 60, Comic.MAGENTA)
	var price := Rect2(w - 138, 18, 120, 112)
	draw_circle(price.get_center(), 54, Comic.CYAN)
	draw_arc(price.get_center(), 54, 0, TAU, 40, Art.INK, 5.0, true)
	draw_string(Art.comic_font(), price.position + Vector2(0, 66), "FREE!", HORIZONTAL_ALIGNMENT_CENTER, price.size.x, 34, Art.INK)
	# The barcode with the version, bottom right.
	var code := Rect2(w - 190, h - 92, 170, 74)
	draw_rect(code, Color.WHITE)
	draw_rect(code, Art.INK, false, 3.0)
	for i in 34:
		if (i * 7 + 3) % 5 < 3:
			draw_rect(Rect2(code.position.x + 10 + i * 4.4, code.position.y + 8, 2.6 if i % 3 else 1.4, 40), Art.INK)
	var version := "v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	draw_string(Art.ui_font(), code.position + Vector2(0, 66), version, HORIZONTAL_ALIGNMENT_CENTER, code.size.x, 16, Art.INK)
	# The cover's ink frame.
	draw_rect(Rect2(Vector2.ZERO, size).grow(-5), Art.INK, false, 10.0)
