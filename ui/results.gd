extends Control
## End-of-shift results: stars, score and what happened.

var _shown_stars := 0
var _stars := 0
var _timer := 0.0
var _star_area: Control


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
	column.add_child(UiStyle.title(level.name.to_upper(), 34, Color.WHITE))
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
		details += "\nBest %d" % int(Game.best_arcade.get(level.id, 0))
	column.add_child(UiStyle.text(details, 24, Color.WHITE))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var retry := UiStyle.button("RETRY", Art.PAPER, 30)
	retry.pressed.connect(func(): Game.start_level(level.id))
	buttons.add_child(retry)
	var next_id := Game.next_level_id(level.id)
	if level.type != LevelDef.TYPE_ARCADE and not next_id.is_empty() and Game.progression.is_level_unlocked(next_id):
		var next := UiStyle.button("NEXT ▶", Art.SUN, 30)
		next.pressed.connect(func(): Game.start_level(next_id))
		buttons.add_child(next)
	var menu := UiStyle.button("MENU", Color("#7fc8f8"), 30)
	menu.pressed.connect(func(): Game.goto(Game.SCENE_MENU if level.type == LevelDef.TYPE_ARCADE else Game.SCENE_LEVEL_SELECT))
	buttons.add_child(menu)
	column.add_child(buttons)


func _process(delta: float) -> void:
	_timer += delta
	if _shown_stars < _stars and _timer > 0.5 + _shown_stars * 0.45:
		_shown_stars += 1
		Sfx.play("ding", 0.0)
		Game.vibrate(50)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.goto(Game.SCENE_MENU)


func _draw() -> void:
	var failed: bool = Game.last_outcome.get("failed", false)
	UiStyle.draw_halftone(self, Rect2(Vector2.ZERO, size), Color("#6a4fb3") if failed else Art.LEAF, Color("#7d62c4") if failed else Color("#58c062"), 22.0)
	if Game.current_level.type == LevelDef.TYPE_ARCADE:
		return
	var center := _star_area.get_rect().get_center()
	for i in 3:
		var pos := center + Vector2((i - 1) * 120.0, -12.0 if i == 1 else 8.0)
		var lit := i < _shown_stars
		_star(pos, 52.0 if i == 1 else 44.0, Art.SUN if lit else Color(1, 1, 1, 0.25))


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + TAU * i / 10.0
		var r := radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Art.INK, 5.0, true)
