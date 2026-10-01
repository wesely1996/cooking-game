class_name RivalChef
extends RefCounted
## The AI chef the players race against in competition levels. It cooks the
## same list of dishes as the players. It isn't simulated step by step: each
## dish takes the time one cook would need (ContentDB.nominal_seconds)
## divided by the rival's speed, adjusted by its personality.
##
## Config: {"name", "personality", "speed"} where speed may be keyed by
## player count, so 1 and 4 players both get a fair fight.

const PERSONALITIES := ["steady", "show_off", "perfectionist", "chaotic"]
## Chance per dish that the show-off burns it and has to redo the cooking.
const SHOW_OFF_BURN_CHANCE := 0.25

var name := "Rival"
var personality := "steady"
var speed := 1.0
var dishes: Array = []
var index := 0  # dish currently being cooked
var progress := 0.0  # seconds spent on the current dish
var duration := 0.0  # seconds the current dish takes
var current_burnt := false
var done_count := 0
var perfect_count := 0
var score := 0
var finished := false

var _db: ContentDB
var _rng := RandomNumberGenerator.new()
var _events: Array[Dictionary] = []


func _init(db: ContentDB, p_dishes: Array, config: Dictionary, player_count: int, seed: int = 0) -> void:
	_db = db
	dishes = p_dishes
	name = str(config.get("name", name))
	personality = str(config.get("personality", personality))
	speed = maxf(float(LevelDef.pick(config.get("speed", 1.0), player_count)), 0.05)
	_rng.seed = seed
	if dishes.is_empty():
		finished = true
	else:
		_start_dish()


func current_dish() -> String:
	return "" if finished else dishes[index]


## Progress on the current dish, 0..1.
func dish_fraction() -> float:
	return 1.0 if finished else clampf(progress / duration, 0.0, 1.0)


func tick(delta: float) -> void:
	if finished:
		return
	progress += delta
	while not finished and progress >= duration:
		progress -= duration
		_complete_dish()


func drain_events() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events


# How long the rival will take for dish number `i`, before any burn redo.
# Chaotic rivals roll a new factor on every call.
func _planned_seconds(i: int) -> float:
	return _db.nominal_seconds(dishes[i]) / (speed * _personality_factor(i))


func _personality_factor(i: int) -> float:
	match personality:
		"show_off":
			return 1.25
		"perfectionist":
			return 0.8 if i < dishes.size() / 2 else 1.3
		"chaotic":
			return _rng.randf_range(0.65, 1.45)
	return 1.0


func _start_dish() -> void:
	var dish: String = dishes[index]
	duration = _planned_seconds(index)
	current_burnt = false
	if personality == "show_off":
		var cook_time := _longest_cook(dish)
		if cook_time > 0.0 and _rng.randf() < SHOW_OFF_BURN_CHANCE:
			current_burnt = true
			duration += cook_time * 1.5 / speed
			_events.append({"type": "rival_taunt", "taunt": "burnt", "dish": dish})
	_events.append({"type": "rival_dish_started", "index": index, "dish": dish, "duration": duration})


func _complete_dish() -> void:
	var dish: String = dishes[index]
	var points := int(_db.items[dish].price)
	if not current_burnt:
		points += ShiftRules.PERFECT_BONUS
		perfect_count += 1
	score += points
	done_count += 1
	_events.append({"type": "rival_dish_done", "index": index, "dish": dish, "points": points})
	index += 1
	if index >= dishes.size():
		finished = true
		progress = 0.0
		_events.append({"type": "rival_finished", "score": score})
	else:
		_start_dish()


func _longest_cook(dish: String) -> float:
	var longest := 0.0
	for step in _db.process_steps(dish):
		longest = maxf(longest, float(_db.processes[step].cook_time))
	return longest
