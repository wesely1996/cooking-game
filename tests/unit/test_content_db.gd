extends TestCase


func _db() -> ContentDB:
	return ContentDB.load_dir()


func test_shipped_packs_are_valid() -> void:
	var db := _db()
	assert_empty(db.validate(), "content errors")
	assert_true(db.pack_ids.has("italian"))
	assert_true(db.pack_ids.has("common"))


func test_plates_make_dishes_in_any_order() -> void:
	var db := _db()
	assert_eq(db.effective_id("tomato", []), "tomato")
	assert_eq(db.effective_id("plate", ["basil", "chopped_tomato", "sliced_mozzarella"]), "caprese_salad")
	assert_eq(db.effective_id("plate", ["basil", "chopped_tomato"]), "", "half a caprese (or bruschetta)")
	var food_onto_plate := db.combine("plate", [], "whole_pizza", [])
	assert_true(food_onto_plate.ok)
	assert_eq(food_onto_plate.keep, "target")
	var plate_onto_food := db.combine("tomato_sauce", [], "plate", ["cooked_pasta"])
	assert_true(plate_onto_food.ok)
	assert_eq(plate_onto_food.keep, "source", "the plate stays the base")
	assert_eq(plate_onto_food.contents, ["cooked_pasta", "tomato_sauce"])


func test_combine_rejects_wrong_or_repeated_parts() -> void:
	var db := _db()
	assert_false(db.combine("plate", [], "flour", []).ok, "flour isn't on any plate")
	assert_false(db.combine("plate", ["basil"], "basil", []).ok, "basil twice")
	assert_false(db.combine("plate", ["cooked_pasta"], "basil", []).ok, "no dish has pasta and basil")


func test_dough_works_like_a_plate() -> void:
	var db := _db()
	assert_eq(db.effective_id("dough", ["chopped_tomato", "sliced_mozzarella"]), "raw_pizza_margherita")
	assert_true(db.combine("dough", [], "chopped_tomato", []).ok)


func test_contents_decide_the_recipe() -> void:
	var db := _db()
	assert_eq(db.recipe_for("bowl", ["water", "flour"]).get("output", ""), "dough", "order doesn't matter")
	assert_true(db.recipe_for("bowl", ["flour"]).is_empty(), "flour alone isn't dough yet")
	assert_eq(db.recipe_for("pot", ["fresh_pasta"]).get("output", ""), "cooked_pasta")
	assert_eq(db.recipe_for("pan", ["chopped_tomato"]).get("output", ""), "tomato_sauce")
	assert_eq(db.recipe_for("board", ["tomato"]).get("output", ""), "chopped_tomato")
	assert_true(db.is_cook_recipe(db.recipe_for("pot", ["fresh_pasta"])))
	assert_false(db.is_cook_recipe(db.recipe_for("board", ["tomato"])))


func test_stations_only_take_what_can_become_a_recipe() -> void:
	var db := _db()
	assert_true(db.accepts("bowl", [], "flour"))
	assert_true(db.accepts("bowl", ["flour"], "water"))
	assert_false(db.accepts("bowl", ["flour"], "flour"), "two flours make nothing")
	assert_false(db.accepts("pot", [], "tomato"), "a raw tomato can't go in the pot")
	assert_true(db.accepts("board", [], "plate"), "boards hold anything")
	assert_false(db.accepts("board", ["tomato"], "basil"), "one thing per board")
	assert_true(db.accepts("counter", [], "flour"))
	assert_false(db.accepts("counter", ["flour"], "water"))
	assert_false(db.accepts("serving_window", [], "caprese_salad"))


func test_requirements_of_pizza() -> void:
	var db := _db()
	assert_eq(db.raw_requirements("pizza_margherita"), ["flour", "mozzarella", "plate", "tomato", "water"])
	assert_eq(db.station_requirements("pizza_margherita"), ["board", "bowl", "oven"])
	assert_eq(db.station_requirements("caprese_salad"), ["board"])
	assert_true(db.nominal_seconds("pizza_margherita") > db.nominal_seconds("caprese_salad"))
	assert_almost(db.longest_cook("pizza_margherita"), 8.0)


func test_validation_catches_broken_content() -> void:
	var db := _db()
	db.add_pack({
		"id": "broken",
		"items": {
			"mystery": {"kind": "intermediate"},
			"loop_a": {}, "loop_b": {},
			"cheap_dish": {"kind": "dish"},
		},
		"recipes": [
			{"id": "a_to_b", "station": "board", "inputs": ["loop_a"], "action": "chop", "work": 1, "output": "loop_b"},
			{"id": "b_to_a", "station": "oven", "inputs": ["loop_b"], "action": "bake", "cook_time": 2, "output": "loop_a"},
			{"id": "slow_pot", "station": "pot", "inputs": ["tomato"], "action": "boil", "output": "cheap_dish"},
			{"id": "on_counter", "station": "counter", "inputs": ["basil"], "action": "chop", "work": 1, "output": "mystery"},
			{"id": "same_as_chop", "station": "board", "inputs": ["tomato"], "action": "chop", "work": 1, "output": "mystery"},
		],
	})
	var errors := "\n".join(db.validate())
	assert_true(errors.contains("cycle"), "cycle")
	assert_true(errors.contains("dish 'cheap_dish' needs a price"), "dish price")
	assert_true(errors.contains("recipe 'slow_pot': needs a cook_time"), "cook without time")
	assert_true(errors.contains("the 'counter' can't cook"), "counters do nothing")
	assert_true(errors.contains("two recipes for"), "same inputs twice")


func test_italy_is_the_template() -> void:
	var db := _db()
	var dishes := db.items.values().filter(func(item): return item.kind == ContentDB.KIND_DISH and item.pack == "italian")
	assert_eq(dishes.size(), 4, "caprese, bruschetta, pasta and pizza")
	for dish in dishes:
		var steps := db.recipe_steps(dish.id).size()
		assert_true(steps >= 2 and steps <= 6, "%s takes a few steps (%d)" % [dish.id, steps])


func test_every_item_and_station_has_a_picture() -> void:
	var db := ContentDB.load_dir()
	for id in db.items:
		assert_true(ResourceLoader.exists("res://art/items/%s.svg" % id), "picture for " + id)
	for id in db.stations:
		if not db.station_kind(id) in [ContentDB.STATION_PASS, ContentDB.STATION_COUNTER]:
			assert_true(ResourceLoader.exists("res://art/equipment/%s.svg" % id), "picture for " + id)
