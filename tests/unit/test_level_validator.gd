extends TestCase


func test_all_shipped_levels_are_valid_for_1_to_4_players() -> void:
	var db := ContentDB.load_dir()
	var levels := LevelDef.load_dir()
	assert_true(levels.size() >= 7, "levels found")
	for level in levels:
		assert_empty(LevelValidator.validate(db, level), level.id)


func test_level_ids_are_unique() -> void:
	var seen := {}
	for level in LevelDef.load_dir():
		assert_false(seen.has(level.id), "duplicate id " + level.id)
		seen[level.id] = true


func test_detects_missing_equipment_and_solo_dishes() -> void:
	var db := ContentDB.load_dir()
	var level := LevelDef.from_dict({
		"id": "broken",
		"type": "normal",
		"dishes": ["bruschetta"],
		"duration": 100,
		"stars": [1, 2, 3],
		"roles": {
			"1": [{"name": "Chef", "crates": ["bread", "tomato", "garlic", "basil"], "equipment": ["knife", "serving_window"]}],
			"2": [
				{"name": "Everything", "crates": ["bread", "tomato", "garlic", "basil"], "equipment": ["knife", "oven", "serving_window"]},
				{"name": "Idle", "crates": ["egg"], "equipment": []},
			],
		},
	})
	var errors := "\n".join(LevelValidator.validate(db, level))
	assert_true(errors.contains("nobody has the 'oven'"), "missing oven for 1 player")
	assert_true(errors.contains("'Everything' can make 'bruschetta' alone"), "solo dish")
	assert_true(errors.contains("'Idle' has nothing to do"), "idle role")
	assert_true(errors.contains("3 player(s): needs 3 roles"), "missing roles")


func test_detects_bad_competition_setup() -> void:
	var db := ContentDB.load_dir()
	var level := LevelDef.from_dict({
		"id": "bad_comp",
		"type": "competition",
		"dishes": ["pizza_margherita"],
		"roles": "trattoria",
		"judges_orders": ["bruschetta"],
		"rival": {"personality": "sleepy"},
	})
	var errors := "\n".join(LevelValidator.validate(db, level))
	assert_true(errors.contains("'bruschetta' is not on the level's menu"))
	assert_true(errors.contains("rival needs one of the personalities"))
