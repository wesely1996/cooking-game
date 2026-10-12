extends Control
## Everything that starts a game: the World Tour, playing with a friend over
## LAN, and arcade (pick a cuisine you have reached in the World Tour).

enum Page { MAIN, ARCADE }

var _content: VBoxContainer
var _title: Label
var _page := Page.MAIN


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var header := UiStyle.header("PLAY", _on_back)
	_title = header.get_child(0).get_child(1)
	root.add_child(header)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 18)
	center.add_child(_content)
	_show(Page.MAIN)


func _show(page: Page) -> void:
	_page = page
	for child in _content.get_children():
		child.queue_free()
	match page:
		Page.MAIN:
			_title.text = "PLAY"
			# Three panels of one comic page.
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			_content.add_child(row)
			_add_choice(row, "WORLD TOUR", "Six issues, six kitchens: learn them all and win their competitions.",
				Comic.YELLOW, ["pizza_margherita", "beef_taco", "miso_ramen"], func(): Game.goto(Game.SCENE_LEVEL_SELECT))
			_add_choice(row, "PLAY WITH A FRIEND", "Two phones on the same Wi-Fi: one kitchen, two chefs.",
				Color("#7be08a"), ["caprese_salad", "salmon_nigiri"], func(): Game.goto(Game.SCENE_LOBBY))
			_add_choice(row, "ARCADE", "Endless orders in the cuisine of your choice. How long can you last?",
				Comic.CYAN, ["cheeseburger"], func(): _show(Page.ARCADE))
		Page.ARCADE:
			_title.text = "ARCADE"
			_content.add_child(UiStyle.title("PICK A CUISINE", 34, Color.WHITE))
			# Up to four cuisines in a row; more go on a grid of two rows.
			var count := Game.progression.regions.size()
			var grid := GridContainer.new()
			grid.columns = count if count <= 4 else ceili(count / 2.0)
			grid.add_theme_constant_override("h_separation", 18)
			grid.add_theme_constant_override("v_separation", 14)
			_content.add_child(UiStyle.centered(grid))
			for i in count:
				grid.add_child(_cuisine_card(i, Vector2(250, 260) if count <= 4 else Vector2(240, 190)))
			_content.add_child(UiStyle.text("Win a region's competition in the World Tour to unlock the next cuisine.", 20, Color.WHITE))


func _add_choice(row: HBoxContainer, text: String, help: String, color: Color, dishes: Array, action: Callable) -> void:
	var panel := UiStyle.panel(color)
	panel.custom_minimum_size = Vector2(370, 430)
	row.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	for dish in dishes:
		var icon := TextureRect.new()
		icon.texture = Art.item(dish)
		icon.custom_minimum_size = Vector2(100, 100)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icons.add_child(icon)
	column.add_child(icons)
	column.add_child(UiStyle.title(text, 36, Color.WHITE))
	var label := UiStyle.text(help, 20)
	label.custom_minimum_size = Vector2(320, 0)
	column.add_child(label)
	var button := UiStyle.button("GO!", Art.PAPER, 36)
	button.custom_minimum_size = Vector2(200, 0)
	button.pressed.connect(action)
	button.name = text.replace(" ", "_")
	column.add_child(UiStyle.centered(button))


func _cuisine_card(region_index: int, card_size: Vector2) -> Control:
	var region: Dictionary = Game.progression.regions[region_index]
	var pack: String = region.get("pack", "")
	var unlocked := Game.progression.is_region_unlocked(region_index)
	var level_id := Game.arcade_level_id(pack)
	var card := UiStyle.button("", Art.PAPER if unlocked else Color("#b9b2a4"), 24)
	card.custom_minimum_size = card_size
	card.disabled = not unlocked or not Game.levels.has(level_id)
	card.name = "Arcade_" + pack
	card.icon = Game.cuisine_icon(pack)
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var best := Game.best_arcade_score(level_id, 1)
	if unlocked:
		card.text = "%s\nBEST %d" % [Game.cuisine_name(pack).to_upper(), best]
	else:
		card.text = "%s\nLOCKED" % Game.cuisine_name(pack).to_upper()
	card.pressed.connect(func(): Game.start_level(level_id))
	return card


func _on_back() -> void:
	if _page == Page.ARCADE:
		_show(Page.MAIN)
	else:
		Game.goto(Game.SCENE_MENU)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _draw() -> void:
	UiStyle.draw_page(self, Rect2(Vector2.ZERO, size))
