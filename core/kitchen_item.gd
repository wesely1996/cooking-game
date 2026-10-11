class_name KitchenItem
extends RefCounted
## One piece of food in the kitchen: on a station (counter, board, pot...) or
## in the air. Assemblies keep the base item (a plate, a pizza dough) and list
## the parts added to it.

var uid: int
var type: String
var contents: Array = []  # parts added to this base item, sorted
var work := 0.0  # work done by hand, kept when the food leaves a board half-done
var work_recipe := ""  # the recipe `work` belongs to
var perfect := false  # taken out of a pot, pan or oven during the perfect window


func _init(p_uid: int = 0, p_type: String = "") -> void:
	uid = p_uid
	type = p_type


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"type": type,
		"contents": contents.duplicate(),
		"work": work,
		"work_recipe": work_recipe,
		"perfect": perfect,
	}


static func from_dict(data: Dictionary) -> KitchenItem:
	var item := KitchenItem.new(int(data.get("uid", 0)), str(data.get("type", "")))
	for part in data.get("contents", []):
		item.contents.append(str(part))
	item.work = float(data.get("work", 0.0))
	item.work_recipe = str(data.get("work_recipe", ""))
	item.perfect = bool(data.get("perfect", false))
	return item
