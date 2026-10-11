extends TestCase

var db: ContentDB


func _kitchen(roles: Array) -> KitchenState:
	db = ContentDB.load_dir()
	return KitchenState.new(db, roles)


func _two_player_kitchen() -> KitchenState:
	return _kitchen([
		{"name": "Prep", "crates": ["tomato", "mozzarella"], "equipment": ["knife", "sauce_pot"], "slots": 3},
		{"name": "Oven", "crates": ["bread"], "equipment": ["oven", "serving_window"], "slots": 3},
	])


func test_roles_set_up_ownership() -> void:
	var k := _two_player_kitchen()
	assert_eq(k.players.size(), 2)
	assert_eq(k.players[0].slots.size(), 3)
	assert_true(k.players[0].tools.has("knife"))
	assert_true(k.players[0].appliances.has("sauce_pot"))
	assert_eq(k.pass_owner(), 1)
	assert_eq(k.owners_of_crate("tomato"), [0] as Array[int])


func test_take_only_from_own_crates() -> void:
	var k := _two_player_kitchen()
	assert_ok(k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"}))
	assert_eq(k.item_at(0, 0).type, "tomato")
	assert_error(k.do_intent({"type": "take", "player": 0, "ingredient": "bread"}), "not_owned")
	assert_error(k.do_intent({"type": "take", "player": 7, "ingredient": "tomato"}), "bad_player")


func test_counter_fills_up() -> void:
	var k := _two_player_kitchen()
	for i in 3:
		assert_ok(k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"}))
	assert_error(k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"}), "counter_full")


func test_chopping_takes_several_gestures() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	for i in 4:
		assert_ok(k.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "knife"}))
	assert_eq(k.item_at(0, 0).type, "tomato", "not chopped yet")
	assert_ok(k.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "knife"}))
	assert_eq(k.item_at(0, 0).type, "chopped_tomato")
	assert_error(k.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "knife"}), "no_process")
	assert_error(k.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "rolling_pin"}), "not_owned")


func test_paused_work_is_kept_when_food_moves() -> void:
	var k := _kitchen([
		{"name": "A", "crates": ["tomato"], "equipment": ["knife"], "slots": 3},
		{"name": "B", "crates": ["bread"], "equipment": ["knife", "serving_window"], "slots": 3},
	])
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	for i in 2:
		k.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "knife"})
	# Leave it half chopped, move it along the counter, throw it to a friend...
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": 0, "to": 2}))
	assert_eq(k.item_at(0, 2).work, 2.0)
	assert_ok(k.do_intent({"type": "throw", "player": 0, "slot": 2, "target": 1}))
	var item := k.item_at(1, 0)
	assert_eq(item.work, 2.0, "progress travels with the food")
	assert_eq(item.work_process, "chop_tomato")
	# ...who finishes the last three chops.
	for i in 3:
		assert_ok(k.do_intent({"type": "work", "player": 1, "slot": 0, "equipment": "knife"}))
	assert_eq(k.item_at(1, 0).type, "chopped_tomato")


func test_paused_appliance_work_is_kept() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	for i in 5:
		k.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "knife"})
	k.do_intent({"type": "insert", "player": 0, "slot": 0, "equipment": "sauce_pot"})
	k.do_intent({"type": "work_appliance", "player": 0, "equipment": "sauce_pot", "index": 0})
	k.tick(30.0)  # the chef wanders off to do something else
	var aslot: KitchenState.ApplianceSlot = k.players[0].appliances["sauce_pot"][0]
	assert_eq(aslot.progress, 1.0)
	assert_false(aslot.done)
	for i in 2:
		k.do_intent({"type": "work_appliance", "player": 0, "equipment": "sauce_pot", "index": 0})
	assert_true(aslot.done)


func test_work_amount_is_capped() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	assert_error(k.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "knife", "amount": 50}), "bad_amount")


func test_oven_cooks_then_burns() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 1, "ingredient": "bread"})
	assert_ok(k.do_intent({"type": "insert", "player": 1, "slot": 0, "equipment": "oven"}))
	assert_true(k.item_at(1, 0) == null, "bread left the counter")
	k.tick(3.9)
	var aslot: KitchenState.ApplianceSlot = k.players[1].appliances["oven"][0]
	assert_false(aslot.done)
	k.tick(0.2)
	assert_true(aslot.done)
	assert_eq(aslot.item.type, "toast")
	k.tick(8.0)
	assert_true(aslot.burnt)
	assert_eq(aslot.item.type, ContentDB.BURNT_ITEM)


func test_perfect_window() -> void:
	var k := _two_player_kitchen()
	for i in 2:
		k.do_intent({"type": "take", "player": 1, "ingredient": "bread"})
		k.do_intent({"type": "insert", "player": 1, "slot": 0, "equipment": "oven"})
	k.tick(4.5)
	assert_ok(k.do_intent({"type": "remove", "player": 1, "equipment": "oven", "index": 0}))
	assert_true(k.item_at(1, 0).perfect, "removed right away")
	k.tick(3.0)  # 3.5 s after ready, past the 3 s window
	assert_ok(k.do_intent({"type": "remove", "player": 1, "equipment": "oven", "index": 1}))
	assert_eq(k.item_at(1, 1).type, "toast")
	assert_false(k.item_at(1, 1).perfect, "removed late")


func test_appliance_only_takes_what_it_can_cook() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 0, "ingredient": "mozzarella"})
	assert_error(k.do_intent({"type": "insert", "player": 0, "slot": 0, "equipment": "sauce_pot"}), "no_process")
	assert_error(k.do_intent({"type": "insert", "player": 0, "slot": 0, "equipment": "oven"}), "not_owned")


func test_stirring_sauce_in_pot() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	for i in 5:
		k.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "knife"})
	assert_ok(k.do_intent({"type": "insert", "player": 0, "slot": 0, "equipment": "sauce_pot"}))
	for i in 3:
		assert_ok(k.do_intent({"type": "work_appliance", "player": 0, "equipment": "sauce_pot", "index": 0}))
	var aslot: KitchenState.ApplianceSlot = k.players[0].appliances["sauce_pot"][0]
	assert_true(aslot.done)
	assert_eq(aslot.item.type, "tomato_sauce")
	k.tick(60.0)
	assert_false(aslot.burnt, "manual results never burn")


func test_combine_builds_an_assembly() -> void:
	var k := _kitchen([{"crates": ["flour", "water", "egg"], "equipment": ["mixing_bowl", "serving_window"]}])
	k.do_intent({"type": "take", "player": 0, "ingredient": "flour"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "water"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "egg"})
	assert_ok(k.do_intent({"type": "combine", "player": 0, "from": 1, "to": 0}))
	assert_true(k.item_at(0, 1) == null, "water used up")
	assert_eq(k.effective_id(k.item_at(0, 0)), "pizza_dough_mix")
	assert_error(k.do_intent({"type": "combine", "player": 0, "from": 2, "to": 0}), "cannot_combine")


func test_combining_base_onto_part_keeps_target_slot() -> void:
	var k := _kitchen([{"crates": ["flour", "water"], "equipment": ["serving_window"]}])
	k.do_intent({"type": "take", "player": 0, "ingredient": "flour"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "water"})
	assert_ok(k.do_intent({"type": "combine", "player": 0, "from": 0, "to": 1}))
	assert_true(k.item_at(0, 0) == null)
	assert_eq(k.effective_id(k.item_at(0, 1)), "pizza_dough_mix")


func test_throw_lands_in_first_free_slot() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 1, "ingredient": "bread"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	assert_ok(k.do_intent({"type": "throw", "player": 0, "slot": 0, "target": 1}))
	assert_true(k.item_at(0, 0) == null)
	assert_eq(k.item_at(1, 1).type, "tomato")
	assert_error(k.do_intent({"type": "throw", "player": 1, "slot": 1, "target": 1}), "bad_target")


func test_cannot_throw_to_full_counter() -> void:
	var k := _two_player_kitchen()
	for i in 3:
		k.do_intent({"type": "take", "player": 1, "ingredient": "bread"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	assert_error(k.do_intent({"type": "throw", "player": 0, "slot": 0, "target": 1}), "target_full")
	assert_eq(k.item_at(0, 0).type, "tomato", "item stays")


func test_serve_goes_through_handler() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 1, "ingredient": "bread"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	assert_error(k.do_intent({"type": "serve", "player": 0, "slot": 0}), "not_owned")
	assert_error(k.do_intent({"type": "serve", "player": 1, "slot": 0}), "no_customers")
	var served := []
	k.serve_handler = func(_p: int, item: KitchenItem) -> Dictionary:
		served.append(item.type)
		return {"ok": true}
	assert_ok(k.do_intent({"type": "serve", "player": 1, "slot": 0}))
	assert_eq(served, ["bread"])
	assert_true(k.item_at(1, 0) == null)


func test_events_and_snapshot() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	k.do_intent({"type": "throw", "player": 0, "slot": 0, "target": 1})
	var types := k.drain_events().map(func(e): return e.type)
	assert_eq(types, ["item_added", "item_thrown"])
	assert_empty(k.drain_events())
	var snap := k.snapshot()
	assert_eq(snap.players[1].slots[0].type, "tomato")
	assert_eq(snap.players[1].serves, true)
	var restored := KitchenItem.from_dict(snap.players[1].slots[0])
	assert_eq(restored.type, "tomato")
