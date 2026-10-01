extends Control
## The world map. For now one region (Italy) with its levels as cards. Stars
## unlock the next levels; the competition opens the next region.


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	var back := UiStyle.button("◀ BACK", Art.PAPER, 26)
	back.pressed.connect(func(): Game.goto(Game.SCENE_MENU))
	header.add_child(back)
	var region: Dictionary = Game.progression.regions[0]
	var title := UiStyle.title("%s  ·  ★ %d" % [region.name.to_upper(), Game.progression.region_stars(0)], 56, Art.SUN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_child(header)
	root.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var row_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		row_margin.add_theme_constant_override("margin_" + side, 24)
	row_margin.add_child(row)
	scroll.add_child(row_margin)

	for entry in region.get("levels", []):
		row.add_child(_card(entry))


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
		Game.goto(Game.SCENE_MENU)


func _draw() -> void:
	UiStyle.draw_halftone(self, Rect2(Vector2.ZERO, size), Color("#3f8fe0"), Color("#5aa2ea"), 22.0)
