extends TestCase


func _rival(personality: String, speed: Variant, seed: int = 1) -> RivalChef:
	var db := ContentDB.load_dir()
	var dishes := ["pizza_margherita", "bruschetta", "pasta_pomodoro", "pizza_margherita"]
	return RivalChef.new(db, dishes, {"name": "Test", "personality": personality, "speed": speed}, 2, seed)


func _time_to_finish(rival: RivalChef) -> float:
	var t := 0.0
	while not rival.finished and t < 10000.0:
		rival.tick(0.5)
		t += 0.5
	return t


func test_steady_rival_takes_nominal_time() -> void:
	var db := ContentDB.load_dir()
	var rival := _rival("steady", 1.0)
	var expected := 0.0
	for dish in rival.dishes:
		expected += db.nominal_seconds(dish)
	assert_almost(_time_to_finish(rival), expected, 0.6)
	assert_eq(rival.done_count, 4)
	assert_eq(rival.perfect_count, 4)


func test_speed_can_depend_on_player_count() -> void:
	var slow := _rival("steady", {"1": 1.0, "2": 2.0})
	var fast := _rival("steady", 1.0)
	assert_almost(slow.speed, 2.0)
	assert_true(_time_to_finish(slow) < _time_to_finish(fast))


func test_show_off_is_fast_but_sometimes_burns() -> void:
	var burns := 0
	for seed in 20:
		var rival := _rival("show_off", 1.0, seed)
		_time_to_finish(rival)
		burns += rival.done_count - rival.perfect_count
	assert_true(burns > 0, "burnt at least once in 20 runs")
	assert_true(burns < 40, "doesn't burn everything")


func test_rivals_are_deterministic_per_seed() -> void:
	var a := _rival("chaotic", 1.0, 42)
	var b := _rival("chaotic", 1.0, 42)
	assert_almost(_time_to_finish(a), _time_to_finish(b))


func test_events() -> void:
	var rival := _rival("steady", 100.0)
	rival.tick(100.0)
	var types := rival.drain_events().map(func(e): return e.type)
	assert_true(types.has("rival_dish_done"))
	assert_eq(types.back(), "rival_finished")
