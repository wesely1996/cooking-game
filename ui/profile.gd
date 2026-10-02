extends Control
## The player's profile: name, what their chef looks like, and their kitchen
## stats, including the favourite cuisine (played most) and the best cuisine
## (highest average score).

var _portrait: ChefPortrait
var _name_edit: LineEdit
var _option_labels := {}  # part -> Label
var _option_swatches := {}  # part -> ColorRect


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(UiStyle.header("MY CHEF", _on_back))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(UiStyle.margin(body, 18, 18, 0, 18))
	body.add_child(_chef_panel())
	body.add_child(_stats_panel())


func _chef_panel() -> Control:
	var panel := UiStyle.panel()
	panel.custom_minimum_size = Vector2(520, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	_portrait = ChefPortrait.new()
	_portrait.custom_minimum_size = Vector2(210, 240)
	_portrait.look = Game.profile.look
	left.add_child(_portrait)
	left.add_child(UiStyle.left_text("Name", 18))
	_name_edit = UiStyle.line_edit("Your name", 24)
	_name_edit.text = Game.profile.name
	_name_edit.max_length = PlayerProfile.MAX_NAME_LENGTH
	_name_edit.custom_minimum_size = Vector2(210, 52)
	_name_edit.text_changed.connect(func(value: String):
		Game.profile.name = PlayerProfile.clean_name(value))
	_name_edit.text_submitted.connect(func(_value): Game.save())
	left.add_child(_name_edit)

	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 10)
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(options)
	for part in ChefLook.PARTS:
		options.add_child(_option_row(part))
	var random := UiStyle.button("SURPRISE ME!", Art.SUN, 22)
	random.pressed.connect(_randomize)
	options.add_child(random)
	return panel


func _option_row(part: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := UiStyle.left_text(ChefLook.PARTS[part].label, 18)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var prev := UiStyle.button("◀", Art.PAPER, 20)
	prev.pressed.connect(func(): _step(part, -1))
	row.add_child(prev)
	var value_box := HBoxContainer.new()
	value_box.custom_minimum_size = Vector2(110, 40)
	value_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(40, 32)
	value_box.add_child(swatch)
	var value := UiStyle.text("", 18)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_box.add_child(value)
	row.add_child(value_box)
	var next := UiStyle.button("▶", Art.PAPER, 20)
	next.pressed.connect(func(): _step(part, 1))
	row.add_child(next)
	_option_labels[part] = value
	_option_swatches[part] = swatch
	_refresh_option(part)
	return row


func _step(part: String, direction: int) -> void:
	var look := ChefLook.sanitize(Game.profile.look)
	look[part] = posmod(int(look[part]) + direction, ChefLook.PARTS[part].count)
	_set_look(look)


func _randomize() -> void:
	var look := {}
	for part in ChefLook.PARTS:
		look[part] = randi() % ChefLook.PARTS[part].count
	_set_look(look)
	Sfx.play("cheer")


func _set_look(look: Dictionary) -> void:
	Game.profile.look = look
	_portrait.look = look
	for part in ChefLook.PARTS:
		_refresh_option(part)
	Game.save()


func _refresh_option(part: String) -> void:
	var index := int(ChefLook.sanitize(Game.profile.look)[part])
	var color: Variant = ChefLook.option_color(part, index)
	_option_swatches[part].visible = color != null
	if color != null:
		_option_swatches[part].color = color
	_option_labels[part].text = "" if color != null else ChefLook.option_name(part, index)


func _stats_panel() -> Control:
	var panel := UiStyle.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UiStyle.title("MY KITCHEN", 36, Art.TOMATO))

	var profile := Game.profile
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	column.add_child(cards)
	var favorite := profile.favorite_cuisine()
	var best := profile.best_cuisine()
	cards.add_child(_cuisine_card("FAVOURITE CUISINE", favorite,
		"%d shifts played" % int(profile.cuisines[favorite].plays) if not favorite.is_empty() else "Play a shift to find out!"))
	cards.add_child(_cuisine_card("BEST CUISINE", best,
		"Average score %d" % roundi(profile.average_score(best)) if not best.is_empty() else "Your best scores will show here"))

	var all_dishes := Game.db.items.values().filter(func(item): return item.kind == ContentDB.KIND_DISH).size()
	var regions_reached := 0
	for i in Game.progression.regions.size():
		if Game.progression.is_region_unlocked(i):
			regions_reached += 1
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	for entry in [
		["Shifts played", str(profile.total_plays())],
		["Dishes served", str(profile.dishes_served)],
		["Stars collected", "★ %d" % Game.progression.total_stars()],
		["Recipes discovered", "%d / %d" % [Game.progression.discovered.size(), all_dishes]],
		["Regions reached", "%d / %d" % [regions_reached, Game.progression.regions.size()]],
	]:
		var label := UiStyle.left_text(entry[0], 22)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(label)
		var value := UiStyle.left_text(entry[1], 22, Art.TOMATO)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(value)
	column.add_child(grid)
	return panel


func _cuisine_card(heading: String, pack: String, detail: String) -> Control:
	var card := UiStyle.panel(Color("#ffe9a8") if not pack.is_empty() else Color("#e8e2d6"))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	column.add_child(UiStyle.title(heading, 20, Art.TOMATO))
	var icon := TextureRect.new()
	icon.texture = Game.cuisine_icon(pack) if not pack.is_empty() else null
	icon.custom_minimum_size = Vector2(90, 90)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(icon)
	column.add_child(UiStyle.title(Game.cuisine_name(pack).to_upper() if not pack.is_empty() else "?", 32, Color.WHITE))
	column.add_child(UiStyle.text(detail, 18))
	return card


func _on_back() -> void:
	Game.profile.name = PlayerProfile.clean_name(_name_edit.text)
	Game.save()
	Game.goto(Game.SCENE_MENU)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _draw() -> void:
	UiStyle.draw_halftone(self, Rect2(Vector2.ZERO, size), Color("#b45ab4"), Color("#c46ec4"), 22.0)
