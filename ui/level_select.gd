extends Control
## The World Tour: one tab per region (Italy, Mexico, Japan...). Stars unlock
## the levels of a region; winning its competition opens the next region.

const REGION_COLORS := {"italy": Color("#3fae49"), "mexico": Color("#e5352b"), "japan": Color("#f2f2f2")}

var _tabs: HBoxContainer
var _cards: HBoxContainer
var _title: Label


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	var back := UiStyle.button("◀ BACK", Art.PAPER, 26)
	back.pressed.connect(func(): Game.goto(Game.SCENE_PLAY))
	header.add_child(back)
	_title = UiStyle.title("", 52, Art.SUN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var book := UiStyle.button("RECIPES", Color("#ffd1e8"), 26)
	book.pressed.connect(func(): Game.open_recipe_book(Game.SCENE_LEVEL_SELECT))
	header.add_child(book)
	root.add_child(UiStyle.margin(header, 20, 20, 16, 0))

	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 12)
	root.add_child(_tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 22)
	scroll.add_child(UiStyle.margin(_cards, 24, 24, 10, 24))
	_show_region(clampi(Game.selected_region, 0, Game.progression.regions.size() - 1))


func _show_region(index: int) -> void:
	Game.selected_region = index
	var region: Dictionary = Game.progression.regions[index]
	_title.text = "%s  ·  ★ %d" % [str(region.name).to_upper(), Game.progression.region_stars(index)]
	for child in _tabs.get_children():
		child.queue_free()
	for i in Game.progression.regions.size():
		var r: Dictionary = Game.progression.regions[i]
		var unlocked := Game.progression.is_region_unlocked(i)
		var label := str(r.name).to_upper() + ("" if unlocked else " 🔒")
		var tab := UiStyle.button(label, Art.SUN if i == index else (Art.PAPER if unlocked else Color("#b9b2a4")), 26)
		tab.name = "Region_" + str(r.id)
		tab.pressed.connect(func(): _show_region(i))
		_tabs.add_child(tab)
	for child in _cards.get_children():
		child.queue_free()
	if not Game.progression.is_region_unlocked(index):
		_cards.add_child(_locked_region_card(index))
		return
	for entry in region.get("levels", []):
		_cards.add_child(_card(entry))


func _locked_region_card(index: int) -> Control:
	var previous: Dictionary = Game.progression.regions[index - 1]
	var boss: LevelDef = Game.levels.get(previous.get("boss", ""))
	var panel := UiStyle.panel(Color("#e8e2d6"))
	panel.custom_minimum_size = Vector2(700, 380)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var region: Dictionary = Game.progression.regions[index]
	column.add_child(UiStyle.title("%s IS LOCKED" % str(region.name).to_upper(), 44, Art.TOMATO))
	var icon := TextureRect.new()
	icon.texture = Game.cuisine_icon(str(region.get("pack", "")))
	icon.custom_minimum_size = Vector2(140, 140)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(0.1, 0.08, 0.15, 0.6)
	column.add_child(icon)
	column.add_child(UiStyle.text("Win %s in %s to travel here." % [boss.name if boss else "the competition", previous.name], 24))
	return panel


func _card(entry: Dictionary) -> Control:
	var level: LevelDef = Game.levels.get(entry.id)
	var unlocked := Game.progression.is_level_unlocked(entry.id)
	var stars := int(Game.progression.best_stars.get(entry.id, 0))
	var color := Art.PAPER
	match level.type:
		LevelDef.TYPE_FESTIVAL:
			color = Color("#ffd1e8")
		LevelDef.TYPE_COMPETITION:
			color = Color("#e3d1ff")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(color if unlocked else Color("#b9b2a4")))
	panel.custom_minimum_size = Vector2(250, 440)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var kind: String = {"normal": "SHIFT", "festival": "FESTIVAL", "competition": "COMPETITION"}.get(level.type, "")
	column.add_child(UiStyle.title(kind, 22, Art.TOMATO))
	column.add_child(UiStyle.title(level.name.to_upper(), 32, Color.WHITE))
	var picture := TextureRect.new()
	picture.texture = Art.item(level.dish_ids()[0])
	picture.custom_minimum_size = Vector2(120, 120)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not unlocked:
		picture.modulate = Color(0, 0, 0, 0.5)
	column.add_child(picture)
	var description := UiStyle.text(level.description, 16)
	description.custom_minimum_size = Vector2(220, 0)
	column.add_child(description)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(UiStyle.title("★".repeat(stars) + "☆".repeat(3 - stars), 34, Art.SUN))
	var play := UiStyle.button("PLAY" if unlocked else "★ %d NEEDED" % int(entry.get("stars_required", 0)), Art.SUN, 26)
	play.disabled = not unlocked
	play.pressed.connect(func(): Game.start_level(entry.id))
	column.add_child(play)
	return panel


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.goto(Game.SCENE_PLAY)


func _draw() -> void:
	UiStyle.draw_halftone(self, Rect2(Vector2.ZERO, size), Color("#3f8fe0"), Color("#5aa2ea"), 22.0)
