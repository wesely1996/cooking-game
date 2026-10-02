extends TestCase


func test_recipe_steps_come_in_a_working_order() -> void:
	var db := ContentDB.load_dir()
	for dish in db.items.keys().filter(func(id): return db.is_dish(id)):
		var made := {}
		for raw in db.raw_requirements(dish):
			made[raw] = true
		var steps := db.recipe_steps(dish)
		assert_true(not steps.is_empty(), dish + " has steps")
		for step in steps:
			var needs: Array = [step.input] if step.kind == "process" else [step.base] + step.parts
			for need in needs:
				assert_true(made.has(need), "%s: '%s' is made before it is used" % [dish, need])
			made[step.output] = true
		assert_eq(steps.back().output, dish, dish + " ends with the dish")


func test_pizza_instructions() -> void:
	var db := ContentDB.load_dir()
	var lines := RecipeText.instructions(db, "pizza_margherita")
	assert_eq(lines.size(), 9, "8 steps + serve")
	assert_eq(lines[0], "Put the WATER on the FLOUR → Pizza dough mix")
	assert_true(lines[1].begins_with("Knead the PIZZA DOUGH MIX with the MIXING BOWL (tap ×12)"))
	assert_true(lines.any(func(l): return l.begins_with("Put the CHOPPED TOMATO in the SAUCE POT and stir it (draw circles ×3)")))
	assert_true(lines[7].begins_with("Bake the RAW PIZZA MARGHERITA in the OVEN for 8 s"))
	assert_eq(lines.back(), "Serve the PIZZA MARGHERITA at the SERVING WINDOW!")


func test_discovered_dishes_are_saved() -> void:
	var progress := Progression.load_map()
	assert_true(progress.discover("pizza_margherita"), "first time")
	assert_false(progress.discover("pizza_margherita"), "second time")
	var copy := Progression.load_map()
	copy.load_save(JSON.parse_string(JSON.stringify(progress.to_dict())))
	assert_true(copy.is_discovered("pizza_margherita"))
	assert_false(copy.is_discovered("bruschetta"))


func test_hint_bot_only_plans_for_matching_orders() -> void:
	var db := ContentDB.load_dir()
	var shift := Shift.new(db, LevelDef.load_file("res://data/levels/italy_02_aperitivo.json"), 1, 1)
	shift.orders.orders.clear()
	shift.spawn_customer("pizza_margherita")
	var bot := KitchenBot.new()
	bot.order_filter = func(order): return order.dish != "pizza_margherita"
	assert_empty(bot.plan(shift), "known dish: no hints")
	shift.spawn_customer("bruschetta")
	var plan := bot.plan(shift)
	assert_true(not plan.is_empty())
	assert_eq(plan[0].ingredient, "bread", "bruschetta starts with bread")


func test_star_thresholds_rise_with_levels_and_players() -> void:
	var levels := {}
	for level in LevelDef.load_dir():
		levels[level.id] = level
	assert_true(int(levels["italy_01"].value("stars", 1)[2]) >= 200, "solo Pizza Night needs 200+ for 3 stars")
	for region in Progression.load_map().regions:
		var story: Array = region.levels.map(func(e): return e.id).filter(func(id): return levels[id].type == LevelDef.TYPE_NORMAL)
		assert_eq(story.size(), 4, region.id + " has four shifts")
		for n in [1, 2, 3, 4]:
			var previous := 0
			for id in story:
				var stars: Array = levels[id].value("stars", n)
				assert_true(stars[0] < stars[1] and stars[1] < stars[2], "%s %dp thresholds go up" % [id, n])
				assert_true(int(stars[2]) > previous, "%s %dp is harder than the level before" % [id, n])
				previous = int(stars[2])
		for id in story:
			for n in [2, 3, 4]:
				assert_true(int(levels[id].value("stars", n)[2]) > int(levels[id].value("stars", n - 1)[2]), "%s: more players need more points" % id)
