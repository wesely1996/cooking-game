class_name CompetitionRules
extends ShiftRules
## Competition (boss) level: the players and a rival AI chef cook the same
## list of dishes for a judging panel. The judges reveal the list a few dishes
## at a time and never leave. The players win by finishing the list before the
## rival, or by having the higher judges' score when time runs out.
##
## Level settings: judges_orders (array of dish ids), max_active,
## time_limit, and rival {name, personality, speed}.

## Fraction of the time limit that has to be left for the speed star.
const FAST_FINISH_SHARE := 0.25

var queue: Array = []  # judges' dishes not revealed yet
var total_orders := 0
var players_done := 0
var _rival_lead_taunted := false


func setup(shift: Shift) -> void:
	queue = shift.level.data.get("judges_orders", []).duplicate()
	total_orders = queue.size()
	var config: Dictionary = shift.level.data.get("rival", {})
	shift.rival = RivalChef.new(shift.db, queue.duplicate(), config, shift.player_count, shift.rng.randi())
	_reveal(shift)


func tick(shift: Shift, delta: float) -> void:
	var before := shift.rival.done_count
	shift.rival.tick(delta)
	if shift.rival.done_count > before and shift.rival.done_count > players_done and not _rival_lead_taunted:
		_rival_lead_taunted = true
		shift.emit({"type": "rival_taunt", "taunt": "too_slow"})
	if shift.rival.done_count <= players_done:
		_rival_lead_taunted = false


func on_served(shift: Shift, order: Dictionary, item: KitchenItem) -> int:
	players_done += 1
	_reveal(shift)
	return serve_points(shift, order, item, false, false)


func is_finished(shift: Shift) -> bool:
	return players_finished() or shift.rival.finished or shift.time >= _time_limit(shift)


func players_finished() -> bool:
	return players_done >= total_orders


func outcome(shift: Shift) -> Dictionary:
	var won: bool
	if players_finished():
		won = true
	elif shift.rival.finished:
		won = false
	else:
		won = shift.score >= shift.rival.score
	var stars := 0
	if won:
		stars = 1
		if shift.stats.served > 0 and float(shift.stats.perfect) / shift.stats.served >= 0.5:
			stars += 1
		if players_finished() and shift.time <= _time_limit(shift) * (1.0 - FAST_FINISH_SHARE):
			stars += 1
	return {
		"type": LevelDef.TYPE_COMPETITION,
		"failed": not won,
		"stars": stars,
		"score": shift.score,
		"rival_score": shift.rival.score,
		"dishes_done": players_done,
		"rival_dishes_done": shift.rival.done_count,
	}


func sync_state() -> Dictionary:
	return {"queue": queue.duplicate(), "total_orders": total_orders, "players_done": players_done}


func load_sync_state(data: Dictionary) -> void:
	queue = data.get("queue", queue).duplicate()
	total_orders = int(data.get("total_orders", total_orders))
	players_done = int(data.get("players_done", players_done))


func _reveal(shift: Shift) -> void:
	var max_active := int(shift.level.value("max_active", shift.player_count, 2))
	while not queue.is_empty() and shift.orders.active_count() < max_active:
		shift.orders.add(queue.pop_front(), -1.0)


func _time_limit(shift: Shift) -> float:
	return float(shift.level.value("time_limit", shift.player_count, 300.0))
