class_name Progression
extends RefCounted
## Story mode progress on the world map: best stars per level and which
## festivals and competitions were won. Stars unlock levels within a region;
## winning a region's competition opens the next region.
##
## The map comes from data/story/world_map.json:
## {"regions": [{"id", "name", "boss", "levels": [{"id", "stars_required"}]}]}

const DEFAULT_MAP_PATH := "res://data/story/world_map.json"

var regions: Array = []
var best_stars := {}  # level id -> int
var won := {}  # level id -> true, for festivals and competitions that were won
var discovered := {}  # dish id -> true, once the players have served it


func _init(p_regions: Array = []) -> void:
	regions = p_regions


static func load_map(path: String = DEFAULT_MAP_PATH) -> Progression:
	var data: Variant = DataFiles.read_json(path)
	return Progression.new(data.get("regions", []) if data is Dictionary else [])


## Records a finished shift. Failed attempts never lower earlier results.
func record(level_id: String, outcome: Dictionary) -> void:
	if outcome.get("failed", false):
		return
	best_stars[level_id] = maxi(int(best_stars.get(level_id, 0)), int(outcome.get("stars", 0)))
	if outcome.get("type", "") in [LevelDef.TYPE_FESTIVAL, LevelDef.TYPE_COMPETITION]:
		won[level_id] = true


## Marks a dish as made. Returns true the first time.
func discover(dish: String) -> bool:
	if discovered.has(dish):
		return false
	discovered[dish] = true
	return true


func is_discovered(dish: String) -> bool:
	return discovered.has(dish)


func total_stars() -> int:
	var total := 0
	for stars in best_stars.values():
		total += int(stars)
	return total


func region_stars(region_index: int) -> int:
	var total := 0
	for entry in regions[region_index].get("levels", []):
		total += int(best_stars.get(entry.id, 0))
	return total


func is_region_unlocked(region_index: int) -> bool:
	if region_index <= 0:
		return true
	return won.has(regions[region_index - 1].get("boss", ""))


func is_region_complete(region_index: int) -> bool:
	return won.has(regions[region_index].get("boss", ""))


func is_level_unlocked(level_id: String) -> bool:
	for i in regions.size():
		for entry in regions[i].get("levels", []):
			if entry.id == level_id:
				return is_region_unlocked(i) and region_stars(i) >= int(entry.get("stars_required", 0))
	return false


## Arcade mode offers the cuisines of every region the players have reached.
func unlocked_arcade_packs() -> Array[String]:
	var packs: Array[String] = []
	for i in regions.size():
		var pack := str(regions[i].get("pack", ""))
		if is_region_unlocked(i) and not pack.is_empty() and not packs.has(pack):
			packs.append(pack)
	return packs


func to_dict() -> Dictionary:
	return {"best_stars": best_stars.duplicate(), "won": won.keys(), "discovered": discovered.keys()}


func load_save(data: Dictionary) -> void:
	best_stars.clear()
	won.clear()
	discovered.clear()
	var stars: Dictionary = data.get("best_stars", {})
	for level_id in stars:
		best_stars[level_id] = int(stars[level_id])
	for level_id in data.get("won", []):
		won[level_id] = true
	for dish in data.get("discovered", []):
		discovered[dish] = true
