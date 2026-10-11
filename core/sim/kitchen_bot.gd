class_name KitchenBot
extends RefCounted
## A simple bot that controls every player in a shift, used for headless
## simulations: it checks that levels can really be finished through the same
## intents real players send, and gives rough numbers for balancing. Its
## planner also gives the new-dish tips their next step.
##
## Every step it re-plans from scratch. For the oldest orders it walks the
## recipe tree backwards ("to serve a pizza I need a plate with a baked pizza
## at the server; the pizza bakes in the oven owner's oven, which needs a raw
## pizza there, which is a dough with tomato and mozzarella...") and collects
## one next action per branch. Each player then does their first possible
## action and is busy for a human-like time afterwards.

## Seconds a player is busy after each kind of action.
const ACTION_SECONDS := {
	"take": 0.4, "move": 0.45, "work": 0.25, "throw": 0.5, "serve": 0.4, "trash": 0.4,
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
var _claimed := {}  # item uid or "station:<player>:<index>" -> true, already planned for
var _actions: Array[Dictionary] = []
var _kitchen: KitchenState
var _db: ContentDB


func step(shift: Shift) -> void:
	while _busy_until.size() < shift.kitchen.players.size():
		_busy_until.append(0.0)
	var acted := {}
	for action in plan(shift):
		var p: int = action.player
		if acted.has(p) or shift.elapsed < _busy_until[p]:
			continue
		var result := shift.do_intent(action)
		actions_done += 1
		if not result.ok:
			actions_failed += 1
			continue
		acted[p] = true
		_busy_until[p] = shift.elapsed + ACTION_SECONDS[action.type] / speed


## The useful next actions for every player, most urgent first, without
## doing them. Also used for the tips shown to new players.
func plan(shift: Shift) -> Array[Dictionary]:
	_kitchen = shift.kitchen
	_db = shift.db
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
			_add({"type": "serve", "player": server, "station": loc.station})
	_plan_cleanup()
	return _actions


## Runs a whole shift with the bot and returns the outcome. In a prologue
## the bot plays the tutorial orders first, like a player would.
static func play(shift: Shift, bot: KitchenBot = null, dt: float = 0.1, max_time: float = 1800.0) -> Dictionary:
	if bot == null:
		bot = KitchenBot.new()
	var steps := 0
	while not shift.finished and shift.time < max_time and steps < int(max_time / dt) * 2:
		bot.step(shift)
		shift.tick(dt)
		steps += 1
	return shift.outcome


# Makes sure an item with this id ends up on `dest`'s stations (or anyone's
# for ANYWHERE), ready to be picked up. Returns its location {"player",
# "station", "uid"} once it is there, or {} while it is still being made
# (the next actions are queued in _actions).
func _ensure(id: String, dest: int, depth: int) -> Dictionary:
	if depth > MAX_DEPTH:
		return {}
	var loc := _find_ready(id, dest)
	if not loc.is_empty():
		_claimed[loc.uid] = true
		if loc.player == dest or dest == ANYWHERE:
			return loc
		_add({"type": "throw", "player": loc.player, "station": loc.station, "target": dest})
		return {}

	var running := _find_running(id)
	if not running.is_empty():
		_claim_station(running.player, running.station)
		if _db.station_kind(running.type) == ContentDB.STATION_MANUAL:
			_add({"type": "work", "player": running.player, "station": running.station})
		return {}

	var prod := _db.producer(id)
	if prod.is_empty():
		var owner := _pick_owner(_kitchen.owners_of_crate(id), dest)
		if owner >= 0:
			_add({"type": "take", "player": owner, "ingredient": id})
		return {}
	if prod.kind == "recipe":
		_make_with_recipe(_db.recipes[prod.id], dest, depth)
		return {}
	_assemble(_db.assemblies[prod.id], dest, depth)
	return {}


# Fills a station with a recipe's inputs. The cooking or the gestures happen
# once it's full (see _find_running).
func _make_with_recipe(recipe: Dictionary, dest: int, depth: int) -> void:
	var worker := _pick_owner(_kitchen.owners_of_station(recipe.station), dest)
	if worker < 0:
		return
	var st := _pick_station(worker, recipe)
	if st == null:
		return
	_claim_station(worker, st.index)
	var missing: Array = recipe.inputs.duplicate()
	for have in _kitchen.contents_ids(st):
		missing.erase(have)
	for input in missing:
		# Raw food goes straight from the worker's own crate into the station.
		if _db.producer(input).is_empty() and _kitchen.players[worker].crates.has(input) and _find_ready(input, worker).is_empty():
			_add({"type": "take", "player": worker, "ingredient": input, "station": st.index})
			continue
		var input_loc := _ensure(input, worker, depth + 1)
		if not input_loc.is_empty():
			_add({"type": "move", "player": worker, "from": input_loc.station, "to": st.index})


# Builds an assembly wherever its base already is (so only the finished
# assembly travels to dest). Parts are prepared right away but only brought
# over once the base exists, so they don't clog anyone's counter.
func _assemble(asm: Dictionary, dest: int, depth: int) -> void:
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
		elif site == ANYWHERE:
			site = _pick_owner(_kitchen.owners_of_crate(asm.base), -1) if _db.producer(asm.base).is_empty() else -1
		base_loc = _ensure(asm.base, site if site >= 0 else ANYWHERE, depth + 1)
		if not base_loc.is_empty():
			site = base_loc.player
	var parts_dest := site if not base_loc.is_empty() and site >= 0 else ANYWHERE
	for part in asm.parts:
		if have.has(part):
			continue
		var part_loc := _ensure(part, parts_dest, depth + 1)
		if not part_loc.is_empty() and not base_loc.is_empty():
			_add({"type": "move", "player": site, "from": part_loc.station, "to": base_loc.station})


# A station of the recipe's type at the worker that already holds some of the
# inputs, or else an empty one.
func _pick_station(worker: int, recipe: Dictionary) -> KitchenState.Station:
	var empty: KitchenState.Station = null
	for st in _kitchen.players[worker].stations_of(recipe.station):
		if _claimed.has(_station_key(worker, st.index)) or st.burnt:
			continue
		if st.is_empty():
			if empty == null:
				empty = st
			continue
		if st.recipe.is_empty() and ContentDB._is_sub_multiset(_kitchen.contents_ids(st), recipe.inputs):
			return st
	return empty


# A finished, unclaimed item with this id that can be picked up: on any
# station (dest's first), but not food that is still being cooked or worked.
func _find_ready(id: String, dest: int) -> Dictionary:
	for p in _players_from(dest):
		for st in _kitchen.players[p].stations:
			var item := st.item()
			if item == null or st.burnt or _claimed.has(item.uid):
				continue
			if not st.recipe.is_empty() and not st.done:
				continue
			if _kitchen.effective_id(item) == id:
				return {"player": p, "station": st.index, "uid": item.uid}
	return {}


# A station that is turning its contents into this id: cooking, or full and
# waiting for gestures.
func _find_running(id: String) -> Dictionary:
	for pk in _kitchen.players:
		for st in pk.stations:
			if st.recipe.is_empty() or st.done or st.recipe.output != id:
				continue
			if _claimed.has(_station_key(pk.index, st.index)):
				continue
			return {"player": pk.index, "station": st.index, "type": st.type}
	return {}


# An unclaimed, half-assembled base for this assembly.
func _find_partial(asm: Dictionary, dest: int) -> Dictionary:
	for p in _players_from(dest):
		for st in _kitchen.players[p].stations:
			var item := st.item()
			if item and item.type == asm.base and not item.contents.is_empty() and not _claimed.has(item.uid) \
					and not st.burnt and item.contents.all(func(part): return asm.parts.has(part)):
				return {"player": p, "station": st.index, "uid": item.uid, "contents": item.contents}
	return {}


# Bins burnt food, and makes room on full counters by binning food no order
# needs right now.
func _plan_cleanup() -> void:
	for pk in _kitchen.players:
		for st in pk.stations:
			if st.burnt:
				_add({"type": "trash", "player": pk.index, "station": st.index})
		if pk.free_counter(_db) >= 0:
			continue
		for st in pk.stations:
			var item := st.item()
			if item and _db.station_kind(st.type) == ContentDB.STATION_COUNTER and not _claimed.has(item.uid):
				_add({"type": "trash", "player": pk.index, "station": st.index})
				break


func _claim_station(player: int, index: int) -> void:
	_claimed[_station_key(player, index)] = true


static func _station_key(player: int, index: int) -> String:
	return "station:%d:%d" % [player, index]


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
		"take":
			if action.get("station", -1) < 0 and _kitchen.players[action.player].free_counter(_db) < 0:
				return
		"throw":
			if _kitchen.players[action.target].free_counter(_db) < 0:
				return
	_actions.append(action)
