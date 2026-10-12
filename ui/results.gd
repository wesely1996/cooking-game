extends Control
## End-of-shift results, drawn as the last panel of the issue: a caption
## naming the issue and page, the stars bursting out of a splash, the score,
## and "TO BE CONTINUED..." when the next page is open.

var _shown_stars := 0
var _stars := 0
var _timer := 0.0
var _star_area: Control
var _time := 0.0
var _caption := ""
var _ending := "THE END"


func _ready() -> void:
	var outcome := Game.last_outcome
	var stats := Game.last_stats
	var level := Game.current_level
	_stars = int(outcome.get("stars", 0))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var headline := "SHIFT OVER!"
	if outcome.get("failed", false):
		headline = "THE RIVAL WINS!" if level.type == LevelDef.TYPE_COMPETITION else "THE CROWD WENT HOME!"
	elif level.type == LevelDef.TYPE_COMPETITION:
		headline = "YOU WON THE CUP!"
	elif level.type == LevelDef.TYPE_FESTIVAL:
		headline = "WHAT A FESTIVAL!"
	elif level.type == LevelDef.TYPE_ARCADE:
		headline = "GAME OVER!"
	column.add_child(UiStyle.title(headline, 80, Art.SUN))
	var subtitle := level.name.to_upper()
	if Game.player_count > 1:
		subtitle += "  ·  %d CHEFS" % Game.player_count
	column.add_child(UiStyle.title(subtitle, 34, Color.WHITE))
	_star_area = Control.new()
	_star_area.custom_minimum_size = Vector2(0, 130)
	column.add_child(_star_area)
	column.add_child(UiStyle.title("SCORE  %d" % int(outcome.get("score", 0)), 48, Color.WHITE))
	var details := "Served %d · Lost %d · Perfect %d" % [int(stats.get("served", 0)), int(stats.get("lost", 0)), int(stats.get("perfect", 0))]
	if outcome.has("rival_score"):
		details += "\nRival score %d" % int(outcome.rival_score)
	if outcome.has("mood"):
		details += "\nCrowd mood %d%%" % int(outcome.mood)
	if level.type == LevelDef.TYPE_ARCADE:
		details += "\nBest %d" % Game.best_arcade_score(level.id, Game.player_count)
	column.add_child(UiStyle.text(details, 24, Color.WHITE))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var players := Game.player_count
	var next_id := Game.next_level_id(level.id)
	var can_go_next := level.type != LevelDef.TYPE_ARCADE and not next_id.is_empty() and Game.progression.is_level_unlocked(next_id)
	_caption = _issue_caption(level)
	if can_go_next:
		_ending = "TO BE CONTINUED..."
	if Net.is_client():
		column.add_child(UiStyle.text("Waiting for the host to pick what's next...", 24, Color.WHITE))
		var leave := UiStyle.button("LEAVE", Art.PAPER, 30)
		leave.pressed.connect(Game.leave_to_menu)
		buttons.add_child(leave)
	else:
		var retry := UiStyle.button("RETRY", Art.PAPER, 30)
		retry.pressed.connect(func(): Game.start_level(level.id, players))
		buttons.add_child(retry)
		if can_go_next:
			var next := UiStyle.button("NEXT ▶", Art.SUN, 30)
			next.pressed.connect(func(): Game.start_level(next_id, players))
			buttons.add_child(next)
		var menu := UiStyle.button("LOBBY" if Net.is_host() else "MENU", Color("#7fc8f8"), 30)
		menu.pressed.connect(func():
			if Net.is_host():
				Game.back_to_lobby()
			else:
				Game.goto(Game.SCENE_PLAY if level.type == LevelDef.TYPE_ARCADE else Game.SCENE_LEVEL_SELECT))
		buttons.add_child(menu)
	column.add_child(buttons)


## "ISSUE #2 · PAGE 3", or "ARCADE SPECIAL".
func _issue_caption(level: LevelDef) -> String:
	if level.type == LevelDef.TYPE_ARCADE:
		return "ARCADE SPECIAL"
	for i in Game.progression.regions.size():
		var entries: Array = Game.progression.regions[i].get("levels", [])
		for j in entries.size():
			if entries[j].id == level.id:
				var page := "THE FINALE" if level.type == LevelDef.TYPE_COMPETITION else "PAGE %d" % (j + 1)
				return "ISSUE #%d · %s" % [i + 1, page]
	return ""


func _process(delta: float) -> void:
	_time += delta
	_timer += delta
	if _shown_stars < _stars and _timer > 0.5 + _shown_stars * 0.45:
		_shown_stars += 1
		Sfx.play("ding", 0.0)
		Game.vibrate(50)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.leave_to_menu()


func _draw() -> void:
	var failed: bool = Game.last_outcome.get("failed", false)
	UiStyle.draw_page(self, Rect2(Vector2.ZERO, size))
	var panel := Rect2(Vector2(22, 22), size - Vector2(44, 44))
	UiStyle.draw_halftone(self, panel, Color("#6a4fb3") if failed else Color("#14a3a3"), Color("#7d62c4") if failed else Color("#2bb8b8"), 20.0)
	# Speed lines out of the middle of the panel.
	var middle := panel.get_center()
	for i in 24:
		var a := TAU * i / 24.0 + _time * 0.05
		draw_line(middle + Vector2(cos(a), sin(a)) * 260.0, middle + Vector2(cos(a), sin(a)) * 900.0, Color(1, 1, 1, 0.08), 6.0)
	draw_rect(panel, Art.INK, false, 8.0)
	_draw_caption(panel.position + Vector2(-2, -2), _caption, Comic.YELLOW)
	var font := Art.comic_font()
	var ending_w := font.get_string_size(_ending, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 24.0
	_draw_caption(panel.end - Vector2(ending_w - 2, 38), _ending, Art.PAPER)
	if Game.current_level.type == LevelDef.TYPE_ARCADE:
		return
	var center := _star_area.get_rect().get_center() + _star_area.get_parent_control().position
	# The star splash: a yellow burst that pops once the stars are in.
	var pop := clampf(_timer * 3.0, 0.0, 1.0)
	UiStyle.draw_burst(self, center + Vector2(6, 8), 125.0 * pop, Art.INK, 18, _time * 0.2, 0.0)
	UiStyle.draw_burst(self, center, 125.0 * pop, Color(Comic.MAGENTA if _stars == 3 else Comic.YELLOW, 0.95), 18, _time * 0.2, 5.0)
	for i in 3:
		var pos := center + Vector2((i - 1) * 120.0, -12.0 if i == 1 else 8.0)
		var lit := i < _shown_stars
		_star(pos, 52.0 if i == 1 else 44.0, Art.SUN if lit else Color(1, 1, 1, 0.25))


func _draw_caption(pos: Vector2, text: String, color: Color) -> void:
	if text.is_empty():
		return
	var font := Art.comic_font()
	var rect := Rect2(pos, Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 24.0, 40))
	draw_rect(rect, color)
	draw_rect(rect, Art.INK, false, 4.0)
	draw_string(font, rect.position + Vector2(12, 31), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Art.INK)


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + TAU * i / 10.0
		var r := radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Art.INK, 5.0, true)
