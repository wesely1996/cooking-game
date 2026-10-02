extends TestCase
## Host and client sessions talking through a loopback "network" that encodes
## every message exactly like the real transport (var_to_bytes, no objects).

const PEER := 7

var db: ContentDB
var host: HostSession
var client: ClientSession
var _to_host: Array = []
var _to_client: Array = []


## Breaks the session <-> test reference cycles so nothing leaks.
func after_each() -> void:
	if host:
		host.send = Callable()
	if client:
		client.send = Callable()


func _setup(level_file: String, seed: int = 3) -> void:
	after_each()
	db = ContentDB.load_dir()
	var level := LevelDef.load_file("res://data/levels/" + level_file)
	host = HostSession.new(Shift.new(db, level, 2, seed), func(_peer, msg): _to_client.append(_wire(msg)))
	client = ClientSession.new(Shift.new(db, level, 2, 0), 1, func(msg): _to_host.append(_wire(msg)))
	host.add_peer(PEER, 1)
	_pump()


func _wire(message: Dictionary) -> Dictionary:
	return bytes_to_var(var_to_bytes(message))


func _pump() -> void:
	while not _to_host.is_empty() or not _to_client.is_empty():
		for msg in _to_host.duplicate():
			_to_host.erase(msg)
			host.on_message(PEER, msg)
		for msg in _to_client.duplicate():
			_to_client.erase(msg)
			client.on_message(msg)


func _run(seconds: float, step: float = 0.05) -> void:
	var t := 0.0
	while t < seconds:
		host.tick(step)
		_pump()
		t += step


func _same_state() -> bool:
	host._broadcast_state()
	_pump()
	return JSON.stringify(ShiftSync.snapshot(host.shift)) == JSON.stringify(ShiftSync.snapshot(client.shift))


func test_client_mirrors_host_from_the_start() -> void:
	_setup("italy_01_pizza_night.json")
	assert_true(client.states_received >= 1)
	assert_true(_same_state())


func test_client_acts_for_its_own_chef_only() -> void:
	_setup("italy_02_aperitivo.json")
	var answers := []
	client.intent_answered.connect(func(intent, result): answers.append([intent.type, result]))
	client.do_intent({"type": "take", "ingredient": "tomato"})
	_pump()
	assert_eq(answers[0][1].ok, true, "the client's chef owns tomatoes")
	assert_eq(host.shift.kitchen.item_at(1, 0).type, "tomato")
	# Pretending to be the host's chef doesn't work.
	client.do_intent({"type": "take", "player": 0, "ingredient": "flour"})
	_pump()
	assert_eq(answers[1][1].get("error", ""), "not_owned")
	_run(0.2)
	assert_eq(client.shift.kitchen.item_at(1, 0).type, "tomato", "the mirror catches up")


func test_throwing_between_phones() -> void:
	_setup("italy_01_pizza_night.json")
	client.do_intent({"type": "take", "ingredient": "tomato"})
	client.do_intent({"type": "throw", "slot": 0, "target": 0})
	_pump()
	assert_eq(host.shift.kitchen.item_at(0, 0).type, "tomato", "lands on the host's counter")
	var thrown := host.drain_events().filter(func(e): return e.type == "item_thrown")
	assert_eq(thrown.size(), 1)
	assert_eq(thrown[0].target, 0)
	_run(0.2)
	var client_events := client.drain_events().map(func(e): return e.type)
	assert_true(client_events.has("item_thrown"), "the client sees the throw too")
	assert_true(client.shift.kitchen.item_at(1, 0) == null)
	assert_true(_same_state())


func test_pause_is_shared() -> void:
	_setup("italy_01_pizza_night.json")
	_run(1.0)
	client.set_paused(true)
	_pump()
	assert_true(host.paused)
	var time := host.shift.time
	_run(2.0)
	assert_almost(host.shift.time, time, 0.0001, "time stops")
	assert_true(client.paused)
	client.set_paused(false)
	_pump()
	_run(1.0)
	assert_true(host.shift.time > time + 0.9)


func test_whole_shift_stays_in_sync() -> void:
	_setup("italy_03_pasta_e_pizza.json")
	var bot := KitchenBot.new()
	var ended := false
	while not host.shift.finished and host.shift.time < 600.0:
		bot.step(host.shift)
		host.tick(0.1)
		_pump()
		ended = ended or client.drain_events().any(func(e): return e.type == "shift_ended")
	_pump()
	assert_true(host.shift.stats.served >= 3, "the bots served dishes")
	assert_true(client.shift.finished)
	assert_true(ended, "the client got the shift_ended event")
	assert_eq(client.shift.outcome.stars, host.shift.outcome.stars)
	assert_eq(client.shift.score, host.shift.score)
	assert_true(_same_state())


func test_festival_and_competition_status_sync() -> void:
	_setup("italy_festival_festa_della_pizza.json")
	_run(30.0, 0.25)
	var host_rules: FestivalRules = host.shift.rules
	var client_rules: FestivalRules = client.shift.rules
	assert_true(host_rules.mood < 60.0, "idle crowd gets upset")
	assert_almost(client_rules.mood, host_rules.mood)
	assert_eq(client_rules.wave, host_rules.wave)
	_setup("italy_competition_gran_premio.json")
	_run(40.0, 0.25)
	assert_true(host.shift.rival.done_count >= 1)
	assert_eq(client.shift.rival.done_count, host.shift.rival.done_count)
	assert_eq(client.shift.rival.name, host.shift.rival.name)
	assert_true(_same_state())


func test_solo_host_needs_no_network() -> void:
	db = ContentDB.load_dir()
	var solo := HostSession.new(Shift.new(db, LevelDef.load_file("res://data/levels/italy_01_pizza_night.json"), 1, 1))
	assert_ok(solo.do_intent({"type": "take", "ingredient": "flour"}))
	solo.tick(0.1)
	assert_eq(solo.drain_events()[0].type, "item_added")
