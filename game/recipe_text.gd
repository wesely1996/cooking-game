class_name RecipeText
extends RefCounted
## Turns recipe steps (ContentDB.recipe_steps) into short instructions for
## the recipe book, e.g. "Chop the TOMATO with the KNIFE (swipe down ×5)".

const GESTURES := {
	"chop": "swipe down ×%d",
	"slice": "swipe down ×%d",
	"knead": "tap ×%d",
	"roll": "swipe side to side ×%d",
	"stir": "draw circles ×%d",
	"crank": "draw circles ×%d",
	"press": "tap ×%d",
	"mash": "tap ×%d",
	"grate": "swipe down ×%d",
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
	var item := _name(db, step.input)
	var tool := _name_equipment(db, step.equipment)
	var verb: String = VERBS.get(step.action, step.action.capitalize())
	if float(step.cook_time) > 0.0:
		return "%s the %s in the %s for %d s, then take it out while the ring is green" % [verb, item, tool, roundi(step.cook_time)]
	var gesture: String = GESTURES.get(step.action, "×%d") % roundi(step.work)
	if db.equipment_kind(step.equipment) == ContentDB.EQUIP_APPLIANCE:
		return "Put the %s in the %s and %s it (%s)" % [item, tool, step.action, gesture]
	return "%s the %s with the %s (%s)" % [verb, item, tool, gesture]


## All steps of a dish as numbered lines, ending with serving it.
static func instructions(db: ContentDB, dish: String) -> Array[String]:
	var lines: Array[String] = []
	for step in db.recipe_steps(dish):
		lines.append("%s → %s" % [step_text(db, step), db.item_name(step.output)])
	lines.append("Serve the %s at the SERVING WINDOW!" % _name(db, dish))
	return lines


static func _name(db: ContentDB, id: String) -> String:
	return db.item_name(id).to_upper()


static func _name_equipment(db: ContentDB, id: String) -> String:
	return str(db.equipment.get(id, {}).get("name", id)).to_upper()


static func _join(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names.back()
