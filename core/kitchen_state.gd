class_name KitchenState
extends RefCounted
## The authoritative state of every player's kitchen: the crates they own and
## their stations (counter spots, boards, bowls, pots, ovens, the serving
## window) with the food on or in them.
##
## All changes go through do_intent() with a plain Dictionary, so the same
## code serves solo play, the LAN host and (later) the online host. Every
## change is recorded as an event Dictionary for the UI and network layer.
##
## Intents (all carry "player"):
## - take {ingredient, station = -1}: a new item from a crate, onto a station
##   (or the first free counter),
## - move {from, to}: food from one station to another. The target may take it
##   in (a pot that can cook it), or the two may combine (food onto a plate);
## - work {station, amount}: a gesture on a board, bowl or gadget,
## - throw {station, target}: food to a teammate's first free counter,
## - serve {station}: food to the customers (only the serving window's owner),
## - trash {station}: everything on a station into the bin.

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


class Station:
	extends RefCounted
	var index := 0
	var type := ""
	var contents: Array = []  # KitchenItem
	var recipe := {}  # what the contents make (or made)
	var progress := 0.0  # work done by hand, or seconds cooked
	var done := false  # cooked (cook stations only)
	var since_ready := 0.0
	var burnt := false

	## The one item on the station, or null when it's empty or holds several
	## things (a pot with pasta and water).
	func item() -> KitchenItem:
		return contents[0] if contents.size() == 1 else null

	func is_empty() -> bool:
		return contents.is_empty()

	func to_dict() -> Dictionary:
		return {
			"type": type,
			"contents": contents.map(func(i): return i.to_dict()),
			"recipe": recipe.get("id", ""),
			"progress": progress,
			"done": done,
			"since_ready": since_ready,
			"burnt": burnt,
		}


class PlayerKitchen:
	extends RefCounted
	var index := 0
	var role := ""
	var crates: Array = []
	var stations: Array[Station] = []
	var serves := false

	## Index of the first empty counter spot, or -1.
	func free_counter(db: ContentDB) -> int:
		for st in stations:
			if st.is_empty() and db.station_kind(st.type) == ContentDB.STATION_COUNTER:
				return st.index
		return -1

	func free_counter_count(db: ContentDB) -> int:
		return stations.filter(func(st): return st.is_empty() and db.station_kind(st.type) == ContentDB.STATION_COUNTER).size()

	func has_station(type: String) -> bool:
		return stations.any(func(st): return st.type == type)

	func stations_of(type: String) -> Array[Station]:
		var result: Array[Station] = []
		for st in stations:
			if st.type == type:
				result.append(st)
		return result

	func pass_station(db: ContentDB) -> int:
		for st in stations:
			if db.station_kind(st.type) == ContentDB.STATION_PASS:
				return st.index
		return -1


## roles: one Dictionary per player: {"name", "crates", "stations": {type: count}}.
func _init(p_db: ContentDB, roles: Array) -> void:
	db = p_db
	for i in roles.size():
		var role: Dictionary = roles[i]
		var pk := PlayerKitchen.new()
		pk.index = i
		pk.role = str(role.get("name", "Chef %d" % (i + 1)))
		pk.crates = role.get("crates", []).duplicate()
		var counts: Dictionary = role.get("stations", {})
		for type in counts:
			for n in int(counts[type]):
				var st := Station.new()
				st.index = pk.stations.size()
				st.type = type
				pk.stations.append(st)
				if db.station_kind(type) == ContentDB.STATION_PASS:
					pk.serves = true
		players.append(pk)


# --- Queries -----------------------------------------------------------------

func station(player: int, index: int) -> Station:
	if player < 0 or player >= players.size():
		return null
	var list := players[player].stations
	if index < 0 or index >= list.size():
		return null
	return list[index]


## The single item on a station, or null.
func item_at(player: int, index: int) -> KitchenItem:
	var st := station(player, index)
	return st.item() if st else null


func effective_id(item: KitchenItem) -> String:
	return db.effective_id(item.type, item.contents)


## Effective ids of everything on a station.
func contents_ids(st: Station) -> Array:
	return st.contents.map(func(i): return effective_id(i))


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


func owners_of_station(type: String) -> Array[int]:
	var result: Array[int] = []
	for pk in players:
		if pk.has_station(type):
			result.append(pk.index)
	return result


## Whether the food on a station can be picked up right now: one item, not
## burnt (burnt food only goes in the bin), and not halfway through cooking
## with other things in the pot.
func can_take(st: Station) -> bool:
	return st != null and st.item() != null and not st.burnt


func drain_events() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events


## Full state for a joining or reconnecting client.
func snapshot() -> Dictionary:
	var result := []
	for pk in players:
		result.append({
			"role": pk.role,
			"crates": pk.crates.duplicate(),
			"serves": pk.serves,
			"stations": pk.stations.map(func(st): return st.to_dict()),
		})
	return {"players": result, "next_uid": _next_uid}


## Replaces the food on every station with a snapshot from the host (the
## crates, stations and roles come from the level and never change).
func load_snapshot(data: Dictionary) -> void:
	var entries: Array = data.get("players", [])
	for i in mini(entries.size(), players.size()):
		var saved: Array = entries[i].get("stations", [])
		for st in players[i].stations:
			var entry: Dictionary = saved[st.index] if st.index < saved.size() and saved[st.index] is Dictionary else {}
			st.contents = []
			for item_data in entry.get("contents", []):
				st.contents.append(KitchenItem.from_dict(item_data))
			st.recipe = db.recipes.get(str(entry.get("recipe", "")), {})
			st.progress = float(entry.get("progress", 0.0))
			st.done = bool(entry.get("done", false))
			st.since_ready = float(entry.get("since_ready", 0.0))
			st.burnt = bool(entry.get("burnt", false))
	_next_uid = maxi(_next_uid, int(data.get("next_uid", _next_uid)))


# --- Intents -----------------------------------------------------------------

## Applies one player action. Returns {"ok": true} or {"ok": false, "error": code}.
func do_intent(intent: Dictionary) -> Dictionary:
	var p := int(intent.get("player", -1))
	if p < 0 or p >= players.size():
		return _fail("bad_player")
	var st := int(intent.get("station", -1))
	match str(intent.get("type", "")):
		"take":
			return _take(p, str(intent.get("ingredient", "")), st)
		"move":
			return _move(p, int(intent.get("from", -1)), int(intent.get("to", -1)))
		"work":
			return _work(p, st, float(intent.get("amount", 1.0)))
		"throw":
			return _throw(p, st, int(intent.get("target", -1)))
		"serve":
			return _serve(p, st)
		"trash":
			return _trash(p, st)
	return _fail("unknown_intent")


func _take(p: int, ingredient: String, to: int) -> Dictionary:
	var pk := players[p]
	if not pk.crates.has(ingredient):
		return _fail("not_owned")
	if to < 0:
		to = pk.free_counter(db)
		if to < 0:
			return _fail("counter_full")
	var target := station(p, to)
	if target == null:
		return _fail("bad_station")
	var item := KitchenItem.new(_next_uid, ingredient)
	var result := _put(p, item, target, null)
	if result.ok:
		_next_uid += 1
		_emit({"type": "item_added", "player": p, "station": result.station, "item": _item_dict(p, result.station)})
	return result


func _move(p: int, from: int, to: int) -> Dictionary:
	var source := station(p, from)
	var target := station(p, to)
	if source == null or target == null or from == to:
		return _fail("bad_station")
	if source.is_empty():
		return _fail("empty_station")
	if not can_take(source):
		return _fail("burnt" if source.burnt else "cannot_take")
	var result := _put(p, source.item(), target, source)
	if result.ok:
		_emit({"type": "item_moved", "player": p, "from": from, "to": result.station, "item": _item_dict(p, result.station),
			"combined": result.get("combined", false)})
	return result


# Puts an item onto a station: in if the station can take it, or combined
# with the one item already there. `source` is the station the item comes
# from (null for a fresh item from a crate); it is emptied on success.
# Returns {"ok", "station": where the item (or the combined result) ended up}.
func _put(p: int, item: KitchenItem, target: Station, source: Station) -> Dictionary:
	if db.station_kind(target.type) == ContentDB.STATION_PASS:
		return _fail("use_serve")
	var item_id := effective_id(item)
	if db.accepts(target.type, contents_ids(target), item_id):
		if source:
			_take_out(source)
		target.contents.append(item)
		_contents_changed(p, target, item)
		return {"ok": true, "station": target.index}
	var resident := target.item()
	if resident == null or target.burnt:
		return _fail("station_full" if not target.is_empty() else "cannot_place")
	var combo := db.combine(resident.type, resident.contents, item.type, item.contents)
	if not combo.ok:
		return _fail("cannot_combine")
	if combo.keep == "target":
		if source:
			_take_out(source)
		resident.contents = combo.contents
		resident.perfect = resident.perfect or item.perfect
		_contents_changed(p, target, null)
		return {"ok": true, "station": target.index, "combined": true}
	# The moving item is the base (a plate dropped onto the sauce): the food
	# on the target jumps onto it, and the base stays where it was, unless the
	# target is a counter it can sit on.
	var food := _take_out(target)
	item.contents = combo.contents
	item.perfect = item.perfect or food.perfect
	if source == null or db.accepts(target.type, [], effective_id(item)):
		if source:
			_take_out(source)
		target.contents.append(item)
		_contents_changed(p, target, null)
		return {"ok": true, "station": target.index, "combined": true}
	_contents_changed(p, source, null)
	return {"ok": true, "station": source.index, "combined": true}


# Removes the single item from a station, keeping what was done to it: the
# perfect flag when it leaves a pot in time, and half-done work by hand.
func _take_out(st: Station) -> KitchenItem:
	var item := st.item()
	if item == null:
		return null
	if st.done and not st.burnt and db.is_cook_recipe(st.recipe):
		item.perfect = st.since_ready <= float(st.recipe.perfect_window)
	elif not st.recipe.is_empty() and st.progress > 0.0 and not db.is_cook_recipe(st.recipe):
		item.work = st.progress
		item.work_recipe = st.recipe.id
	st.contents.clear()
	_reset(st)
	return item


func _reset(st: Station) -> void:
	st.recipe = {}
	st.progress = 0.0
	st.done = false
	st.since_ready = 0.0
	st.burnt = false


# Something was added to a station or changed on it: work out what it makes
# now. Cooking restarts whenever the contents change; half-done work by hand
# comes back when the same food returns to the same kind of station.
func _contents_changed(p: int, st: Station, arrived: KitchenItem) -> void:
	var recipe := db.recipe_for(st.type, contents_ids(st))
	_reset(st)
	st.recipe = recipe
	if recipe.is_empty():
		return
	if db.is_cook_recipe(recipe):
		_emit({"type": "cook_started", "player": p, "station": st.index, "recipe": recipe.id})
	elif arrived and arrived.work_recipe == recipe.id and st.contents.size() == 1:
		st.progress = arrived.work
	if arrived:
		arrived.work = 0.0
		arrived.work_recipe = ""


func _work(p: int, index: int, amount: float) -> Dictionary:
	var st := station(p, index)
	if st == null or st.is_empty():
		return _fail("empty_station")
	if st.recipe.is_empty() or db.station_kind(st.type) != ContentDB.STATION_MANUAL:
		return _fail("no_recipe")
	if amount <= 0.0 or amount > MAX_WORK_PER_INTENT:
		return _fail("bad_amount")
	st.progress += amount
	if st.progress >= float(st.recipe.work):
		var recipe := st.recipe
		st.contents = [_new_item(recipe.output)]
		_contents_changed(p, st, null)
		_emit({"type": "item_processed", "player": p, "station": index, "recipe": recipe.id, "item": _item_dict(p, index)})
	else:
		_emit({"type": "item_worked", "player": p, "station": index, "recipe": st.recipe.id, "progress": st.progress / float(st.recipe.work)})
	return _ok()


func _throw(p: int, index: int, target: int) -> Dictionary:
	var st := station(p, index)
	if st == null or st.is_empty():
		return _fail("empty_station")
	if not can_take(st):
		return _fail("burnt" if st.burnt else "cannot_take")
	if target < 0 or target >= players.size() or target == p:
		return _fail("bad_target")
	var landing := players[target].free_counter(db)
	if landing < 0:
		return _fail("target_full")
	var item := _take_out(st)
	players[target].stations[landing].contents.append(item)
	_emit({"type": "item_thrown", "player": p, "station": index, "target": target, "target_station": landing, "item": item.to_dict()})
	return _ok()


func _serve(p: int, index: int) -> Dictionary:
	var st := station(p, index)
	if st == null or st.is_empty():
		return _fail("empty_station")
	if not players[p].serves:
		return _fail("not_owned")
	if not can_take(st):
		return _fail("cannot_take")
	if not serve_handler.is_valid():
		return _fail("no_customers")
	var item := st.item()
	var result: Dictionary = serve_handler.call(p, item)
	if result.get("ok", false):
		_take_out(st)
		_emit({"type": "item_served", "player": p, "station": index, "item": item.to_dict()})
	return result


func _trash(p: int, index: int) -> Dictionary:
	var st := station(p, index)
	if st == null or st.is_empty():
		return _fail("empty_station")
	var gone: Array = st.contents.map(func(i): return i.to_dict())
	st.contents.clear()
	_reset(st)
	_emit({"type": "item_trashed", "player": p, "station": index, "items": gone})
	return _ok()


# --- Time --------------------------------------------------------------------

## Advances everything that cooks on its own (pots, pans, ovens...).
func tick(delta: float) -> void:
	for pk in players:
		for st in pk.stations:
			if not st.recipe.is_empty() and not st.burnt and db.is_cook_recipe(st.recipe):
				_cook(pk.index, st, delta)


func _cook(p: int, st: Station, delta: float) -> void:
	var recipe := st.recipe
	st.progress += delta
	if not st.done and st.progress >= float(recipe.cook_time):
		st.contents = [_new_item(recipe.output)]
		st.done = true
		st.since_ready = st.progress - float(recipe.cook_time)
		_emit({"type": "cook_ready", "player": p, "station": st.index, "item": _item_dict(p, st.index)})
	elif st.done:
		st.since_ready += delta
	if st.done and float(recipe.burn_time) > 0.0 and st.since_ready >= float(recipe.burn_time):
		st.contents = [_new_item(ContentDB.BURNT_ITEM)]
		st.burnt = true
		_emit({"type": "cook_burnt", "player": p, "station": st.index})


# --- Helpers -----------------------------------------------------------------

func _new_item(type: String) -> KitchenItem:
	var item := KitchenItem.new(_next_uid, type)
	_next_uid += 1
	return item


func _item_dict(p: int, index: int) -> Dictionary:
	var item := item_at(p, index)
	return item.to_dict() if item else {}


func _emit(event: Dictionary) -> void:
	_events.append(event)


func _ok() -> Dictionary:
	return {"ok": true}


func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
