class_name RecipeText
extends RefCounted
## Turns recipe steps (ContentDB.recipe_steps) into short instructions for
## the recipe book, e.g. "Chop the TOMATO on the CHOPPING BOARD (tap ×4)".

const GESTURES := {
	"chop": "tap ×%d",
	"slice": "tap ×%d",
	"knead": "tap ×%d",
	"roll": "swipe side to side ×%d",
	"stir": "draw circles ×%d",
	"crank": "draw circles ×%d",
	"press": "tap ×%d",
	"mash": "tap ×%d",
	"grate": "tap ×%d",
	"whisk": "draw circles ×%d",
	"blend": "draw circles ×%d",
}
const VERBS := {
	"chop": "Chop", "slice": "Slice", "knead": "Knead", "roll": "Roll out",
	"stir": "Stir", "crank": "Crank", "bake": "Bake", "boil": "Boil",
	"press": "Press", "mash": "Mash", "grate": "Grate", "cook": "Cook", "sizzle": "Fry",
	"grill": "Grill", "steam": "Steam", "fry": "Fry", "simmer": "Simmer", "whisk": "Whisk", "blend": "Blend",
}


static func step_text(db: ContentDB, step: Dictionary) -> String:
	if step.kind == "assembly":
		var parts: Array = step.parts.map(func(p): return _name(db, p))
		return "Put the %s on the %s" % [_join(parts), _name(db, step.base)]
	var inputs: Array = step.inputs.map(func(i): return _name(db, i))
	var station := _name_station(db, step.station)
	var verb: String = VERBS.get(step.action, step.action.capitalize())
	if float(step.cook_time) > 0.0:
		return "%s the %s in the %s for %d s, then take it out while the ring is green" % [verb, _join(inputs), station, roundi(step.cook_time)]
	var gesture: String = GESTURES.get(step.action, "×%d") % roundi(step.work)
	if inputs.size() > 1:
		return "Put the %s in the %s and %s (%s)" % [_join(inputs), station, step.action, gesture]
	return "%s the %s on the %s (%s)" % [verb, _join(inputs), station, gesture]


## All steps of a dish as numbered lines, ending with serving it.
static func instructions(db: ContentDB, dish: String) -> Array[String]:
	var lines: Array[String] = []
	for step in db.recipe_steps(dish):
		lines.append("%s → %s" % [step_text(db, step), db.item_name(step.output)])
	lines.append("Serve the %s at the SERVING WINDOW!" % _name(db, dish))
	return lines


static func _name(db: ContentDB, id: String) -> String:
	return db.item_name(id).to_upper()


static func _name_station(db: ContentDB, id: String) -> String:
	return db.station_name(id).to_upper()


static func _join(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names.back()
