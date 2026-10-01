class_name NormalRules
extends ShiftRules
## Normal story level: customers arrive at a steady rate for a fixed time and
## the shift always ends with a 0-3 star rating. It can't be failed.
##
## Level settings: duration, max_active, spawn_interval, first_spawn,
## last_call (no new customers in the final seconds), lost_penalty, and
## stars (three score thresholds).

var next_spawn := 0.0


func setup(shift: Shift) -> void:
	next_spawn = float(shift.level.value("first_spawn", shift.player_count, 2.0))


func tick(shift: Shift, _delta: float) -> void:
	var n := shift.player_count
	var duration := float(shift.level.value("duration", n, 180.0))
	if shift.time > duration - float(shift.level.value("last_call", n, 15.0)):
		return
	# An empty window never waits long for the next customer.
	if shift.orders.active_count() == 0:
		next_spawn = minf(next_spawn, shift.time + 2.0)
	if shift.time >= next_spawn and shift.orders.active_count() < int(shift.level.value("max_active", n, 3)):
		shift.spawn_customer(shift.random_dish())
		next_spawn = shift.time + float(shift.level.value("spawn_interval", n, 25.0))


func on_lost(shift: Shift, _order: Dictionary) -> void:
	shift.add_score(-int(shift.level.value("lost_penalty", shift.player_count, 5)))


func is_finished(shift: Shift) -> bool:
	return shift.time >= float(shift.level.value("duration", shift.player_count, 180.0))


func outcome(shift: Shift) -> Dictionary:
	var thresholds: Array = shift.level.value("stars", shift.player_count, [])
	return {
		"type": LevelDef.TYPE_NORMAL,
		"failed": false,
		"stars": stars_for(shift.score, thresholds),
		"score": shift.score,
	}
