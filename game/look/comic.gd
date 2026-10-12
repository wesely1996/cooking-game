class_name Comic
extends RefCounted
## Gives 3D models the comic look (art/shaders/comic.gdshader with an ink
## outline). Background things are muted; "actors" (food, chefs, the station
## you can use right now) keep full colour and can "pop" when they need you.

const SHADER := preload("res://art/shaders/comic.gdshader")
const OUTLINE := preload("res://art/shaders/comic_outline.gdshader")

## Spider-Verse print colours used across the game.
const MAGENTA := Color("#ff2fa4")
const CYAN := Color("#19d8ff")
const YELLOW := Color("#ffe14a")
const INK := Color("#1d1a2f")
const PAPER := Color("#f8eedb")

static var _shared := {}  # cache key -> ShaderMaterial (muted background)
static var _outlines := {}  # width -> ShaderMaterial


## Replaces the materials of every mesh under `node`.
## muted: 0 (an actor) .. 1 (background). tint: multiplied with the colours.
## unique: give this node its own materials, so pop() and tint() can change
## it alone (food, stations, chefs).
static func apply(node: Node, muted: float = 0.0, tint: Color = Color.WHITE, unique: bool = false, outline_px: float = 2.5) -> void:
	var own: Array[ShaderMaterial] = []
	for mesh in _meshes(node):
		for s in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(s)
			var material: ShaderMaterial
			if unique:
				material = _make(source, muted, tint, outline_px)
				own.append(material)
			else:
				var key := "%s|%.2f|%s|%.1f" % [source.get_instance_id() if source else 0, muted, tint.to_html(), outline_px]
				if not _shared.has(key):
					_shared[key] = _make(source, muted, tint, outline_px)
				material = _shared[key]
			mesh.set_surface_override_material(s, material)
	if unique:
		node.set_meta("comic_materials", own)


## Highlights a node given unique materials (0 = off, 1 = full).
static func pop(node: Node, amount: float) -> void:
	set_param(node, "pop", amount)


static func set_param(node: Node, param: String, value: Variant) -> void:
	for material in node.get_meta("comic_materials", []):
		if material.get_shader_parameter(param) != value:
			material.set_shader_parameter(param, value)


static func _make(source: Material, muted: float, tint: Color, outline_px: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		material.set_shader_parameter("albedo_color", base.albedo_color)
		if base.albedo_texture:
			material.set_shader_parameter("albedo_texture", base.albedo_texture)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("muted", muted)
	if outline_px > 0.0:
		material.next_pass = _outline(outline_px)
	return material


static func _outline(width: float) -> ShaderMaterial:
	if not _outlines.has(width):
		var material := ShaderMaterial.new()
		material.shader = OUTLINE
		material.set_shader_parameter("width_px", width)
		material.set_shader_parameter("ink", INK)
		_outlines[width] = material
	return _outlines[width]


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result.append(node)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if (child as MeshInstance3D).mesh:
			result.append(child)
	return result
