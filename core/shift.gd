class_name Shift
extends RefCounted
## One play session of a level: the kitchen, the customers, the score and
## (in competitions) the rival chef. The level type's rules decide when
## customers arrive and how the shift ends.
##
## Usage: create it, call do_intent() for player actions and tick() every
## frame (or network tick), and read drain_events() for what happened.

var db: ContentDB
var level: LevelDef
var player_count: int
var kitchen: KitchenState
var orders := OrderBook.new()
var rules: ShiftRules
var rival: RivalChef = null
var rng := RandomNumberGenerator.new()

var time := 0.0
var score := 0
var combo := 0
var stats := {"served": 0, "lost": 0, "perfect": 0}
var finished := false
## Filled in when the shift ends: {"type", "failed", "stars", ...}.
var outcome := {}

var _events: Array[Dictionary] = []


func _init(p_db: ContentDB, p_level: LevelDef, p_player_count: int, seed: int = 0) -> void:
	db = p_db
	level = p_level
	player_count = p_player_count
	rng.seed = seed
	kitchen = KitchenState.new(db, level.roles_for(player_count, db))
	kitchen.serve_handler = _on_serve
	rules = ShiftRules.create(level.type)
	rules.setup(self)
	_collect()


func do_intent(intent: Dictionary) -> Dictionary:
	if finished:
		return {"ok": false, "error": "shift_over"}
	var result := kitchen.do_intent(intent)
	_collect()
	return result


func tick(delta: float) -> void:
	if finished:
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


func _on_serve(_player: int, item: KitchenItem) -> Dictionary:
	var dish := db.effective_id(item.type, item.contents)
	var order := orders.fulfill(dish)
	if order.is_empty():
		return {"ok": false, "error": "no_matching_order"}
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
