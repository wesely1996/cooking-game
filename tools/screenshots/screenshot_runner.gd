extends Node
## Visual check: opens the main screens, plays the first Italian shift (with
## its new-dish prologue) through the kitchen screen and saves PNG
## screenshots. Needs a display (or xvfb):
##
##   xvfb-run godot --path . res://tools/screenshots/screenshot_runner.tscn -- <output dir>
##
## It also checks that taps and drags work, and logs an error otherwise.
## tools/smoke_test.sh runs it and fails on any logged error. With --headless
## it runs the same steps without images or the input checks.

var _out := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	Game.settings.sound = false
	# Start from an empty save and never write the player's real one.
	Game.save_enabled = false
	Game.progression.load_save({})
	# Let a dummy node be the "current scene" so scene changes don't free us.
	await get_tree().process_frame
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	await _run()
	get_tree().quit()


func _run() -> void:
	# As if an old save had just been reset for the new kitchen.
	Game.show_makeover_note = true
	Game.goto(Game.SCENE_MENU)
	await _wait(0.6)
	await _shot("00_makeover_note")
	var ok: Button = get_tree().current_scene.find_child("MakeoverOk", true, false)
	_check(ok != null, "an old save gets the makeover note")
	ok.pressed.emit()
	await _wait(0.3)
	_check(not Game.show_makeover_note, "the note is shown once")
	await _shot("01_menu")
	Game.goto(Game.SCENE_LEVEL_SELECT)
	await _wait(0.4)
	await _shot("02_level_select")
	get_tree().current_scene._show_region(1)
	await _wait(0.2)
	await _shot("02_level_select_locked_issue")
	get_tree().current_scene._show_region(0)

	Game.open_recipe_book(Game.SCENE_MENU)
	await _wait(0.4)
	await _shot("02b_recipe_book_empty")
	Game.goto(Game.SCENE_MENU)
	await _wait(0.4)
	get_tree().current_scene.find_child("Play", true, false).pressed.emit()
	await _wait(0.4)
	_check(get_tree().current_scene.name == "PlayMenu", "PLAY opens the play menu")
	await _shot("02c_play_menu")
	get_tree().current_scene._show(1)
	await _wait(0.3)
	await _shot("02d_arcade_picker")
	Game.profile.name = "Nikola"
	Game.profile.look = {"skin": 1, "hair": 1, "hair_color": 3, "hat": 0, "apron": 1}
	Game.profile.record("italian", 320, 180.0, 6)
	Game.profile.record("italian", 280, 180.0, 5)
	Game.goto(Game.SCENE_PROFILE)
	await _wait(0.4)
	await _shot("02e_profile")
	var profile_screen := get_tree().current_scene
	profile_screen._step("hat", 1)
	_check(int(Game.profile.look.hat) == 1, "changing the hat updates the profile")
	profile_screen._step("hat", -1)
	Game.goto(Game.SCENE_SETTINGS)
	await _wait(0.4)
	await _shot("02f_settings")
	var tips_toggle: Button = get_tree().current_scene.find_child("Toggle_tips", true, false)
	tips_toggle.pressed.emit()
	_check(not Game.settings.tips and tips_toggle.text == "OFF", "settings toggle turns tips off")
	tips_toggle.pressed.emit()
	_check(Game.settings.tips, "and back on")
	Game.selected_region = 0

	# The first shift: caprese is new, so it starts with the prologue.
	Game.start_level("italy_01")
	await _wait(2.3)
	var screen := get_tree().current_scene
	var shift: Shift = screen.shift
	_check(shift.in_prologue(), "a new dish starts with the prologue")
	await _wait(0.5)
	await _shot("03_kitchen_prologue")
	_check(not screen._hint_text.is_empty(), "the prologue shows tips")
	_check(shift.time == 0.0, "the clock waits during the prologue")

	# Real pointer input (a headless run gets no GUI input, so this part needs
	# a display): taps, drags, the chopping mini-game, LATER and resuming.
	if DisplayServer.get_name() != "headless":
		await _check_input(screen, shift)

	# Make the caprese the way a player would, through intents.
	var k := shift.kitchen
	var boards := k.players[0].stations_of("board")
	var steps := [
		{"type": "take", "ingredient": "tomato", "station": boards[0].index},
		{"type": "take", "ingredient": "mozzarella", "station": boards[1].index},
		{"type": "take", "ingredient": "plate"},
	]
	for step in steps:
		step.player = 0
		shift.do_intent(step)
		await _wait(0.15)
	screen._selected = boards[0].index
	await _wait(0.3)
	await _shot("04_kitchen_selected")
	screen._selected = -1
	screen._start_work(boards[1].index)
	for i in 2:
		screen._on_minigame_work(1)
		await _wait(0.08)
	await _wait(0.1)
	await _shot("05_minigame_slice")
	screen._on_minigame_work(1)
	await _wait(0.8)
	for i in 4:
		shift.do_intent({"type": "work", "player": 0, "station": boards[0].index})
	var plate := _find(k, 0, "plate")
	shift.do_intent({"type": "move", "player": 0, "from": boards[0].index, "to": plate})
	shift.do_intent({"type": "move", "player": 0, "from": boards[1].index, "to": plate})
	await _wait(0.5)
	await _shot("06_kitchen_plating")
	shift.do_intent({"type": "take", "player": 0, "ingredient": "basil", "station": plate})
	shift.do_intent({"type": "serve", "player": 0, "station": plate})
	await _wait(0.4)
	await _shot("07_prologue_done")
	_check(Game.progression.is_discovered("caprese_salad"), "serving the tutorial caprese discovers it")
	_check(not shift.in_prologue(), "then the real shift starts")
	_check(shift.score == 0, "the tutorial dish scores nothing")
	await _wait(3.0)
	_check(shift.time > 1.0, "the clock runs")
	_check(screen._hint_text.is_empty(), "no tips after the prologue")

	# A busy kitchen: the bot plays the Pizzeria for a while at 4x speed,
	# after skipping its prologue.
	Game.start_level("italy_04")
	await _wait(2.0)
	screen = get_tree().current_scene
	shift = screen.shift
	_check(shift.in_prologue(), "pizza and pasta are new")
	screen._intent({"type": "skip_prologue"})
	_check(not shift.in_prologue(), "SKIP starts the shift")
	var bot := KitchenBot.new()
	Engine.time_scale = 4.0
	while shift.time < 50.0:
		bot.step(shift)
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await _shot("10_busy_kitchen")
	# Two chefs: the teammate's chef in the team panel; then the rival panel.
	await _play_a_bit("mexico_04", 2, "10b_team_kitchen")
	await _play_a_bit("japan_competition", 1, "10c_rival_kitchen")
	await _play_a_bit("france_04", 1, "10d_france_kitchen")
	await _play_a_bit("usa_04", 3, "10e_usa_kitchen")
	await _play_a_bit("spain_04", 1, "10f_spain_kitchen")
	Game.current_level = Game.levels["italy_01"]
	Game.finish_level({"type": "normal", "failed": false, "stars": 2, "score": 312}, {"served": 4, "lost": 1, "perfect": 2, "score": 312})
	await _wait(1.6)
	await _shot("11_results")
	Game.open_recipe_book(Game.SCENE_MENU)
	await _wait(0.4)
	await _shot("12_recipe_book")
	var book := get_tree().current_scene
	book._show_dish("caprese_salad")
	await _wait(0.2)
	await _shot("13_recipe_caprese")
	book._show_dish("pizza_margherita")
	await _wait(0.2)
	await _shot("13b_recipe_locked")
	book._show_mystery({"cuisine": "Penguin Iceberg", "region": "The Iceberg", "issue": 7})
	await _wait(0.2)
	await _shot("14_recipe_coming_soon")


## Starts a level without a prologue, lets the bot cook all kitchens for a
## while at 4x speed and takes a screenshot.
func _play_a_bit(level_id: String, players: int, shot: String) -> void:
	var none: Array[String] = []
	Game.start_level(level_id, players, 7, none)
	await _wait(2.0)
	var screen := get_tree().current_scene
	var shift: Shift = screen.shift
	var bot := KitchenBot.new()
	Engine.time_scale = 4.0
	while shift.time < 25.0:
		bot.step(shift)
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await _shot(shot)


func _check_input(screen: Node, shift: Shift) -> void:
	var k := shift.kitchen
	var crate_pos: Vector2 = screen.crate_center("tomato")
	await _tap(crate_pos)
	var first := k.item_at(0, 0)
	_check(first != null and first.type == "tomato", "tapping a crate puts food on the first counter")
	await _drag(screen.station_center(0), screen.bin_center())
	_check(k.item_at(0, 0) == null, "dragging food to the bin trashes it")
	await _tap(crate_pos)
	await _tap(screen.station_center(0))
	_check(screen._selected == 0, "tapping food selects it")
	await _tap(screen.bin_center())
	_check(k.item_at(0, 0) == null, "tap food, then tap the bin")
	# Drag a tomato from the crate onto a board, tap the board, chop it.
	var board: int = screen.station_of("board")
	await _drag(crate_pos, screen.station_center(board))
	_check(k.item_at(0, board) != null and k.item_at(0, board).type == "tomato", "dragging a crate onto a board")
	await _tap(screen.station_center(board))
	_check(screen._minigame.visible, "tapping a full board opens the mini-game")
	var center: Vector2 = screen._minigame.get_transform() * (screen._minigame.size * 0.5)
	for i in 2:
		await _drag(center + Vector2(0, -60), center + Vector2(0, 10))
	# Pause with LATER: the board keeps the two chops.
	await _tap(screen._minigame.get_transform() * screen._minigame.close_rect().get_center())
	_check(not screen._minigame.visible, "LATER closes the mini-game")
	_check(k.station(0, board).progress == 2.0, "paused work keeps its progress")
	await _wait(0.3)
	await _shot("03b_paused_work")
	await _tap(screen.station_center(board))
	_check(screen._minigame.visible and screen._minigame.done == 2.0, "tapping the board again goes on where it stopped")
	await _drag(center + Vector2(0, -60), center + Vector2(0, 10))
	# Tapping the kitchen pauses too, and the tap still does its job.
	await _tap(screen.crate_center("basil"))
	_check(not screen._minigame.visible, "tapping outside pauses the work")
	_check(k.item_at(0, 0) != null and k.item_at(0, 0).type == "basil", "...and the tap still takes an ingredient")
	await _tap(screen.station_center(board))
	await _drag(center + Vector2(0, -60), center + Vector2(0, 10))
	var chopped := k.item_at(0, board)
	_check(chopped != null and chopped.type == "chopped_tomato", "four swipes down, with breaks, chop the tomato")
	await _wait(0.8)
	for station in [0, board]:
		await _drag(screen.station_center(station), screen.bin_center())
	await _wait(0.4)


func _find(k: KitchenState, player: int, type: String) -> int:
	for st in k.players[player].stations:
		var item := st.item()
		if item and (item.type == type or k.effective_id(item) == type):
			return st.index
	return -1


func _tap(pos: Vector2) -> void:
	_mouse_button(pos, true)
	await get_tree().process_frame
	_mouse_button(pos, false)
	await get_tree().process_frame


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse_button(from, true)
	await get_tree().process_frame
	for i in 6:
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, (i + 1) / 6.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion)
		await get_tree().process_frame
	_mouse_button(to, false)
	await get_tree().process_frame


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event)


func _check(condition: bool, what: String) -> void:
	if condition:
		print("check ok: ", what)
	else:
		push_error("check failed: " + what)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		print("step ", name)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(name + ".png"))
	print("saved ", name)
