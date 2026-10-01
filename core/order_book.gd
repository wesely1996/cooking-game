class_name OrderBook
extends RefCounted
## Customers waiting at the serving window, oldest first. Each order is a
## Dictionary: {"uid", "dish", "patience", "max_patience"}. A max_patience
## below zero means the customer never leaves (competition judges).

var orders: Array[Dictionary] = []
var served := 0
var lost := 0

var _next_uid := 1
var _events: Array[Dictionary] = []


func add(dish: String, patience: float) -> Dictionary:
	var order := {"uid": _next_uid, "dish": dish, "patience": patience, "max_patience": patience}
	_next_uid += 1
	orders.append(order)
	_events.append({"type": "order_added", "order": order.duplicate()})
	return order


func active_count() -> int:
	return orders.size()


## Counts patience down. Returns the orders whose customers just left.
func tick(delta: float) -> Array[Dictionary]:
	var left: Array[Dictionary] = []
	for order in orders:
		if order.max_patience < 0.0:
			continue
		order.patience = maxf(order.patience - delta, 0.0)
		if order.patience <= 0.0:
			left.append(order)
	for order in left:
		orders.erase(order)
		lost += 1
		_events.append({"type": "order_lost", "order": order.duplicate()})
	return left


## Removes and returns the oldest order for the dish, or {} if nobody wants it.
func fulfill(dish: String) -> Dictionary:
	for order in orders:
		if order.dish == dish:
			orders.erase(order)
			served += 1
			return order
	return {}


## Fraction of patience left (1 = just arrived). 1 for orders without a timer.
static func patience_fraction(order: Dictionary) -> float:
	if order.max_patience <= 0.0:
		return 1.0
	return clampf(order.patience / order.max_patience, 0.0, 1.0)


func drain_events() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events
