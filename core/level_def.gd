class_name LevelDef
extends RefCounted
## One playable level, loaded from data/levels/*.json.
##
## Settings that depend on the number of players are written as an object
## keyed by player count, e.g. "max_active": {"1": 2, "2": 3, "3": 3, "4": 4}.
## value() picks the right entry; plain values apply to every player count.

const DEFAULT_LEVEL_DIR := "res://data/levels"

const TYPE_NORMAL := "normal"
const TYPE_FESTIVAL := "festival"
const TYPE_COMPETITION := "competition"
const TYPE_ARCADE := "arcade"
const TYPES := [TYPE_NORMAL, TYPE_FESTIVAL, TYPE_COMPETITION, TYPE_ARCADE]

## Fewer players means more work per player, so customers wait longer.
const DEFAULT_PATIENCE_MULTIPLIER := {"1": 1.7, "2": 1.3, "3": 1.1, "4": 1.0}

var id := ""
var name := ""
var description := ""
var pack := ""
var type := TYPE_NORMAL
var dishes: Array[Dictionary] = []  # {"id": String, "weight": float}
var data := {}


static func from_dict(raw: Dictionary) -> LevelDef:
	var level := LevelDef.new()
	level.data = raw
	level.id = str(raw.get("id", ""))
	level.name = str(raw.get("name", level.id))
	level.description = str(raw.get("description", ""))
	level.pack = str(raw.get("pack", ""))
	level.type = str(raw.get("type", TYPE_NORMAL))
	for entry in raw.get("dishes", []):
		if entry is String:
			level.dishes.append({"id": entry, "weight": 1.0})
		else:
			level.dishes.append({"id": str(entry.get("id", "")), "weight": float(entry.get("weight", 1.0))})
	return level


static func load_file(path: String) -> LevelDef:
	var raw: Variant = DataFiles.read_json(path)
	return from_dict(raw) if raw is Dictionary else null


static func load_dir(dir_path: String = DEFAULT_LEVEL_DIR) -> Array[LevelDef]:
	var levels: Array[LevelDef] = []
	for path in DataFiles.list_files(dir_path, ".json"):
		var level := load_file(path)
		if level:
			levels.append(level)
	return levels


## A setting for the given player count (see the class description).
func value(key: String, player_count: int, default: Variant = null) -> Variant:
	return pick(data.get(key, default), player_count)


static func pick(v: Variant, player_count: int) -> Variant:
	if v is Dictionary and v.has(str(player_count)):
		return v[str(player_count)]
	return v


func dish_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in dishes:
		ids.append(entry.id)
	return ids


func patience_multiplier(player_count: int) -> float:
	return float(value("patience_multiplier", player_count, DEFAULT_PATIENCE_MULTIPLIER))


## The roles (who owns which crates and equipment) for a player count.
## "roles" is either the name of a role preset from the pack or an inline
## object keyed by player count.
func roles_for(player_count: int, db: ContentDB) -> Array:
	var roles: Variant = data.get("roles", {})
	if roles is String:
		roles = db.role_presets.get(roles, {})
	if roles is Dictionary:
		return roles.get(str(player_count), [])
	return []
