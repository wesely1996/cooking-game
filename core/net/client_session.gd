class_name ClientSession
extends RefCounted
## A remote player's view of a shift running on the host. The client keeps a
## mirror Shift that is never ticked; every state message from the host
## overwrites it. Player actions are sent to the host, which answers with
## the result (used for "NOPE!" feedback).

signal intent_answered(intent: Dictionary, result: Dictionary)

var shift: Shift
var me := 1
var paused := false
## func(message: Dictionary) -> sends to the host.
var send: Callable
var states_received := 0

var _events: Array[Dictionary] = []
var _pending := {}  # intent id -> intent
var _next_id := 1


func _init(p_shift: Shift, p_me: int, p_send: Callable) -> void:
	shift = p_shift
	me = p_me
	send = p_send


func tick(_delta: float) -> void:
	pass  # the host runs the rules


## Sends an action to the host. The real result arrives later through
## intent_answered; this returns {"ok": true, "pending": true}.
func do_intent(intent: Dictionary) -> Dictionary:
	intent.player = me
	var id := _next_id
	_next_id += 1
	_pending[id] = intent
	send.call({"t": "intent", "id": id, "intent": intent})
	return {"ok": true, "pending": true}


func set_paused(on: bool) -> void:
	send.call({"t": "pause", "on": on})


func on_message(message: Dictionary) -> void:
	match str(message.get("t", "")):
		"state":
			ShiftSync.apply(shift, message.get("snap", {}))
			paused = bool(message.get("paused", false))
			for event in message.get("events", []):
				_events.append(event)
			states_received += 1
		"result":
			var id := int(message.get("id", 0))
			var intent: Dictionary = _pending.get(id, {})
			_pending.erase(id)
			intent_answered.emit(intent, message.get("result", {}))


func drain_events() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events
