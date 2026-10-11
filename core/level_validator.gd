class_name LevelValidator
extends RefCounted
## Checks that a level can actually be played with 1, 2, 3 and 4 players:
## every dish can be made from the crates and stations the roles own, exactly
## one player serves, every player has something to do and somewhere to put
## food down, and (with 2+ players) the server can't make a dish alone, so
## teamwork is needed.

const PLAYER_COUNTS := [1, 2, 3, 4]
const MIN_COUNTERS := 2


static func validate(db: ContentDB, level: LevelDef) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "level '%s': " % level.id
	if level.id.is_empty():
		errors.append("level without an id")
	if not LevelDef.TYPES.has(level.type):
		errors.append(prefix + "unknown type '%s'" % level.type)
	if level.dishes.is_empty():
		errors.append(prefix + "has no dishes")
	for dish in level.dish_ids():
		if not db.is_dish(dish):
			errors.append(prefix + "'%s' is not a dish" % dish)
	if not errors.is_empty():
		return errors
	errors.append_array(_validate_type(level, prefix))
	for n in PLAYER_COUNTS:
		errors.append_array(_validate_roles(db, level, n, prefix + "%d player(s): " % n))
	return errors


static func _validate_type(level: LevelDef, prefix: String) -> Array[String]:
	var errors: Array[String] = []
	match level.type:
		LevelDef.TYPE_NORMAL:
			for n in PLAYER_COUNTS:
				if float(level.value("duration", n, 0.0)) <= 0.0:
					errors.append(prefix + "needs a duration")
				var stars: Variant = level.value("stars", n, [])
				if not (stars is Array and stars.size() == 3):
					errors.append(prefix + "needs three star thresholds for %d player(s)" % n)
		LevelDef.TYPE_FESTIVAL:
			var waves: Array = level.data.get("waves", [])
			if waves.is_empty():
				errors.append(prefix + "a festival needs waves")
			for wave in waves:
				for n in PLAYER_COUNTS:
					if int(LevelDef.pick(wave.get("customers", 0), n)) <= 0:
						errors.append(prefix + "every wave needs customers")
		LevelDef.TYPE_COMPETITION:
			var judges: Array = level.data.get("judges_orders", [])
			if judges.is_empty():
				errors.append(prefix + "a competition needs judges_orders")
			for dish in judges:
				if not level.dish_ids().has(dish):
					errors.append(prefix + "judges order '%s' is not on the level's menu" % dish)
			var rival: Dictionary = level.data.get("rival", {})
			if not RivalChef.PERSONALITIES.has(rival.get("personality", "")):
				errors.append(prefix + "rival needs one of the personalities %s" % [RivalChef.PERSONALITIES])
	return errors


static func _validate_roles(db: ContentDB, level: LevelDef, n: int, prefix: String) -> Array[String]:
	var errors: Array[String] = []
	var roles := level.roles_for(n, db)
	if roles.size() != n:
		return [prefix + "needs %d roles, has %d" % [n, roles.size()]]
	var pass_owners := 0
	var all_crates := {}
	var all_stations := {}
	for role in roles:
		var role_stations: Dictionary = role.get("stations", {})
		var counters := 0
		for crate in role.get("crates", []):
			if not db.is_raw(crate):
				errors.append(prefix + "role '%s' has unknown crate '%s'" % [role.get("name", "?"), crate])
			all_crates[crate] = true
		for st in role_stations:
			if not db.stations.has(st):
				errors.append(prefix + "role '%s' has unknown station '%s'" % [role.get("name", "?"), st])
				continue
			match db.station_kind(st):
				ContentDB.STATION_PASS:
					pass_owners += 1
				ContentDB.STATION_COUNTER:
					counters += int(role_stations[st])
			all_stations[st] = true
		if counters < MIN_COUNTERS:
			errors.append(prefix + "role '%s' needs at least %d counter spots" % [role.get("name", "?"), MIN_COUNTERS])
	if pass_owners != 1:
		errors.append(prefix + "exactly one player must own the serving window (found %d)" % pass_owners)

	var used_crates := {}
	var used_stations := {}
	for dish in level.dish_ids():
		var raw := db.raw_requirements(dish)
		var needed := db.station_requirements(dish)
		for crate in raw:
			used_crates[crate] = true
			if not all_crates.has(crate):
				errors.append(prefix + "nobody has the '%s' needed for '%s'" % [crate, dish])
		for st in needed:
			used_stations[st] = true
			if not all_stations.has(st):
				errors.append(prefix + "nobody has the '%s' needed for '%s'" % [st, dish])
		if n >= 2:
			for role in roles:
				if _can_make_alone(db, role, raw, needed):
					errors.append(prefix + "role '%s' can make '%s' alone" % [role.get("name", "?"), dish])

	for role in roles:
		var useful := false
		for crate in role.get("crates", []):
			useful = useful or used_crates.has(crate)
		for st in role.get("stations", {}):
			useful = useful or used_stations.has(st) or db.station_kind(st) == ContentDB.STATION_PASS
		if not useful:
			errors.append(prefix + "role '%s' has nothing to do" % role.get("name", "?"))
	return errors


static func _can_make_alone(db: ContentDB, role: Dictionary, raw: Array, needed: Array) -> bool:
	var crates: Array = role.get("crates", [])
	var role_stations: Dictionary = role.get("stations", {})
	var serves := role_stations.keys().any(func(st): return db.station_kind(st) == ContentDB.STATION_PASS)
	return serves and raw.all(func(c): return crates.has(c)) and needed.all(func(st): return role_stations.has(st))
