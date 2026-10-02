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


func test_three_players_make_a_pizza_together() -> void:
	# The flow from the design doc: Dough -> Sauce -> Oven & Pass.
	var db := ContentDB.load_dir()
	var shift := Shift.new(db, LevelDef.load_file("res://data/levels/italy_01_pizza_night.json"), 3, 1)
	shift.orders.orders.clear()
	shift.spawn_customer("pizza_margherita")
	var dough := 0
	var sauce := 1
	var oven := 2
	var steps := [
		{"type": "take", "player": dough, "ingredient": "flour"},
		{"type": "take", "player": dough, "ingredient": "water"},
		{"type": "combine", "player": dough, "from": 1, "to": 0},
	]
	for i in 12:
		steps.append({"type": "work", "player": dough, "slot": 0, "equipment": "mixing_bowl"})
	for i in 3:
		steps.append({"type": "work", "player": dough, "slot": 0, "equipment": "rolling_pin"})
	steps.append({"type": "throw", "player": dough, "slot": 0, "target": sauce})
	steps.append({"type": "take", "player": sauce, "ingredient": "tomato"})
	for i in 5:
		steps.append({"type": "work", "player": sauce, "slot": 1, "equipment": "knife"})
	steps.append({"type": "insert", "player": sauce, "slot": 1, "equipment": "sauce_pot"})
	for i in 3:
		steps.append({"type": "work_appliance", "player": sauce, "equipment": "sauce_pot", "index": 0})
	steps.append({"type": "remove", "player": sauce, "equipment": "sauce_pot", "index": 0})
	steps.append({"type": "combine", "player": sauce, "from": 1, "to": 0})
	steps.append({"type": "throw", "player": sauce, "slot": 0, "target": oven})
	steps.append({"type": "take", "player": oven, "ingredient": "mozzarella"})
	for i in 4:
		steps.append({"type": "work", "player": oven, "slot": 1, "equipment": "knife"})
	steps.append({"type": "combine", "player": oven, "from": 1, "to": 0})
	steps.append({"type": "insert", "player": oven, "slot": 0, "equipment": "oven"})
	for step in steps:
		assert_ok(shift.do_intent(step), str(step))
	shift.tick(8.5)
	assert_ok(shift.do_intent({"type": "remove", "player": oven, "equipment": "oven", "index": 0}))
	assert_eq(shift.kitchen.item_at(oven, 0).type, "pizza_margherita")
	assert_ok(shift.do_intent({"type": "serve", "player": oven, "slot": 0}))
	assert_eq(shift.stats.served, 1)
	assert_eq(shift.stats.perfect, 1)


func _level_files(type: String) -> Array[String]:
	var files: Array[String] = []
	for path in DataFiles.list_files(LevelDef.DEFAULT_LEVEL_DIR, ".json"):
		if LevelDef.load_file(path).type == type:
			files.append(path.get_file())
	return files


func test_bots_finish_every_normal_level_with_every_player_count() -> void:
	var files := _level_files(LevelDef.TYPE_NORMAL)
	assert_true(files.size() >= 12, "three regions of shifts")
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
