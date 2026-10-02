extends TestCase


func test_favorite_is_played_most_and_best_is_highest_average() -> void:
	var profile := PlayerProfile.new()
	assert_eq(profile.favorite_cuisine(), "")
	assert_eq(profile.best_cuisine(), "")
	profile.record("italian", 300, 180.0, 6)
	profile.record("italian", 100, 180.0, 2)
	profile.record("italian", 200, 180.0, 4)
	profile.record("mexican", 500, 180.0, 9)
	assert_eq(profile.favorite_cuisine(), "italian", "3 Italian shifts vs 1 Mexican")
	assert_eq(profile.best_cuisine(), "mexican", "average 500 vs 200")
	assert_almost(profile.average_score("italian"), 200.0)
	assert_eq(profile.dishes_served, 21)
	assert_eq(profile.total_plays(), 4)


func test_ties_on_plays_go_to_more_time() -> void:
	var profile := PlayerProfile.new()
	profile.record("italian", 100, 100.0, 1)
	profile.record("japanese", 100, 300.0, 1)
	assert_eq(profile.favorite_cuisine(), "japanese")


func test_names_are_cleaned() -> void:
	assert_eq(PlayerProfile.clean_name("   "), "Chef")
	assert_eq(PlayerProfile.clean_name("  Nikola  "), "Nikola")
	assert_eq(PlayerProfile.clean_name("A very very long chef name"), "A very very long")


func test_save_round_trip() -> void:
	var profile := PlayerProfile.new()
	profile.name = "Luigi"
	profile.look = {"skin": 2, "hat": 1}
	profile.record("japanese", 420, 200.0, 7)
	var copy := PlayerProfile.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_eq(copy.name, "Luigi")
	assert_eq(int(copy.look.skin), 2)
	assert_eq(copy.best_cuisine(), "japanese")
	assert_eq(copy.dishes_served, 7)
