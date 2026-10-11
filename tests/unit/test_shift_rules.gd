extends TestCase

var db: ContentDB


func _level(file: String) -> LevelDef:
	db = ContentDB.load_dir()
	return LevelDef.load_file("res://data/levels/" + file)


# Puts a ready-made item on the player's first counter (station 0).
func _place(shift: Shift, player: int, type: String, contents: Array = [], perfect: bool = false) -> void:
	var item := KitchenItem.new(1000 + shift.stats.served, type)
	item.contents = contents
	item.perfect = perfect
	shift.kitchen.players[player].stations[0].contents = [item]


func _run_idle(shift: Shift, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not shift.finished:
		shift.tick(0.5)
		t += 0.5


func test_normal_level_spawns_customers_and_ends_without_failing() -> void:
	var shift := Shift.new(ContentDB.load_dir(), LevelDef.load_file("res://data/levels/italy_01_caprese_corner.json"), 2, 1)
	shift.tick(2.5)
	assert_eq(shift.orders.active_count(), 1, "first customer arrives")
	_run_idle(shift, 1000.0)
	assert_true(shift.finished)
	assert_false(shift.outcome.failed, "normal levels can't be failed")
	assert_eq(shift.outcome.stars, 0)
	assert_true(shift.stats.lost > 0)
	assert_eq(shift.score, 0, "score never goes below zero")


func test_patience_scales_with_player_count() -> void:
	var level := _level("italy_01_caprese_corner.json")
	var solo := Shift.new(db, level, 1, 1)
	var four := Shift.new(db, level, 4, 1)
	var solo_order := solo.spawn_customer("pizza_margherita")
	var four_order := four.spawn_customer("pizza_margherita")
	assert_almost(solo_order.max_patience, 70.0 * 1.7)
	assert_almost(four_order.max_patience, 70.0)


func test_serving_scores_price_tip_and_combo() -> void:
	var level := _level("italy_02_aperitivo.json")
	var shift := Shift.new(db, level, 1, 1)
	shift.orders.orders.clear()
	shift.spawn_customer("bruschetta")
	shift.spawn_customer("bruschetta")
	_place(shift, 0, "plate", ["basil", "chopped_tomato", "toast"])
	assert_ok(shift.do_intent({"type": "serve", "player": 0, "station": 0}))
	assert_eq(shift.score, 30, "20 + full 50% tip")
	_place(shift, 0, "plate", ["basil", "chopped_tomato", "toast"], true)
	assert_ok(shift.do_intent({"type": "serve", "player": 0, "station": 0}))
	assert_eq(shift.score, 30 + 39, "(20 + 10 + 5 perfect) * 1.1 combo")
	assert_eq(shift.stats.perfect, 1)


func test_wrong_dish_bounces_back() -> void:
	var level := _level("italy_01_caprese_corner.json")
	var shift := Shift.new(db, level, 1, 1)
	shift.spawn_customer("pizza_margherita")
	_place(shift, 0, "plate", ["basil", "chopped_tomato", "sliced_mozzarella"])
	assert_error(shift.do_intent({"type": "serve", "player": 0, "station": 0}), "no_matching_order")
	assert_eq(shift.kitchen.effective_id(shift.kitchen.item_at(0, 0)), "caprese_salad", "the caprese stays")


func test_festival_fails_when_the_crowd_turns() -> void:
	var shift := Shift.new(ContentDB.load_dir(), LevelDef.load_file("res://data/levels/italy_festival_sagra_in_piazza.json"), 3, 1)
	assert_true(shift.rules is FestivalRules)
	_run_idle(shift, 2000.0)
	assert_true(shift.finished)
	assert_true(shift.outcome.failed, "nobody served anything")
	assert_eq(shift.outcome.stars, 0)
	assert_almost(shift.outcome.mood, 0.0)


func test_festival_waves_and_mood() -> void:
	var level := _level("italy_festival_sagra_in_piazza.json")
	var shift := Shift.new(db, level, 1, 1)
	var rules: FestivalRules = shift.rules
	assert_almost(rules.mood, 60.0)
	# Serve every customer instantly: the festival is cleared with a full mood.
	while not shift.finished and shift.time < 2000.0:
		for order in shift.orders.orders.duplicate():
			if order.dish == "caprese_salad":
				_place(shift, 0, "plate", ["basil", "chopped_tomato", "sliced_mozzarella"])
			else:
				_place(shift, 0, "plate", ["basil", "chopped_tomato", "toast"])
			assert_ok(shift.do_intent({"type": "serve", "player": 0, "station": 0}))
		shift.tick(0.5)
	assert_true(shift.finished)
	assert_false(shift.outcome.failed)
	assert_eq(shift.outcome.waves_cleared, 3)
	assert_eq(shift.outcome.stars, 3)


func test_competition_lost_when_rival_finishes_first() -> void:
	var shift := Shift.new(ContentDB.load_dir(), LevelDef.load_file("res://data/levels/italy_competition_gran_premio.json"), 2, 1)
	assert_true(shift.rival != null)
	assert_eq(shift.orders.active_count(), 2, "judges reveal two dishes at a time")
	assert_eq(shift.orders.orders[0].max_patience, -1.0, "judges never leave")
	_run_idle(shift, 1000.0)
	assert_true(shift.finished)
	assert_true(shift.rival.finished)
	assert_true(shift.outcome.failed)


func test_competition_won_by_finishing_first() -> void:
	var level := _level("italy_competition_gran_premio.json")
	var shift := Shift.new(db, level, 4, 1)
	var dishes := {
		"pizza_margherita": ["whole_pizza"],
		"bruschetta": ["basil", "chopped_tomato", "toast"],
		"pasta_pomodoro": ["cooked_pasta", "tomato_sauce"],
	}
	var server := shift.kitchen.pass_owner()
	while not shift.finished:
		var order: Dictionary = shift.orders.orders[0]
		_place(shift, server, "plate", dishes[order.dish], true)
		assert_ok(shift.do_intent({"type": "serve", "player": server, "station": 0}))
		shift.tick(1.0)
	assert_false(shift.outcome.failed)
	assert_eq(shift.outcome.stars, 3, "fast and perfect")
	assert_eq(shift.outcome.dishes_done, 7)


func test_arcade_ends_after_three_strikes() -> void:
	var shift := Shift.new(ContentDB.load_dir(), LevelDef.load_file("res://data/levels/arcade_italian.json"), 1, 1)
	_run_idle(shift, 5000.0)
	assert_true(shift.finished)
	assert_eq(shift.stats.lost, 3)
	assert_eq(shift.outcome.type, "arcade")
