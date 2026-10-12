extends SceneTree
## Renders the 2D pictures of food and stations (art/icons/items/<id>.png,
## art/icons/stations/<id>.png) from the 3D models with the comic look, so
## order cards, the recipe book and flying food match the 3D kitchen. Run it
## again after adding food or changing a model. Needs a display (or xvfb):
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/art/render_icons.gd

const SIZE := 192
const PITCH := 32.0  # degrees the camera looks down
const OUT_ITEMS := "res://art/icons/items"
const OUT_STATIONS := "res://art/icons/stations"


func _initialize() -> void:
	var db := ContentDB.load_dir()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ITEMS))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_STATIONS))

	var jobs: Array = []
	for id in db.items:
		jobs.append({"path": "%s/%s.png" % [OUT_ITEMS, id], "build": _item_builder(db, id)})
	for type in db.stations:
		jobs.append({"path": "%s/%s.png" % [OUT_STATIONS, type], "build": func() -> Node3D: return Models.station(type)})
	for job in jobs:
		var node: Node3D = job.build.call()
		viewport.add_child(node)
		await process_frame  # in the tree, so global transforms are known
		_frame(camera, _bounds(node))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(job.path))
		node.queue_free()
		await process_frame
	print("Rendered %d icons." % jobs.size())
	quit()


## Dishes are drawn the way the kitchen draws them: their base with the parts.
func _item_builder(db: ContentDB, id: String) -> Callable:
	if db.assemblies.has(id):
		var asm: Dictionary = db.assemblies[id]
		return func() -> Node3D: return Models.item(db, asm.base, asm.parts)
	return func() -> Node3D: return Models.item(db, id)


func _frame(camera: Camera3D, box: AABB) -> void:
	var center := box.get_center()
	var direction := Vector3(0.35, sin(deg_to_rad(PITCH)), cos(deg_to_rad(PITCH))).normalized()
	var eye := center + direction * (box.size.length() + 2.0)
	camera.transform = Transform3D(Basis.looking_at(center - eye, Vector3.UP), eye)
	# Fit the box's corners as seen from the camera, with a little room.
	var extent := 0.0
	for i in 8:
		var corner := box.get_endpoint(i) - center
		extent = maxf(extent, maxf(absf(corner.dot(camera.transform.basis.x)), absf(corner.dot(camera.transform.basis.y))))
	camera.size = extent * 2.0 * 1.12


func _bounds(node: Node3D) -> AABB:
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	if meshes.is_empty():
		return AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.4, 0.4))
	var box: AABB = meshes[0].global_transform * meshes[0].get_aabb()
	for mesh in meshes:
		box = box.merge(mesh.global_transform * mesh.get_aabb())
	return box
