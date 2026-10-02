class_name FestivalRules
extends ShiftRules
## Festival (horde) level: a big crowd arrives in waves with short breaks in
## between, ordering simple dishes. A crowd mood meter goes up with every
## served customer and drops sharply with every lost one. If it hits zero the
## festival is a flop (level failed); surviving every wave clears it.
##
## Level settings: waves (array of {customers, spawn_interval, max_active}),
## wave_break, mood {start, served, lost}, and stars (three mood thresholds;
## use 0 for the first so clearing the festival always gives one star).

const MAX_MOOD := 100.0

var mood := 50.0
var wave := 0  # index of the current wave
var spawned_in_wave := 0
var next_spawn := 0.0
var on_break := false
var break_until := 0.0
var cleared := false


func setup(shift: Shift) -> void:
	mood = float(_mood_setting(shift, "start", 50.0))
	_start_wave(shift, 0)


func tick(shift: Shift, _delta: float) -> void:
	if cleared or mood <= 0.0:
		return
	var waves: Array = shift.level.data.get("waves", [])
	if on_break:
		if shift.time >= break_until:
			_start_wave(shift, wave + 1)
		return
	var n := shift.player_count
	var current: Dictionary = waves[wave]
	var customers := int(LevelDef.pick(current.get("customers", 5), n))
	if spawned_in_wave < customers:
		if shift.time >= next_spawn and shift.orders.active_count() < int(LevelDef.pick(current.get("max_active", 3), n)):
			shift.spawn_customer(shift.random_dish())
			spawned_in_wave += 1
			next_spawn = shift.time + float(LevelDef.pick(current.get("spawn_interval", 6.0), n))
	elif shift.orders.active_count() == 0:
		if wave + 1 >= waves.size():
			cleared = true
		else:
			on_break = true
			break_until = shift.time + float(shift.level.value("wave_break", n, 6.0))
			shift.emit({"type": "wave_cleared", "wave": wave})


func on_served(shift: Shift, order: Dictionary, item: KitchenItem) -> int:
	_change_mood(shift, float(_mood_setting(shift, "served", 5.0)))
	return serve_points(shift, order, item, true, true)


func on_lost(shift: Shift, _order: Dictionary) -> void:
	_change_mood(shift, -float(_mood_setting(shift, "lost", 20.0)))


func is_finished(_shift: Shift) -> bool:
	return cleared or mood <= 0.0


func outcome(shift: Shift) -> Dictionary:
	var failed := mood <= 0.0
	var thresholds: Array = shift.level.value("stars", shift.player_count, [0, 50, 80])
	return {
		"type": LevelDef.TYPE_FESTIVAL,
		"failed": failed,
		"stars": 0 if failed else stars_for(mood, thresholds),
		"score": shift.score,
		"mood": mood,
		"waves_cleared": wave + (1 if cleared else 0),
	}


func sync_state() -> Dictionary:
	return {"mood": mood, "wave": wave, "spawned_in_wave": spawned_in_wave, "on_break": on_break, "cleared": cleared}


func load_sync_state(data: Dictionary) -> void:
	mood = float(data.get("mood", mood))
	wave = int(data.get("wave", wave))
	spawned_in_wave = int(data.get("spawned_in_wave", spawned_in_wave))
	on_break = bool(data.get("on_break", on_break))
	cleared = bool(data.get("cleared", cleared))


func _start_wave(shift: Shift, index: int) -> void:
	wave = index
	spawned_in_wave = 0
	on_break = false
	next_spawn = shift.time + 1.0
	shift.emit({"type": "wave_started", "wave": wave})


func _change_mood(shift: Shift, amount: float) -> void:
	mood = clampf(mood + amount, 0.0, MAX_MOOD)
	shift.emit({"type": "mood_changed", "mood": mood})


func _mood_setting(shift: Shift, key: String, default: float) -> Variant:
	var settings: Dictionary = shift.level.data.get("mood", {})
	return LevelDef.pick(settings.get(key, default), shift.player_count)
