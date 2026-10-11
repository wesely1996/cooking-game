extends TestCase

var db: ContentDB


func _kitchen(roles: Array) -> KitchenState:
	db = ContentDB.load_dir()
	return KitchenState.new(db, roles)


# Station order follows the role: counters 0-2, then the rest.
func _two_player_kitchen() -> KitchenState:
	return _kitchen([
		{"name": "Prep", "crates": ["tomato", "flour", "water"], "stations": {"counter": 3, "board": 1, "bowl": 1, "pan": 1}},
		{"name": "Pass", "crates": ["plate", "basil", "mozzarella"], "stations": {"counter": 3, "board": 1, "serving_window": 1}},
	])


func _find(k: KitchenState, player: int, type: String) -> int:
	return k.players[player].stations_of(type)[0].index


func test_roles_set_up_stations() -> void:
	var k := _two_player_kitchen()
	assert_eq(k.players.size(), 2)
	assert_eq(k.players[0].stations.size(), 6)
	assert_eq(k.players[0].stations[3].type, "board")
	assert_true(k.players[0].has_station("pan"))
	assert_eq(k.pass_owner(), 1)
	assert_eq(k.owners_of_crate("tomato"), [0] as Array[int])
	assert_eq(k.owners_of_station("board"), [0, 1] as Array[int])


func test_take_goes_to_a_counter_or_a_chosen_station() -> void:
	var k := _two_player_kitchen()
	assert_ok(k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"}))
	assert_eq(k.item_at(0, 0).type, "tomato")
	var board := _find(k, 0, "board")
	assert_ok(k.do_intent({"type": "take", "player": 0, "ingredient": "tomato", "station": board}))
	assert_eq(k.item_at(0, board).type, "tomato")
	assert_error(k.do_intent({"type": "take", "player": 0, "ingredient": "tomato", "station": _find(k, 0, "pan")}), "cannot_place",
		"a raw tomato can't go in the pan")
	assert_error(k.do_intent({"type": "take", "player": 0, "ingredient": "basil"}), "not_owned")
	assert_error(k.do_intent({"type": "take", "player": 7, "ingredient": "tomato"}), "bad_player")


func test_counters_fill_up() -> void:
	var k := _two_player_kitchen()
	for i in 3:
		assert_ok(k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"}))
	assert_error(k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"}), "counter_full")


func test_chopping_on_the_board() -> void:
	var k := _two_player_kitchen()
	var board := _find(k, 0, "board")
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	assert_error(k.do_intent({"type": "work", "player": 0, "station": 0}), "no_recipe", "no chopping on the counter")
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": 0, "to": board}))
	for i in 3:
		assert_ok(k.do_intent({"type": "work", "player": 0, "station": board}))
	assert_eq(k.item_at(0, board).type, "tomato", "not chopped yet")
	assert_ok(k.do_intent({"type": "work", "player": 0, "station": board}))
	assert_eq(k.item_at(0, board).type, "chopped_tomato")
	assert_error(k.do_intent({"type": "work", "player": 0, "station": board}), "no_recipe")
	assert_error(k.do_intent({"type": "work", "player": 0, "station": board, "amount": 50}), "no_recipe")


func test_work_amount_is_capped() -> void:
	var k := _two_player_kitchen()
	var board := _find(k, 0, "board")
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato", "station": board})
	assert_error(k.do_intent({"type": "work", "player": 0, "station": board, "amount": 50}), "bad_amount")


func test_half_chopped_food_keeps_its_progress() -> void:
	var k := _two_player_kitchen()
	var board := _find(k, 0, "board")
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato", "station": board})
	for i in 2:
		k.do_intent({"type": "work", "player": 0, "station": board})
	# Off the board, thrown to a friend, onto their board: two chops to go.
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": board, "to": 1}))
	assert_eq(k.item_at(0, 1).work, 2.0)
	assert_ok(k.do_intent({"type": "throw", "player": 0, "station": 1, "target": 1}))
	var their_board := _find(k, 1, "board")
	assert_ok(k.do_intent({"type": "move", "player": 1, "from": 0, "to": their_board}))
	assert_almost(k.station(1, their_board).progress, 2.0)
	for i in 2:
		k.do_intent({"type": "work", "player": 1, "station": their_board})
	assert_eq(k.item_at(1, their_board).type, "chopped_tomato")


func test_mixing_bowl_takes_several_things() -> void:
	var k := _two_player_kitchen()
	var bowl := _find(k, 0, "bowl")
	assert_ok(k.do_intent({"type": "take", "player": 0, "ingredient": "flour", "station": bowl}))
	assert_error(k.do_intent({"type": "take", "player": 0, "ingredient": "flour", "station": bowl}), "cannot_combine",
		"two flours make nothing")
	assert_error(k.do_intent({"type": "work", "player": 0, "station": bowl}), "no_recipe", "not dough yet")
	assert_ok(k.do_intent({"type": "take", "player": 0, "ingredient": "water", "station": bowl}))
	assert_error(k.do_intent({"type": "move", "player": 0, "from": bowl, "to": 0}), "cannot_take", "can't pick up half a dough")
	for i in 8:
		assert_ok(k.do_intent({"type": "work", "player": 0, "station": bowl}))
	assert_eq(k.item_at(0, bowl).type, "dough")


func test_pan_cooks_then_burns() -> void:
	var k := _two_player_kitchen()
	var board := _find(k, 0, "board")
	var pan := _find(k, 0, "pan")
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato", "station": board})
	for i in 4:
		k.do_intent({"type": "work", "player": 0, "station": board})
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": board, "to": pan}))
	var st := k.station(0, pan)
	assert_eq(st.recipe.id, "cook_sauce")
	k.tick(4.0)
	assert_false(st.done)
	k.tick(1.5)
	assert_true(st.done)
	assert_eq(k.item_at(0, pan).type, "tomato_sauce")
	k.tick(10.0)
	assert_true(st.burnt)
	assert_eq(st.contents[0].type, "burnt_food")
	assert_error(k.do_intent({"type": "move", "player": 0, "from": pan, "to": 0}), "burnt", "burnt food only goes in the bin")
	assert_ok(k.do_intent({"type": "trash", "player": 0, "station": pan}))
	assert_true(st.is_empty())
	assert_false(st.burnt)


func test_perfect_window_and_plating_from_the_pan() -> void:
	var k := _kitchen([{"crates": ["tomato", "plate"], "stations": {"counter": 3, "board": 1, "pan": 1, "serving_window": 1}}])
	var board := _find(k, 0, "board")
	var pan := _find(k, 0, "pan")
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato", "station": board})
	for i in 4:
		k.do_intent({"type": "work", "player": 0, "station": board})
	k.do_intent({"type": "move", "player": 0, "from": board, "to": pan})
	k.do_intent({"type": "take", "player": 0, "ingredient": "plate"})
	k.tick(6.0)
	# Drag the pan onto the plate: the sauce moves, the pan stays.
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": pan, "to": 0}))
	assert_true(k.station(0, pan).is_empty())
	var plate := k.item_at(0, 0)
	assert_eq(plate.type, "plate")
	assert_eq(plate.contents, ["tomato_sauce"])
	assert_true(plate.perfect, "taken out in the perfect window")


func test_plate_dropped_on_the_pot_stays_where_it_was() -> void:
	var k := _kitchen([{"crates": ["tomato", "plate"], "stations": {"counter": 3, "board": 1, "pan": 1, "serving_window": 1}}])
	var board := _find(k, 0, "board")
	var pan := _find(k, 0, "pan")
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato", "station": board})
	for i in 4:
		k.do_intent({"type": "work", "player": 0, "station": board})
	k.do_intent({"type": "move", "player": 0, "from": board, "to": pan})
	k.tick(5.5)
	k.do_intent({"type": "take", "player": 0, "ingredient": "plate"})
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": 0, "to": pan}))
	assert_true(k.station(0, pan).is_empty(), "the sauce jumped onto the plate")
	assert_eq(k.item_at(0, 0).contents, ["tomato_sauce"])


func test_contents_change_restarts_cooking() -> void:
	var k := _kitchen([{"crates": ["flour", "water"], "stations": {"counter": 3, "bowl": 1, "pasta_machine": 1, "pot": 2}}])
	var bowl := _find(k, 0, "bowl")
	var machine := _find(k, 0, "pasta_machine")
	var pot := _find(k, 0, "pot")
	k.do_intent({"type": "take", "player": 0, "ingredient": "flour", "station": bowl})
	k.do_intent({"type": "take", "player": 0, "ingredient": "water", "station": bowl})
	for i in 8:
		k.do_intent({"type": "work", "player": 0, "station": bowl})
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": bowl, "to": machine}))
	for i in 3:
		k.do_intent({"type": "work", "player": 0, "station": machine})
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": machine, "to": pot}))
	k.tick(3.0)
	assert_almost(k.station(0, pot).progress, 3.0)
	# Taking it out and putting it back starts again.
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": pot, "to": 0}))
	assert_ok(k.do_intent({"type": "move", "player": 0, "from": 0, "to": pot + 1}))
	assert_almost(k.station(0, pot + 1).progress, 0.0)


func test_throw_lands_on_the_first_free_counter() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 1, "ingredient": "basil"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	assert_ok(k.do_intent({"type": "throw", "player": 0, "station": 0, "target": 1}))
	assert_true(k.item_at(0, 0) == null)
	assert_eq(k.item_at(1, 1).type, "tomato")
	assert_error(k.do_intent({"type": "throw", "player": 1, "station": 1, "target": 1}), "bad_target")


func test_cannot_throw_to_a_full_kitchen() -> void:
	var k := _two_player_kitchen()
	for i in 3:
		k.do_intent({"type": "take", "player": 1, "ingredient": "basil"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	assert_error(k.do_intent({"type": "throw", "player": 0, "station": 0, "target": 1}), "target_full")
	assert_eq(k.item_at(0, 0).type, "tomato", "item stays")


func test_serve_goes_through_handler() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 1, "ingredient": "plate"})
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	assert_error(k.do_intent({"type": "serve", "player": 0, "station": 0}), "not_owned")
	assert_error(k.do_intent({"type": "serve", "player": 1, "station": 0}), "no_customers")
	var served := []
	k.serve_handler = func(_p: int, item: KitchenItem) -> Dictionary:
		served.append(item.type)
		return {"ok": true}
	assert_ok(k.do_intent({"type": "serve", "player": 1, "station": 0}))
	assert_eq(served, ["plate"])
	assert_true(k.item_at(1, 0) == null)


func test_events_and_snapshot() -> void:
	var k := _two_player_kitchen()
	k.do_intent({"type": "take", "player": 0, "ingredient": "tomato"})
	k.do_intent({"type": "throw", "player": 0, "station": 0, "target": 1})
	var types := k.drain_events().map(func(e): return e.type)
	assert_eq(types, ["item_added", "item_thrown"])
	assert_empty(k.drain_events())
	var bowl := _find(k, 0, "bowl")
	k.do_intent({"type": "take", "player": 0, "ingredient": "flour", "station": bowl})
	k.do_intent({"type": "take", "player": 0, "ingredient": "water", "station": bowl})
	k.do_intent({"type": "work", "player": 0, "station": bowl})
	var snap := k.snapshot()
	assert_eq(snap.players[1].stations[0].contents[0].type, "tomato")
	assert_eq(snap.players[1].serves, true)
	var mirror := KitchenState.new(db, [
		{"name": "Prep", "crates": ["tomato", "flour", "water"], "stations": {"counter": 3, "board": 1, "bowl": 1, "pan": 1}},
		{"name": "Pass", "crates": ["plate", "basil", "mozzarella"], "stations": {"counter": 3, "board": 1, "serving_window": 1}},
	])
	mirror.load_snapshot(JSON.parse_string(JSON.stringify(snap)))
	assert_eq(mirror.item_at(1, 0).type, "tomato")
	assert_eq(mirror.station(0, bowl).contents.size(), 2)
	assert_eq(mirror.station(0, bowl).recipe.id, "knead_dough")
	assert_almost(mirror.station(0, bowl).progress, 1.0)
