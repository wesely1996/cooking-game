extends Control
## The recipe book, an inner page of the comic. Each dish you have served
## is a little comic strip, one panel per step (what goes in, the tool, the
## gesture, what comes out), ending with the plated dish. Dishes you haven't
## made yet are covered panels that say where to find them; planned cuisines
## are "?" cards, coming soon in a future issue.

const CARD := Vector2(124, 150)
const STRIP_PANEL := Vector2(150, 220)
const COMING_SOON_PATH := "res://data/recipe_book.json"

var _db: ContentDB
var _detail: VBoxContainer
var _cards: Array[Button] = []


func _ready() -> void:
	_db = Game.db
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var dishes := _dishes()
	var known := dishes.filter(func(d): return Game.progression.is_discovered(d)).size()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	var back := UiStyle.button("◀ BACK", Art.PAPER, 26)
	back.pressed.connect(func(): Game.goto(Game.recipe_book_return))
	header.add_child(back)
	header.add_child(UiStyle.caption("RECIPE BOOK  ·  %d/%d DISHES" % [known, dishes.size()], 44))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(back.get_combined_minimum_size().x, 0)
	header.add_child(spacer)
	root.add_child(_margin(header, 18, 18, 14, 0))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(_margin(body, 18, 18, 0, 18))

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(4 * (CARD.x + 10) + 24, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list_scroll.add_child(list)

	var by_pack := {}
	for dish in dishes:
		var pack: String = _db.items[dish].pack
		if not by_pack.has(pack):
			by_pack[pack] = []
		by_pack[pack].append(dish)
	for pack in by_pack:
		list.add_child(UiStyle.title(str(_db.pack_names.get(pack, pack)).to_upper(), 30, Color.WHITE))
		var grid := _grid()
		for dish in by_pack[pack]:
			grid.add_child(_dish_card(dish))
		list.add_child(grid)
	var coming: Variant = DataFiles.read_json(COMING_SOON_PATH)
	var issue := Game.progression.regions.size()
	for entry in (coming.get("coming_soon", []) if coming is Dictionary else []):
		issue += 1
		entry["issue"] = issue
		list.add_child(UiStyle.title("%s · COMING SOON" % str(entry.cuisine).to_upper(), 26, Color(1, 1, 1, 0.75)))
		var grid := _grid()
		for i in int(entry.get("dishes", 1)):
			grid.add_child(_mystery_card(entry))
		list.add_child(grid)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", UiStyle.panel_box(Art.PAPER))
	body.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(_detail)

	var first_known := dishes.filter(func(d): return Game.progression.is_discovered(d))
	_show_dish(first_known[0] if not first_known.is_empty() else dishes[0])


## Every dish in the game, in the order the story introduces them.
func _dishes() -> Array:
	var ordered := []
	for id in Game.level_order():
		var level: LevelDef = Game.levels.get(id)
		if level:
			for dish in level.dish_ids():
				if not ordered.has(dish):
					ordered.append(dish)
	for id in _db.items:
		if _db.is_dish(id) and not ordered.has(id):
			ordered.append(id)
	return ordered


func _dish_card(dish: String) -> Button:
	var known := Game.progression.is_discovered(dish)
	var card := _card_button(_db.item_name(dish).to_upper() if known else "???", Art.PAPER if known else Color("#d8d0c0"))
	card.icon = Art.item(dish)
	if not known:
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			card.add_theme_color_override(state, Color(0.1, 0.08, 0.15, 0.6))
	card.pressed.connect(func(): _show_dish(dish))
	return card


func _mystery_card(entry: Dictionary) -> Button:
	var card := _card_button("?", Color("#b9b2a4"))
	card.add_theme_font_size_override("font_size", 72)
	card.pressed.connect(func(): _show_mystery(entry))
	return card


func _card_button(text: String, color: Color) -> Button:
	var card := UiStyle.button(text, color, 16)
	card.custom_minimum_size = CARD
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = card.get_theme_stylebox(state).duplicate()
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		box.shadow_offset = Vector2(3, 3)
		card.add_theme_stylebox_override(state, box)
	_cards.append(card)
	return card


func _show_dish(dish: String) -> void:
	_clear_detail()
	var known := Game.progression.is_discovered(dish)
	var level := Game.first_level_with(dish)
	var where := "%s (%s)" % [level.name, _region_name(level.id)] if level else "a future level"
	_detail.add_child(_left(UiStyle.title(_db.item_name(dish).to_upper() if known else "LOCKED DISH", 40, Art.TOMATO)))
	if known:
		_detail.add_child(_left(UiStyle.text("Price %d · first served in %s" % [int(_db.items[dish].price), where], 18)))
	else:
		_detail.add_child(_left(UiStyle.text("You haven't made this one yet. Cook it in %s to uncover its strip: " % where +
			"the first time you make a new dish, tips and arrows show every step.", 18)))
	var strip := HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 10)
	strip.add_theme_constant_override("v_separation", 10)
	_detail.add_child(strip)
	var steps := _db.recipe_steps(dish)
	for i in steps.size():
		strip.add_child(_step_panel(i + 1, steps[i]) if known else _covered_panel(i + 1))
	strip.add_child(_serve_panel(dish, known))


func _show_mystery(entry: Dictionary) -> void:
	_clear_detail()
	var issue := int(entry.get("issue", Game.progression.regions.size() + 1))
	_detail.add_child(_left(UiStyle.title("A %s DISH" % str(entry.cuisine).to_upper(), 40, Art.TOMATO)))
	_detail.add_child(_left(UiStyle.text("This recipe isn't in the kitchen yet. The crew will learn it when the World Tour reaches %s." %
		entry.get("region", "a new region"), 20)))
	var strip := HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 10)
	_detail.add_child(strip)
	for i in 3:
		strip.add_child(_covered_panel(i + 1))
	var soon := _strip_panel(Comic.MAGENTA)
	var column: VBoxContainer = soon.get_child(0)
	column.add_child(UiStyle.title("COMING SOON", 30, Comic.YELLOW))
	column.add_child(UiStyle.title("IN ISSUE #%d!" % issue, 34, Color.WHITE))
	strip.add_child(soon)


func _icon_row(ids: Array, icon_size: float = 48.0) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	for id in ids:
		var icon := TextureRect.new()
		icon.texture = Art.item(id)
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = _db.item_name(id)
		row.add_child(icon)
	return row


## One step of a recipe as a comic panel: the step's caption, what goes in,
## the tool and the gesture (or cooking time), and what comes out.
func _step_panel(number: int, step: Dictionary) -> Control:
	var panel := _strip_panel(Art.PAPER)
	var column: VBoxContainer = panel.get_child(0)
	if step.kind == "assembly":
		column.add_child(_step_caption("%d · PLATE IT" % number if step.base == ContentDB.PLATE else "%d · TOP IT" % number))
		column.add_child(_icon_row(step.parts, 38.0))
		column.add_child(UiStyle.text("on the %s" % _db.item_name(step.base).to_lower(), 15))
		column.add_child(_icon_row([step.base], 40.0))
	else:
		var verb: String = RecipeText.VERBS.get(step.action, str(step.action).capitalize())
		column.add_child(_step_caption("%d · %s" % [number, verb.to_upper()]))
		column.add_child(_icon_row(step.inputs, 38.0))
		var tool := TextureRect.new()
		tool.texture = Art.equipment(step.station)
		tool.custom_minimum_size = Vector2(52, 52)
		tool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tool.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tool.tooltip_text = _db.station_name(step.station)
		column.add_child(tool)
		var how: String
		if float(step.cook_time) > 0.0:
			how = "cooks %d s" % roundi(step.cook_time)
		else:
			how = str(RecipeText.GESTURES.get(step.action, "×%d")) % roundi(step.work)
		column.add_child(UiStyle.text(how, 15, Art.TOMATO))
	column.add_child(UiStyle.text("= %s" % _db.item_name(step.output).to_upper(), 15))
	return panel


## The strip's last panel: the plated dish, served.
func _serve_panel(dish: String, known: bool) -> Control:
	var panel := _strip_panel(Comic.YELLOW if known else Color("#3b3157"))
	var column: VBoxContainer = panel.get_child(0)
	var picture := TextureRect.new()
	picture.texture = Art.item(dish)
	picture.custom_minimum_size = Vector2(110, 110)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not known:
		picture.modulate = Color(0.1, 0.08, 0.15, 0.7)
	column.add_child(picture)
	column.add_child(UiStyle.title("SERVE!" if known else "???", 34, Color.WHITE))
	return panel


## A step you haven't seen yet: an ink panel with a question mark.
func _covered_panel(number: int) -> Control:
	var panel := _strip_panel(Color("#3b3157"))
	var column: VBoxContainer = panel.get_child(0)
	column.add_child(_step_caption("%d · ???" % number))
	column.add_child(UiStyle.title("?", 72, Color(1, 1, 1, 0.35)))
	return panel


func _strip_panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := UiStyle.panel_box(color, 4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = STRIP_PANEL
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	return panel


func _step_caption(text: String) -> Label:
	var label := UiStyle.caption(text, 18)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


## The region whose issue has the level, e.g. "Italy".
func _region_name(level_id: String) -> String:
	for region in Game.progression.regions:
		for entry in region.get("levels", []):
			if entry.id == level_id:
				return str(region.name)
	return ""


func _clear_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	return grid


func _left(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _margin(control: Control, left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_vertical = control.size_flags_vertical
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_child(control)
	return margin


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.goto(Game.recipe_book_return)


func _draw() -> void:
	UiStyle.draw_page(self, Rect2(Vector2.ZERO, size))
