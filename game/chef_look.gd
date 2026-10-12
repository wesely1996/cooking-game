class_name ChefLook
extends RefCounted
## A player's chef: which character model, which hat and the colours of the
## hat and the apron. A look is a small Dictionary of option indexes, so it
## can be saved and sent to the other phone in a LAN game. The chef itself
## is built in 3D by Models.chef.

const HATS := ["Toque", "Cap", "Bandana", "No hat"]
const APRONS := [Color("#e5352b"), Color("#3f8fe0"), Color("#3fae49"), Color("#f2b632"), Color("#b48ce0"), Color("#2b2523"),
	Color("#ff8ac6"), Color("#f8f4ec")]
## White first, so the classic toque is the default; then the apron colours.
const HAT_COLORS := [Color("#f8f4ec"), Color("#e5352b"), Color("#3f8fe0"), Color("#3fae49"), Color("#f2b632"),
	Color("#b48ce0"), Color("#2b2523"), Color("#ff8ac6")]

## The editable parts, with their option counts and display names. "model"
## picks one of the character models that fit a chef's hat (see
## Models.CHEF_VARIANTS).
const PARTS := {
	"model": {"label": "Chef", "count": 10},
	"hat": {"label": "Hat", "count": 4},
	"hat_color": {"label": "Hat colour", "count": 8},
	"apron": {"label": "Apron", "count": 8},
}


static func default_look() -> Dictionary:
	return {"model": 0, "hat": 0, "hat_color": 0, "apron": 0}


## A valid look from any (saved or received) Dictionary. Looks from v0.6.0
## and older (skin, hair, hair colour) turn into the model those players saw,
## and their hat keeps its colour (the toque was white, other hats took the
## apron's colour).
static func sanitize(look: Variant) -> Dictionary:
	var result := default_look()
	if not look is Dictionary:
		return result
	var data: Dictionary = look
	if not data.has("model") and (data.has("skin") or data.has("hair")):
		data = data.duplicate()
		data["model"] = int(data.get("skin", 0)) * 2 + int(data.get("hair", 0))
		var old_apron := posmod(int(data.get("apron", 0)), 6)
		data["hat_color"] = 0 if int(data.get("hat", 0)) == 0 else old_apron + 1
	for part in PARTS:
		result[part] = posmod(int(data.get(part, 0)), PARTS[part].count)
	return result


static func option_name(part: String, index: int) -> String:
	match part:
		"model":
			return "%d / %d" % [index + 1, PARTS.model.count]
		"hat":
			return HATS[index]
	return "%d" % (index + 1)


static func option_color(part: String, index: int) -> Variant:
	match part:
		"hat_color":
			return HAT_COLORS[index]
		"apron":
			return APRONS[index]
	return null
