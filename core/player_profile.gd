class_name PlayerProfile
extends RefCounted
## The player's name, chef look and what they have played: per cuisine, how
## many shifts, their total score and time. From that come the favourite
## cuisine (played most) and the best cuisine (highest average score).

const MAX_NAME_LENGTH := 16
const DEFAULT_NAME := "Chef"

var name := DEFAULT_NAME
var look := {}  # option indexes, see ChefLook (game layer)
var cuisines := {}  # pack id -> {"plays": int, "score": int, "seconds": float}
var dishes_served := 0


## Name as typed, trimmed and limited; falls back to "Chef".
static func clean_name(value: String) -> String:
	var cleaned := value.strip_edges().replace("\n", " ").substr(0, MAX_NAME_LENGTH)
	return cleaned if not cleaned.is_empty() else DEFAULT_NAME


func record(pack: String, score: int, seconds: float, served: int) -> void:
	var entry: Dictionary = cuisines.get(pack, {"plays": 0, "score": 0, "seconds": 0.0})
	entry.plays = int(entry.plays) + 1
	entry.score = int(entry.score) + maxi(score, 0)
	entry.seconds = float(entry.seconds) + maxf(seconds, 0.0)
	cuisines[pack] = entry
	dishes_served += maxi(served, 0)


func total_plays() -> int:
	var total := 0
	for entry in cuisines.values():
		total += int(entry.plays)
	return total


func average_score(pack: String) -> float:
	var entry: Dictionary = cuisines.get(pack, {})
	return float(entry.score) / entry.plays if int(entry.get("plays", 0)) > 0 else 0.0


## The cuisine played most (ties go to the one played longer), or "".
func favorite_cuisine() -> String:
	var best := ""
	for pack in cuisines:
		if best.is_empty():
			best = pack
			continue
		var a: Dictionary = cuisines[pack]
		var b: Dictionary = cuisines[best]
		if int(a.plays) > int(b.plays) or (int(a.plays) == int(b.plays) and float(a.seconds) > float(b.seconds)):
			best = pack
	return best


## The cuisine with the highest average score per shift, or "".
func best_cuisine() -> String:
	var best := ""
	for pack in cuisines:
		if int(cuisines[pack].plays) > 0 and (best.is_empty() or average_score(pack) > average_score(best)):
			best = pack
	return best


func to_dict() -> Dictionary:
	return {"name": name, "look": look.duplicate(), "cuisines": cuisines.duplicate(true), "dishes_served": dishes_served}


func load_dict(data: Dictionary) -> void:
	name = clean_name(str(data.get("name", DEFAULT_NAME)))
	look = data.get("look", {}).duplicate() if data.get("look", {}) is Dictionary else {}
	cuisines.clear()
	var saved: Dictionary = data.get("cuisines", {})
	for pack in saved:
		var entry: Dictionary = saved[pack]
		cuisines[pack] = {"plays": int(entry.get("plays", 0)), "score": int(entry.get("score", 0)), "seconds": float(entry.get("seconds", 0.0))}
	dishes_served = int(data.get("dishes_served", 0))
