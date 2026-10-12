extends Control
## The World Tour as a comic series: every region is an issue (#1 Italy,
## #2 Mexico...) with a little cover; the chosen issue's levels are the
## panels of its page: four shifts, the festival and the competition finale.
## Tap a panel to play it. Stars unlock the panels of an issue; winning its
## competition opens the next issue.

const ISSUE_COLORS := {"italy": Color("#3fae49"), "mexico": Color("#e5352b"), "usa": Color("#3f6fe0"),
	"spain": Color("#f28c28"), "japan": Color("#f2f2f2"), "france": Color("#2f3f8f")}
const KIND_CAPTIONS := {"normal": "SHIFT", "festival": "FESTIVAL", "competition": "THE FINALE"}
const GUTTER := 12.0

var _title: Label
var _covers: HBoxContainer
var _page: Control
var _panels: Array[Button] = []
var _time := 0.0


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
	_title = UiStyle.caption("", 40)
	header.add_child(_title)
	var book := UiStyle.button("RECIPES", Color("#ffd1e8"), 26)
	book.pressed.connect(func(): Game.open_recipe_book(Game.SCENE_LEVEL_SELECT))
	header.add_child(book)
	root.add_child(UiStyle.margin(header, 18, 18, 14, 0))

	_covers = HBoxContainer.new()
	_covers.alignment = BoxContainer.ALIGNMENT_CENTER
	_covers.add_theme_constant_override("separation", 12)
	root.add_child(_covers)

	_page = Control.new()
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.resized.connect(_layout_panels)
	root.add_child(UiStyle.margin(_page, 18, 18, 0, 16))
	_show_region(clampi(Game.selected_region, 0, Game.progression.regions.size() - 1))


func _show_region(index: int) -> void:
	Game.selected_region = index
	var region: Dictionary = Game.progression.regions[index]
	_title.text = "ISSUE #%d: %s  ·  ★ %d" % [index + 1, str(region.name).to_upper(), Game.progression.region_stars(index)]
	for child in _covers.get_children():
		child.queue_free()
	for i in Game.progression.regions.size():
		_covers.add_child(_cover(i, i == index))
	for panel in _panels:
		panel.queue_free()
	_panels.clear()
	if not Game.progression.is_region_unlocked(index):
		_panels.append(_locked_issue_panel(index))
	else:
		for entry in region.get("levels", []):
			_panels.append(_level_panel(entry))
	for panel in _panels:
		_page.add_child(panel)
	_layout_panels()


## The issue's page: shifts 1-3 on top, shift 4, the festival and the
## finale below, the finale a little wider.
func _layout_panels() -> void:
	var area := Rect2(Vector2.ZERO, _page.size)
	if _panels.size() == 1:
		_panels[0].position = Vector2.ZERO
		_panels[0].size = area.size
		return
	var rows := [_panels.slice(0, 3), _panels.slice(3)]
	var shares := [[0.36, 0.32, 0.32], [0.3, 0.3, 0.4]]
	var row_h := (area.size.y - GUTTER) * 0.5
	for r in rows.size():
		var x := 0.0
		var row: Array = rows[r]
		var total := area.size.x - GUTTER * (row.size() - 1)
		for i in row.size():
			var share: float = shares[r][i] if row.size() == 3 else 1.0 / row.size()
			var panel: Button = row[i]
			panel.position = Vector2(x, r * (row_h + GUTTER))
			panel.size = Vector2(total * share, row_h)
			x += total * share + GUTTER


## A little cover for each issue; locked issues are greyed out.
func _cover(index: int, selected: bool) -> Button:
	var region: Dictionary = Game.progression.regions[index]
	var unlocked := Game.progression.is_region_unlocked(index)
	var button := Button.new()
	button.name = "Region_" + str(region.id)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, 74)
	button.tooltip_text = str(region.name)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var color: Color = ISSUE_COLORS.get(region.id, Art.PAPER)
	var icon := Game.cuisine_icon(str(region.get("pack", "")))
	button.draw.connect(func():
		var rect := Rect2(Vector2(4, 0 if selected else 6), button.size - Vector2(8, 8))
		button.draw_rect(Rect2(rect.position + Vector2(5, 5), rect.size), Color(Art.INK, 0.8))
		button.draw_rect(rect, color if unlocked else Color("#6d6878"))
		if icon:
			button.draw_texture_rect(icon, Rect2(rect.end.x - 64, rect.position.y + 4, 58, 58), false,
				Color.WHITE if unlocked else Color(0.15, 0.12, 0.2, 0.7))
		var ink := Art.INK if color.get_luminance() > 0.5 and unlocked else Color.WHITE
		button.draw_string(Art.comic_font(), rect.position + Vector2(8, 30), "#%d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
		var label := str(region.name).to_upper() if unlocked else "LOCKED"
		button.draw_string(Art.comic_font(), rect.position + Vector2(8, 58), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 60, 20, ink)
		button.draw_rect(rect, Comic.YELLOW if selected else Art.INK, false, 5.0 if selected else 4.0))
	button.pressed.connect(func():
		Sfx.play("pop")
		_show_region(index))
	return button


func _level_panel(entry: Dictionary) -> Button:
	var level: LevelDef = Game.levels.get(entry.id)
	var unlocked := Game.progression.is_level_unlocked(entry.id)
	var stars := int(Game.progression.best_stars.get(entry.id, 0))
	var won: bool = Game.progression.won.has(entry.id)
	var page_number := _panels.size() + 1
	var button := Button.new()
	button.name = "Level_" + level.id
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not unlocked
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var color := Art.PAPER
	match level.type:
		LevelDef.TYPE_FESTIVAL:
			color = Color("#ffd1e8")
		LevelDef.TYPE_COMPETITION:
			color = Color("#e3d1ff")
	var dishes := level.dish_ids()
	button.draw.connect(func():
		var rect := Rect2(Vector2.ZERO, button.size)
		button.draw_rect(rect, color)
		# The dishes of the shift, as the panel's art.
		var icon_size := minf(rect.size.y * 0.34, rect.size.x / maxf(dishes.size(), 1) - 8.0)
		var start := rect.get_center().x - (icon_size + 6.0) * dishes.size() * 0.5
		for i in dishes.size():
			var icon := Art.item(dishes[i])
			if icon:
				button.draw_texture_rect(icon, Rect2(start + i * (icon_size + 6.0), rect.size.y * 0.26, icon_size, icon_size), false)
		var font := Art.comic_font()
		var caption: String = KIND_CAPTIONS.get(level.type, "")
		if level.type == LevelDef.TYPE_NORMAL:
			caption = "PAGE %d · %s" % [page_number, caption]
		var caption_w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 16.0
		button.draw_rect(Rect2(0, 0, caption_w, 28), Comic.YELLOW)
		button.draw_rect(Rect2(0, 0, caption_w, 28), Art.INK, false, 3.0)
		button.draw_string(font, Vector2(8, 22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.INK)
		UiStyle.draw_print_title(button, Vector2(0, rect.size.y * 0.22), level.name.to_upper(), 30, Color.WHITE, rect.size.x)
		button.draw_multiline_string(Art.ui_font(), Vector2(12, rect.size.y * 0.26 + icon_size + 22), level.description,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 24, 14, 3, Art.INK)
		var star_text := "★".repeat(stars) + "☆".repeat(3 - stars)
		if level.type == LevelDef.TYPE_COMPETITION:
			star_text = "CUP WON!" if won else "BEAT THE RIVAL!"
		button.draw_string(font, Vector2(0, rect.size.y - 12), star_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 30,
			Comic.MAGENTA if level.type == LevelDef.TYPE_COMPETITION else Color("#f2b632"))
		if not unlocked:
			# A covered panel: ink with halftone dots and what opens it.
			UiStyle.draw_halftone(button, rect, Color(Art.INK, 0.92), Color(1, 1, 1, 0.06), 12.0)
			UiStyle.draw_print_title(button, Vector2(0, rect.get_center().y + 14), "★ %d TO OPEN" % int(entry.get("stars_required", 0)),
				34, Comic.YELLOW, rect.size.x)
		elif button.is_hovered():
			button.draw_rect(rect.grow(-4), Comic.MAGENTA, false, 4.0)
		button.draw_rect(rect, Art.INK, false, 6.0))
	button.pressed.connect(func():
		Sfx.play("pop")
		Game.start_level(entry.id))
	return button


func _locked_issue_panel(index: int) -> Button:
	var previous: Dictionary = Game.progression.regions[index - 1]
	var boss: LevelDef = Game.levels.get(previous.get("boss", ""))
	var region: Dictionary = Game.progression.regions[index]
	var icon := Game.cuisine_icon(str(region.get("pack", "")))
	var button := Button.new()
	button.name = "LockedIssue"
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.draw.connect(func():
		var rect := Rect2(Vector2.ZERO, button.size)
		UiStyle.draw_halftone(button, rect, Color("#3b3157"), Color("#4a3f6a"), 14.0)
		var center := rect.get_center()
		UiStyle.draw_burst(button, center + Vector2(0, -20), 120.0, Color(Comic.CYAN, 0.35), 16, 0.0, 0.0)
		if icon:
			button.draw_texture_rect(icon, Rect2(center + Vector2(-80, -110), Vector2(160, 160)), false, Color(0.1, 0.08, 0.15, 0.8))
		UiStyle.draw_print_title(button, Vector2(0, rect.size.y * 0.2), "ISSUE #%d: %s" % [index + 1, str(region.name).to_upper()],
			48, Comic.YELLOW, rect.size.x)
		var text := "Win %s in %s to open this issue." % [boss.name if boss else "the competition", previous.name]
		button.draw_string(Art.ui_font(), Vector2(0, rect.size.y * 0.82), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24, Color.WHITE)
		button.draw_rect(rect, Art.INK, false, 6.0))
	return button


func _process(delta: float) -> void:
	_time += delta
	for panel in _panels:
		panel.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.goto(Game.SCENE_PLAY)


func _draw() -> void:
	UiStyle.draw_page(self, Rect2(Vector2.ZERO, size))
