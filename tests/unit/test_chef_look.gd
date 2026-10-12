extends TestCase
## The chef's look: a character model, a hat, and separate hat and apron
## colours; older looks (skin, hair) turn into the chef players already had.


func test_default_look_is_a_white_toque() -> void:
	var look := ChefLook.sanitize({})
	assert_eq(look, {"model": 0, "hat": 0, "hat_color": 0, "apron": 0})
	assert_eq(ChefLook.HAT_COLORS[0], Color("#f8f4ec"), "the classic toque is white")


func test_values_wrap_into_range() -> void:
	var look := ChefLook.sanitize({"model": 12, "hat": -1, "hat_color": 9, "apron": 3})
	assert_eq(look, {"model": 2, "hat": 3, "hat_color": 1, "apron": 3})


func test_old_looks_keep_their_chef() -> void:
	# v0.6.0 picked the model from skin and hair: skin * 2 + hair.
	var look := ChefLook.sanitize({"skin": 3, "hair": 2, "hair_color": 1, "hat": 0, "apron": 2})
	assert_eq(int(look.model), 8)
	assert_eq(int(look.hat_color), 0, "the old toque was white")
	assert_eq(int(look.apron), 2)
	# Caps and bandanas took the apron's colour.
	var cap := ChefLook.sanitize({"skin": 0, "hair": 1, "hat": 1, "apron": 2})
	assert_eq(ChefLook.HAT_COLORS[int(cap.hat_color)], ChefLook.APRONS[2])
	assert_eq(int(cap.model), 1)


func test_every_part_has_names_or_colours() -> void:
	for part in ChefLook.PARTS:
		for i in ChefLook.PARTS[part].count:
			var colour: Variant = ChefLook.option_color(part, i)
			assert_true(colour != null or not ChefLook.option_name(part, i).is_empty(), "%s %d shows something" % [part, i])
