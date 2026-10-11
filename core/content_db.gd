class_name ContentDB
extends RefCounted
## All game content (items, stations, recipes, assemblies and role presets),
## merged from one or more JSON packs. Read-only once loaded.
##
## Cooking works like in Overcooked:
## - a *station* is a place in the kitchen: a counter spot, a chopping board,
##   a mixing bowl, a pot, a pan, an oven... Most stations are containers that
##   hold a few items;
## - a *recipe* says what a station makes from what it holds: a board with a
##   tomato makes chopped tomato (by hand: swipe to chop), a pot with fresh
##   pasta makes boiled pasta (on its own, over time). The contents decide the
##   result, so one pot can boil pasta or cook a sauce;
## - an *assembly* is food put together on a base, in any order: a plate with
##   chopped tomato, mozzarella and basil is a caprese; a dough with tomato and
##   mozzarella is a raw pizza, ready for the oven.
## Every non-raw item has exactly one producer, which keeps recipes unambiguous.

const DEFAULT_PACK_DIR := "res://data/packs"
const BURNT_ITEM := "burnt_food"
const PLATE := "plate"

const KIND_RAW := "raw"
const KIND_INTERMEDIATE := "intermediate"
const KIND_DISH := "dish"
const KIND_WASTE := "waste"
const ITEM_KINDS := [KIND_RAW, KIND_INTERMEDIATE, KIND_DISH, KIND_WASTE]

## A counter spot holds any one item and does nothing with it.
const STATION_COUNTER := "counter"
## Worked by hand with a gesture mini-game (board, bowl, gadgets).
const STATION_MANUAL := "manual"
## Cooks on its own over time, then burns (pot, pan, oven, fryer, grill).
const STATION_COOK := "cook"
## The serving window.
const STATION_PASS := "pass"
const STATION_KINDS := [STATION_COUNTER, STATION_MANUAL, STATION_COOK, STATION_PASS]

## Rough seconds a competent player needs per kind of step. Only used for
## pacing the rival chef and for balancing, never for gameplay rules.
const TAKE_SECONDS := 0.5
const WORK_UNIT_SECONDS := 0.3
const HANDLING_SECONDS := 0.5
const COMBINE_SECONDS := 0.5

var items := {}  # id -> {id, name, kind, pack, [price, patience] for dishes}
var stations := {}  # id -> {id, name, kind, capacity, holds_anything, pack}
var recipes := {}  # id -> {id, station, inputs (sorted), action, output, work, cook_time, perfect_window, burn_time, pack}
var assemblies := {}  # output id -> {output, base, parts (sorted), pack}
var role_presets := {}  # name -> {"1": [role, ...], "2": [...], ...}
var pack_ids: Array[String] = []
var pack_names := {}  # pack id -> display name, e.g. "italian" -> "Italian"
var load_errors: Array[String] = []

var _producers := {}  # item id -> {"kind": "recipe"|"assembly", "id": String}
var _recipes_by_station := {}  # station id -> Array of recipe ids
var _assemblies_by_base := {}  # base id -> Array of assembly output ids
var _nominal_cache := {}


## Loads every *.json pack in a directory.
static func load_dir(dir_path: String = DEFAULT_PACK_DIR) -> ContentDB:
	return load_files(DataFiles.list_files(dir_path, ".json"))


static func load_files(paths: Array) -> ContentDB:
	var db := ContentDB.new()
	for path in paths:
		var data: Variant = DataFiles.read_json(path)
		if data is Dictionary:
			db.add_pack(data, path)
		else:
			db.load_errors.append("%s: not a JSON object" % path)
	return db


func add_pack(data: Dictionary, source: String = "") -> void:
	var pack_id := str(data.get("id", source))
	pack_ids.append(pack_id)
	pack_names[pack_id] = str(data.get("name", pack_id))
	var items_data: Dictionary = data.get("items", {})
	for id in items_data:
		if items.has(id):
			load_errors.append("%s: duplicate item '%s'" % [pack_id, id])
			continue
		var item: Dictionary = items_data[id].duplicate()
		item["id"] = id
		item["pack"] = pack_id
		item["name"] = str(item.get("name", id))
		item["kind"] = str(item.get("kind", KIND_INTERMEDIATE))
		items[id] = item
	var stations_data: Dictionary = data.get("stations", {})
	for id in stations_data:
		if stations.has(id):
			load_errors.append("%s: duplicate station '%s'" % [pack_id, id])
			continue
		var st: Dictionary = stations_data[id].duplicate()
		st["id"] = id
		st["pack"] = pack_id
		st["name"] = str(st.get("name", id))
		st["kind"] = str(st.get("kind", STATION_COUNTER))
		st["capacity"] = int(st.get("capacity", 1))
		st["holds_anything"] = bool(st.get("holds_anything", st.kind == STATION_COUNTER))
		stations[id] = st
	for raw in data.get("recipes", []):
		var inputs: Array = []
		for input in raw.get("inputs", []):
			inputs.append(str(input))
		inputs.sort()
		var recipe := {
			"id": str(raw.get("id", "")),
			"station": str(raw.get("station", "")),
			"inputs": inputs,
			"action": str(raw.get("action", "")),
			"output": str(raw.get("output", "")),
			"work": float(raw.get("work", 0.0)),
			"cook_time": float(raw.get("cook_time", 0.0)),
			"perfect_window": float(raw.get("perfect_window", 0.0)),
			"burn_time": float(raw.get("burn_time", 0.0)),
			"pack": pack_id,
		}
		if recipe.id.is_empty() or recipes.has(recipe.id):
			load_errors.append("%s: missing or duplicate recipe id '%s'" % [pack_id, recipe.id])
			continue
		recipes[recipe.id] = recipe
	for raw in data.get("assemblies", []):
		var parts: Array = []
		for part in raw.get("parts", []):
			parts.append(str(part))
		parts.sort()
		var asm := {
			"output": str(raw.get("output", "")),
			"base": str(raw.get("base", "")),
			"parts": parts,
			"pack": pack_id,
		}
		if asm.output.is_empty() or assemblies.has(asm.output):
			load_errors.append("%s: missing or duplicate assembly '%s'" % [pack_id, asm.output])
			continue
		assemblies[asm.output] = asm
	var presets: Dictionary = data.get("role_presets", {})
	for preset_name in presets:
		if role_presets.has(preset_name):
			load_errors.append("%s: duplicate role preset '%s'" % [pack_id, preset_name])
			continue
		role_presets[preset_name] = presets[preset_name]
	_rebuild_indexes()


func _rebuild_indexes() -> void:
	_producers.clear()
	_recipes_by_station.clear()
	_assemblies_by_base.clear()
	_nominal_cache.clear()
	for recipe in recipes.values():
		_add_producer(recipe.output, "recipe", recipe.id)
		if not _recipes_by_station.has(recipe.station):
			_recipes_by_station[recipe.station] = []
		for other_id in _recipes_by_station[recipe.station]:
			if recipes[other_id].inputs == recipe.inputs:
				load_errors.append("two recipes for %s in the '%s'" % [recipe.inputs, recipe.station])
		_recipes_by_station[recipe.station].append(recipe.id)
	for asm in assemblies.values():
		_add_producer(asm.output, "assembly", asm.output)
		if not _assemblies_by_base.has(asm.base):
			_assemblies_by_base[asm.base] = []
		_assemblies_by_base[asm.base].append(asm.output)


func _add_producer(item_id: String, kind: String, id: String) -> void:
	if _producers.has(item_id):
		var msg := "item '%s' has more than one producer" % item_id
		if not load_errors.has(msg):
			load_errors.append(msg)
		return
	_producers[item_id] = {"kind": kind, "id": id}


# --- Queries -----------------------------------------------------------------

func item_name(id: String) -> String:
	return str(items.get(id, {}).get("name", id))


func station_name(id: String) -> String:
	return str(stations.get(id, {}).get("name", id))


func is_dish(id: String) -> bool:
	return items.get(id, {}).get("kind", "") == KIND_DISH


func is_raw(id: String) -> bool:
	return items.get(id, {}).get("kind", "") == KIND_RAW


func station_kind(id: String) -> String:
	return str(stations.get(id, {}).get("kind", ""))


func station_capacity(id: String) -> int:
	return int(stations.get(id, {}).get("capacity", 0))


func is_cook_recipe(recipe: Dictionary) -> bool:
	return float(recipe.get("cook_time", 0.0)) > 0.0


## The id an item counts as. A base item with parts on it counts as the
## assembly it completes, e.g. plate + [tomato, mozzarella, basil] is a
## "caprese". Unfinished assemblies return "".
func effective_id(type: String, contents: Array) -> String:
	if contents.is_empty():
		return type
	for output in _assemblies_by_base.get(type, []):
		if assemblies[output].parts == contents:
			return output
	return ""


## The recipe a station runs with exactly these contents (item ids), or {}.
func recipe_for(station: String, contents: Array) -> Dictionary:
	var sorted := contents.duplicate()
	sorted.sort()
	for id in _recipes_by_station.get(station, []):
		if recipes[id].inputs == sorted:
			return recipes[id]
	return {}


## Whether a station holding `contents` (item ids) may take `new_id` too:
## there's room, and the contents can still become one of its recipes (or the
## station holds anything, like a counter or a board, and is empty).
func accepts(station: String, contents: Array, new_id: String) -> bool:
	var st: Dictionary = stations.get(station, {})
	if st.is_empty() or st.kind == STATION_PASS or new_id.is_empty():
		return false
	if contents.size() >= st.capacity:
		return false
	if st.holds_anything and contents.is_empty():
		return true
	if st.kind == STATION_COUNTER:
		return false
	var wanted := contents.duplicate()
	wanted.append(new_id)
	for id in _recipes_by_station.get(station, []):
		if _is_sub_multiset(wanted, recipes[id].inputs):
			return true
	return false


## The stations that have a recipe using this item (for hints and the bot).
func stations_using(item_id: String) -> Array[String]:
	var result: Array[String] = []
	for recipe in recipes.values():
		if recipe.inputs.has(item_id) and not result.has(recipe.station):
			result.append(recipe.station)
	return result


static func _is_sub_multiset(small: Array, big: Array) -> bool:
	var left := big.duplicate()
	for value in small:
		var i := left.find(value)
		if i < 0:
			return false
		left.remove_at(i)
	return true


## Result of putting the source item onto the target item.
## Returns {"ok": true, "keep": "target"|"source", "contents": Array} where
## "keep" says which of the two items survives as the base, or {"ok": false}.
func combine(target_type: String, target_contents: Array, source_type: String, source_contents: Array) -> Dictionary:
	var source_part := effective_id(source_type, source_contents)
	if not source_part.is_empty():
		var as_target: Variant = _contents_with(target_type, target_contents, source_part)
		if as_target != null:
			return {"ok": true, "keep": "target", "contents": as_target}
	var target_part := effective_id(target_type, target_contents)
	if not target_part.is_empty():
		var as_source: Variant = _contents_with(source_type, source_contents, target_part)
		if as_source != null:
			return {"ok": true, "keep": "source", "contents": as_source}
	return {"ok": false}


## Contents of `base` after adding `part`, or null when no assembly allows it.
func _contents_with(base: String, contents: Array, part: String) -> Variant:
	if contents.has(part) or not _assemblies_by_base.has(base):
		return null
	var new_contents := contents.duplicate()
	new_contents.append(part)
	new_contents.sort()
	for output in _assemblies_by_base[base]:
		var parts: Array = assemblies[output].parts
		if new_contents.all(func(p): return parts.has(p)):
			return new_contents
	return null


## How an item is made: {"kind": "recipe"|"assembly", "id": ...}, or {} for
## raw ingredients (they come from crates).
func producer(id: String) -> Dictionary:
	return _producers.get(id, {})


## The items an item is made from (recipe inputs, or assembly base + parts).
func dependencies(id: String) -> Array:
	var prod := producer(id)
	if prod.is_empty():
		return []
	if prod.kind == "recipe":
		return recipes[prod.id].inputs.duplicate()
	var asm: Dictionary = assemblies[prod.id]
	return [asm.base] + asm.parts


## Ids of all recipes in an item's recipe tree (repeats included).
func recipe_ids_in(id: String) -> Array:
	var steps: Array = []
	_collect_recipe_ids(id, steps, 0)
	return steps


func _collect_recipe_ids(id: String, steps: Array, depth: int) -> void:
	if depth > 32:
		return
	var prod := producer(id)
	if not prod.is_empty() and prod.kind == "recipe":
		steps.append(prod.id)
	for dep in dependencies(id):
		_collect_recipe_ids(dep, steps, depth + 1)


## Raw ingredients needed for an item, sorted and unique (plates included).
func raw_requirements(id: String) -> Array:
	var result := {}
	_collect_raw(id, result, 0)
	var list := result.keys()
	list.sort()
	return list


func _collect_raw(id: String, result: Dictionary, depth: int) -> void:
	if depth > 32:
		return
	if producer(id).is_empty():
		result[id] = true
		return
	for dep in dependencies(id):
		_collect_raw(dep, result, depth + 1)


## Stations needed for an item, sorted and unique (counters and the serving
## window not included).
func station_requirements(id: String) -> Array:
	var result := {}
	for recipe_id in recipe_ids_in(id):
		result[recipes[recipe_id].station] = true
	var list := result.keys()
	list.sort()
	return list


## Longest cooking time in an item's recipe tree (0 if nothing cooks).
func longest_cook(id: String) -> float:
	var longest := 0.0
	for recipe_id in recipe_ids_in(id):
		longest = maxf(longest, float(recipes[recipe_id].cook_time))
	return longest


## Step-by-step instructions for making an item from raw ingredients, in an
## order that works (everything is made before it is used). Each step is
## {"kind": "recipe", "recipe", "station", "inputs", "action", "output",
##  "work", "cook_time"} or {"kind": "assembly", "base", "parts", "output"}.
## Used by the recipe book.
func recipe_steps(id: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	_collect_steps(id, steps, {}, 0)
	return steps


func _collect_steps(id: String, steps: Array[Dictionary], done: Dictionary, depth: int) -> void:
	if depth > 32 or done.has(id):
		return
	var prod := producer(id)
	if prod.is_empty():
		return
	for dep in dependencies(id):
		_collect_steps(dep, steps, done, depth + 1)
	done[id] = true
	if prod.kind == "recipe":
		var recipe: Dictionary = recipes[prod.id]
		steps.append({
			"kind": "recipe", "recipe": recipe.id, "station": recipe.station, "inputs": recipe.inputs.duplicate(),
			"action": recipe.action, "output": recipe.output, "work": recipe.work, "cook_time": recipe.cook_time,
		})
	else:
		var asm: Dictionary = assemblies[prod.id]
		steps.append({"kind": "assembly", "base": asm.base, "parts": asm.parts.duplicate(), "output": asm.output})


## Seconds one competent cook needs to make an item from scratch, doing every
## step in sequence. Used to pace the rival chef.
func nominal_seconds(id: String) -> float:
	if _nominal_cache.has(id):
		return _nominal_cache[id]
	var seconds := _nominal(id, 0)
	_nominal_cache[id] = seconds
	return seconds


func _nominal(id: String, depth: int) -> float:
	if depth > 32:
		return 0.0
	var prod := producer(id)
	if prod.is_empty():
		return TAKE_SECONDS
	if prod.kind == "recipe":
		var recipe: Dictionary = recipes[prod.id]
		var total: float = recipe.cook_time if is_cook_recipe(recipe) else recipe.work * WORK_UNIT_SECONDS
		for input in recipe.inputs:
			total += _nominal(input, depth + 1) + HANDLING_SECONDS
		return total
	var asm: Dictionary = assemblies[prod.id]
	var sum := _nominal(asm.base, depth + 1)
	for part in asm.parts:
		sum += _nominal(part, depth + 1) + COMBINE_SECONDS
	return sum


# --- Validation --------------------------------------------------------------

## Returns a list of human-readable problems with the loaded content.
func validate() -> Array[String]:
	var errors: Array[String] = load_errors.duplicate()
	for required in [BURNT_ITEM, PLATE]:
		if not items.has(required):
			errors.append("missing the '%s' item" % required)
	for item in items.values():
		if not ITEM_KINDS.has(item.kind):
			errors.append("item '%s' has unknown kind '%s'" % [item.id, item.kind])
		var has_producer := _producers.has(item.id)
		if item.kind == KIND_RAW and has_producer:
			errors.append("raw item '%s' must not have a producer" % item.id)
		if (item.kind == KIND_INTERMEDIATE or item.kind == KIND_DISH) and not has_producer:
			errors.append("item '%s' has no recipe or assembly that makes it" % item.id)
		if item.kind == KIND_DISH:
			if float(item.get("price", 0)) <= 0.0:
				errors.append("dish '%s' needs a price" % item.id)
			if float(item.get("patience", 0)) <= 0.0:
				errors.append("dish '%s' needs a patience" % item.id)
	for st in stations.values():
		if not STATION_KINDS.has(st.kind):
			errors.append("station '%s' has unknown kind '%s'" % [st.id, st.kind])
		if st.kind != STATION_PASS and st.capacity < 1:
			errors.append("station '%s' needs a capacity of at least 1" % st.id)
	for recipe in recipes.values():
		var where := "recipe '%s'" % recipe.id
		var kind := station_kind(recipe.station)
		if kind.is_empty():
			errors.append("%s: unknown station '%s'" % [where, recipe.station])
		elif kind == STATION_COUNTER or kind == STATION_PASS:
			errors.append("%s: the '%s' can't cook" % [where, recipe.station])
		if recipe.inputs.is_empty():
			errors.append("%s: needs inputs" % where)
		elif not kind.is_empty() and recipe.inputs.size() > station_capacity(recipe.station):
			errors.append("%s: more inputs than the '%s' holds" % [where, recipe.station])
		for input in recipe.inputs:
			if not items.has(input):
				errors.append("%s: unknown input '%s'" % [where, input])
		if not items.has(recipe.output):
			errors.append("%s: unknown output '%s'" % [where, recipe.output])
		if kind == STATION_MANUAL:
			if recipe.work <= 0.0 or recipe.action.is_empty():
				errors.append("%s: work by hand needs an action and work" % where)
		elif kind == STATION_COOK:
			if recipe.cook_time <= 0.0:
				errors.append("%s: needs a cook_time" % where)
			if recipe.burn_time > 0.0 and recipe.perfect_window > recipe.burn_time:
				errors.append("%s: perfect_window is longer than burn_time" % where)
	for asm in assemblies.values():
		var where := "assembly '%s'" % asm.output
		if not items.has(asm.output):
			errors.append("%s: unknown output item" % where)
		if not items.has(asm.base):
			errors.append("%s: unknown base '%s'" % [where, asm.base])
		if assemblies.has(asm.base):
			errors.append("%s: base '%s' can't itself be an assembly" % [where, asm.base])
		if asm.parts.is_empty():
			errors.append("%s: needs at least one part" % where)
		for part in asm.parts:
			if not items.has(part):
				errors.append("%s: unknown part '%s'" % [where, part])
	for id in items:
		if _has_cycle(id, {}, 0):
			errors.append("recipe for '%s' contains a cycle" % id)
			break
	for preset_name in role_presets:
		var preset: Dictionary = role_presets[preset_name]
		for count in preset:
			for role in preset[count]:
				for crate in role.get("crates", []):
					if not is_raw(crate):
						errors.append("role preset '%s': crate '%s' is not a raw ingredient" % [preset_name, crate])
				var role_stations: Dictionary = role.get("stations", {})
				for st in role_stations:
					if not stations.has(st):
						errors.append("role preset '%s': unknown station '%s'" % [preset_name, st])
					elif int(role_stations[st]) < 1:
						errors.append("role preset '%s': needs at least one '%s'" % [preset_name, st])
	return errors


func _has_cycle(id: String, visiting: Dictionary, depth: int) -> bool:
	if visiting.has(id) or depth > 64:
		return true
	visiting[id] = true
	for dep in dependencies(id):
		if _has_cycle(dep, visiting, depth + 1):
			return true
	visiting.erase(id)
	return false
