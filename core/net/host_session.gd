class_name HostSession
extends RefCounted
## Runs a shift on the host (or alone, in solo play): the only place where the
## game rules run. Remote players send intents as messages; the host applies
## them for the sender's own player index, answers with the result, and sends
## everyone a state snapshot plus the events since the last one, several
## times a second.
##
## Messages are plain Dictionaries with a "t" (type) field:
##   client -> host: {"t": "intent", "id": int, "intent": {...}}
##                   {"t": "pause", "on": bool}
##   host -> client: {"t": "state", "snap": {...}, "events": [...], "paused": bool}
##                   {"t": "result", "id": int, "result": {...}}

const SEND_INTERVAL := 1.0 / 15.0

var shift: Shift
var me := 0  # the host's own player index
var paused := false
## func(peer_id: int, message: Dictionary). Unset in solo play.
var send: Callable

var _peers := {}  # peer id -> player index
var _local_events: Array[Dictionary] = []
var _net_events: Array[Dictionary] = []
var _since_send := 0.0


func _init(p_shift: Shift, p_send: Callable = Callable()) -> void:
	shift = p_shift
	send = p_send


func add_peer(peer_id: int, player: int) -> void:
	_peers[peer_id] = player
	_broadcast_state()


func has_peers() -> bool:
	return not _peers.is_empty()


func tick(delta: float) -> void:
	if not paused:
		shift.tick(delta)
	_collect()
	_since_send += delta
	if _since_send >= SEND_INTERVAL or shift.finished:
		_broadcast_state()


## An action by the host's own player.
func do_intent(intent: Dictionary) -> Dictionary:
	intent.player = me
	var result := shift.do_intent(intent)
	_collect()
	return result


func set_paused(on: bool) -> void:
	paused = on
	_broadcast_state()


func on_message(peer_id: int, message: Dictionary) -> void:
	if not _peers.has(peer_id):
		return
	match str(message.get("t", "")):
		"intent":
			var intent: Dictionary = message.get("intent", {})
			# A client may only act for its own chef.
			intent.player = _peers[peer_id]
			var result := shift.do_intent(intent)
			_collect()
			_send(peer_id, {"t": "result", "id": message.get("id", 0), "result": result})
		"pause":
			set_paused(bool(message.get("on", false)))


## Events for the host's own screen.
func drain_events() -> Array[Dictionary]:
	_collect()
	var events := _local_events
	_local_events = []
	return events


func _collect() -> void:
	var events := shift.drain_events()
	_local_events.append_array(events)
	if has_peers():
		_net_events.append_array(events)


func _broadcast_state() -> void:
	_since_send = 0.0
	if not has_peers():
		return
	var message := {"t": "state", "snap": ShiftSync.snapshot(shift), "events": _net_events, "paused": paused}
	_net_events = []
	for peer_id in _peers:
		_send(peer_id, message)


func _send(peer_id: int, message: Dictionary) -> void:
	if send.is_valid():
		send.call(peer_id, message)
