extends Node
## Global game state (autoload "Game"): loaded content, story progress and
## settings, which level is being played, and scene changes.

const SAVE_PATH := "user://save.json"
const SCENE_MENU := "res://ui/main_menu.tscn"
const SCENE_LEVEL_SELECT := "res://ui/level_select.tscn"
const SCENE_KITCHEN := "res://game/kitchen/kitchen_screen.tscn"
const SCENE_RESULTS := "res://ui/results.tscn"
const SCENE_RECIPE_BOOK := "res://ui/recipe_book.tscn"
const SCENE_LOBBY := "res://ui/lobby.tscn"
const SCENE_PLAY := "res://ui/play_menu.tscn"
const SCENE_PROFILE := "res://ui/profile.tscn"
const SCENE_SETTINGS := "res://ui/settings.tscn"

var db: ContentDB
var levels := {}  # id -> LevelDef
var progression: Progression
var settings := {"sound": true, "haptics": true, "tips": true, "easy_minigames": false}
var profile := PlayerProfile.new()
## The world-map region shown last, so the map reopens where you were.
var selected_region := 0

var current_level: LevelDef
var player_count := 1
var last_outcome := {}
var last_stats := {}
var best_arcade := {}  # "level id:<n>p" -> best score
var shift_seed := 0
## Shown once by the lobby, e.g. "Your friend left the kitchen."
var lobby_message := ""
## Off for automated runs (smoke test), so they never touch a player's save.
var save_enabled := true
## Where the recipe book returns to.
var recipe_book_return := SCENE_MENU


func _ready() -> void:
	db = ContentDB.load_dir()
	for level in LevelDef.load_dir():
		levels[level.id] = level
	progression = Progression.load_map()
	_load()
	var errors := db.validate()
	print("Pass the Plate! %s: %d packs, %d levels, %d content errors" % [
		ProjectSettings.get_setting("application/config/version"), db.pack_ids.size(), levels.size(), errors.size()])
	for error in errors:
		push_error(error)
	if profile.look.is_empty():
		profile.look = ChefLook.default_look()
	Net.message_received.connect(_on_net_message)
	Net.disconnected.connect(_on_net_disconnected)


func level_order() -> Array[String]:
	var ids: Array[String] = []
	for region in progression.regions:
		for entry in region.get("levels", []):
			ids.append(entry.id)
	return ids


func next_level_id(level_id: String) -> String:
	var ids := level_order()
	var index := ids.find(level_id)
	return ids[index + 1] if index >= 0 and index + 1 < ids.size() else ""


## Starts a level. Solo by default; in a LAN game the host calls this with 2
## players and every client follows when the "start" message arrives.
func start_level(level_id: String, players: int = 1, seed: int = -1) -> void:
	current_level = levels[level_id]
	player_count = players
	for i in progression.regions.size():
		if progression.regions[i].levels.any(func(entry): return entry.id == level_id):
			selected_region = i
	shift_seed = seed if seed >= 0 else randi()
	if Net.is_host():
		Net.send_to_clients({"t": "start", "level": level_id, "seed": shift_seed, "players": players})
	get_tree().change_scene_to_file(SCENE_KITCHEN)


## Host only: brings everybody back to the lobby after a level.
func back_to_lobby() -> void:
	if Net.is_host():
		Net.send_to_clients({"t": "lobby"})
	goto(SCENE_LOBBY)


## Leaves a LAN game (if any) and goes to the title screen.
func leave_to_menu() -> void:
	Net.leave()
	player_count = 1
	goto(SCENE_PLAY)


## Wipes stars, dishes, arcade scores and stats. Name, look and settings stay.
func reset_progress() -> void:
	progression.load_save({})
	best_arcade.clear()
	profile.load_dict({"name": profile.name, "look": profile.look})
	selected_region = 0
	save()


## The arcade level for a cuisine pack, e.g. "arcade_italian".
func arcade_level_id(pack: String) -> String:
	return "arcade_" + pack


## A cuisine's display name, e.g. "Mexican".
func cuisine_name(pack: String) -> String:
	return str(db.pack_names.get(pack, pack.capitalize()))


## A dish that represents the cuisine (the first dish of its first level).
func cuisine_icon(pack: String) -> Texture2D:
	for region in progression.regions:
		if region.get("pack", "") == pack:
			var level: LevelDef = levels.get(region.levels[0].id)
			if level:
				return Art.item(level.dish_ids()[0])
	return null


func arcade_key(level_id: String, players: int) -> String:
	return "%s:%dp" % [level_id, players]


func best_arcade_score(level_id: String, players: int) -> int:
	return int(best_arcade.get(arcade_key(level_id, players), 0))


func finish_level(outcome: Dictionary, stats: Dictionary) -> void:
	last_outcome = outcome
	last_stats = stats
	profile.record(current_level.pack, int(outcome.get("score", 0)), float(stats.get("time", 0.0)), int(stats.get("served", 0)))
	if current_level.type == LevelDef.TYPE_ARCADE:
		var key := arcade_key(current_level.id, player_count)
		best_arcade[key] = maxi(int(best_arcade.get(key, 0)), int(outcome.get("score", 0)))
	else:
		progression.record(current_level.id, outcome)
	save()
	get_tree().change_scene_to_file(SCENE_RESULTS)


## Records that a dish was served. Returns true the first time ever.
func discover(dish: String) -> bool:
	var is_new := progression.discover(dish)
	if is_new:
		save()
	return is_new


## The first story level whose menu has the dish, or null.
func first_level_with(dish: String) -> LevelDef:
	for id in level_order():
		var level: LevelDef = levels.get(id)
		if level and level.dish_ids().has(dish):
			return level
	return null


func open_recipe_book(return_scene: String) -> void:
	recipe_book_return = return_scene
	goto(SCENE_RECIPE_BOOK)


func goto(scene: String) -> void:
	get_tree().change_scene_to_file(scene)


func vibrate(ms: int) -> void:
	if settings.haptics:
		Input.vibrate_handheld(ms)


func save() -> void:
	if not save_enabled:
		return
	var data := {"progress": progression.to_dict(), "settings": settings, "best_arcade": best_arcade, "profile": profile.to_dict()}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	progression.load_save(data.get("progress", {}))
	var saved_settings: Dictionary = data.get("settings", {})
	for key in settings:
		settings[key] = bool(saved_settings.get(key, settings[key]))
	profile.load_dict(data.get("profile", {}))
	var arcade: Dictionary = data.get("best_arcade", {})
	for key in arcade:
		# Saves from v0.1/v0.2 had no player count: those were solo games.
		best_arcade[key if ":" in key else arcade_key(key, 1)] = int(arcade[key])


func _on_net_message(_peer_id: int, message: Dictionary) -> void:
	if not Net.is_client():
		return
	match str(message.get("t", "")):
		"start":
			start_level(str(message.get("level", "")), int(message.get("players", 2)), int(message.get("seed", 0)))
		"lobby":
			goto(SCENE_LOBBY)


func _on_net_disconnected(reason: String) -> void:
	Net.leave()
	player_count = 1
	lobby_message = reason
	goto(SCENE_LOBBY)
