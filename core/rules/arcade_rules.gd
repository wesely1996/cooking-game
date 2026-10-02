class_name ArcadeRules
extends ShiftRules
## Arcade mode: an endless shift that gets harder over time. It ends after a
## number of lost customers ("strikes"); the goal is the highest score.
##
## Level settings: spawn_interval, max_active, strikes, escalate_every,
## and the per-step factors interval_factor and patience_factor.

const MAX_ACTIVE_CAP := 6

var next_spawn := 0.0
var level_up := 0  # how many times the pace has increased


func setup(shift: Shift) -> void:
	next_spawn = float(shift.level.value("first_spawn", shift.player_count, 2.0))


func tick(shift: Shift, _delta: float) -> void:
	var n := shift.player_count
	var new_level := int(shift.time / float(shift.level.value("escalate_every", n, 30.0)))
	if new_level > level_up:
		level_up = new_level
		shift.emit({"type": "pace_up", "level": level_up})
	if shift.orders.active_count() == 0:
		next_spawn = minf(next_spawn, shift.time + 1.5)
	var max_active := mini(int(shift.level.value("max_active", n, 3)) + level_up / 2, MAX_ACTIVE_CAP)
	if shift.time >= next_spawn and shift.orders.active_count() < max_active:
		var patience_scale := pow(float(shift.level.value("patience_factor", n, 0.95)), level_up)
		shift.spawn_customer(shift.random_dish(), patience_scale)
		var interval := float(shift.level.value("spawn_interval", n, 20.0))
		next_spawn = shift.time + interval * pow(float(shift.level.value("interval_factor", n, 0.92)), level_up)


func on_lost(shift: Shift, _order: Dictionary) -> void:
	shift.emit({"type": "strike", "strikes": shift.stats.lost})


func is_finished(shift: Shift) -> bool:
	return shift.stats.lost >= int(shift.level.value("strikes", shift.player_count, 3))


func sync_state() -> Dictionary:
	return {"level_up": level_up}


func load_sync_state(data: Dictionary) -> void:
	level_up = int(data.get("level_up", level_up))


func outcome(shift: Shift) -> Dictionary:
	return {
		"type": LevelDef.TYPE_ARCADE,
		"failed": false,
		"stars": 0,
		"score": shift.score,
		"served": shift.stats.served,
		"time": shift.time,
	}
