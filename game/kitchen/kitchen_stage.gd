class_name KitchenStage
extends Node3D
## The 3D kitchen behind the comic page. Every panel of the page looks at its
## own "set" through its own camera: the pantry's crates, the prep counters,
## the stove, the pass with the customers, the teammates, the rival. All sets
## live in one 3D world, side by side (far enough apart that no camera sees
## another set).
##
## The kitchen screen tells the stage which stations go in which panel, then
## calls sync() every frame; the stage keeps a model for every piece of food
## on the stations and moves it around. Food that moves to another panel is
## reported in `jumps`, so the screen can fly it across the gutter.

const SET_SPACING := 100.0
const SLOT := 1.05  # width of one counter unit
const ROW_DEPTH := 1.25
const COUNTER_HEIGHT := 1.0
const CAMERA_PITCH := deg_to_rad(44.0)
const TOP_CROP := 0.15  # how much of the cabinet fronts shows below the tops
## How high a counter set is framed: room above the tops for the chef's face.
const SET_TOP := 1.75
## The chef in the kitchen is a little bigger than life, so they stand head
## and shoulders above the counters, just behind the back row.
const CHEF_SCALE := 1.3
const CHEF_BEHIND := 0.95
const CAMERA_FOV := 34.0
const FRAME_MARGIN := 1.02
const SHELF_HEIGHT := 0.6
const SHELF_WIDTH := 0.8
## Spider-Verse print colours behind each panel's set; the floor is dark ink
## so the light counters and the food stand out.
const WALL_COLORS := {"pantry": Color("#6a3fc4"), "prep": Color("#1f86c8"), "stove": Color("#d6336c"),
	"pass": Color("#14a3a3"), "team": Color("#8a4fd8"), "rival": Color("#c42f5e")}
const FLOOR_COLOR := Color("#3b3157")

## One entry per panel: {kind, stations: Array[int], crates, mates, origin,
## camera, bounds}.
var sets: Array[Dictionary] = []
## Food that changed panels since the last call: {uid, from_set, from, to_set, to} (world positions).
var jumps: Array[Dictionary] = []

var _db: ContentDB
var _kitchen: KitchenState
var _me := 0
var _station_set := {}  # station index -> set index
var _anchors := {}  # station index -> Node3D (where food sits)
var _station_nodes := {}  # station index -> Node3D
var _crate_nodes := {}  # crate id -> Node3D
var _items := {}  # uid -> {node, signature, set}
var _hidden := {}  # uid -> seconds to stay hidden (flying across a gutter)
var _bin: Node3D
var _chefs := {}  # player -> Node3D
var _chef_set := -1  # the set this phone's chef is working in
var _chef_edge := Vector3.INF  # the back edge of the counters in front of them
var _customers := {}  # order uid -> Node3D
var _rival: Node3D


func setup(db: ContentDB, kitchen: KitchenState, me: int) -> void:
	_db = db
	_kitchen = kitchen
	_me = me


## Builds the sets. panels: Array of {kind, stations, crates, mates, aspect}.
func build(panels: Array) -> void:
	for child in get_children():
		child.queue_free()
	sets.clear()
	_station_set.clear()
	_anchors.clear()
	_station_nodes.clear()
	_crate_nodes.clear()
	_items.clear()
	_chefs.clear()
	_customers.clear()
	_rival = null
	_bin = null
	for i in panels.size():
		var panel: Dictionary = panels[i]
		var origin := Vector3(i * SET_SPACING, 0, 0)
		var set_root := Node3D.new()
		set_root.name = "Set_%s" % panel.kind
		set_root.position = origin
		add_child(set_root)
		var entry := {"kind": panel.kind, "stations": panel.get("stations", []), "crates": panel.get("crates", []),
			"mates": panel.get("mates", []), "origin": origin, "root": set_root, "aspect": float(panel.get("aspect", 1.6))}
		match panel.kind:
			"pantry":
				_build_pantry(set_root, entry)
			"team":
				_build_people(set_root, entry, panel.get("mates", []))
			"rival":
				# The rival is a 2D status card on the screen: an empty set.
				entry.bounds = AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
			_:
				_build_counters(set_root, entry, i)
		_add_backdrop(set_root, entry)
		entry.camera = _make_camera(entry, float(panel.get("aspect", 1.6)))
		sets.append(entry)
	_place_my_chef()


func _build_counters(root: Node3D, entry: Dictionary, set_index: int) -> void:
	var stations: Array = entry.stations
	var n := stations.size() + (1 if entry.kind == "prep" else 0)  # the bin gets a spot in prep
	var rows := best_rows(n, float(entry.get("aspect", 1.6)), entry.kind == "pass")
	var cols := ceili(float(n) / rows)
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for i in n:
		var row := i / cols
		var col := i % cols
		var in_row := mini(cols, n - row * cols)
		var pos := Vector3((col - (in_row - 1) * 0.5) * SLOT, 0, -row * ROW_DEPTH)
		lo = Vector3(minf(lo.x, pos.x), 0, minf(lo.z, pos.z))
		hi = Vector3(maxf(hi.x, pos.x), 0, maxf(hi.z, pos.z))
		if i >= stations.size():
			_bin = Models.prop("bin", 0.2)
			_bin.position = pos + Vector3(0, 0, 0.15)
			root.add_child(_bin)
			continue
		var index: int = stations[i]
		var type: String = _kitchen.players[_me].stations[index].type
		var on_floor := Models.station_on_floor(type)
		if not on_floor:
			var cabinet := Models.prop("cabinet")
			cabinet.position = pos
			root.add_child(cabinet)
		var model := Models.station(type)
		model.position = pos + Vector3(0, 0.0 if on_floor else COUNTER_HEIGHT, 0.05)
		root.add_child(model)
		Comic.set_param(model, "muted", 0.25)
		var anchor := Node3D.new()
		anchor.position = model.position + Vector3(0, Models.station_top(type, model), 0)
		root.add_child(anchor)
		_anchors[index] = anchor
		_station_nodes[index] = model
		_station_set[index] = set_index
	# Tight around the counter tops: the cabinet fronts below are cropped
	# away, so the tops (where the food goes) fill the panel. The chef's head
	# may poke out of the top.
	var floor_y := COUNTER_HEIGHT - TOP_CROP
	for index in stations:
		if _anchors.has(index):
			floor_y = minf(floor_y, (_anchors[index] as Node3D).position.y - TOP_CROP)
	entry.bounds = AABB(lo + Vector3(-SLOT * 0.52, floor_y, -0.45), (hi - lo) + Vector3(SLOT * 1.04, SET_TOP - floor_y, 0.95))


## The pantry: the food on a shelf, read top to bottom. The number of
## columns is the one that makes the food biggest in the panel.
## How big a counter set of n stations looks from the camera, in world units
## (width, height): the panel layout uses it to give panels the right shape.
## A set with the serving window shows more height (its shelf sits low).
static func counter_extent(n: int, rows: int, with_window: bool = false) -> Vector2:
	var cols := ceili(float(maxi(n, 1)) / rows)
	var height := (SET_TOP if with_window else SET_TOP - 0.7) * cos(CAMERA_PITCH) + ((rows - 1) * ROW_DEPTH + 0.95) * sin(CAMERA_PITCH)
	return Vector2(cols * SLOT * 1.04 + 0.1, height)


## One or two rows of stations, whichever shows them biggest in a panel of
## this aspect (width / height).
static func best_rows(n: int, aspect: float, with_window: bool = false) -> int:
	var one := counter_extent(n, 1, with_window)
	var two := counter_extent(n, 2, with_window)
	var fit_one := minf(aspect / one.x, 1.0 / one.y)
	var fit_two := minf(aspect / two.x, 1.0 / two.y)
	return 2 if n > 1 and fit_two > fit_one * 1.05 else 1


## How much a food model is scaled up on the pantry shelf: big, but never
## taller than its shelf or wider than its spot.
static func pantry_scale(box: AABB) -> float:
	var room := Vector2(SHELF_WIDTH * 0.85, SHELF_HEIGHT - 0.07 - 0.06)
	return minf(1.5, minf(room.x / maxf(box.size.x, 0.01), room.y / maxf(box.end.y, 0.01)))


## How big the pantry shelf looks for n crates (see _build_pantry).
static func pantry_extent(n: int, aspect: float) -> Vector2:
	var best := Vector2(1, 1)
	var best_fit := 0.0
	for cols in range(1, 4):
		var rows := maxi(ceili(n / float(cols)), 1)
		var extent := Vector2(cols * SHELF_WIDTH + 0.3, rows * SHELF_HEIGHT + 0.2)
		var fit := minf(aspect / extent.x, 1.0 / extent.y)
		if fit > best_fit:
			best_fit = fit
			best = extent
	return best


func _build_pantry(root: Node3D, entry: Dictionary) -> void:
	var crates: Array = entry.crates
	var aspect: float = entry.get("aspect", 0.4)
	var cols := 1
	var best := 0.0
	for c in range(1, 4):
		var r := maxi(ceili(crates.size() / float(c)), 1)
		var fit := minf(aspect / (c * SHELF_WIDTH + 0.3), 1.0 / (r * SHELF_HEIGHT + 0.2))
		if fit > best:
			best = fit
			cols = c
	var rows := maxi(ceili(crates.size() / float(cols)), 1)
	var height := rows * SHELF_HEIGHT + 0.1
	var width := cols * SHELF_WIDTH + 0.2
	var wood := Color("#9c6a3f")
	root.add_child(_box(Vector3(width, height, 0.08), Vector3(0, height * 0.5, -0.36), wood.darkened(0.25), 0.3))
	for r in rows + 1:
		root.add_child(_box(Vector3(width, 0.07, 0.72), Vector3(0, r * SHELF_HEIGHT, 0), wood, 0.2))
	for side in [-1, 1]:
		root.add_child(_box(Vector3(0.07, height, 0.72), Vector3(side * width * 0.5, height * 0.5, 0), wood, 0.2))
	for i in crates.size():
		var row := rows - 1 - i / cols
		var in_row := mini(cols, crates.size() - (i / cols) * cols)
		var pos := Vector3(((i % cols) - (in_row - 1) * 0.5) * SHELF_WIDTH, row * SHELF_HEIGHT + 0.035, 0.05)
		var food := Models.item(_db, crates[i])
		food.position = pos
		food.scale = Vector3.ONE * pantry_scale(Models._aabb(food))
		root.add_child(food)
		_crate_nodes[crates[i]] = food
	entry.pitch = deg_to_rad(12.0)
	entry.bounds = AABB(Vector3(-width * 0.5 - 0.05, 0, -0.4), Vector3(width + 0.1, height + 0.05, 0.8))


## Teammates (or the rival): each stands in front of their own counter,
## facing us, shot from low so their faces read.
func _build_people(root: Node3D, entry: Dictionary, mates: Array) -> void:
	var count := maxi(mates.size(), 1)
	for i in count:
		var pos := Vector3((i - (count - 1) * 0.5) * 1.6, 0, 0)
		var cabinet := Models.prop("cabinet")
		cabinet.position = pos + Vector3(0, 0, -0.6)
		root.add_child(cabinet)
		var tool := Models.station("pot" if entry.kind == "rival" else "board")
		tool.position = pos + Vector3(0.15, COUNTER_HEIGHT, -0.55)
		root.add_child(tool)
		var person: Node3D
		if entry.kind == "team":
			var player: int = mates[i]
			person = Models.chef(Net.profile_of(player).look)
			_chefs[player] = person
		else:
			person = Models.character(4)
			_rival = person
		person.position = pos + Vector3(0, 0, 0.2)
		root.add_child(person)
		Models.animate(person, "idle", true)
	entry.pitch = deg_to_rad(14.0)
	# Room under their feet for the name tag drawn over the panel.
	entry.bounds = AABB(Vector3(-count * 0.8, -0.2, -1.0), Vector3(count * 1.6, 1.8, 1.5))


func _add_backdrop(root: Node3D, entry: Dictionary) -> void:
	var bounds: AABB = entry.bounds
	var wall_color: Color = WALL_COLORS.get(entry.kind, Comic.CYAN)
	# Big enough to fill any panel shape; the sets are SET_SPACING apart.
	var floor_node := _box(Vector3(70.0, 0.02, 40.0), Vector3(bounds.get_center().x, -0.011, bounds.position.z + 19.0), FLOOR_COLOR, 0.0)
	root.add_child(floor_node)
	root.add_child(_box(Vector3(70.0, 30.0, 0.1), Vector3(bounds.get_center().x, 15.0, bounds.position.z - 0.9), wall_color, 0.0))
	# A darker skirting stripe where the wall meets the floor.
	root.add_child(_box(Vector3(70.0, 0.3, 0.12), Vector3(bounds.get_center().x, 0.15, bounds.position.z - 0.84), wall_color.darkened(0.45), 0.0))


## A camera that frames the set's bounds as tightly as the panel allows.
func _make_camera(entry: Dictionary, aspect: float) -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var bounds: AABB = entry.bounds
	var pitch: float = entry.get("pitch", CAMERA_PITCH)
	var center: Vector3 = entry.origin + bounds.get_center()
	var direction := Vector3(0, sin(pitch), cos(pitch))
	var basis := Basis.looking_at(-direction, Vector3.UP)
	var tan_h := tan(deg_to_rad(CAMERA_FOV) * 0.5)
	var tan_w := tan_h * aspect
	var distance := 0.0
	for i in 8:
		var corner := bounds.get_endpoint(i) - bounds.get_center()
		var x := absf(corner.dot(basis.x))
		var y := absf(corner.dot(basis.y))
		var z := corner.dot(basis.z)
		distance = maxf(distance, maxf(z + x / tan_w, z + y / tan_h))
	distance *= FRAME_MARGIN
	camera.transform = Transform3D(basis, center + direction * distance)
	return camera


# --- Every frame ---------------------------------------------------------------

func sync(delta: float) -> void:
	var seen := {}
	for st in _kitchen.players[_me].stations:
		if not _anchors.has(st.index):
			continue
		var anchor: Node3D = _anchors[st.index]
		var n := st.contents.size()
		for i in n:
			var item: KitchenItem = st.contents[i]
			seen[item.uid] = true
			var target := anchor.global_position
			if n > 1:
				target += Vector3((i - (n - 1) * 0.5) * 0.2, 0.02 * i, 0)
			_update_item(item, target, int(_station_set[st.index]), 0.62 if n > 1 else 1.0, delta)
	for uid in _items.keys():
		if not seen.has(uid):
			_items[uid].node.queue_free()
			_items.erase(uid)
	for uid in _hidden.keys():
		_hidden[uid] -= delta
		if _hidden[uid] <= 0.0:
			_hidden.erase(uid)
			if _items.has(uid):
				_items[uid].node.visible = true


func _update_item(item: KitchenItem, target: Vector3, set_index: int, scale_factor: float, delta: float) -> void:
	var signature := "%s|%s" % [item.type, ",".join(item.contents)]
	var entry: Dictionary = _items.get(item.uid, {})
	if entry.is_empty() or entry.signature != signature:
		var position := target
		var old_set := set_index
		if not entry.is_empty():
			position = entry.node.global_position
			old_set = entry.set
			entry.node.queue_free()
		var node := Models.item(_db, item.type, item.contents)
		add_child(node)
		node.global_position = position
		entry = {"node": node, "signature": signature, "set": old_set}
		_items[item.uid] = entry
		if _hidden.has(item.uid):
			node.visible = false
	var node: Node3D = entry.node
	if entry.set != set_index:
		jumps.append({"uid": item.uid, "from_set": entry.set, "from": node.global_position, "to_set": set_index, "to": target})
		entry.set = set_index
		node.global_position = target
		node.visible = false
		_hidden[item.uid] = 0.28
	else:
		node.global_position = node.global_position.lerp(target, 1.0 - exp(-delta * 14.0))
	node.scale = node.scale.lerp(Vector3.ONE * scale_factor, 1.0 - exp(-delta * 12.0))


## Hides a piece of food for a moment (it's flying in over the page).
func hide_item(uid: int, seconds: float) -> void:
	_hidden[uid] = seconds
	if _items.has(uid):
		_items[uid].node.visible = false


func set_item_visible(uid: int, on: bool) -> void:
	if _items.has(uid):
		_items[uid].node.visible = on


# --- Highlights ----------------------------------------------------------------

func pop_station(index: int, amount: float) -> void:
	if _station_nodes.has(index):
		Comic.pop(_station_nodes[index], amount)
		Comic.set_param(_station_nodes[index], "muted", 0.0 if amount > 0.0 else 0.25)


func pop_item(uid: int, amount: float) -> void:
	if _items.has(uid):
		Comic.pop(_items[uid].node, amount)


func pop_crate(id: String, amount: float) -> void:
	if _crate_nodes.has(id):
		Comic.pop(_crate_nodes[id], amount)


# --- People --------------------------------------------------------------------

func _place_my_chef() -> void:
	var chef := Models.chef(Game.profile.look if is_instance_valid(Game) else {})
	chef.scale = Vector3.ONE * CHEF_SCALE
	add_child(chef)
	_chefs[_me] = chef
	chef.visible = false
	Models.animate(chef, "idle", true)


## Shows this phone's chef at a station, doing something. The chef always
## stands behind the back row of the panel, so they never hide a station
## (with two rows, standing between them would cover the back one), and
## they're big enough that their face shows above the counters.
func chef_act(station_index: int, animation: String) -> void:
	if not _chefs.has(_me) or not _anchors.has(station_index):
		return
	var chef: Node3D = _chefs[_me]
	var anchor: Node3D = _anchors[station_index]
	var back_z := anchor.global_position.z
	var set_index := set_of_station(station_index)
	for index in _anchors:
		if set_of_station(index) == set_index:
			back_z = minf(back_z, (_anchors[index] as Node3D).global_position.z)
	chef.visible = true
	_chef_set = set_index
	_chef_edge = Vector3(anchor.global_position.x + 0.3, anchor.global_position.y + 0.1, back_z - 0.45)
	chef.global_position = Vector3(anchor.global_position.x + 0.3, 0, back_z - CHEF_BEHIND)
	chef.rotation.y = deg_to_rad(-25.0)
	Models.animate(chef, animation)


## A teammate did something: their chef in the team panel reacts.
func mate_act(player: int, animation: String) -> void:
	if _chefs.has(player) and player != _me:
		Models.animate(_chefs[player], animation)


func rival_act(animation: String) -> void:
	if _rival:
		Models.animate(_rival, animation)


## Keeps one customer per waiting order behind the serving window.
func sync_customers(orders: Array, pass_index: int, delta: float) -> void:
	if not _anchors.has(pass_index):
		return
	var window: Node3D = _anchors[pass_index]
	var pass_set: Dictionary = sets[set_of_station(pass_index)]
	var row_center: float = pass_set.origin.x + (pass_set.bounds as AABB).get_center().x
	var alive := {}
	var shown := orders.slice(0, 4)
	for i in shown.size():
		var order: Dictionary = shown[i]
		alive[order.uid] = true
		# Spread along the pass counters, behind them, so they show over the
		# counter tops (not hidden behind the window's awning).
		var spot := Vector3(row_center + (i - (shown.size() - 1) * 0.5) * 0.85, 0, window.global_position.z - 1.05 - (i % 2) * 0.12)
		if not _customers.has(order.uid):
			var person := Models.character(int(order.uid) * 5 + 3)
			add_child(person)
			person.global_position = spot + Vector3(2.5, 0, 0)
			person.rotation.y = 0.0
			_customers[order.uid] = person
			Models.animate(person, "walk", true)
		var node: Node3D = _customers[order.uid]
		if node.global_position.distance_to(spot) > 0.05:
			node.global_position = node.global_position.move_toward(spot, 2.5 * delta)
			if node.global_position.distance_to(spot) <= 0.05:
				Models.animate(node, "idle", true)
	for uid in _customers.keys():
		if not alive.has(uid) and not _customers[uid].has_meta("leaving"):
			_customers[uid].queue_free()
			_customers.erase(uid)


## A customer got their food (or gave up): they react, then leave.
func customer_leaves(order_uid: int, happy: bool) -> void:
	if not _customers.has(order_uid):
		return
	var node: Node3D = _customers[order_uid]
	_customers.erase(order_uid)
	node.set_meta("leaving", true)
	Models.animate(node, "emote-yes" if happy else "emote-no")
	var tween := node.create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(node, "position", node.position + Vector3(-3.0, 0, -0.5), 1.0)
	tween.tween_callback(node.queue_free)


## Where this phone's chef's face is while they're working (the screen tests
## check it shows in the panel), or INF while they're off.
func chef_face() -> Vector3:
	if not _chefs.has(_me) or not (_chefs[_me] as Node3D).visible:
		return Vector3.INF
	return (_chefs[_me] as Node3D).global_position + Vector3(0, Models.CHARACTER_HEIGHT * CHEF_SCALE * 0.75, 0)


## The set the chef is working in, or -1.
func chef_set() -> int:
	return _chef_set


## The top of the back edge of the counters in front of the chef: the face
## should show above it.
func chef_counter_edge() -> Vector3:
	return _chef_edge


func customer_head(order_uid: int) -> Vector3:
	if _customers.has(order_uid):
		return _customers[order_uid].global_position + Vector3(0, 1.55, 0)
	return Vector3.INF


# --- Positions for the 2D overlay ----------------------------------------------

func station_position(index: int) -> Vector3:
	return _anchors[index].global_position if _anchors.has(index) else Vector3.INF


func crate_position(id: String) -> Vector3:
	return _crate_nodes[id].global_position if _crate_nodes.has(id) else Vector3.INF


func bin_position() -> Vector3:
	return _bin.global_position + Vector3(0, 0.5, 0) if _bin else Vector3.INF


func set_of_station(index: int) -> int:
	return int(_station_set.get(index, -1))


func set_index(kind: String) -> int:
	for i in sets.size():
		if sets[i].kind == kind:
			return i
	return -1


func set_containing(position: Vector3) -> int:
	return clampi(roundi(position.x / SET_SPACING), 0, sets.size() - 1)


func _box(box_size: Vector3, position: Vector3, color: Color, muted: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	Comic.apply(node, muted, Color.WHITE, false, 0.0 if muted <= 0.0 else 2.0)
	return node


## A close-up of one station for the mini-game's splash panel.
func closeup_camera(station_index: int, aspect: float) -> Camera3D:
	if not _anchors.has(station_index):
		return null
	var target: Vector3 = _anchors[station_index].global_position + Vector3(0, 0.05, 0)
	var camera := Camera3D.new()
	camera.fov = 26.0 if aspect >= 1.6 else 34.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# From the front left: the chef (behind, to the right) stays beside the food.
	var eye := target + Vector3(-0.7, 0.9, 1.15)
	var look := target + Vector3(0.12, 0.12, 0)
	camera.transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	return camera
