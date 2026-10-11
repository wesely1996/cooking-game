class_name KitchenBot
extends RefCounted
## A simple bot that controls every player in a shift, used for headless
## simulations: it checks that levels can really be finished through the same
## intents real players send, and gives rough numbers for balancing.
##
## Every step it re-plans from scratch. For the oldest orders it walks the
## recipe tree backwards ("to serve a pizza I need a raw pizza at the oven
## owner, which needs a base, sauce and cheese there, ...") and collects one
## next action per branch. Each player then does their first possible action
## and is busy for a human-like time afterwards.

## Seconds a player is busy after each kind of action.
const ACTION_SECONDS := {
	"take": 0.4, "work": 0.25, "work_appliance": 0.3, "insert": 0.4, "remove": 0.4,
	"combine": 0.45, "throw": 0.5, "serve": 0.4, "trash": 0.4, "trash_appliance": 0.4,
}
const MAX_DEPTH := 16
## Destination meaning "make it, but leave it wherever it ends up".
const ANYWHERE := -1

## How many of the oldest orders the bot works on at once.
var max_orders := 2
## 1.0 = roughly an average human; higher is faster.
var speed := 1.0
## Optional func(order: Dictionary) -> bool: only plan for matching orders.
var order_filter: Callable
var actions_done := 0
var actions_failed := 0

var _busy_until: Array[float] = []
var _claimed := {}  # item uid -> true, items already planned for an order
var _actions: Array[Dictionary] = []
var _kitchen: KitchenState


func step(shift: Shift) -> void:
	while _busy_until.size() < shift.kitchen.players.size():
		_busy_until.append(0.0)
	var acted := {}
	for action in plan(shift):
		var p: int = action.player
		if acted.has(p) or shift.time < _busy_until[p]:
			continue
		var result := shift.do_intent(action)
		actions_done += 1
		if not result.ok:
			actions_failed += 1
			continue
		acted[p] = true
		_busy_until[p] = shift.time + ACTION_SECONDS[action.type] / speed


## The useful next actions for every player, most urgent first, without
## doing them. Also used for the hints shown to new players.
func plan(shift: Shift) -> Array[Dictionary]:
	_kitchen = shift.kitchen
	_claimed.clear()
	_actions = []
	var server := _kitchen.pass_owner()
	var planned := 0
	for order in shift.orders.orders:
		if planned >= max_orders:
			break
		if order_filter.is_valid() and not order_filter.call(order):
			continue
		planned += 1
		var loc := _ensure(order.dish, server, 0)
		if not loc.is_empty():
			_add({"type": "serve", "player": server, "slot": loc.slot})
	_plan_cleanup()
	return _actions


## Runs a whole shift with the bot and returns the outcome.
static func play(shift: Shift, bot: KitchenBot = null, dt: float = 0.1, max_time: float = 1800.0) -> Dictionary:
	if bot == null:
		bot = KitchenBot.new()
	while not shift.finished and shift.time < max_time:
		bot.step(shift)
		shift.tick(dt)
	return shift.outcome


# Makes sure an item with this id ends up on `dest`'s counter (or on anyone's
# counter for ANYWHERE). Returns its location {"player", "slot", "uid"} once it
# is there, or {} while it is still being made (the next actions are queued in
# _actions).
func _ensure(id: String, dest: int, depth: int) -> Dictionary:
	if depth > MAX_DEPTH:
		return {}
	var db := _kitchen.db
	var loc := _find_ready(id, dest)
	if not loc.is_empty():
		_claimed[loc.uid] = true
		if loc.kind == "slot":
			if loc.player == dest or dest == ANYWHERE:
				return loc
			_add({"type": "throw", "player": loc.player, "slot": loc.slot, "target": dest})
		else:
			_add({"type": "remove", "player": loc.player, "equipment": loc.equipment, "index": loc.index})
		return {}

	var running := _find_running(id)
	if not running.is_empty():
		_claimed[running.uid] = true
		if not db.is_passive(running.process):
			_add({"type": "work_appliance", "player": running.player, "equipment": running.equipment, "index": running.index})
		return {}

	var prod := db.producer(id)
	if prod.is_empty():
		var owner := _pick_owner(_kitchen.owners_of_crate(id), dest)
		if owner >= 0:
			_add({"type": "take", "player": owner, "ingredient": id})
		return {}

	if prod.kind == "process":
		var proc: Dictionary = db.processes[prod.id]
		var worker := _pick_owner(_kitchen.owners_of_equipment(proc.equipment), dest)
		if worker < 0:
			return {}
		var input_loc := _ensure(proc.input, worker, depth + 1)
		if input_loc.is_empty():
			return {}
		if db.equipment_kind(proc.equipment) == ContentDB.EQUIP_TOOL:
			_add({"type": "work", "player": worker, "slot": input_loc.slot, "equipment": proc.equipment})
		else:
			_add({"type": "insert", "player": worker, "slot": input_loc.slot, "equipment": proc.equipment})
		return {}

	# Assembly: build it wherever its base already is (so only the finished
	# assembly travels to dest). Parts are prepared right away but only brought
	# over once the base exists, so they don't clog anyone's counter.
	var asm: Dictionary = db.assemblies[prod.id]
	var have: Array = []
	var site := dest
	var base_loc := _find_partial(asm, dest)
	if not base_loc.is_empty():
		_claimed[base_loc.uid] = true
		have = base_loc.contents
		site = base_loc.player
	else:
		var existing_base := _find_ready(asm.base, dest)
		if not existing_base.is_empty():
			site = existing_base.player
		base_loc = _ensure(asm.base, site, depth + 1)
	var parts_dest := site if not base_loc.is_empty() or not have.is_empty() else ANYWHERE
	for part in asm.parts:
		if have.has(part):
			continue
		var part_loc := _ensure(part, parts_dest, depth + 1)
		if not part_loc.is_empty() and not base_loc.is_empty():
			_add({"type": "combine", "player": site, "from": part_loc.slot, "to": base_loc.slot})
	return {}


# A finished, unclaimed item with this id: on a counter (dest's first) or
# ready in an appliance.
func _find_ready(id: String, dest: int) -> Dictionary:
	for p in _players_from(dest):
		var pk := _kitchen.players[p]
		for slot in pk.slots.size():
			var item: KitchenItem = pk.slots[slot]
			if item and not _claimed.has(item.uid) and _kitchen.effective_id(item) == id:
				return {"kind": "slot", "player": p, "slot": slot, "uid": item.uid}
		for eq in pk.appliances:
			var appliance: Array = pk.appliances[eq]
			for index in appliance.size():
				var aslot: KitchenState.ApplianceSlot = appliance[index]
				if aslot and aslot.done and not aslot.burnt and not _claimed.has(aslot.item.uid) \
						and _kitchen.effective_id(aslot.item) == id:
					return {"kind": "appliance", "player": p, "equipment": eq, "index": index, "uid": aslot.item.uid}
	return {}


# An unclaimed item in an appliance that is turning into this id.
func _find_running(id: String) -> Dictionary:
	for pk in _kitchen.players:
		for eq in pk.appliances:
			var appliance: Array = pk.appliances[eq]
			for index in appliance.size():
				var aslot: KitchenState.ApplianceSlot = appliance[index]
				if aslot and not aslot.done and aslot.process.output == id and not _claimed.has(aslot.item.uid):
					return {"player": pk.index, "equipment": eq, "index": index, "uid": aslot.item.uid, "process": aslot.process}
	return {}


# An unclaimed, half-assembled base for this assembly.
func _find_partial(asm: Dictionary, dest: int) -> Dictionary:
	for p in _players_from(dest):
		var pk := _kitchen.players[p]
		for slot in pk.slots.size():
			var item: KitchenItem = pk.slots[slot]
			if item and item.type == asm.base and not item.contents.is_empty() and not _claimed.has(item.uid) \
					and item.contents.all(func(part): return asm.parts.has(part)):
				return {"player": p, "slot": slot, "uid": item.uid, "contents": item.contents}
	return {}


# Trashes burnt food, and makes room on full counters by trashing items no
# order needs right now.
func _plan_cleanup() -> void:
	for pk in _kitchen.players:
		for eq in pk.appliances:
			var appliance: Array = pk.appliances[eq]
			for index in appliance.size():
				var aslot: KitchenState.ApplianceSlot = appliance[index]
				if aslot and aslot.burnt:
					_add({"type": "trash_appliance", "player": pk.index, "equipment": eq, "index": index})
		for slot in pk.slots.size():
			var item: KitchenItem = pk.slots[slot]
			if item and item.type == ContentDB.BURNT_ITEM:
				_add({"type": "trash", "player": pk.index, "slot": slot})
		if pk.free_slot_count() == 0:
			for slot in pk.slots.size():
				var item: KitchenItem = pk.slots[slot]
				if item and not _claimed.has(item.uid):
					_add({"type": "trash", "player": pk.index, "slot": slot})
					break


func _pick_owner(owners: Array[int], preferred: int) -> int:
	if owners.has(preferred):
		return preferred
	return owners[0] if not owners.is_empty() else -1


func _players_from(first: int) -> Array[int]:
	var order: Array[int] = []
	if first >= 0:
		order.append(first)
	for p in _kitchen.players.size():
		if p != first:
			order.append(p)
	return order


func _add(action: Dictionary) -> void:
	# Skip actions that would obviously be rejected for lack of space.
	match action.type:
		"take", "remove":
			if _kitchen.players[action.player].free_slot() < 0:
				return
		"throw":
			if _kitchen.players[action.target].free_slot() < 0:
				return
		"insert":
			if not _kitchen.players[action.player].appliances.get(action.equipment, []).has(null):
				return
	_actions.append(action)
