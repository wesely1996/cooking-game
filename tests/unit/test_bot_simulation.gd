extends TestCase
## Bots play real levels through the same intents players send. This proves
## every level can be finished with every player count, and prints numbers
## that help with balancing.


func _play(level_file: String, players: int, seed: int = 7) -> Shift:
	var shift := Shift.new(ContentDB.load_dir(), LevelDef.load_file("res://data/levels/" + level_file), players, seed)
	var bot := KitchenBot.new()
	KitchenBot.play(shift, bot)
	print("      %-40s %dp  served %2d  lost %2d  score %4d  stars %d  failed %s  (bot actions %d, rejected %d)" % [
		level_file, players, shift.stats.served, shift.stats.lost, shift.score,
		shift.outcome.get("stars", 0), shift.outcome.get("failed", false), bot.actions_done, bot.actions_failed])
	return shift


func test_two_players_make_a_pizza_together() -> void:
	# The flow from the design: P1 kneads the dough and chops tomatoes, P2 tops
	# the pizza with mozzarella and throws it back, P1 bakes it, P2 plates it.
	var db := ContentDB.load_dir()
	var shift := Shift.new(db, LevelDef.load_file("res://data/levels/italy_04_pizzeria.json"), 2, 1)
	shift.orders.orders.clear()
	shift.spawn_customer("pizza_margherita")
	var p1 := 0
	var p2 := 1
	var board := shift.kitchen.players[p1].stations_of("board")[0].index
	var bowl := shift.kitchen.players[p1].stations_of("bowl")[0].index
	var oven := shift.kitchen.players[p1].stations_of("oven")[0].index
	var p2_board := shift.kitchen.players[p2].stations_of("board")[0].index
	var steps := [
		{"type": "take", "player": p1, "ingredient": "flour", "station": bowl},
		{"type": "take", "player": p1, "ingredient": "water", "station": bowl},
	]
	for i in 8:
		steps.append({"type": "work", "player": p1, "station": bowl})
	steps.append({"type": "take", "player": p1, "ingredient": "tomato", "station": board})
	for i in 4:
		steps.append({"type": "work", "player": p1, "station": board})
	steps.append({"type": "throw", "player": p1, "station": bowl, "target": p2})  # dough lands on P2's counter 0
	steps.append({"type": "throw", "player": p1, "station": board, "target": p2})  # tomato on counter 1
	steps.append({"type": "move", "player": p2, "from": 1, "to": 0})
	steps.append({"type": "take", "player": p2, "ingredient": "mozzarella", "station": p2_board})
	for i in 3:
		steps.append({"type": "work", "player": p2, "station": p2_board})
	steps.append({"type": "move", "player": p2, "from": p2_board, "to": 0})
	steps.append({"type": "throw", "player": p2, "station": 0, "target": p1})
	steps.append({"type": "move", "player": p1, "from": 0, "to": oven})
	for step in steps:
		assert_ok(shift.do_intent(step), str(step))
	shift.tick(8.5)
	assert_eq(shift.kitchen.item_at(p1, oven).type, "whole_pizza")
	assert_ok(shift.do_intent({"type": "throw", "player": p1, "station": oven, "target": p2}))
	assert_ok(shift.do_intent({"type": "take", "player": p2, "ingredient": "plate", "station": 1}))
	assert_ok(shift.do_intent({"type": "move", "player": p2, "from": 0, "to": 1}))
	assert_eq(shift.kitchen.effective_id(shift.kitchen.item_at(p2, 1)), "pizza_margherita")
	assert_ok(shift.do_intent({"type": "serve", "player": p2, "station": 1}))
	assert_eq(shift.stats.served, 1)
	assert_eq(shift.stats.perfect, 1)


func test_prologue_teaches_new_dishes_before_the_clock() -> void:
	var db := ContentDB.load_dir()
	var shift := Shift.new(db, LevelDef.load_file("res://data/levels/italy_02_aperitivo.json"), 1, 1, ["bruschetta", "pasta_pomodoro"])
	assert_true(shift.in_prologue())
	assert_eq(shift.prologue, ["bruschetta"] as Array[String], "only dishes on this level's menu")
	assert_eq(shift.orders.orders.size(), 1)
	assert_true(shift.orders.orders[0].tutorial)
	shift.tick(30.0)
	assert_almost(shift.time, 0.0, 0.001, "the clock waits")
	assert_eq(shift.orders.orders.size(), 1, "no other customers yet")
	var bot := KitchenBot.new()
	var steps := 0
	while shift.in_prologue() and steps < 1200:
		bot.step(shift)
		shift.tick(0.1)
		steps += 1
	assert_false(shift.in_prologue(), "the bot made the bruschetta")
	assert_eq(shift.score, 0, "the tutorial dish scores nothing")
	assert_eq(shift.stats.served, 0)


func test_prologue_can_be_skipped() -> void:
	var db := ContentDB.load_dir()
	var shift := Shift.new(db, LevelDef.load_file("res://data/levels/italy_competition_gran_premio.json"), 1, 1, ["pizza_margherita"])
	assert_true(shift.rival == null, "the rival waits too")
	assert_ok(shift.do_intent({"type": "skip_prologue"}))
	assert_false(shift.in_prologue())
	assert_true(shift.rival != null)
	assert_false(shift.orders.orders.any(func(o): return o.get("tutorial", false)))
	assert_error(shift.do_intent({"type": "skip_prologue"}), "no_prologue")


func _level_files(type: String) -> Array[String]:
	var files: Array[String] = []
	for path in DataFiles.list_files(LevelDef.DEFAULT_LEVEL_DIR, ".json"):
		if LevelDef.load_file(path).type == type:
			files.append(path.get_file())
	return files


func test_bots_finish_every_normal_level_with_every_player_count() -> void:
	var files := _level_files(LevelDef.TYPE_NORMAL)
	assert_true(files.size() >= 4, "Italy's shifts")
	for file in files:
		for players in [1, 2, 3, 4]:
			var shift := _play(file, players)
			assert_true(shift.finished, "%s %dp finished" % [file, players])
			assert_true(shift.stats.served >= 2, "%s %dp served some dishes" % [file, players])


func test_bots_play_every_festival() -> void:
	for file in _level_files(LevelDef.TYPE_FESTIVAL):
		for players in [1, 2, 3, 4]:
			var shift := _play(file, players)
			assert_true(shift.finished)
			assert_true(shift.stats.served >= 5, "%s %dp served some of the crowd" % [file, players])


func test_bots_play_every_competition() -> void:
	for file in _level_files(LevelDef.TYPE_COMPETITION):
		for players in [1, 2, 3, 4]:
			var shift := _play(file, players)
			assert_true(shift.finished)
			assert_true(shift.stats.served >= 1, "%s %dp served the judges" % [file, players])


func test_bots_play_arcade() -> void:
	for file in _level_files(LevelDef.TYPE_ARCADE):
		var shift := _play(file, 2)
		assert_true(shift.finished, file + " eventually ends")
		assert_true(shift.stats.served >= 3)
