extends Control
## Placeholder start screen until the menus exist (milestone M2). Loads all
## content and shows whether it is valid, so a device build can be checked.

const BACKGROUND := Color("#ffd75e")
const INK := Color("#1d1a2f")


func _ready() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	var title := Label.new()
	title.text = "PASS THE PLATE!"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var info := Label.new()
	info.text = _content_summary()
	info.add_theme_font_size_override("font_size", 22)
	info.add_theme_color_override("font_color", INK)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(info)


func _content_summary() -> String:
	var db := ContentDB.load_dir()
	var levels := LevelDef.load_dir()
	var errors := db.validate()
	for level in levels:
		errors.append_array(LevelValidator.validate(db, level))
	var dishes := db.items.values().filter(func(item): return item.kind == ContentDB.KIND_DISH)
	var summary := "%d cuisines · %d dishes · %d levels" % [db.pack_ids.size() - 1, dishes.size(), levels.size()]
	if errors.is_empty():
		return summary + "\nKitchen is coming soon!"
	return summary + "\n%d content errors:\n%s" % [errors.size(), "\n".join(errors.slice(0, 5))]
