extends SceneTree
## Renders a contact sheet of the 3D models with the comic look, to check
## the art. Needs a display (or xvfb):
##
##   xvfb-run godot --path . --script res://tools/art/preview_models.gd -- out.png

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://models.png"
	var db := ContentDB.load_dir()
	var root := Node3D.new()
	get_root().add_child(root)
	get_root().transparent_bg = false
	RenderingServer.set_default_clear_color(Color("#f3e7cf"))
	var ids: Array = Models.ITEMS.keys()
	var x := 0
	for id in ids:
		var node := Models.item(db, id)
		node.position = Vector3((x % 9) * 0.6, 0, (x / 9) * 0.7)
		root.add_child(node)
		x += 1
	var dishes := [["plate", ["basil", "chopped_tomato", "sliced_mozzarella"]], ["plate", ["basil", "chopped_tomato", "toast"]],
		["plate", ["cooked_pasta", "tomato_sauce"]], ["plate", ["whole_pizza"]], ["dough", ["chopped_tomato"]]]
	for d in dishes:
		var node := Models.item(db, d[0], d[1])
		node.position = Vector3((x % 9) * 0.6, 0, (x / 9) * 0.7)
		root.add_child(node)
		x += 1
	var sx := 0
	for type in Models.STATIONS:
		var node := Models.station(type)
		node.position = Vector3(sx * 1.1, 0, 3.0)
		root.add_child(node)
		sx += 1
	for i in 3:
		var chef := Models.chef({"skin": i, "hair": i, "hair_color": i, "hat": i, "apron": i})
		chef.position = Vector3(i * 0.9, 0, 4.6)
		root.add_child(chef)
		Models.animate(chef, "idle", true)
	var cab := Models.prop("cabinet")
	cab.position = Vector3(3.5, 0, 4.6)
	root.add_child(cab)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	var focus := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "all"
	match focus:
		"chefs":
			cam.look_at_from_position(Vector3(0.9, 2.2, 7.6), Vector3(0.9, 0.7, 4.6))
		"food":
			cam.look_at_from_position(Vector3(2.4, 2.6, 2.6), Vector3(2.4, 0.0, 0.7))
		_:
			cam.look_at_from_position(Vector3(2.6, 6.5, 9.5), Vector3(2.6, 0.0, 2.4))
	cam.current = true
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
