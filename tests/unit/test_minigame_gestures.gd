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


func test_chopping_is_tapping() -> void:
	# The swipe-down mini-game is gone: chop, slice and grate are taps.
	for action in ["chop", "slice", "grate"]:
		assert_eq(Minigame.ACTION_KINDS[action], Minigame.KIND_TAP, action)


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


func test_every_action_has_a_gesture_and_a_verb() -> void:
	var db := ContentDB.load_dir()
	for recipe in db.recipes.values():
		assert_true(RecipeText.VERBS.has(recipe.action), "recipe book verb for '%s'" % recipe.action)
		if not db.is_cook_recipe(recipe):
			assert_true(Minigame.ACTION_KINDS.has(recipe.action), "mini-game gesture for '%s'" % recipe.action)
			assert_true(RecipeText.GESTURES.has(recipe.action), "recipe book gesture for '%s'" % recipe.action)
