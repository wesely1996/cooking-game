extends Node
## Global game state (autoload "Game"): loaded content, story progress and
## settings, which level is being played, and scene changes.

const SAVE_PATH := "user://save.json"
const SCENE_MENU := "res://ui/main_menu.tscn"
const SCENE_LEVEL_SELECT := "res://ui/level_select.tscn"
const SCENE_KITCHEN := "res://game/kitchen/kitchen_screen.tscn"
const SCENE_RESULTS := "res://ui/results.tscn"

var db: ContentDB
var levels := {}  # id -> LevelDef
var progression: Progression
var settings := {"sound": true, "haptics": true}

var current_level: LevelDef
var player_count := 1
var last_outcome := {}
var last_stats := {}
var best_arcade := {}  # level id -> best score


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


func start_level(level_id: String) -> void:
	current_level = levels[level_id]
	get_tree().change_scene_to_file(SCENE_KITCHEN)


func finish_level(outcome: Dictionary, stats: Dictionary) -> void:
	last_outcome = outcome
	last_stats = stats
	if current_level.type == LevelDef.TYPE_ARCADE:
		best_arcade[current_level.id] = maxi(int(best_arcade.get(current_level.id, 0)), int(outcome.get("score", 0)))
	else:
		progression.record(current_level.id, outcome)
	save()
	get_tree().change_scene_to_file(SCENE_RESULTS)


func goto(scene: String) -> void:
	get_tree().change_scene_to_file(scene)


func vibrate(ms: int) -> void:
	if settings.haptics:
		Input.vibrate_handheld(ms)


func save() -> void:
	var data := {"progress": progression.to_dict(), "settings": settings, "best_arcade": best_arcade}
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
	var arcade: Dictionary = data.get("best_arcade", {})
	for key in arcade:
		best_arcade[key] = int(arcade[key])
