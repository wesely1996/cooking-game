extends Node
## End-to-end LAN test: two copies of the game on one computer, one hosting
## and one joining over real ENet sockets. Pizza is new to them, so the shift
## starts with the pizza prologue, which they cook together across both
## kitchens (throwing with real drag gestures): chef 1 kneads the dough and
## chops tomatoes, chef 2 tops it with mozzarella and throws it back, chef 1
## bakes it, chef 2 plates and serves it. Then they finish the level, go back
## to the lobby, start arcade, and check what happens when the host leaves.
##
##   godot --path . res://tools/lan_test/lan_runner.tscn -- host <screenshot dir>
##   godot --path . res://tools/lan_test/lan_runner.tscn -- client <screenshot dir>
##
## tools/lan_test.sh starts both. Each copy exits with 0 when all its checks
## passed. Needs a display (xvfb) because it uses real pointer input.

const TIMEOUT := 40.0

var _role := "host"
var _out := "user://lan_test"
var _failed := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_role = args[0]
	if args.size() >= 2:
		_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	Game.settings.sound = false
	Game.save_enabled = false
	Game.progression.load_save({})
	# Only pizza is new to both chefs, so it's the one dish in the prologue.
	for dish in ["caprese_salad", "pasta_pomodoro"]:
		Game.progression.discover(dish)
	Game.profile.name = "Nikola" if _role == "host" else "Maria"
	Game.profile.look = {"model": 3, "hat": 0, "hat_color": 0, "apron": 0} if _role == "host" else {"model": 8, "hat": 2, "hat_color": 3, "apron": 2}
	await get_tree().process_frame
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	get_window().title = "Pass the Plate! – " + _role
	if _role == "host":
		await _run_host()
	else:
		await _run_client()
	print("%s: %s" % [_role, "ALL CHECKS PASSED" if _failed == 0 else "%d CHECKS FAILED" % _failed])
	get_tree().quit(0 if _failed == 0 else 1)


# --- Host (chef 1: pantry and stove) ----------------------------------------

func _run_host() -> void:
	Game.goto(Game.SCENE_LOBBY)
	await _wait(0.5)
	var lobby := get_tree().current_scene
	lobby._on_host()
	_check(Net.is_host(), "hosting a kitchen")
	await _shot("1_lobby_waiting")
	_check(await _until(func(): return not Net.client_peers.is_empty()), "the friend joined")
	_check(Net.profile_of(1).name == "Maria", "the host knows the friend's name")
	await _wait(0.5)
	await _shot("2_lobby_ready")

	Game.start_level("italy_04", 2)
	var screen := await _kitchen()
	var shift: Shift = screen.shift
	var k := shift.kitchen
	_check(screen._mates.size() == 1, "one teammate panel")
	_check(shift.in_prologue() and shift.prologue == (["pizza_margherita"] as Array[String]), "the shift starts with the pizza prologue")
	var bowl: int = screen.station_of("bowl")
	var board: int = screen.station_of("board")
	var oven: int = screen.station_of("oven")
	screen._intent({"type": "take", "ingredient": "flour", "station": bowl})
	screen._intent({"type": "take", "ingredient": "water", "station": bowl})
	for i in 8:
		screen._intent({"type": "work", "station": bowl})
	screen._intent({"type": "take", "ingredient": "tomato", "station": board})
	for i in 4:
		screen._intent({"type": "work", "station": board})
	_check(k.item_at(0, bowl).type == "dough" and k.item_at(0, board).type == "chopped_tomato", "dough and chopped tomato ready")
	await _wait(0.5)
	await _shot("3_kitchen_dough_ready")
	# Throw the dough with a real drag onto the teammate's panel.
	await _drag(screen.station_center(bowl), screen.mate_center(1))
	_check(k.item_at(0, bowl) == null and _find(k, 1, "dough") >= 0, "drag to the teammate throws the dough to chef 2")
	screen._intent({"type": "throw", "station": board, "target": 1})
	# Chef 2 tops it and throws the raw pizza back: into the oven.
	_check(await _until(func(): return _find(k, 0, "raw_pizza_margherita") >= 0), "the raw pizza comes back")
	await _drag(screen.station_center(_find(k, 0, "raw_pizza_margherita")), screen.station_center(oven))
	_check(await _until(func(): return k.station(0, oven).done), "the pizza bakes")
	await _shot("4_kitchen_baked")
	screen._intent({"type": "throw", "station": oven, "target": 1})
	_check(await _until(func(): return not shift.in_prologue()), "chef 2 serves it, and the real shift starts")
	_check(await _until(func(): return Game.progression.is_discovered("pizza_margherita")), "the host learned pizza")
	await _wait(0.6)
	await _shot("5_kitchen_served")

	# End the shift and check the results flow.
	shift.time = float(shift.level.value("duration", 2, 180.0)) - 0.05
	_check(await _until(func(): return _scene_is("Results")), "results screen")
	await _wait(1.5)
	await _shot("6_results")
	Game.back_to_lobby()
	await _wait(1.0)
	Game.start_level("arcade_italian", 2)
	screen = await _kitchen()
	_check(screen.shift.level.type == LevelDef.TYPE_ARCADE, "arcade together")
	_check(screen.shift.prologue == (["bruschetta"] as Array[String]), "only bruschetta is still new to the team")
	await _wait(3.0)
	await _shot("7_arcade")
	# Wait until the client has checked arcade, then leave.
	await _wait(3.0)
	Game.leave_to_menu()
	await _wait(1.0)


# --- Client (chef 2: toppings and the pass) ---------------------------------

func _run_client() -> void:
	await _wait(1.0)
	Game.goto(Game.SCENE_LOBBY)
	await _wait(0.3)
	var lobby := get_tree().current_scene
	lobby._show(lobby.Page.JOIN)
	_check(await _until(func(): return Net.found_games.size() == 1, 10.0), "found the host's kitchen by discovery")
	await _wait(2.5)
	_check(Net.found_games.size() == 1, "the kitchen is listed once")
	var address: String = Net.found_games.values()[0].address
	_check(address.is_valid_ip_address(), "with its address (%s)" % address)
	await _shot("1_lobby_found")
	lobby._join(address)
	_check(await _until(func(): return Net.is_client() and Net.local_player == 1), "joined as chef 2")
	_check(Net.profile_of(0).name == "Nikola" and int(Net.profile_of(0).look.model) == 3, "the friend knows the host's name and chef")
	await _wait(0.3)
	await _shot("2_lobby_joined")

	var screen := await _kitchen()
	var shift: Shift = screen.shift
	var k := shift.kitchen
	_check(screen._me == 1 and screen._session is ClientSession, "the client plays chef 2")
	_check(shift.in_prologue(), "the client is in the prologue too")
	var board: int = screen.station_of("board")
	# The dough and the chopped tomato arrive: tomato onto the dough.
	_check(await _until(func(): return _find(k, 1, "dough") >= 0 and _find(k, 1, "chopped_tomato") >= 0), "caught the dough and the tomato")
	await _wait(0.4)
	await _shot("3_kitchen_caught")
	screen._intent({"type": "move", "from": _find(k, 1, "chopped_tomato"), "to": _find(k, 1, "dough")})
	screen._intent({"type": "take", "ingredient": "mozzarella", "station": board})
	_check(await _until(func(): return k.item_at(1, board) != null), "mozzarella on the board (confirmed by the host)")
	for i in 3:
		screen._intent({"type": "work", "station": board})
	_check(await _until(func(): return _find(k, 1, "sliced_mozzarella") >= 0), "sliced it")
	screen._intent({"type": "move", "from": board, "to": _find(k, 1, "dough")})
	_check(await _until(func(): return _find(k, 1, "raw_pizza_margherita") >= 0), "raw pizza assembled")
	var raw := _find(k, 1, "raw_pizza_margherita")
	await _drag(screen.station_center(raw), screen.mate_center(0))
	_check(await _until(func(): return _find(k, 1, "raw_pizza_margherita") < 0), "threw the raw pizza back with a drag")
	# The baked pizza comes back: plate it and serve it with a real drag.
	_check(await _until(func(): return _find(k, 1, "whole_pizza") >= 0), "the baked pizza arrives")
	screen._intent({"type": "take", "ingredient": "plate"})
	_check(await _until(func(): return _find(k, 1, "plate") >= 0), "a plate")
	screen._intent({"type": "move", "from": _find(k, 1, "whole_pizza"), "to": _find(k, 1, "plate")})
	_check(await _until(func(): return _find(k, 1, "pizza_margherita") >= 0), "pizza on the plate")
	await _wait(0.3)
	await _drag(screen.station_center(_find(k, 1, "pizza_margherita")), screen.station_center(k.players[1].pass_station(k.db)))
	_check(await _until(func(): return not shift.in_prologue()), "served it: the real shift starts")
	_check(await _until(func(): return Game.progression.is_discovered("pizza_margherita")), "the client learned pizza too")
	await _wait(0.6)
	await _shot("5_kitchen_served")

	_check(await _until(func(): return _scene_is("Results")), "results screen")
	await _wait(1.5)
	await _shot("6_results")
	_check(await _until(func(): return _scene_is("Lobby")), "back in the lobby with the host")
	screen = await _kitchen()
	_check(screen.shift.level.type == LevelDef.TYPE_ARCADE, "arcade together")
	await _wait(1.0)
	await _shot("7_arcade")
	_check(await _until(func(): return _scene_is("Lobby") and not Net.is_online()), "back to the lobby when the host leaves")
	await _wait(0.3)
	await _shot("8_host_left")
	_check(get_tree().current_scene._status.text.contains("closed"), "explains that the host left")


# --- Helpers -----------------------------------------------------------------

func _kitchen() -> Node:
	await _until(func(): return _scene_is("KitchenScreen"))
	var screen := get_tree().current_scene
	await _until(func(): return screen._start_timer <= 0.0)
	return screen


func _scene_is(scene_name: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.name == scene_name


func _find(k: KitchenState, player: int, type: String) -> int:
	for st in k.players[player].stations:
		var item := st.item()
		if item and (item.type == type or k.effective_id(item) == type):
			return st.index
	return -1


func _until(condition: Callable, timeout: float = TIMEOUT) -> bool:
	var waited := 0.0
	while waited < timeout:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _drag(from: Vector2, to: Vector2) -> void:
	_button(from, true)
	await get_tree().process_frame
	for i in 6:
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, (i + 1) / 6.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion)
		await get_tree().process_frame
	_button(to, false)
	await get_tree().process_frame


func _button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event)


func _check(condition: bool, what: String) -> void:
	if condition:
		print("%s check ok: %s" % [_role, what])
	else:
		_failed += 1
		push_error("%s check failed: %s" % [_role, what])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [_role, name]))
