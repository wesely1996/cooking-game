extends Node
## Visual check: opens the main screens, plays a little of Pizza Night through
## the kitchen screen and saves PNG screenshots. Needs a display (or xvfb):
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
	Game.goto(Game.SCENE_MENU)
	await _wait(0.6)
	await _shot("01_menu")
	Game.goto(Game.SCENE_LEVEL_SELECT)
	await _wait(0.4)
	await _shot("02_level_select")

	Game.open_recipe_book(Game.SCENE_MENU)
	await _wait(0.4)
	await _shot("02b_recipe_book_empty")

	Game.start_level("italy_01")
	await _wait(2.3)
	var screen := get_tree().current_scene
	var shift: Shift = screen.shift
	await _shot("03_kitchen_start")
	await _wait(2.5)
	_check(not screen._hint_text.is_empty(), "a new dish shows tips")

	# Real pointer input: tap a crate, then drag the food into the bin.
	# (A headless run gets no GUI input, so this part needs a display.)
	if DisplayServer.get_name() != "headless":
		await _check_input(screen, shift)

	# Make a pizza the way a player would, through intents.
	var steps := [
		{"type": "take", "ingredient": "flour"}, {"type": "take", "ingredient": "water"},
		{"type": "take", "ingredient": "tomato"}, {"type": "take", "ingredient": "mozzarella"},
		{"type": "combine", "from": 1, "to": 0},
	]
	for step in steps:
		step.player = 0
		shift.do_intent(step)
		await _wait(0.15)
	screen._selected_uid = shift.kitchen.item_at(0, 0).uid
	await _wait(0.3)
	await _shot("04_kitchen_selected")
	screen._start_work_on_slot(0, "mixing_bowl")
	for i in 5:
		screen._on_minigame_work(1)
		await _wait(0.08)
	await _wait(0.1)
	await _shot("05_minigame_knead")
	for i in 7:
		screen._on_minigame_work(1)
	await _wait(0.8)
	for i in 3:
		shift.do_intent({"type": "work", "player": 0, "slot": 0, "equipment": "rolling_pin"})
	for i in 5:
		shift.do_intent({"type": "work", "player": 0, "slot": 2, "equipment": "knife"})
	shift.do_intent({"type": "insert", "player": 0, "slot": 2, "equipment": "sauce_pot"})
	for i in 4:
		shift.do_intent({"type": "work", "player": 0, "slot": 3, "equipment": "knife"})
	shift.do_intent({"type": "combine", "player": 0, "from": 3, "to": 0})
	await _wait(0.5)
	await _shot("06_kitchen_partial")
	for i in 3:
		shift.do_intent({"type": "work_appliance", "player": 0, "equipment": "sauce_pot", "index": 0})
	shift.do_intent({"type": "remove", "player": 0, "equipment": "sauce_pot", "index": 0})
	var sauce_slot := shift.kitchen.players[0].slots.find_custom(func(i): return i != null and i.type == "tomato_sauce")
	shift.do_intent({"type": "combine", "player": 0, "from": sauce_slot, "to": 0})
	shift.do_intent({"type": "insert", "player": 0, "slot": 0, "equipment": "oven"})
	await _wait(3.0)
	await _shot("07_oven_baking")
	await _wait(5.6)
	await _shot("08_oven_ready")
	shift.do_intent({"type": "remove", "player": 0, "equipment": "oven", "index": 0})
	shift.do_intent({"type": "serve", "player": 0, "slot": 0})
	await _wait(0.3)
	await _shot("09_served")
	_check(Game.progression.is_discovered("pizza_margherita"), "serving a pizza discovers it")
	shift.spawn_customer("pizza_margherita")
	await _wait(0.6)
	_check(screen._hint_text.is_empty(), "no tips for a dish you already made")
	# A busy kitchen: the bot plays Full Trattoria for a while at 4x speed.
	Game.start_level("italy_04")
	await _wait(2.0)
	screen = get_tree().current_scene
	shift = screen.shift
	var bot := KitchenBot.new()
	Engine.time_scale = 4.0
	while shift.time < 50.0:
		bot.step(shift)
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await _shot("10_busy_kitchen")
	Game.current_level = Game.levels["italy_01"]
	Game.finish_level({"type": "normal", "failed": false, "stars": 2, "score": 312}, {"served": 4, "lost": 1, "perfect": 2, "score": 312})
	await _wait(1.6)
	await _shot("11_results")
	Game.open_recipe_book(Game.SCENE_MENU)
	await _wait(0.4)
	await _shot("12_recipe_book")
	var book := get_tree().current_scene
	book._show_dish("bruschetta")
	await _wait(0.2)
	await _shot("13_recipe_locked")
	book._show_mystery({"cuisine": "Mexican", "region": "Mexico"})
	await _wait(0.2)
	await _shot("14_recipe_coming_soon")


func _check_input(screen: Node, shift: Shift) -> void:
	var crate_pos: Vector2 = screen._crates[0].rect.get_center()
	await _tap(crate_pos)
	var first := shift.kitchen.item_at(0, 0)
	_check(first != null and first.type == shift.kitchen.players[0].crates[0], "tapping a crate takes an ingredient")
	await _drag(screen._slots[0].center, screen._trash_rect.get_center())
	_check(shift.kitchen.item_at(0, 0) == null, "dragging food to the bin trashes it")
	await _tap(crate_pos)
	await _tap(screen._slots[0].center)
	_check(screen._selected_uid != 0, "tapping food selects it")
	await _tap(screen._trash_rect.get_center())
	_check(shift.kitchen.item_at(0, 0) == null, "tap food, then tap the bin")
	# Drag the knife onto a tomato and chop it with five swipes down.
	var tomato_pos: Vector2 = screen._crate_rect("tomato").get_center()
	await _tap(tomato_pos)
	await _drag(screen._tool_rect("knife").get_center(), screen._slots[0].center)
	_check(screen._minigame.visible, "dragging a tool onto food opens the mini-game")
	var center: Vector2 = screen._minigame.position + screen._minigame.size * 0.5
	for i in 5:
		await _drag(center + Vector2(0, -90), center + Vector2(0, 40))
	var chopped := shift.kitchen.item_at(0, 0)
	_check(chopped != null and chopped.type == "chopped_tomato", "five swipes down chop the tomato")
	await _wait(0.8)
	await _tap(screen._slots[0].center)
	await _tap(screen._trash_rect.get_center())
	await _wait(0.4)


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
