class_name Models
extends RefCounted
## Builds the 3D models of the kitchen: food, stations, furniture and
## characters. Most come from Kenney's CC0 packs (art/models/), recoloured by
## the comic shader; a few are built here from simple shapes. Every model is
## centred, standing on y = 0, and scaled to a common kitchen scale where a
## counter is about 1 unit wide and tall.
##
## Food that is an assembly (a plate with parts, a dough with toppings) is
## drawn as its base with the parts on top, so dishes need no models of their
## own. A complete assembly with its own model (a raw pizza) uses that one.

const COUNTER_SIZE := 1.0
const ITEM_SIZE := 0.34
const CHARACTER_HEIGHT := 1.45

## Food: model (art/models/<model>.glb) or proc (built here), size (across),
## tint, count (a small pile of copies).
const ITEMS := {
	"tomato": {"model": "food/tomato", "size": 0.3},
	"chopped_tomato": {"model": "food/tomato-slice", "size": 0.18, "count": 3},
	"mozzarella": {"proc": "mozzarella", "size": 0.28},
	"sliced_mozzarella": {"proc": "mozzarella_slices", "size": 0.3},
	"basil": {"proc": "leaves", "size": 0.3},
	"bread": {"model": "food/loaf-baguette", "size": 0.42},
	"sliced_bread": {"model": "food/bread", "size": 0.24, "count": 2},
	"toast": {"model": "food/bread", "size": 0.24, "count": 2, "tint": Color("#c98a48")},
	"flour": {"model": "food/bag", "size": 0.3, "tint": Color("#f6efe0")},
	"water": {"model": "food/bottle-oil", "size": 0.14, "tint": Color("#7fd0ff")},
	"dough": {"proc": "dough", "size": 0.36},
	"fresh_pasta": {"proc": "pasta", "size": 0.34},
	"cooked_pasta": {"proc": "pasta", "size": 0.34, "tint": Color("#fff6c8")},
	"tomato_sauce": {"model": "food/bowl-soup", "size": 0.32, "tint": Color("#ff7b62")},
	"raw_pizza_margherita": {"model": "food/pizza", "size": 0.44, "tint": Color("#fff2dc")},
	"whole_pizza": {"model": "food/pizza", "size": 0.44},
	"plate": {"model": "food/plate", "size": 0.48},
	"burnt_food": {"model": "food/meat-cooked", "size": 0.32, "tint": Color("#3a3030")},
}

## Stations. "floor": stands on the floor instead of on a counter.
const STATIONS := {
	"counter": {"proc": "mat", "size": 0.5},
	"board": {"model": "food/cutting-board", "size": 0.62},
	"bowl": {"model": "food/bowl", "size": 0.5, "tint": Color("#9fd2ff")},
	"pot": {"model": "food/pot", "size": 0.56},
	"pan": {"model": "food/frying-pan", "size": 0.66},
	"oven": {"model": "furniture/kitchenStove", "size": 1.0, "floor": true},
	"grill": {"proc": "grill", "size": 0.66},
	"fryer": {"proc": "fryer", "size": 0.6},
	"pasta_machine": {"proc": "pasta_machine", "size": 0.5},
	"serving_window": {"proc": "window", "size": 1.0, "floor": true},
}

const PROPS := {
	"cabinet": {"model": "furniture/kitchenCabinet", "size": 1.0},
	"fridge": {"model": "furniture/kitchenFridge", "size": 1.0},
	"bin": {"model": "furniture/trashcan", "size": 0.55},
	"crate": {"model": "furniture/cardboardBoxOpen", "size": 0.62},
}

const CHARACTERS := ["male-a", "female-a", "male-b", "female-b", "male-c", "female-c",
	"male-d", "female-d", "male-e", "female-e", "male-f", "female-f"]
## Characters without hats of their own, so the chef's hat fits.
const CHEF_VARIANTS := [0, 1, 2, 3, 6, 7, 8, 9, 10, 11]

static var _scenes := {}


# --- Food ----------------------------------------------------------------------

## A food item (with the parts on it, for assemblies), in full colour.
static func item(db: ContentDB, type: String, contents: Array = []) -> Node3D:
	var effective := db.effective_id(type, contents) if db else type
	var root: Node3D
	if not contents.is_empty() and ITEMS.has(effective) and effective != type:
		root = _build(ITEMS[effective])
	else:
		root = _build(ITEMS.get(type, {"proc": "blob", "size": ITEM_SIZE}))
		var top := _height(root) * 0.7
		for i in contents.size():
			var part := _build(ITEMS.get(contents[i], {"proc": "blob", "size": ITEM_SIZE}))
			var angle := TAU * i / maxf(contents.size(), 1) + 0.6
			var spread := 0.0 if contents.size() == 1 else 0.11
			part.position = Vector3(cos(angle) * spread, top + i * 0.015, sin(angle) * spread)
			part.scale *= 0.7
			root.add_child(part)
	Comic.apply(root, 0.0, Color.WHITE, true)
	return root


# --- Stations and props --------------------------------------------------------

static func station(type: String) -> Node3D:
	var node := _build(STATIONS.get(type, {"proc": "mat", "size": 0.5}))
	Comic.apply(node, 0.0, Color.WHITE, true)
	return node


static func station_on_floor(type: String) -> bool:
	return bool(STATIONS.get(type, {}).get("floor", false))


## Where food sits on a station, as a height above the station's base.
static func station_top(type: String, node: Node3D) -> float:
	match type:
		"pot", "bowl":
			return _height(node) * 0.45
		"pan", "grill", "fryer":
			return _height(node) * 0.55
		"serving_window":
			return 0.62
	return _height(node)


## Background furniture (muted).
static func prop(name: String, muted: float = 0.65) -> Node3D:
	var node := _build(PROPS[name])
	Comic.apply(node, muted)
	return node


# --- Characters ----------------------------------------------------------------

## A character model with its AnimationPlayer (idle, walk, pick-up,
## interact-right, emote-yes, emote-no...).
static func character(variant: int) -> Node3D:
	var path := "res://art/models/characters/character-%s.glb" % CHARACTERS[posmod(variant, CHARACTERS.size())]
	var node := _instance(path)
	var pivot := _fit(node, 0.0, CHARACTER_HEIGHT)
	Comic.apply(pivot, 0.0, Color.WHITE, true, 2.0)
	return pivot


## The player's chef: a character picked by skin and hair, plus a hat and an
## apron in the chosen colours.
static func chef(look: Dictionary) -> Node3D:
	look = ChefLook.sanitize(look)
	var variant: int = CHEF_VARIANTS[(int(look.skin) * 2 + int(look.hair)) % CHEF_VARIANTS.size()]
	var pivot := character(variant)
	var skeleton := _skeleton(pivot)
	if skeleton:
		var head := BoneAttachment3D.new()
		head.bone_name = "head"
		skeleton.add_child(head)
		var hat := _hat(int(look.hat), ChefLook.APRONS[int(look.apron)], ChefLook.HAIR_COLORS[int(look.hair_color)])
		if hat:
			head.add_child(hat)
		var torso := BoneAttachment3D.new()
		torso.bone_name = "torso"
		skeleton.add_child(torso)
		var apron := _box(Vector3(0.17, 0.14, 0.02), ChefLook.APRONS[int(look.apron)])
		apron.position = Vector3(0, 0.02, 0.13)
		torso.add_child(apron)
		Comic.apply(head, 0.0, Color.WHITE, true, 2.0)
		Comic.apply(torso, 0.0, Color.WHITE, true, 2.0)
	return pivot


## Plays an animation by name (if the character has it), e.g. "idle".
static func animate(character_node: Node, animation: String, loop: bool = false) -> void:
	var player := character_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(animation):
		return
	player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	player.play(animation, 0.15)
	if not loop:
		player.queue("idle")


static func _hat(kind: int, color: Color, hair: Color) -> Node3D:
	var hat := Node3D.new()
	match kind:
		0:  # toque
			var band := _cylinder(0.13, 0.13, 0.08, Color.WHITE)
			band.position.y = 0.35
			hat.add_child(band)
			var puff := _sphere(0.3, 0.15, Color.WHITE)
			puff.position.y = 0.43
			hat.add_child(puff)
		1:  # cap
			var cap := _sphere(0.34, 0.14, color)
			cap.position.y = 0.33
			hat.add_child(cap)
			var brim := _box(Vector3(0.26, 0.02, 0.16), color)
			brim.position = Vector3(0, 0.33, 0.2)
			hat.add_child(brim)
		2:  # bandana
			var band := _cylinder(0.175, 0.175, 0.07, color)
			band.position.y = 0.27
			hat.add_child(band)
		_:
			return null
	return hat


# --- Building blocks -----------------------------------------------------------

static func _build(spec: Dictionary) -> Node3D:
	var size := float(spec.get("size", ITEM_SIZE))
	var node: Node3D
	if spec.has("model"):
		node = _instance("res://art/models/%s.glb" % spec.model)
	else:
		node = _proc(str(spec.get("proc", "blob")))
	var tint: Color = spec.get("tint", Color.WHITE)
	if tint != Color.WHITE:
		_tint_source(node, tint)
	var pivot := _fit(node, size, 0.0)
	var count := int(spec.get("count", 1))
	if count > 1:
		var pile := Node3D.new()
		for i in count:
			var copy: Node3D = pivot if i == 0 else pivot.duplicate()
			copy.position = Vector3((i - (count - 1) * 0.5) * size * 0.45, i * 0.02, (i % 2) * size * 0.2)
			copy.rotation.y = i * 0.7
			pile.add_child(copy)
		return pile
	return pivot


# Wraps a model in a pivot: centred on x/z, bottom at y = 0, scaled so its
# footprint is `size` across (or its height is `height`).
static func _fit(node: Node3D, size: float, height: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.add_child(node)
	var box := _aabb(node)
	var across := maxf(box.size.x, box.size.z)
	var s := 1.0
	if height > 0.0 and box.size.y > 0.0:
		s = height / box.size.y
	elif across > 0.0:
		s = size / across
	node.scale = Vector3.ONE * s
	var center := box.get_center()
	node.position = Vector3(-center.x * s, -box.position.y * s, -center.z * s)
	return pivot


static func _instance(path: String) -> Node3D:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _scenes[path]
	return scene.instantiate() if scene else _proc("blob")


# Bakes a colour tint into the model's materials (so Comic.apply keeps it).
static func _tint_source(node: Node, tint: Color) -> void:
	for mesh in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var mi := mesh as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var source := mi.get_active_material(s)
			var copy: StandardMaterial3D = source.duplicate() if source is StandardMaterial3D else StandardMaterial3D.new()
			copy.albedo_color = copy.albedo_color * tint
			mi.set_surface_override_material(s, copy)


static func _aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var mi := mesh as MeshInstance3D
		var box := _relative_transform(mi, node) * mi.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var current: Node = node
	while current and current != ancestor:
		if current is Node3D:
			t = (current as Node3D).transform * t
		current = current.get_parent()
	return t


static func _height(node: Node3D) -> float:
	var box := _aabb(node)
	return box.position.y + box.size.y


static func _skeleton(node: Node) -> Skeleton3D:
	var found := node.find_children("*", "Skeleton3D", true, false)
	return found[0] if not found.is_empty() else null


# --- Simple shapes -------------------------------------------------------------

static func _proc(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"leaves":
			for i in 3:
				var leaf := _sphere(0.16, 0.035, Color("#3fae49"))
				leaf.scale = Vector3(1.0, 1.0, 0.5)
				leaf.rotation.y = i * 2.1
				leaf.position = Vector3(cos(i * 2.1) * 0.06, 0.02 + i * 0.01, sin(i * 2.1) * 0.06)
				root.add_child(leaf)
		"mozzarella":
			var ball := _sphere(0.28, 0.24, Color("#fbf8f0"))
			ball.position.y = 0.12
			root.add_child(ball)
		"mozzarella_slices":
			for i in 3:
				var slice := _cylinder(0.08, 0.08, 0.03, Color("#fbf8f0"))
				slice.position = Vector3((i - 1) * 0.1, 0.015 + i * 0.012, (i % 2) * 0.04)
				root.add_child(slice)
		"dough":
			var ball := _sphere(0.36, 0.13, Color("#f3d9a4"))
			ball.position.y = 0.065
			root.add_child(ball)
		"pasta":
			for i in 9:
				var strand := _cylinder(0.018, 0.018, 0.28, Color("#f6d860"))
				strand.rotation = Vector3(PI / 2.0, i * 0.35, 0.25 * sin(i))
				strand.position = Vector3(0, 0.02 + (i % 3) * 0.02, (i - 4) * 0.012)
				root.add_child(strand)
		"mat":
			var mat := _cylinder(0.25, 0.25, 0.02, Color("#e2cfae"))
			mat.position.y = 0.01
			root.add_child(mat)
		"grill":
			var body := _box(Vector3(0.66, 0.16, 0.5), Color("#2b2523"))
			body.position.y = 0.08
			root.add_child(body)
			var coals := _box(Vector3(0.58, 0.02, 0.42), Color("#ff7a1c"))
			coals.position.y = 0.17
			root.add_child(coals)
			for i in 6:
				var bar := _box(Vector3(0.62, 0.02, 0.025), Color("#c5ced8"))
				bar.position = Vector3(0, 0.19, -0.18 + i * 0.072)
				root.add_child(bar)
		"fryer":
			var tank := _box(Vector3(0.6, 0.3, 0.46), Color("#c5ced8"))
			tank.position.y = 0.15
			root.add_child(tank)
			var oil := _box(Vector3(0.52, 0.02, 0.38), Color("#f2b830"))
			oil.position.y = 0.3
			root.add_child(oil)
		"pasta_machine":
			var body := _box(Vector3(0.36, 0.22, 0.28), Color("#c5ced8"))
			body.position.y = 0.11
			root.add_child(body)
			var roller := _cylinder(0.05, 0.05, 0.3, Color("#9aa5b1"))
			roller.rotation.z = PI / 2.0
			roller.position = Vector3(0, 0.25, 0.0)
			root.add_child(roller)
			var crank := _box(Vector3(0.04, 0.2, 0.04), Color("#e5352b"))
			crank.position = Vector3(0.22, 0.28, 0.0)
			root.add_child(crank)
		"window":
			var shelf := _box(Vector3(1.0, 0.08, 0.5), Color("#d9a066"))
			shelf.position.y = 0.58
			root.add_child(shelf)
			for x in [-0.46, 0.46]:
				var post := _box(Vector3(0.08, 1.3, 0.08), Color("#7fc8f8"))
				post.position = Vector3(x, 0.65, -0.2)
				root.add_child(post)
			for i in 6:
				var stripe := _box(Vector3(1.0 / 6.0, 0.16, 0.3), Color("#e5352b") if i % 2 == 0 else Color.WHITE)
				stripe.position = Vector3(-0.5 + (i + 0.5) / 6.0, 1.32, -0.1)
				root.add_child(stripe)
			var bell := _sphere(0.14, 0.07, Color("#f2b830"))
			bell.position = Vector3(0.36, 0.65, 0.12)
			root.add_child(bell)
		_:
			var blob := _sphere(0.3, 0.2, Color("#d9a066"))
			blob.position.y = 0.1
			root.add_child(blob)
	return root


static func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, color)


static func _sphere(diameter: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = diameter * 0.5
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mesh(mesh, color)


static func _cylinder(top: float, bottom: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh(mesh, color)


static func _mesh(mesh: PrimitiveMesh, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance
