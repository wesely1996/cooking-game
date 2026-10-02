class_name KitchenState
extends RefCounted
## The authoritative state of every player's kitchen: counter slots, the
## crates and equipment each player owns, and what is cooking in appliances.
##
## All changes go through do_intent() with a plain Dictionary, so the same
## code serves solo play, the LAN host and (later) the online host. Every
## change is recorded as an event Dictionary for the UI and network layer.

const DEFAULT_SLOTS := 5
## Largest amount of work one intent may add. Mini-games send one unit per
## successful gesture, so anything bigger is a bug or a cheat.
const MAX_WORK_PER_INTENT := 3.0

var db: ContentDB
var players: Array[PlayerKitchen] = []
## Called as serve_handler.call(player: int, item: KitchenItem) and returns
## {"ok": bool, "error": String, ...}. Set by the Shift that owns the orders.
var serve_handler: Callable

var _next_uid := 1
var _events: Array[Dictionary] = []


class PlayerKitchen:
	extends RefCounted
	var index := 0
	var role := ""
	var crates: Array = []
	var tools: Array = []
	var appliances := {}  # equipment id -> Array of ApplianceSlot (null = empty)
	var serves := false
	var slots: Array = []  # KitchenItem or null

	func free_slot() -> int:
		return slots.find(null)

	func free_slot_count() -> int:
		return slots.count(null)

	func owns(equipment_id: String) -> bool:
		return tools.has(equipment_id) or appliances.has(equipment_id)


class ApplianceSlot:
	extends RefCounted
	var item: KitchenItem
	var process := {}  # the process running (or that ran) on the item
	var progress := 0.0  # seconds cooked (passive) or work done (manual)
	var done := false
	var since_ready := 0.0
	var burnt := false

	func to_dict() -> Dictionary:
		return {
			"item": item.to_dict(),
			"process": process.get("id", ""),
			"progress": progress,
			"done": done,
			"since_ready": since_ready,
			"burnt": burnt,
		}


## roles: one Dictionary per player: {"name", "crates", "equipment", "slots"}.
func _init(p_db: ContentDB, roles: Array) -> void:
	db = p_db
	for i in roles.size():
		var role: Dictionary = roles[i]
		var pk := PlayerKitchen.new()
		pk.index = i
		pk.role = str(role.get("name", "Chef %d" % (i + 1)))
		pk.crates = role.get("crates", []).duplicate()
		for eq_id in role.get("equipment", []):
			match db.equipment_kind(eq_id):
				ContentDB.EQUIP_TOOL:
					pk.tools.append(eq_id)
				ContentDB.EQUIP_APPLIANCE:
					var appliance_slots := []
					appliance_slots.resize(int(db.equipment[eq_id].capacity))
					pk.appliances[eq_id] = appliance_slots
				ContentDB.EQUIP_PASS:
					pk.serves = true
		pk.slots.resize(int(role.get("slots", DEFAULT_SLOTS)))
		players.append(pk)


# --- Queries -----------------------------------------------------------------

func item_at(player: int, slot: int) -> KitchenItem:
	if player < 0 or player >= players.size():
		return null
	var slots := players[player].slots
	if slot < 0 or slot >= slots.size():
		return null
	return slots[slot]


func effective_id(item: KitchenItem) -> String:
	return db.effective_id(item.type, item.contents)


## Index of the player who owns the serving window, or -1.
func pass_owner() -> int:
	for pk in players:
		if pk.serves:
			return pk.index
	return -1


func owners_of_crate(ingredient: String) -> Array[int]:
	var result: Array[int] = []
	for pk in players:
		if pk.crates.has(ingredient):
			result.append(pk.index)
	return result


func owners_of_equipment(equipment_id: String) -> Array[int]:
	var result: Array[int] = []
	for pk in players:
		if pk.owns(equipment_id):
			result.append(pk.index)
	return result


func drain_events() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events


## Full state for a joining or reconnecting client.
func snapshot() -> Dictionary:
	var result := []
	for pk in players:
		var slots := []
		for item in pk.slots:
			slots.append(item.to_dict() if item else null)
		var appliances := {}
		for eq_id in pk.appliances:
			var entries := []
			for aslot in pk.appliances[eq_id]:
				entries.append(aslot.to_dict() if aslot else null)
			appliances[eq_id] = entries
		result.append({
			"role": pk.role,
			"crates": pk.crates.duplicate(),
			"tools": pk.tools.duplicate(),
			"serves": pk.serves,
			"slots": slots,
			"appliances": appliances,
		})
	return {"players": result}


## Replaces the counters and appliances with a snapshot from the host (the
## crates, tools and roles come from the level and never change).
func load_snapshot(data: Dictionary) -> void:
	var entries: Array = data.get("players", [])
	for i in mini(entries.size(), players.size()):
		var pk := players[i]
		var entry: Dictionary = entries[i]
		var slots: Array = entry.get("slots", [])
		for s in pk.slots.size():
			pk.slots[s] = KitchenItem.from_dict(slots[s]) if s < slots.size() and slots[s] is Dictionary else null
		var appliances: Dictionary = entry.get("appliances", {})
		for eq in pk.appliances:
			var saved: Array = appliances.get(eq, [])
			var current: Array = pk.appliances[eq]
			for index in current.size():
				current[index] = _appliance_slot_from(saved[index]) if index < saved.size() and saved[index] is Dictionary else null


func _appliance_slot_from(data: Dictionary) -> ApplianceSlot:
	var aslot := ApplianceSlot.new()
	aslot.item = KitchenItem.from_dict(data.get("item", {}))
	aslot.process = db.processes.get(str(data.get("process", "")), {})
	aslot.progress = float(data.get("progress", 0.0))
	aslot.done = bool(data.get("done", false))
	aslot.since_ready = float(data.get("since_ready", 0.0))
	aslot.burnt = bool(data.get("burnt", false))
	return aslot


# --- Intents -----------------------------------------------------------------

## Applies one player action. Returns {"ok": true} or {"ok": false, "error": code}.
func do_intent(intent: Dictionary) -> Dictionary:
	var p := int(intent.get("player", -1))
	if p < 0 or p >= players.size():
		return _fail("bad_player")
	var slot := int(intent.get("slot", -1))
	var eq := str(intent.get("equipment", ""))
	match str(intent.get("type", "")):
		"take":
			return _take(p, str(intent.get("ingredient", "")), slot)
		"work":
			return _work(p, slot, eq, float(intent.get("amount", 1.0)))
		"insert":
			return _insert(p, slot, eq)
		"work_appliance":
			return _work_appliance(p, eq, int(intent.get("index", 0)), float(intent.get("amount", 1.0)))
		"remove":
			return _remove(p, eq, int(intent.get("index", 0)), slot)
		"trash_appliance":
			return _trash_appliance(p, eq, int(intent.get("index", 0)))
		"combine":
			return _combine(p, int(intent.get("from", -1)), int(intent.get("to", -1)))
		"move":
			return _move(p, int(intent.get("from", -1)), int(intent.get("to", -1)))
		"throw":
			return _throw(p, slot, int(intent.get("target", -1)))
		"serve":
			return _serve(p, slot)
		"trash":
			return _trash(p, slot)
	return _fail("unknown_intent")


func _take(p: int, ingredient: String, slot: int) -> Dictionary:
	var pk := players[p]
	if not pk.crates.has(ingredient):
		return _fail("not_owned")
	if slot < 0:
		slot = pk.free_slot()
		if slot < 0:
			return _fail("counter_full")
	elif slot >= pk.slots.size() or pk.slots[slot] != null:
		return _fail("slot_taken")
	var item := KitchenItem.new(_next_uid, ingredient)
	_next_uid += 1
	pk.slots[slot] = item
	_emit({"type": "item_added", "player": p, "slot": slot, "item": item.to_dict()})
	return _ok()


func _work(p: int, slot: int, eq: String, amount: float) -> Dictionary:
	var item := item_at(p, slot)
	if item == null:
		return _fail("empty_slot")
	if not players[p].tools.has(eq):
		return _fail("not_owned")
	var proc := db.process_for(effective_id(item), eq)
	if proc.is_empty():
		return _fail("no_process")
	if amount <= 0.0 or amount > MAX_WORK_PER_INTENT:
		return _fail("bad_amount")
	if item.work_process != proc.id:
		item.work_process = proc.id
		item.work = 0.0
	item.work += amount
	if item.work >= proc.work:
		_transform(item, proc.output)
		_emit({"type": "item_processed", "player": p, "slot": slot, "process": proc.id, "item": item.to_dict()})
	else:
		_emit({"type": "item_worked", "player": p, "slot": slot, "process": proc.id, "progress": item.work / proc.work})
	return _ok()


func _insert(p: int, slot: int, eq: String) -> Dictionary:
	var item := item_at(p, slot)
	if item == null:
		return _fail("empty_slot")
	var appliance: Array = players[p].appliances.get(eq, [])
	if appliance.is_empty():
		return _fail("not_owned")
	var proc := db.process_for(effective_id(item), eq)
	if proc.is_empty():
		return _fail("no_process")
	var index := appliance.find(null)
	if index < 0:
		return _fail("appliance_full")
	var aslot := ApplianceSlot.new()
	aslot.item = item
	aslot.process = proc
	appliance[index] = aslot
	players[p].slots[slot] = null
	_emit({"type": "appliance_inserted", "player": p, "slot": slot, "equipment": eq, "index": index, "item": item.to_dict()})
	return _ok()


func _work_appliance(p: int, eq: String, index: int, amount: float) -> Dictionary:
	var aslot := _appliance_slot(p, eq, index)
	if aslot == null:
		return _fail("empty_appliance")
	if aslot.done or db.is_passive(aslot.process):
		return _fail("no_process")
	if amount <= 0.0 or amount > MAX_WORK_PER_INTENT:
		return _fail("bad_amount")
	aslot.progress += amount
	if aslot.progress >= aslot.process.work:
		_transform(aslot.item, aslot.process.output)
		aslot.done = true
		_emit({"type": "cook_ready", "player": p, "equipment": eq, "index": index, "item": aslot.item.to_dict()})
	else:
		_emit({"type": "appliance_worked", "player": p, "equipment": eq, "index": index, "progress": aslot.progress / aslot.process.work})
	return _ok()


func _remove(p: int, eq: String, index: int, slot: int) -> Dictionary:
	var aslot := _appliance_slot(p, eq, index)
	if aslot == null:
		return _fail("empty_appliance")
	var pk := players[p]
	if slot < 0:
		slot = pk.free_slot()
		if slot < 0:
			return _fail("counter_full")
	elif slot >= pk.slots.size() or pk.slots[slot] != null:
		return _fail("slot_taken")
	var item := aslot.item
	if aslot.done and not aslot.burnt and db.is_passive(aslot.process):
		item.perfect = aslot.since_ready <= aslot.process.perfect_window
	pk.appliances[eq][index] = null
	pk.slots[slot] = item
	_emit({"type": "appliance_removed", "player": p, "equipment": eq, "index": index, "slot": slot, "item": item.to_dict()})
	return _ok()


func _trash_appliance(p: int, eq: String, index: int) -> Dictionary:
	var aslot := _appliance_slot(p, eq, index)
	if aslot == null:
		return _fail("empty_appliance")
	players[p].appliances[eq][index] = null
	_emit({"type": "item_trashed", "player": p, "equipment": eq, "index": index, "item": aslot.item.to_dict()})
	return _ok()


func _combine(p: int, from: int, to: int) -> Dictionary:
	var source := item_at(p, from)
	var target := item_at(p, to)
	if source == null or target == null or from == to:
		return _fail("empty_slot")
	var result := db.combine(target.type, target.contents, source.type, source.contents)
	if not result.ok:
		return _fail("cannot_combine")
	var kept := target if result.keep == "target" else source
	kept.contents = result.contents
	players[p].slots[from] = null
	players[p].slots[to] = kept
	_emit({"type": "items_combined", "player": p, "from": from, "to": to, "item": kept.to_dict()})
	return _ok()


func _move(p: int, from: int, to: int) -> Dictionary:
	var item := item_at(p, from)
	if item == null:
		return _fail("empty_slot")
	var slots := players[p].slots
	if to < 0 or to >= slots.size() or slots[to] != null:
		return _fail("slot_taken")
	slots[to] = item
	slots[from] = null
	_emit({"type": "item_moved", "player": p, "from": from, "to": to})
	return _ok()


func _throw(p: int, slot: int, target: int) -> Dictionary:
	var item := item_at(p, slot)
	if item == null:
		return _fail("empty_slot")
	if target < 0 or target >= players.size() or target == p:
		return _fail("bad_target")
	var target_slot := players[target].free_slot()
	if target_slot < 0:
		return _fail("target_full")
	players[p].slots[slot] = null
	players[target].slots[target_slot] = item
	_emit({"type": "item_thrown", "player": p, "slot": slot, "target": target, "target_slot": target_slot, "item": item.to_dict()})
	return _ok()


func _serve(p: int, slot: int) -> Dictionary:
	var item := item_at(p, slot)
	if item == null:
		return _fail("empty_slot")
	if not players[p].serves:
		return _fail("not_owned")
	if not serve_handler.is_valid():
		return _fail("no_customers")
	var result: Dictionary = serve_handler.call(p, item)
	if result.get("ok", false):
		players[p].slots[slot] = null
		_emit({"type": "item_served", "player": p, "slot": slot, "item": item.to_dict()})
	return result


func _trash(p: int, slot: int) -> Dictionary:
	var item := item_at(p, slot)
	if item == null:
		return _fail("empty_slot")
	players[p].slots[slot] = null
	_emit({"type": "item_trashed", "player": p, "slot": slot, "item": item.to_dict()})
	return _ok()


# --- Time --------------------------------------------------------------------

## Advances everything that cooks on its own (ovens, boiling pots).
func tick(delta: float) -> void:
	for pk in players:
		for eq in pk.appliances:
			var appliance: Array = pk.appliances[eq]
			for index in appliance.size():
				var aslot: ApplianceSlot = appliance[index]
				if aslot == null or aslot.burnt or not db.is_passive(aslot.process):
					continue
				_cook(pk.index, eq, index, aslot, delta)


func _cook(p: int, eq: String, index: int, aslot: ApplianceSlot, delta: float) -> void:
	var proc := aslot.process
	aslot.progress += delta
	if not aslot.done and aslot.progress >= proc.cook_time:
		_transform(aslot.item, proc.output)
		aslot.done = true
		aslot.since_ready = aslot.progress - proc.cook_time
		_emit({"type": "cook_ready", "player": p, "equipment": eq, "index": index, "item": aslot.item.to_dict()})
	elif aslot.done:
		aslot.since_ready += delta
	if aslot.done and proc.burn_time > 0.0 and aslot.since_ready >= proc.burn_time:
		_transform(aslot.item, ContentDB.BURNT_ITEM)
		aslot.burnt = true
		_emit({"type": "cook_burnt", "player": p, "equipment": eq, "index": index, "item": aslot.item.to_dict()})


# --- Helpers -----------------------------------------------------------------

func _appliance_slot(p: int, eq: String, index: int) -> ApplianceSlot:
	var appliance: Array = players[p].appliances.get(eq, [])
	if index < 0 or index >= appliance.size():
		return null
	return appliance[index]


func _transform(item: KitchenItem, new_type: String) -> void:
	item.type = new_type
	item.contents = []
	item.work = 0.0
	item.work_process = ""
	item.perfect = false


func _emit(event: Dictionary) -> void:
	_events.append(event)


func _ok() -> Dictionary:
	return {"ok": true}


func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
