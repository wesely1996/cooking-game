class_name Shift
extends RefCounted
## One play session of a level: the kitchen, the customers, the score and
## (in competitions) the rival chef. The level type's rules decide when
## customers arrive and how the shift ends.
##
## Usage: create it, call do_intent() for player actions and tick() every
## frame (or network tick), and read drain_events() for what happened.
##
## New-dish prologue: dishes the players have never made can be taught first.
## Each gets one tutorial order with no patience; the clock, the customers
## and the rival wait until it is served (it scores nothing). Then the real
## shift starts. A "skip_prologue" intent jumps straight to it.

var db: ContentDB
var level: LevelDef
var player_count: int
var kitchen: KitchenState
var orders := OrderBook.new()
var rules: ShiftRules
var rival: RivalChef = null
var rng := RandomNumberGenerator.new()

var time := 0.0  # shift clock: stands still during the prologue
var elapsed := 0.0  # all time since the shift was created
var score := 0
var combo := 0
var stats := {"served": 0, "lost": 0, "perfect": 0}
var finished := false
## Dishes still to teach before the clock starts; the first one is on order.
var prologue: Array[String] = []
var rules_started := false
## Filled in when the shift ends: {"type", "failed", "stars", ...}.
var outcome := {}

var _events: Array[Dictionary] = []


## `prologue_dishes`: dishes to teach first (only those on the level's menu
## are used, each once).
func _init(p_db: ContentDB, p_level: LevelDef, p_player_count: int, seed: int = 0, prologue_dishes: Array = []) -> void:
	db = p_db
	level = p_level
	player_count = p_player_count
	rng.seed = seed
	kitchen = KitchenState.new(db, level.roles_for(player_count, db))
	kitchen.serve_handler = _on_serve
	rules = ShiftRules.create(level.type)
	for dish in level.dish_ids():
		if prologue_dishes.has(dish) and not prologue.has(dish):
			prologue.append(dish)
	if prologue.is_empty():
		start_rules()
	else:
		_order_prologue_dish()
	_collect()


func in_prologue() -> bool:
	return not rules_started


## Starts the real shift (customers, clock, rival). Also called on a LAN
## client's mirror when the host's prologue is over.
func start_rules() -> void:
	if rules_started:
		return
	rules_started = true
	prologue.clear()
	rules.setup(self)
	emit({"type": "shift_started"})


func do_intent(intent: Dictionary) -> Dictionary:
	if finished:
		return {"ok": false, "error": "shift_over"}
	if intent.get("type", "") == "skip_prologue":
		if rules_started:
			return {"ok": false, "error": "no_prologue"}
		orders.orders = orders.orders.filter(func(o): return not o.get("tutorial", false))
		start_rules()
		_collect()
		return {"ok": true}
	var result := kitchen.do_intent(intent)
	_collect()
	return result


func tick(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if not rules_started:
		kitchen.tick(delta)  # food still cooks (and burns) while learning
		_collect()
		return
	time += delta
	kitchen.tick(delta)
	for order in orders.tick(delta):
		stats.lost += 1
		combo = 0
		rules.on_lost(self, order)
	rules.tick(self, delta)
	if rules.is_finished(self):
		finished = true
		outcome = rules.outcome(self)
		emit({"type": "shift_ended", "outcome": outcome})
	_collect()


func add_score(points: int) -> void:
	score = maxi(score + points, 0)


func emit(event: Dictionary) -> void:
	_events.append(event)


func drain_events() -> Array[Dictionary]:
	_collect()
	var events := _events
	_events = []
	return events


## Adds a customer for a dish, with patience scaled for the player count.
func spawn_customer(dish: String, patience_scale: float = 1.0) -> Dictionary:
	var patience: float = float(db.items[dish].patience) * level.patience_multiplier(player_count) * patience_scale
	return orders.add(dish, patience)


## Picks a dish from the level's menu, using the dish weights.
func random_dish() -> String:
	var total := 0.0
	for entry in level.dishes:
		total += entry.weight
	var roll := rng.randf() * total
	for entry in level.dishes:
		roll -= entry.weight
		if roll <= 0.0:
			return entry.id
	return level.dishes.back().id


func _order_prologue_dish() -> void:
	var order := orders.add(prologue[0], -1.0)
	order["tutorial"] = true
	emit({"type": "prologue_dish", "dish": prologue[0], "left": prologue.size()})


func _on_serve(_player: int, item: KitchenItem) -> Dictionary:
	var dish := db.effective_id(item.type, item.contents)
	var order := orders.fulfill(dish)
	if order.is_empty():
		return {"ok": false, "error": "no_matching_order"}
	if order.get("tutorial", false):
		emit({"type": "prologue_served", "dish": dish})
		prologue.erase(dish)
		if prologue.is_empty():
			start_rules()
		else:
			_order_prologue_dish()
		return {"ok": true, "order": order.uid, "points": 0}
	stats.served += 1
	if item.perfect:
		stats.perfect += 1
	var points := rules.on_served(self, order, item)
	add_score(points)
	emit({"type": "order_served", "order": order.duplicate(), "points": points, "perfect": item.perfect})
	return {"ok": true, "order": order.uid, "points": points}


func _collect() -> void:
	_events.append_array(kitchen.drain_events())
	_events.append_array(orders.drain_events())
	if rival:
		_events.append_array(rival.drain_events())
