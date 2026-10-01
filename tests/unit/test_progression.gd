extends TestCase


func test_first_level_open_rest_locked() -> void:
	var progress := Progression.load_map()
	assert_true(progress.regions.size() >= 1)
	assert_true(progress.is_level_unlocked("italy_01"))
	assert_false(progress.is_level_unlocked("italy_02"))
	assert_false(progress.is_level_unlocked("unknown_level"))


func test_stars_unlock_levels() -> void:
	var progress := Progression.load_map()
	progress.record("italy_01", {"type": "normal", "failed": false, "stars": 2})
	assert_true(progress.is_level_unlocked("italy_02"))
	assert_false(progress.is_level_unlocked("italy_03"))
	progress.record("italy_01", {"type": "normal", "failed": false, "stars": 1})
	assert_eq(progress.best_stars["italy_01"], 2, "best result is kept")


func test_failed_boss_does_not_count() -> void:
	var progress := Progression.load_map()
	progress.record("italy_competition", {"type": "competition", "failed": true, "stars": 0})
	assert_false(progress.won.has("italy_competition"))
	progress.record("italy_competition", {"type": "competition", "failed": false, "stars": 1})
	assert_true(progress.is_region_complete(0))


func test_next_region_needs_the_competition_win() -> void:
	var progress := Progression.new([
		{"id": "a", "pack": "italian", "boss": "a_boss", "levels": [{"id": "a_1", "stars_required": 0}, {"id": "a_boss", "stars_required": 0}]},
		{"id": "b", "pack": "mexican", "boss": "b_boss", "levels": [{"id": "b_1", "stars_required": 0}]},
	])
	assert_false(progress.is_level_unlocked("b_1"))
	assert_eq(progress.unlocked_arcade_packs(), ["italian"] as Array[String])
	progress.record("a_boss", {"type": "competition", "failed": false, "stars": 1})
	assert_true(progress.is_level_unlocked("b_1"))
	assert_eq(progress.unlocked_arcade_packs(), ["italian", "mexican"] as Array[String])


func test_save_round_trip() -> void:
	var progress := Progression.load_map()
	progress.record("italy_01", {"type": "normal", "failed": false, "stars": 3})
	progress.record("italy_festival", {"type": "festival", "failed": false, "stars": 2})
	var copy := Progression.load_map()
	copy.load_save(JSON.parse_string(JSON.stringify(progress.to_dict())))
	assert_eq(copy.total_stars(), 5)
	assert_true(copy.won.has("italy_festival"))
