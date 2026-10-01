class_name ContentDB
extends RefCounted
## All game content (items, equipment, processes, assemblies and role presets),
## merged from one or more JSON packs. Read-only once loaded.
##
## Recipes are graphs of two kinds of step:
## - a *process* turns one item into another with a piece of equipment
##   ("tomato" + knife/chop -> "chopped_tomato"),
## - an *assembly* combines a base item with parts on the counter
##   ("pizza_base" + ["tomato_sauce", "sliced_mozzarella"] -> "raw_pizza_margherita").
## Every non-raw item has exactly one producer, which keeps recipes unambiguous.

const DEFAULT_PACK_DIR := "res://data/packs"
const BURNT_ITEM := "burnt_food"

const KIND_RAW := "raw"
const KIND_INTERMEDIATE := "intermediate"
const KIND_DISH := "dish"
const KIND_WASTE := "waste"
const ITEM_KINDS := [KIND_RAW, KIND_INTERMEDIATE, KIND_DISH, KIND_WASTE]

const EQUIP_TOOL := "tool"
const EQUIP_APPLIANCE := "appliance"
const EQUIP_PASS := "pass"
const EQUIPMENT_KINDS := [EQUIP_TOOL, EQUIP_APPLIANCE, EQUIP_PASS]

## Rough seconds a competent player needs per kind of step. Only used for
## pacing the rival chef and for balancing, never for gameplay rules.
const TAKE_SECONDS := 0.5
const WORK_UNIT_SECONDS := 0.3
const HANDLING_SECONDS := 0.5
const COMBINE_SECONDS := 0.5

var items := {}  # id -> {id, name, kind, pack, [price, patience] for dishes}
var equipment := {}  # id -> {id, name, kind, capacity, pack}
var processes := {}  # id -> {id, input, equipment, action, output, work, cook_time, perfect_window, burn_time, pack}
var assemblies := {}  # output id -> {output, base, parts (sorted), pack}
var role_presets := {}  # name -> {"1": [role, ...], "2": [...], ...}
var pack_ids: Array[String] = []
var pack_names := {}  # pack id -> display name, e.g. "italian" -> "Italian"
var load_errors: Array[String] = []

var _producers := {}  # item id -> {"kind": "process"|"assembly", "id": String}
var _process_index := {}  # "input@equipment" -> process id
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
	var equipment_data: Dictionary = data.get("equipment", {})
	for id in equipment_data:
		if equipment.has(id):
			load_errors.append("%s: duplicate equipment '%s'" % [pack_id, id])
			continue
		var eq: Dictionary = equipment_data[id].duplicate()
		eq["id"] = id
		eq["pack"] = pack_id
		eq["name"] = str(eq.get("name", id))
		eq["kind"] = str(eq.get("kind", EQUIP_TOOL))
		eq["capacity"] = int(eq.get("capacity", 1))
		equipment[id] = eq
	for raw in data.get("processes", []):
		var proc := {
			"id": str(raw.get("id", "")),
			"input": str(raw.get("input", "")),
			"equipment": str(raw.get("equipment", "")),
			"action": str(raw.get("action", "")),
			"output": str(raw.get("output", "")),
			"work": float(raw.get("work", 0.0)),
			"cook_time": float(raw.get("cook_time", 0.0)),
			"perfect_window": float(raw.get("perfect_window", 0.0)),
			"burn_time": float(raw.get("burn_time", 0.0)),
			"pack": pack_id,
		}
		if proc.id.is_empty() or processes.has(proc.id):
			load_errors.append("%s: missing or duplicate process id '%s'" % [pack_id, proc.id])
			continue
		processes[proc.id] = proc
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
	_process_index.clear()
	_assemblies_by_base.clear()
	_nominal_cache.clear()
	for proc in processes.values():
		_add_producer(proc.output, "process", proc.id)
		var key: String = proc.input + "@" + proc.equipment
		if _process_index.has(key):
			load_errors.append("two processes for '%s' with '%s'" % [proc.input, proc.equipment])
		_process_index[key] = proc.id
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


func is_dish(id: String) -> bool:
	return items.get(id, {}).get("kind", "") == KIND_DISH


func is_raw(id: String) -> bool:
	return items.get(id, {}).get("kind", "") == KIND_RAW


func is_passive(proc: Dictionary) -> bool:
	return float(proc.get("cook_time", 0.0)) > 0.0


func equipment_kind(id: String) -> String:
	return str(equipment.get(id, {}).get("kind", ""))


## The id an item counts as. A base item with parts on it counts as the
## assembly it completes, e.g. pizza_base + [sauce, cheese] is a
## "raw_pizza_margherita". Unfinished assemblies return "".
func effective_id(type: String, contents: Array) -> String:
	if contents.is_empty():
		return type
	for output in _assemblies_by_base.get(type, []):
		if assemblies[output].parts == contents:
			return output
	return ""


## The process that runs when an item goes into / is worked with a piece of
## equipment, or {} if that equipment can't do anything with it.
func process_for(input_id: String, equipment_id: String) -> Dictionary:
	var id: String = _process_index.get(input_id + "@" + equipment_id, "")
	return processes.get(id, {})


## Result of dropping the source item onto the target item.
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


## How an item is made: {"kind": "process"|"assembly", "id": ...}, or {} for
## raw ingredients (they come from crates).
func producer(id: String) -> Dictionary:
	return _producers.get(id, {})


## The items an item is made from (process input, or assembly base + parts).
func dependencies(id: String) -> Array:
	var prod := producer(id)
	if prod.is_empty():
		return []
	if prod.kind == "process":
		return [processes[prod.id].input]
	var asm: Dictionary = assemblies[prod.id]
	return [asm.base] + asm.parts


## Ids of all processes in an item's recipe tree (repeats included).
func process_steps(id: String) -> Array:
	var steps: Array = []
	_collect_steps(id, steps, 0)
	return steps


func _collect_steps(id: String, steps: Array, depth: int) -> void:
	if depth > 32:
		return
	var prod := producer(id)
	if not prod.is_empty() and prod.kind == "process":
		steps.append(prod.id)
	for dep in dependencies(id):
		_collect_steps(dep, steps, depth + 1)


## Raw ingredients needed for an item, sorted and unique.
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


## Equipment needed for an item, sorted and unique (not including the pass).
func equipment_requirements(id: String) -> Array:
	var result := {}
	for step in process_steps(id):
		result[processes[step].equipment] = true
	var list := result.keys()
	list.sort()
	return list


## Step-by-step instructions for making an item from raw ingredients, in an
## order that works (everything is made before it is used). Each step is
## {"kind": "process", "process": id, "input", "equipment", "action",
##  "output", "work", "cook_time"} or
## {"kind": "assembly", "base", "parts", "output"}.
## Used by the recipe book.
func recipe_steps(id: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	_collect_recipe(id, steps, {}, 0)
	return steps


func _collect_recipe(id: String, steps: Array[Dictionary], done: Dictionary, depth: int) -> void:
	if depth > 32 or done.has(id):
		return
	var prod := producer(id)
	if prod.is_empty():
		return
	for dep in dependencies(id):
		_collect_recipe(dep, steps, done, depth + 1)
	done[id] = true
	if prod.kind == "process":
		var proc: Dictionary = processes[prod.id]
		steps.append({
			"kind": "process", "process": proc.id, "input": proc.input, "equipment": proc.equipment,
			"action": proc.action, "output": proc.output, "work": proc.work, "cook_time": proc.cook_time,
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
	if prod.kind == "process":
		var proc: Dictionary = processes[prod.id]
		var step_time: float = proc.cook_time if is_passive(proc) else proc.work * WORK_UNIT_SECONDS
		return _nominal(proc.input, depth + 1) + step_time + HANDLING_SECONDS
	var asm: Dictionary = assemblies[prod.id]
	var total := _nominal(asm.base, depth + 1)
	for part in asm.parts:
		total += _nominal(part, depth + 1) + COMBINE_SECONDS
	return total


# --- Validation --------------------------------------------------------------

## Returns a list of human-readable problems with the loaded content.
func validate() -> Array[String]:
	var errors: Array[String] = load_errors.duplicate()
	if not items.has(BURNT_ITEM):
		errors.append("missing the '%s' item" % BURNT_ITEM)
	for item in items.values():
		if not ITEM_KINDS.has(item.kind):
			errors.append("item '%s' has unknown kind '%s'" % [item.id, item.kind])
		var has_producer := _producers.has(item.id)
		if item.kind == KIND_RAW and has_producer:
			errors.append("raw item '%s' must not have a producer" % item.id)
		if (item.kind == KIND_INTERMEDIATE or item.kind == KIND_DISH) and not has_producer:
			errors.append("item '%s' has no process or assembly that makes it" % item.id)
		if item.kind == KIND_DISH:
			if float(item.get("price", 0)) <= 0.0:
				errors.append("dish '%s' needs a price" % item.id)
			if float(item.get("patience", 0)) <= 0.0:
				errors.append("dish '%s' needs a patience" % item.id)
	for eq in equipment.values():
		if not EQUIPMENT_KINDS.has(eq.kind):
			errors.append("equipment '%s' has unknown kind '%s'" % [eq.id, eq.kind])
		if eq.kind == EQUIP_APPLIANCE and eq.capacity < 1:
			errors.append("appliance '%s' needs a capacity of at least 1" % eq.id)
	for proc in processes.values():
		var where := "process '%s'" % proc.id
		for key in ["input", "output"]:
			if not items.has(proc[key]):
				errors.append("%s: unknown %s item '%s'" % [where, key, proc[key]])
		var eq_kind := equipment_kind(proc.equipment)
		if eq_kind.is_empty():
			errors.append("%s: unknown equipment '%s'" % [where, proc.equipment])
		elif eq_kind == EQUIP_PASS:
			errors.append("%s: the serving window can't process food" % where)
		if proc.action.is_empty():
			errors.append("%s: needs an action" % where)
		if is_passive(proc):
			if eq_kind == EQUIP_TOOL:
				errors.append("%s: cooking over time needs an appliance, not a tool" % where)
			if proc.burn_time > 0.0 and proc.perfect_window > proc.burn_time:
				errors.append("%s: perfect_window is longer than burn_time" % where)
		elif proc.work <= 0.0:
			errors.append("%s: needs either work or cook_time" % where)
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
				for eq in role.get("equipment", []):
					if not equipment.has(eq):
						errors.append("role preset '%s': unknown equipment '%s'" % [preset_name, eq])
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
