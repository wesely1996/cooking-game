extends TestCase
## Gesture recognition of the mini-games, fed with synthetic pointer events.

var _units := 0


func _game(kind: String) -> Minigame:
	var game := Minigame.new()
	game.size = Vector2(500, 300)
	game.kind = kind
	game.visible = true
	game.work_done.connect(func(units): _units += units)
	return game


func _press(game: Minigame, pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	game.handle_input(event, pos)


func _move(game: Minigame, pos: Vector2) -> void:
	game.handle_input(InputEventMouseMotion.new(), pos)


func test_taps_knead() -> void:
	var game := _game(Minigame.KIND_TAP)
	for i in 4:
		_press(game, Vector2(250, 150), true)
		_press(game, Vector2(250, 150), false)
	assert_eq(_units, 4)
	game.free()


func test_swipe_down_counts_each_stroke() -> void:
	var game := _game(Minigame.KIND_SWIPE_DOWN)
	_press(game, Vector2(250, 40), true)
	for y in range(40, 260, 10):
		_move(game, Vector2(250, y))
	assert_eq(_units, 3, "one long swipe of 220 px = 3 chops of 55 px")
	_press(game, Vector2(250, 260), false)
	_units = 0
	_press(game, Vector2(100, 200), true)
	for x in range(100, 400, 10):
		_move(game, Vector2(x, 200))
	assert_eq(_units, 0, "sideways doesn't chop")
	game.free()


func test_side_swipes_roll() -> void:
	var game := _game(Minigame.KIND_SWIPE_SIDE)
	_press(game, Vector2(100, 150), true)
	for x in range(100, 400, 10):
		_move(game, Vector2(x, 150))
	for x in range(400, 100, -10):
		_move(game, Vector2(x, 150))
	assert_true(_units >= 6, "back and forth rolls (%d)" % _units)
	game.free()


func test_circles_stir() -> void:
	var game := _game(Minigame.KIND_CIRCLE)
	var center := game.size * 0.5
	_press(game, center + Vector2(100, 0), true)
	for i in range(0, 72 * 3 + 1):
		var angle := TAU * i / 72.0
		_move(game, center + Vector2(cos(angle), sin(angle)) * 100.0)
	assert_eq(_units, 3, "three full circles")
	game.free()


func test_close_button() -> void:
	var game := _game(Minigame.KIND_TAP)
	var closed := [false]
	game.closed.connect(func(): closed[0] = true)
	_press(game, game.close_rect().get_center(), true)
	assert_true(closed[0])
	assert_eq(_units, 0, "closing isn't a knead")
	game.free()
