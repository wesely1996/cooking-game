extends TestCase


func _db() -> ContentDB:
	return ContentDB.load_dir()


func test_shipped_packs_are_valid() -> void:
	var db := _db()
	assert_empty(db.validate(), "content errors")
	assert_true(db.pack_ids.has("italian"))


func test_effective_id_of_assemblies() -> void:
	var db := _db()
	assert_eq(db.effective_id("tomato", []), "tomato")
	assert_eq(db.effective_id("pizza_base", ["sliced_mozzarella", "tomato_sauce"]), "raw_pizza_margherita")
	assert_eq(db.effective_id("pizza_base", ["tomato_sauce"]), "", "half-assembled pizza")


func test_combine_adds_part_to_base_either_way() -> void:
	var db := _db()
	var onto_base := db.combine("pizza_base", [], "tomato_sauce", [])
	assert_true(onto_base.ok)
	assert_eq(onto_base.keep, "target")
	assert_eq(onto_base.contents, ["tomato_sauce"])
	var base_onto_part := db.combine("tomato_sauce", [], "pizza_base", ["sliced_mozzarella"])
	assert_true(base_onto_part.ok)
	assert_eq(base_onto_part.keep, "source")
	assert_eq(base_onto_part.contents, ["sliced_mozzarella", "tomato_sauce"])


func test_combine_rejects_wrong_or_repeated_parts() -> void:
	var db := _db()
	assert_false(db.combine("pizza_base", [], "egg", []).ok, "egg on pizza")
	assert_false(db.combine("pizza_base", ["tomato_sauce"], "tomato_sauce", []).ok, "sauce twice")
	assert_false(db.combine("tomato", [], "garlic", []).ok, "no assembly")


func test_flour_makes_two_different_doughs() -> void:
	var db := _db()
	assert_eq(db.effective_id("flour", ["water"]), "pizza_dough_mix")
	assert_eq(db.effective_id("flour", ["egg"]), "pasta_dough_mix")
	assert_false(db.combine("flour", ["water"], "egg", []).ok, "can't mix both")


func test_process_lookup() -> void:
	var db := _db()
	assert_eq(db.process_for("tomato", "knife").get("output", ""), "chopped_tomato")
	assert_true(db.process_for("tomato", "oven").is_empty())
	assert_true(db.is_passive(db.processes["bake_pizza"]))
	assert_false(db.is_passive(db.processes["chop_tomato"]))


func test_requirements_of_pizza() -> void:
	var db := _db()
	assert_eq(db.raw_requirements("pizza_margherita"), ["flour", "mozzarella", "tomato", "water"])
	assert_eq(db.equipment_requirements("pizza_margherita"), ["knife", "mixing_bowl", "oven", "rolling_pin", "sauce_pot"])
	assert_true(db.nominal_seconds("pizza_margherita") > db.nominal_seconds("bruschetta"))
	assert_true(db.nominal_seconds("pizza_slice") > 0.0)


func test_validation_catches_broken_content() -> void:
	var db := _db()
	db.add_pack({
		"id": "broken",
		"items": {
			"mystery": {"kind": "intermediate"},
			"loop_a": {}, "loop_b": {},
			"cheap_dish": {"kind": "dish"},
		},
		"processes": [
			{"id": "a_to_b", "input": "loop_a", "equipment": "knife", "action": "chop", "work": 1, "output": "loop_b"},
			{"id": "b_to_a", "input": "loop_b", "equipment": "oven", "action": "bake", "cook_time": 2, "output": "loop_a"},
			{"id": "bad_tool", "input": "tomato", "equipment": "rolling_pin", "action": "roll", "cook_time": 2, "output": "cheap_dish"},
		],
	})
	var errors := "\n".join(db.validate())
	assert_true(errors.contains("'mystery' has no process"), "missing producer")
	assert_true(errors.contains("cycle"), "cycle")
	assert_true(errors.contains("dish 'cheap_dish' needs a price"), "dish price")
	assert_true(errors.contains("needs an appliance"), "passive on tool")


func test_three_cuisines_with_their_own_dishes() -> void:
	var db := ContentDB.load_dir()
	for pack in ["italian", "mexican", "japanese", "american", "spanish", "french"]:
		var dishes := db.items.values().filter(func(item): return item.kind == ContentDB.KIND_DISH and item.pack == pack)
		assert_true(dishes.size() >= 5, pack + " has at least 5 dishes")
	assert_eq(db.effective_id("tortilla", ["cooked_beef", "salsa"]), "beef_taco")
	assert_eq(db.effective_id("cooked_noodles", ["boiled_egg", "chopped_green_onion", "miso_broth"]), "miso_ramen")
	assert_eq(db.process_for("chicken", "comal").get("output", ""), "cooked_chicken", "same chicken, Mexican comal")
	assert_eq(db.process_for("chicken", "grill").get("output", ""), "grilled_chicken", "same chicken, Japanese grill")


func test_every_item_and_equipment_has_a_picture() -> void:
	var db := ContentDB.load_dir()
	for id in db.items:
		assert_true(ResourceLoader.exists("res://art/items/%s.svg" % id), "picture for " + id)
	for id in db.equipment:
		if db.equipment[id].kind != ContentDB.EQUIP_PASS:
			assert_true(ResourceLoader.exists("res://art/equipment/%s.svg" % id), "picture for " + id)
