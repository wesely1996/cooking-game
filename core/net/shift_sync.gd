class_name ShiftSync
extends RefCounted
## Turns a running Shift into a plain Dictionary the host sends to clients
## several times a second, and applies it to a client's mirror Shift. Only
## plain values (no objects), so it is safe to send over the network.


static func snapshot(shift: Shift) -> Dictionary:
	return {
		"time": shift.time,
		"score": shift.score,
		"combo": shift.combo,
		"stats": shift.stats.duplicate(),
		"finished": shift.finished,
		"outcome": shift.outcome.duplicate(),
		"kitchen": shift.kitchen.snapshot(),
		"orders": shift.orders.orders.duplicate(true),
		"served": shift.orders.served,
		"lost": shift.orders.lost,
		"rules": shift.rules.sync_state(),
		"rival": shift.rival.sync_state() if shift.rival else {},
	}


## Makes the mirror look exactly like the host's shift. The mirror is never
## ticked: all game rules run on the host.
static func apply(shift: Shift, snap: Dictionary) -> void:
	shift.time = float(snap.get("time", shift.time))
	shift.score = int(snap.get("score", shift.score))
	shift.combo = int(snap.get("combo", shift.combo))
	var stats: Dictionary = snap.get("stats", {})
	for key in stats:
		shift.stats[key] = int(stats[key])
	shift.finished = bool(snap.get("finished", false))
	shift.outcome = snap.get("outcome", {}).duplicate()
	shift.kitchen.load_snapshot(snap.get("kitchen", {}))
	var orders: Array[Dictionary] = []
	for order in snap.get("orders", []):
		orders.append(order.duplicate())
	shift.orders.orders = orders
	shift.orders.served = int(snap.get("served", 0))
	shift.orders.lost = int(snap.get("lost", 0))
	shift.rules.load_sync_state(snap.get("rules", {}))
	var rival: Dictionary = snap.get("rival", {})
	if shift.rival and not rival.is_empty():
		shift.rival.load_sync_state(rival)
