extends Control
## The player's kitchen screen: customers on top, crates and tools on the
## left, appliances on the back wall, the counter with its slots in the
## middle, and the serving window on the right.
##
## Every action goes through a session: a HostSession runs the rules (solo,
## or the host of a LAN game) and a ClientSession mirrors the host's shift
## on the other phone. Controls work with taps or drags:
## - tap a crate to take an ingredient (or drag it onto a slot),
## - tap food to select it; the things it can go to glow,
## - then tap (or drag the food onto) a tool, an appliance, other food,
##   the serving window or the bin,
## - tools open a gesture mini-game; ovens and pots cook on their own,
## - work can be paused (LATER, or tap anywhere else) and resumed later from
##   the tool badge on the food,
## - in a LAN game, food dropped on a teammate's portrait is thrown to them.
const TOP_BAR_H := 118.0
const SIDEBAR_W := 236.0
const TAP_DISTANCE := 14.0
const START_DELAY := 1.8
## Food on the counter is drawn this much bigger than in appliances.
const PLATE_ZOOM := 1.5
## Narrowest space a counter slot needs before the counter uses two rows.
const MIN_SLOT_SPACING := 185.0
const END_DELAY := 2.2

const ACTION_SOUNDS := {"chop": "chop", "slice": "slice", "knead": "squish", "roll": "roll", "stir": "swirl", "crank": "swirl",
	"press": "thud", "mash": "squish", "grate": "slice", "whisk": "swirl", "blend": "swirl"}
const INSERT_WORDS := {"oven": "FWOOSH!", "comal": "SIZZLE!", "grill": "TSSSS!", "rice_cooker": "FLUMP!",
	"fryer": "BLUBBLUB!", "griddle": "TSSSS!", "frying_pan": "SIZZLE!", "paella_pan": "BLOP!", "crepe_pan": "SHHHH!"}
const ACTION_WORDS := {"chop": ["CHOP!", "CHAK!", "THUNK!"], "slice": ["SLICE!", "SHING!"], "knead": ["SQUISH!", "SQUASH!", "PAT!"],
	"roll": ["ROLL!", "VRRM!"], "stir": ["SWIRL!", "BLOOP!"], "crank": ["CRANK!", "CLICK!"],
	"press": ["PRESS!", "FLAT!", "KA-CHUNK!"], "mash": ["MASH!", "SMOOSH!", "SPLUT!"], "grate": ["GRATE!", "SHRED!", "SKRITCH!"],
	"whisk": ["WHISK!", "WHIRR!", "SWOOSH!"], "blend": ["BZZZZ!", "WHRRR!", "BLENDO!"]}

var shift: Shift
var db: ContentDB
var kitchen: KitchenState
var _me := 0  # this phone's chef
var _session  # HostSession or ClientSession

var _backdrop: Control
var _dynamic: Control
var _items_layer: Node2D
var _fx_layer: Node2D
var _order_bar: OrderBar
var _minigame: Minigame
var _overlay: Control
var _ghost: Sprite2D

var _item_views := {}  # uid -> ItemView
var _spawn_from := {}  # uid -> start position for new item views

# Layout, rebuilt when the screen size changes.
var _crates: Array[Dictionary] = []  # {id, rect}
var _tools: Array[Dictionary] = []  # {id, rect}
var _stations: Array[Dictionary] = []  # {id, rect, spots: Array[Vector2]}
var _slots: Array[Dictionary] = []  # {center, rect, scale}
var _serve_rect := Rect2()
var _trash_rect := Rect2()
var _pause_rect := Rect2()
var _crate_label_size := 15
var _mates: Array[Dictionary] = []  # {player, rect}: teammates to throw to
var _counter_top := PackedVector2Array()
var _counter_front := PackedVector2Array()

# Interaction state.
var _press: Dictionary = {}  # what was under the finger when it went down
var _press_pos := Vector2.ZERO
var _dragging := false
var _drag_view: ItemView
var _selected_uid := 0
var _work: Dictionary = {}  # what the open mini-game works on
var _start_timer := START_DELAY
var _end_timer := -1.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()

# Hints while making a dish for the first time: the bot's planner suggests
# the next step (with arrows) for orders of dishes not yet discovered.
var _hint_bot := KitchenBot.new()
var _hint_text := ""
var _hint_points: Array[Vector2] = []
var _hint_timer := 0.0


func _ready() -> void:
	db = Game.db
	shift = Shift.new(db, Game.current_level, Game.player_count, Game.shift_seed)
	kitchen = shift.kitchen
	if Net.is_client():
		_me = Net.local_player
		shift.drain_events()  # the mirror's own start-up events; the host sends the real ones
		_session = ClientSession.new(shift, _me, Net.send_to_host)
		_session.intent_answered.connect(_on_intent_answered)
	else:
		_session = HostSession.new(shift, Net.send if Net.is_host() else Callable())
		for i in Net.client_peers.size():
			_session.add_peer(Net.client_peers[i], i + 1)
	Net.message_received.connect(_on_net_message)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_backdrop = _layer_control()
	_backdrop.draw.connect(_draw_backdrop)
	_dynamic = _layer_control()
	_dynamic.draw.connect(_draw_dynamic)
	_items_layer = Node2D.new()
	add_child(_items_layer)
	_fx_layer = Node2D.new()
	add_child(_fx_layer)
	_order_bar = OrderBar.new()
	_order_bar.shift = shift
	_order_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_bar.z_index = 40
	add_child(_order_bar)
	_minigame = Minigame.new()
	_minigame.visible = false
	_minigame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minigame.work_done.connect(_on_minigame_work)
	_minigame.paused.connect(_on_work_paused)
	_minigame.closed.connect(func(): _work = {})
	_minigame.z_index = 45
	add_child(_minigame)
	_overlay = _layer_control()
	_overlay.z_index = 60
	_overlay.draw.connect(_draw_overlay)
	_ghost = Sprite2D.new()
	_ghost.visible = false
	_ghost.z_index = 40
	_fx_layer.add_child(_ghost)

	_hint_bot.max_orders = 1
	_hint_bot.order_filter = func(order: Dictionary) -> bool: return not Game.progression.is_discovered(order.dish)
	_order_bar.is_new = func(dish: String) -> bool: return not Game.progression.is_discovered(dish)
	resized.connect(_layout)
	_layout()
	_handle_events(_session.drain_events())
	_bubble(size * 0.5, "READY?", Art.SUN, 64)


func _on_net_message(peer_id: int, message: Dictionary) -> void:
	if _session is ClientSession:
		_session.on_message(message)
	else:
		_session.on_message(peer_id, message)


func _layer_control() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


func _notification(what: int) -> void:
	# Android back button, or the app going to the background: pause.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _session and not shift.finished:
			_session.set_paused(true)


# --- Layout ------------------------------------------------------------------

func _layout() -> void:
	var w := size.x
	var h := size.y
	var pk := kitchen.players[_me]
	var needed_crates := {}
	var needed_equipment := {}
	for dish in shift.level.dish_ids():
		for crate in db.raw_requirements(dish):
			needed_crates[crate] = true
		for eq in db.equipment_requirements(dish):
			needed_equipment[eq] = true

	_order_bar.position = Vector2.ZERO
	_order_bar.size = Vector2(w, TOP_BAR_H)
	_pause_rect = Rect2(w - 70, TOP_BAR_H + 10, 58, 58)

	# Crates and tools in the sidebar: two big columns, or three smaller ones
	# when a big kitchen (like the solo sushi bar) wouldn't fit.
	var shown_crates := pk.crates.filter(func(c): return needed_crates.has(c))
	var shown_tools := pk.tools.filter(func(t): return needed_equipment.has(t))
	var cols := 2
	var cell := Vector2(98, 92)
	var row_h := 100.0
	var tool_rows := ceili(shown_tools.size() / 3.0)
	if 40 + ceili(shown_crates.size() / 2.0) * row_h + 40 + tool_rows * 78 > h - TOP_BAR_H - 10:
		cols = 3
		cell = Vector2(68, 66)
		row_h = 84.0
	_crate_label_size = 15 if cols == 2 else 12
	_crates.clear()
	var col_w := (SIDEBAR_W - 20.0) / cols
	for i in shown_crates.size():
		var col := i % cols
		var row := i / cols
		_crates.append({"id": shown_crates[i], "rect": Rect2(10 + col * col_w + (col_w - cell.x) * 0.5, TOP_BAR_H + 40 + row * row_h, cell.x, cell.y)})
	var tools_y := TOP_BAR_H + 40 + ceili(shown_crates.size() / float(cols)) * row_h + 34
	_tools.clear()
	for i in shown_tools.size():
		_tools.append({"id": shown_tools[i], "rect": Rect2(10 + (i % 3) * 74, tools_y + (i / 3) * 78, 70, 70)})

	_serve_rect = Rect2(w - 178, TOP_BAR_H + 80, 164, 190) if pk.serves else Rect2()
	_trash_rect = Rect2(w - 150, h - 150, 120, 130)
	_mates.clear()
	var mate_y := TOP_BAR_H + (290.0 if pk.serves else 80.0)
	for p in kitchen.players.size():
		if p != _me:
			_mates.append({"player": p, "rect": Rect2(w - 178, mate_y, 164, 130)})
			mate_y += 140.0

	var area_left := SIDEBAR_W + 20.0
	var area_right := w - 196.0
	_stations.clear()
	var station_ids := pk.appliances.keys().filter(func(e): return needed_equipment.has(e))
	var station_w := minf(200.0, (area_right - area_left) / maxf(station_ids.size(), 1))
	for i in station_ids.size():
		var id: String = station_ids[i]
		var rect := Rect2(area_left + i * station_w + 6, TOP_BAR_H + 14, station_w - 12, 196)
		var capacity: int = pk.appliances[id].size()
		var spots: Array[Vector2] = []
		for s in capacity:
			var fx := (s + 1.0) / (capacity + 1.0)
			spots.append(Vector2(rect.position.x + rect.size.x * fx, rect.position.y + rect.size.y * 0.6))
		_stations.append({"id": id, "rect": rect, "spots": spots})

	var counter_y := TOP_BAR_H + 222.0
	_counter_top = PackedVector2Array([Vector2(SIDEBAR_W + 30, counter_y), Vector2(w - 8, counter_y), Vector2(w + 40, h - 64), Vector2(SIDEBAR_W - 10, h - 64)])
	_counter_front = PackedVector2Array([Vector2(SIDEBAR_W - 10, h - 64), Vector2(w + 40, h - 64), Vector2(w + 40, h + 10), Vector2(SIDEBAR_W - 10, h + 10)])

	_slots.clear()
	var slot_count := pk.slots.size()
	var slot_left := SIDEBAR_W + 60.0
	var slot_right := w - 200.0
	var rows := 1 if (slot_right - slot_left) / maxf(slot_count, 1) >= MIN_SLOT_SPACING else 2
	var per_row := ceili(float(slot_count) / rows)
	for i in slot_count:
		var row := i / per_row
		var col := i % per_row
		var in_row := mini(per_row, slot_count - row * per_row)
		var y := (counter_y + h - 64) * 0.5 + 10.0 if rows == 1 else lerpf(counter_y + 74, h - 146, row)
		var depth := 0.86 if rows == 2 and row == 0 else 1.0
		var inset := (1.0 - depth) * 60.0
		var x := lerpf(slot_left + inset, slot_right - inset, (col + 0.5) / in_row)
		var center := Vector2(x, y)
		var s := depth * PLATE_ZOOM
		_slots.append({"center": center, "rect": Rect2(center - Vector2(62, 58) * s, Vector2(124, 116) * s), "scale": s})

	var mini_size := Vector2(minf(560.0, w - SIDEBAR_W - 80.0), 330.0)
	_minigame.size = mini_size
	_minigame.position = Vector2(SIDEBAR_W + (w - SIDEBAR_W - mini_size.x) * 0.5, TOP_BAR_H + 30)
	_backdrop.queue_redraw()


# --- Frame update ------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if not _session.paused:
		if _start_timer > 0.0:
			_start_timer -= delta
			if _start_timer <= 0.0:
				_bubble(size * 0.5, "COOK!", Art.TOMATO, 72)
				Sfx.play("bell")
		elif not shift.finished:
			_session.tick(delta)
		elif _end_timer > 0.0:
			_end_timer -= delta
			if _end_timer <= 0.0:
				Game.finish_level(shift.outcome, shift.stats.merged({"score": shift.score, "time": shift.time}))
				return
	_handle_events(_session.drain_events())
	_check_work_done()
	_sync_views()
	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint_timer = 0.25
		_update_hint()
	_dynamic.queue_redraw()
	_overlay.queue_redraw()


func _sync_views() -> void:
	var seen := {}
	var pk := kitchen.players[_me]
	for i in pk.slots.size():
		var item: KitchenItem = pk.slots[i]
		if item:
			seen[item.uid] = true
			var view := _view_for(item, _slots[i].center)
			if not view.held:
				view.target = _slots[i].center
			view.display_scale = _slots[i].scale
			view.selected = item.uid == _selected_uid
			view.update_item(item)
			var paused_tool := _paused_tool(item)
			view.resume_icon = Art.equipment(paused_tool) if not paused_tool.is_empty() else null
	for station in _stations:
		var appliance: Array = pk.appliances[station.id]
		for index in appliance.size():
			var aslot: KitchenState.ApplianceSlot = appliance[index]
			if aslot:
				seen[aslot.item.uid] = true
				var view := _view_for(aslot.item, station.spots[index])
				view.target = station.spots[index] + Vector2(0, -6)
				view.display_scale = 0.62
				view.selected = false
				view.update_item(aslot.item)
				view.progress = 0.0
				view.resume_icon = null
	for uid in _item_views.keys():
		if not seen.has(uid):
			_item_views[uid].queue_free()
			_item_views.erase(uid)
	if _selected_uid and not seen.has(_selected_uid):
		_selected_uid = 0


func _view_for(item: KitchenItem, fallback: Vector2) -> ItemView:
	if _item_views.has(item.uid):
		return _item_views[item.uid]
	var view := ItemView.new()
	view.setup(db, item, _spawn_from.get(item.uid, fallback))
	_spawn_from.erase(item.uid)
	_items_layer.add_child(view)
	_item_views[item.uid] = view
	return view


# --- Events from the game rules ----------------------------------------------

func _handle_events(events: Array[Dictionary]) -> void:
	for event in events:
		if event.type == "item_thrown":
			_on_item_thrown(event)
			continue
		# Other chefs' counters aren't on this screen.
		if int(event.get("player", _me)) != _me:
			continue
		match event.type:
			"item_added":
				var crate := _crate_rect(event.item.type)
				if crate.has_area():
					_spawn_from[int(event.item.uid)] = crate.get_center()
				Sfx.play("pop")
			"items_combined":
				Sfx.play("thud")
				_bubble(_slots[event.to].center + Vector2(0, -70), _pick(["SPLAT!", "PLOP!", "TA-DA!"]), Color.WHITE, 30)
			"item_processed":
				Sfx.play("pop")
				Game.vibrate(40)
				_bubble(_slots[event.slot].center + Vector2(0, -80), "DONE!", Art.LEAF, 34)
			"appliance_inserted":
				Sfx.play("whoosh")
				var spot := _station_spot(event.equipment, event.index)
				_bubble(spot + Vector2(0, -70), INSERT_WORDS.get(event.equipment, "SPLOSH!"), Art.SUN, 28)
			"cook_ready":
				Sfx.play("ding", 0.0)
				Game.vibrate(60)
				_bubble(_station_spot(event.equipment, event.index) + Vector2(0, -80), "DING!", Art.SUN, 40)
			"cook_burnt":
				Sfx.play("sizzle")
				Game.vibrate(200)
				_bubble(_station_spot(event.equipment, event.index) + Vector2(0, -80), "BURNT!", Color("#555"), 40)
			"appliance_removed":
				Sfx.play("pop")
				if event.item.perfect:
					_bubble(_slots[event.slot].center + Vector2(0, -80), "PERFECT!", Art.SUN, 36)
			"item_served":
				_fly_away(int(event.item.uid), _serve_rect.get_center())
				Sfx.play("bell", 0.0)
			"order_served":
				Sfx.play("coin")
				Game.vibrate(30)
				_bubble(_serve_rect.get_center() + Vector2(-20, -90), "+%d" % event.points, Art.SUN, 46)
				if Game.discover(event.order.dish):
					Sfx.play("cheer")
					_bubble(size * 0.5 + Vector2(0, -40), "NEW DISH: %s!" % db.item_name(event.order.dish).to_upper(), Art.SUN, 44)
					_hint_text = ""
					_hint_points.clear()
			"item_trashed":
				if event.has("slot"):
					_fly_away(int(event.item.uid), _trash_rect.get_center())
				Sfx.play("thud")
			"order_added":
				Sfx.play("pop", 0.2)
			"order_lost":
				Sfx.play("angry")
				Game.vibrate(120)
				_bubble(Vector2(110, TOP_BAR_H + 10), _pick(["HMPF!", "GRR!", "BYE!"]), Art.TOMATO, 40)
			"wave_started":
				if event.wave > 0:
					_bubble(size * 0.5, "WAVE %d!" % (event.wave + 1), Art.SUN, 64)
			"wave_cleared":
				Sfx.play("cheer")
			"rival_taunt":
				var line := "TOO SLOW!" if event.taunt == "too_slow" else "OOPS, BURNT!"
				_bubble(Vector2(size.x - 220, TOP_BAR_H + 40), line, Color("#b48ce0"), 30)
			"rival_dish_done":
				Sfx.play("pop", 0.3)
			"shift_ended":
				_end_shift()


func _on_item_thrown(event: Dictionary) -> void:
	var uid := int(event.item.uid)
	if event.player == _me:
		_fly_away(uid, _mate_rect(event.target).get_center())
		Sfx.play("whoosh")
		_bubble(_mate_rect(event.target).get_center() + Vector2(-40, -70), "WHOOSH!", Color.WHITE, 34)
	elif event.target == _me:
		_spawn_from[uid] = _mate_rect(event.player).get_center()
		Sfx.play("thud")
		Game.vibrate(40)
		_bubble(_slots[event.target_slot].center + Vector2(0, -80), _pick(["THWACK!", "CATCH!", "PLOP!"]), Art.SUN, 36)


func _end_shift() -> void:
	_close_minigame()
	_end_timer = END_DELAY
	var outcome := shift.outcome
	var text := "TIME'S UP!"
	if outcome.get("failed", false):
		text = "OH NO!"
	elif outcome.type in [LevelDef.TYPE_FESTIVAL, LevelDef.TYPE_COMPETITION]:
		text = "VICTORY!"
	elif outcome.type == LevelDef.TYPE_ARCADE:
		text = "GAME OVER!"
	_bubble(size * 0.5, text, Art.SUN, 80)
	Sfx.play("cheer" if not outcome.get("failed", false) else "angry")


func _fly_away(uid: int, to: Vector2) -> void:
	if not _item_views.has(uid):
		return
	var view: ItemView = _item_views[uid]
	_item_views.erase(uid)
	view.set_process(false)
	var tween := view.create_tween()
	tween.tween_property(view, "position", to, 0.25).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(view, "scale", Vector2(0.2, 0.2), 0.25)
	tween.tween_callback(view.queue_free)


# --- Input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var pos: Vector2 = event.position if "position" in event else Vector2.ZERO
	if _session.paused:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_pause_menu_click(pos)
		return
	if _minigame.visible:
		var outside_tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not Rect2(_minigame.position, _minigame.size).has_point(pos)
		if not outside_tap:
			_minigame.handle_input(event, pos - _minigame.position)
			return
		# Tapping the kitchen pauses the work; the tap then does its usual job.
		_minigame.pause()
	if _start_timer > 0.0 or shift.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = _hit(pos)
			_press_pos = pos
			_dragging = false
			if _press.get("kind", "") == "pause":
				_session.set_paused(true)
				_press = {}
		else:
			_release(pos)
	elif event is InputEventMouseMotion and not _press.is_empty():
		if not _dragging and pos.distance_to(_press_pos) > TAP_DISTANCE:
			_start_drag()
		if _dragging:
			if _drag_view:
				_drag_view.position = pos
			_ghost.position = pos


func _start_drag() -> void:
	_dragging = true
	match _press.kind:
		"slot":
			var item := kitchen.item_at(_me, _press.index)
			if item and _item_views.has(item.uid):
				_drag_view = _item_views[item.uid]
				_drag_view.held = true
				_selected_uid = item.uid
		"crate":
			_show_ghost(Art.item(_press.id))
		"tool":
			_show_ghost(Art.equipment(_press.id))


func _show_ghost(texture: Texture2D) -> void:
	_ghost.texture = texture
	_ghost.scale = Vector2(0.4, 0.4)
	_ghost.position = _press_pos
	_ghost.visible = true


func _release(pos: Vector2) -> void:
	var press := _press
	_press = {}
	_ghost.visible = false
	if _drag_view:
		_drag_view.held = false
		_drag_view = null
	if press.is_empty():
		return
	var target := _hit(pos)
	if not _dragging:
		_tap(press)
		return
	match press.kind:
		"slot":
			_drop_item(press.index, target)
		"crate":
			if target.get("kind", "") == "slot" and kitchen.item_at(_me, target.index) == null:
				_intent({"type": "take", "ingredient": press.id, "slot": target.index})
			elif target.get("kind", "") == "crate":
				_intent({"type": "take", "ingredient": press.id})
		"tool":
			if target.get("kind", "") == "slot" and kitchen.item_at(_me, target.index):
				_start_work_on_slot(target.index, press.id)
	_selected_uid = 0 if press.kind == "slot" else _selected_uid


func _drop_item(from: int, target: Dictionary) -> void:
	match target.get("kind", ""):
		"slot":
			if target.index == from:
				return
			if kitchen.item_at(_me, target.index) == null:
				_intent({"type": "move", "from": from, "to": target.index})
			else:
				_intent({"type": "combine", "from": from, "to": target.index}, true)
		"tool":
			_start_work_on_slot(from, target.id)
		"station":
			_intent({"type": "insert", "slot": from, "equipment": target.id}, true)
		"serve":
			_intent({"type": "serve", "slot": from}, true)
		"trash":
			_intent({"type": "trash", "slot": from})
		"mate":
			_intent({"type": "throw", "slot": from, "target": target.player}, true)


func _tap(press: Dictionary) -> void:
	var selected_slot := _selected_slot()
	match press.kind:
		"crate":
			_intent({"type": "take", "ingredient": press.id}, true)
		"slot":
			var item := kitchen.item_at(_me, press.index)
			if press.has("resume") and selected_slot < 0:
				_start_work_on_slot(press.index, press.resume)
				return
			if item == null:
				if selected_slot >= 0:
					_intent({"type": "move", "from": selected_slot, "to": press.index})
					_selected_uid = 0
			elif item.uid == _selected_uid:
				_selected_uid = 0
			elif selected_slot >= 0 and _can_combine(selected_slot, press.index):
				_intent({"type": "combine", "from": selected_slot, "to": press.index})
				_selected_uid = 0
			else:
				_selected_uid = item.uid
				Sfx.play("pop", 0.3)
		"tool":
			if selected_slot >= 0:
				_start_work_on_slot(selected_slot, press.id)
			else:
				_bubble(_tool_rect(press.id).get_center() + Vector2(60, -40), "PICK FOOD FIRST!", Color.WHITE, 22)
		"station":
			_tap_station(press, selected_slot)
		"serve":
			if selected_slot >= 0:
				_intent({"type": "serve", "slot": selected_slot}, true)
		"trash":
			if selected_slot >= 0:
				_intent({"type": "trash", "slot": selected_slot})
				_selected_uid = 0
		"mate":
			if selected_slot >= 0:
				_intent({"type": "throw", "slot": selected_slot, "target": press.player}, true)
				_selected_uid = 0
			else:
				_bubble(_press_center(press) + Vector2(-40, -60), "PICK FOOD TO THROW!", Color.WHITE, 22)


func _press_center(press: Dictionary) -> Vector2:
	return _mate_rect(press.player).get_center() if press.get("kind", "") == "mate" else _press_pos


func _tap_station(press: Dictionary, selected_slot: int) -> void:
	if selected_slot >= 0:
		if _intent({"type": "insert", "slot": selected_slot, "equipment": press.id}, true):
			_selected_uid = 0
		return
	var appliance: Array = kitchen.players[_me].appliances[press.id]
	var index: int = press.index
	if appliance[index] == null:
		index = appliance.find_custom(func(a): return a != null)
		if index < 0:
			return
	var aslot: KitchenState.ApplianceSlot = appliance[index]
	if aslot.burnt:
		_intent({"type": "trash_appliance", "equipment": press.id, "index": index})
	elif aslot.done:
		_intent({"type": "remove", "equipment": press.id, "index": index}, true)
	elif not db.is_passive(aslot.process):
		_start_work_on_appliance(press.id, index)


func _pause_menu_click(pos: Vector2) -> void:
	var buttons := _pause_buttons()
	if buttons.resume.has_point(pos):
		_session.set_paused(false)
	elif buttons.has("restart") and buttons.restart.has_point(pos):
		Game.start_level(shift.level.id, Game.player_count)
	elif buttons.quit.has_point(pos):
		if Net.is_online():
			Game.leave_to_menu()
		else:
			Game.goto(Game.SCENE_PLAY if shift.level.type == LevelDef.TYPE_ARCADE else Game.SCENE_LEVEL_SELECT)


# --- Actions -----------------------------------------------------------------

## Sends an intent for the local player. On failure optionally shows "NOPE!".
## On a client the answer comes later (see _on_intent_answered).
func _intent(intent: Dictionary, nope_on_fail: bool = false) -> bool:
	var result: Dictionary = _session.do_intent(intent)
	if result.get("pending", false):
		intent["nope"] = nope_on_fail  # local note only: the intent was already sent
		return true
	if not result.ok and nope_on_fail:
		_nope(result.error)
	return result.ok


func _on_intent_answered(intent: Dictionary, result: Dictionary) -> void:
	if not result.get("ok", false) and intent.get("nope", false):
		_nope(str(result.get("error", "")))


func _nope(error: String) -> void:
	Sfx.play("nope", 0.0)
	Game.vibrate(80)
	_bubble(get_local_mouse_position() + Vector2(0, -50), _nope_text(error), Color.WHITE, 28)


func _nope_text(error: String) -> String:
	match error:
		"counter_full":
			return "NO ROOM!"
		"appliance_full":
			return "IT'S FULL!"
		"no_matching_order":
			return "NOBODY ORDERED THAT!"
		"target_full":
			return "THEIR COUNTER IS FULL!"
	return "NOPE!"


func _start_work_on_slot(slot: int, tool: String) -> void:
	var item := kitchen.item_at(_me, slot)
	if item == null:
		return
	var proc := db.process_for(kitchen.effective_id(item), tool)
	if proc.is_empty() or not kitchen.players[_me].tools.has(tool):
		Sfx.play("nope", 0.0)
		_bubble(_slots[slot].center + Vector2(0, -80), "NOPE!", Color.WHITE, 30)
		return
	_selected_uid = 0
	var done := item.work if item.work_process == proc.id else 0.0
	_work = {"kind": "slot", "slot": slot, "equipment": tool, "uid": item.uid, "process": proc}
	_minigame.open(proc.action, proc.work, done, Art.item(kitchen.effective_id(item)), Art.equipment(tool))


func _start_work_on_appliance(eq: String, index: int) -> void:
	var aslot: KitchenState.ApplianceSlot = kitchen.players[_me].appliances[eq][index]
	_work = {"kind": "appliance", "equipment": eq, "index": index, "uid": aslot.item.uid, "process": aslot.process}
	_minigame.open(aslot.process.action, aslot.process.work, aslot.progress, Art.item(aslot.item.type), Art.equipment(eq))


func _on_minigame_work(units: int) -> void:
	if _work.is_empty():
		return
	if Game.settings.easy_minigames:
		units *= 2  # every gesture counts double
	var proc: Dictionary = _work.process
	var ok := false
	if _work.kind == "slot":
		ok = _intent({"type": "work", "slot": _work.slot, "equipment": _work.equipment, "amount": units})
	else:
		ok = _intent({"type": "work_appliance", "equipment": _work.equipment, "index": _work.index, "amount": units})
	if not ok:
		_close_minigame()
		return
	Sfx.play(ACTION_SOUNDS.get(proc.action, "pop"))
	Game.vibrate(15)
	var words: Array = ACTION_WORDS.get(proc.action, ["POW!"])
	_bubble(_minigame.position + Vector2(_rng.randf_range(80, _minigame.size.x - 80), _rng.randf_range(125, 235)), _pick(words), Color.WHITE, 32)
	# Count the gesture right away; on a client the host confirms a moment later.
	_minigame.set_progress(minf(_minigame.done + units, proc.work))
	_check_work_done()


## Closes the mini-game once the food has turned into the next thing.
func _check_work_done() -> void:
	if _work.is_empty():
		return
	var proc: Dictionary = _work.process
	var finished := false
	if _work.kind == "slot":
		var item := kitchen.item_at(_me, _work.slot)
		finished = item == null or item.uid != _work.uid or item.type == proc.output
	else:
		var aslot: KitchenState.ApplianceSlot = kitchen.players[_me].appliances[_work.equipment][_work.index]
		finished = aslot == null or aslot.item.uid != _work.uid or aslot.done
	if finished:
		_work = {}
		_minigame.set_progress(proc.work)
		_minigame.finish()


func _close_minigame() -> void:
	_work = {}
	_minigame.visible = false


## The mini-game was left early: the food keeps its progress for later.
func _on_work_paused() -> void:
	if _work.is_empty() or _minigame.done <= 0.0:
		return
	var at: Vector2 = _station_spot(_work.equipment, _work.index) if _work.kind == "appliance" else _slots[_work.slot].center
	_bubble(at + Vector2(0, -80), "LATER!", Art.SKY, 30)
	Sfx.play("pop", 0.2)


## The tool whose work on this item was paused (and can be resumed here),
## or "" when there's nothing to resume.
func _paused_tool(item: KitchenItem) -> String:
	if item.work <= 0.0 or item.work_process.is_empty():
		return ""
	if _minigame.visible and _work.get("uid", 0) == item.uid:
		return ""
	var proc: Dictionary = db.processes.get(item.work_process, {})
	if proc.is_empty() or not kitchen.players[_me].tools.has(proc.equipment):
		return ""
	if db.process_for(kitchen.effective_id(item), proc.equipment).get("id", "") != proc.id:
		return ""
	return proc.equipment


# --- Hints -------------------------------------------------------------------

func _update_hint() -> void:
	_hint_text = ""
	_hint_points.clear()
	if _start_timer > 0.0 or shift.finished or _minigame.visible or not Game.settings.tips:
		return
	for action in _hint_bot.plan(shift):
		if action.player == _me:
			_describe(action)
			return


func _describe(action: Dictionary) -> void:
	var pk := kitchen.players[_me]
	var item_name := func(slot: int) -> String:
		var item := kitchen.item_at(_me, slot)
		if item == null:
			return "food"
		var id := kitchen.effective_id(item)
		return db.item_name(id if not id.is_empty() else item.type).to_upper()
	match action.type:
		"take":
			_hint_text = "Tap the %s crate" % db.item_name(action.ingredient).to_upper()
			_hint_points = [_crate_rect(action.ingredient).get_center()]
		"combine":
			_hint_text = "Drag the %s onto the %s" % [item_name.call(action.from), item_name.call(action.to)]
			_hint_points = [_slots[action.from].center, _slots[action.to].center]
		"work":
			_hint_text = "Drag the %s onto the %s" % [db.equipment[action.equipment].name.to_upper(), item_name.call(action.slot)]
			_hint_points = [_tool_rect(action.equipment).get_center(), _slots[action.slot].center]
		"insert":
			_hint_text = "Drag the %s into the %s" % [item_name.call(action.slot), db.equipment[action.equipment].name.to_upper()]
			_hint_points = [_slots[action.slot].center, _station_spot(action.equipment, 0)]
		"work_appliance":
			var aslot: KitchenState.ApplianceSlot = pk.appliances[action.equipment][action.index]
			_hint_text = "Tap the %s to %s" % [db.equipment[action.equipment].name.to_upper(), aslot.process.action]
			_hint_points = [_station_spot(action.equipment, action.index)]
		"remove":
			_hint_text = "Ready! Tap the %s to take it out" % db.equipment[action.equipment].name.to_upper()
			_hint_points = [_station_spot(action.equipment, action.index)]
		"serve":
			_hint_text = "Drag the %s to the SERVING WINDOW!" % item_name.call(action.slot)
			_hint_points = [_slots[action.slot].center, _serve_rect.get_center()]
		"trash", "trash_appliance":
			_hint_text = "Throw that in the BIN"
			_hint_points = [_trash_rect.get_center()]
		"throw":
			_hint_text = "Throw the %s to %s" % [item_name.call(action.slot), _mate_name(action.target)]
			_hint_points = [_slots[action.slot].center, _mate_rect(action.target).get_center()]


func _draw_hint(c: CanvasItem, pulse: float) -> void:
	if _hint_text.is_empty():
		return
	for i in _hint_points.size():
		c.draw_arc(_hint_points[i], 58.0 + pulse * 8.0, 0, TAU, 40, Color(Art.TOMATO, 0.9), 6.0, true)
	if _hint_points.size() == 2:
		var a := _hint_points[0]
		var b := _hint_points[1]
		var dir := (b - a).normalized()
		var tip := b - dir * 66.0
		var start := a + dir * 66.0
		c.draw_line(start, tip, Art.TOMATO, 8.0, true)
		c.draw_colored_polygon(PackedVector2Array([tip + dir * 18.0, tip + dir.orthogonal() * 14.0, tip - dir.orthogonal() * 14.0]), Art.TOMATO)
	var font := Art.ui_font()
	var text := "NEW DISH TIP: " + _hint_text
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40.0
	var rect := Rect2(Vector2(SIDEBAR_W + (size.x - SIDEBAR_W - 190.0 - width) * 0.5, size.y - 56), Vector2(width, 44))
	c.draw_rect(rect, Art.PAPER)
	c.draw_rect(rect, Art.INK, false, 4.0)
	c.draw_string(font, rect.position + Vector2(20, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Art.INK)


# --- Queries -----------------------------------------------------------------

func _hit(pos: Vector2) -> Dictionary:
	if _pause_rect.has_point(pos):
		return {"kind": "pause"}
	if _serve_rect.has_area() and _serve_rect.has_point(pos):
		return {"kind": "serve"}
	for mate in _mates:
		if mate.rect.has_point(pos):
			return {"kind": "mate", "player": mate.player}
	if _trash_rect.has_point(pos):
		return {"kind": "trash"}
	for station in _stations:
		if station.rect.has_point(pos):
			var best := 0
			for i in station.spots.size():
				if pos.distance_to(station.spots[i]) < pos.distance_to(station.spots[best]):
					best = i
			return {"kind": "station", "id": station.id, "index": best}
	var best_slot := -1
	var pk_slots := kitchen.players[_me].slots
	for i in _slots.size():
		var item: KitchenItem = pk_slots[i]
		if item and _item_views.has(item.uid) and _item_views[item.uid].resume_icon:
			var badge: Dictionary = _item_views[item.uid].resume_badge()
			if pos.distance_to(badge.center) <= badge.radius:
				return {"kind": "slot", "index": i, "resume": _paused_tool(item)}
	for i in _slots.size():
		if _slots[i].rect.has_point(pos) and (best_slot < 0 or pos.distance_to(_slots[i].center) < pos.distance_to(_slots[best_slot].center)):
			best_slot = i
	if best_slot >= 0:
		return {"kind": "slot", "index": best_slot}
	for crate in _crates:
		if crate.rect.has_point(pos):
			return {"kind": "crate", "id": crate.id}
	for tool in _tools:
		if tool.rect.has_point(pos):
			return {"kind": "tool", "id": tool.id}
	return {}


func _selected_slot() -> int:
	if _selected_uid == 0:
		return -1
	var slots := kitchen.players[_me].slots
	for i in slots.size():
		if slots[i] and slots[i].uid == _selected_uid:
			return i
	return -1


func _can_combine(from: int, to: int) -> bool:
	var a := kitchen.item_at(_me, from)
	var b := kitchen.item_at(_me, to)
	return a != null and b != null and db.combine(b.type, b.contents, a.type, a.contents).ok


## Where the selected (or dragged) item could go, for highlighting.
func _valid_targets() -> Dictionary:
	var targets := {"tools": [], "stations": [], "slots": [], "serve": false, "mates": []}
	var from := _selected_slot()
	if from < 0:
		return targets
	var item := kitchen.item_at(_me, from)
	var effective := kitchen.effective_id(item)
	for tool in _tools:
		if not db.process_for(effective, tool.id).is_empty():
			targets.tools.append(tool.id)
	for station in _stations:
		if not db.process_for(effective, station.id).is_empty():
			targets.stations.append(station.id)
	for i in _slots.size():
		if i != from and kitchen.item_at(_me, i) and _can_combine(from, i):
			targets.slots.append(i)
	targets.serve = shift.orders.orders.any(func(o): return o.dish == effective)
	for mate in _mates:
		if _mate_can_use(mate.player, effective):
			targets.mates.append(mate.player)
	return targets


## Whether a teammate has equipment for this food, or serves it.
func _mate_can_use(player: int, effective: String) -> bool:
	var pk := kitchen.players[player]
	for eq in pk.tools + pk.appliances.keys():
		if not db.process_for(effective, eq).is_empty():
			return true
	return pk.serves and shift.orders.orders.any(func(o): return o.dish == effective)


func _mate_rect(player: int) -> Rect2:
	for mate in _mates:
		if mate.player == player:
			return mate.rect
	return Rect2(size.x - 178, TOP_BAR_H + 80, 164, 130)


func _mate_name(player: int) -> String:
	return "%s (%s)" % [str(Net.profile_of(player).name).to_upper(), kitchen.players[player].role.to_upper()]


func _draw_mate(c: CanvasItem, mate: Dictionary) -> void:
	var rect: Rect2 = mate.rect
	var player: int = mate.player
	var friend := Net.profile_of(player)
	var color: Color = Art.PLAYER_COLORS[player % Art.PLAYER_COLORS.size()]
	c.draw_rect(rect, color.lightened(0.55))
	c.draw_rect(rect, Art.INK, false, 5.0)
	var free := kitchen.players[player].free_slot_count()
	ChefLook.draw(c, rect.position + Vector2(36, 54), 78.0, friend.look, 1.0 if free > 0 else 0.2)
	var font := Art.comic_font()
	c.draw_string(font, rect.position + Vector2(72, 30), str(friend.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 76, 22, Art.INK)
	c.draw_string(Art.ui_font(), rect.position + Vector2(72, 52), kitchen.players[player].role, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 76, 12, Art.INK)
	c.draw_string(Art.ui_font(), rect.position + Vector2(72, 74), "%d free" % free if free > 0 else "FULL!", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 76, 14, Art.INK if free > 0 else Art.TOMATO)
	c.draw_string(font, rect.position + Vector2(0, rect.size.y - 12), "THROW HERE ➜", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20, Art.INK)


func _crate_rect(id: String) -> Rect2:
	for crate in _crates:
		if crate.id == id:
			return crate.rect
	return Rect2()


func _tool_rect(id: String) -> Rect2:
	for tool in _tools:
		if tool.id == id:
			return tool.rect
	return Rect2()


func _station_spot(id: String, index: int) -> Vector2:
	for station in _stations:
		if station.id == id:
			return station.spots[mini(index, station.spots.size() - 1)]
	return size * 0.5


func _bubble(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	ComicBubble.spawn(_fx_layer, pos, text, color, font_size)


func _pick(options: Array) -> String:
	return options[_rng.randi() % options.size()]


# --- Drawing -----------------------------------------------------------------

func _draw_backdrop() -> void:
	var c := _backdrop
	var w := size.x
	var h := size.y
	# Back wall with comic halftone dots.
	UiStyle.draw_halftone(c, Rect2(0, TOP_BAR_H, w, h - TOP_BAR_H), Color("#f8e3b5"), Color("#f1c98a"), 20.0)
	for y in range(int(TOP_BAR_H) + 190, int(h), 46):
		c.draw_line(Vector2(SIDEBAR_W, y), Vector2(w, y), Color("#e9c48f"), 2.0)
	# Counter top and front, in perspective.
	c.draw_colored_polygon(_counter_top, Color("#d9a066"))
	var stripes := Color("#c88d55")
	for i in 7:
		var t := (i + 1) / 8.0
		c.draw_line(_counter_top[0].lerp(_counter_top[3], t), _counter_top[1].lerp(_counter_top[2], t), stripes, 2.0)
	var top_outline := _counter_top.duplicate()
	top_outline.append(_counter_top[0])
	c.draw_polyline(top_outline, Art.INK, 6.0, true)
	c.draw_colored_polygon(_counter_front, Color("#8a5a2e"))
	c.draw_line(_counter_front[0], _counter_front[1], Art.INK, 6.0)
	# Slot plates.
	for slot in _slots:
		var center: Vector2 = slot.center + Vector2(0, 30 * slot.scale)
		_draw_ellipse(c, center, Vector2(60, 20) * slot.scale, Color("#f3e1c4"), 3.0)
	# Appliances on the back wall.
	for station in _stations:
		var rect: Rect2 = station.rect
		var texture := Art.equipment(station.id)
		var side := minf(rect.size.x, 164.0)
		if texture:
			c.draw_texture_rect(texture, Rect2(rect.position + Vector2((rect.size.x - side) * 0.5, 0), Vector2(side, side)), false)
		_draw_label(c, db.equipment[station.id].name.to_upper(), Vector2(rect.position.x, rect.end.y - 8), rect.size.x, 16)
	# Serving window.
	if _serve_rect.has_area():
		_draw_serving_window(c)
	_draw_bin_and_sidebar(c, h)


func _draw_serving_window(c: CanvasItem) -> void:
	c.draw_rect(_serve_rect, Color("#7fc8f8"))
	c.draw_rect(Rect2(_serve_rect.position, Vector2(_serve_rect.size.x, 40)), Art.TOMATO)
	for i in 6:
		c.draw_rect(Rect2(_serve_rect.position + Vector2(i * _serve_rect.size.x / 6.0, 0), Vector2(_serve_rect.size.x / 12.0, 40)), Color.WHITE)
	c.draw_rect(_serve_rect, Art.INK, false, 6.0)
	var bell := Art.equipment("serving_window")
	if bell:
		c.draw_texture_rect(bell, Rect2(_serve_rect.position + Vector2(32, 60), Vector2(100, 100)), false)
	_draw_label(c, "SERVE", Vector2(_serve_rect.position.x, _serve_rect.end.y - 8), _serve_rect.size.x, 24)


func _draw_bin_and_sidebar(c: CanvasItem, h: float) -> void:
	# Bin.
	var bin := Art.equipment("trash")
	if bin:
		c.draw_texture_rect(bin, Rect2(_trash_rect.position + Vector2(10, 0), Vector2(100, 100)), false)
	_draw_label(c, "BIN", Vector2(_trash_rect.position.x, _trash_rect.end.y - 6), _trash_rect.size.x, 18)
	# Sidebar.
	c.draw_rect(Rect2(0, TOP_BAR_H, SIDEBAR_W, h - TOP_BAR_H), Color("#3a2f55"))
	c.draw_line(Vector2(SIDEBAR_W, TOP_BAR_H), Vector2(SIDEBAR_W, h), Art.INK, 6.0)
	var title := "MY CRATES"
	if kitchen.players.size() > 1:
		title = "%s · %s" % [Game.profile.name.to_upper(), kitchen.players[_me].role.to_upper()]
	_draw_label(c, title, Vector2(0, TOP_BAR_H + 30), SIDEBAR_W, 22, Art.PLAYER_COLORS[_me % Art.PLAYER_COLORS.size()].lightened(0.3) if kitchen.players.size() > 1 else Color.WHITE)
	for crate in _crates:
		var rect: Rect2 = crate.rect
		var box := Art.equipment("crate")
		if box:
			c.draw_texture_rect(box, rect, false)
		var icon := Art.item(crate.id)
		if icon:
			var side := rect.size.x * 0.72
			c.draw_texture_rect(icon, Rect2(rect.position + Vector2((rect.size.x - side) * 0.5, rect.size.y * 0.06), Vector2(side, side)), false)
		_draw_label(c, db.item_name(crate.id).to_upper(), Vector2(rect.position.x - 6, rect.end.y + 2), rect.size.x + 12, _crate_label_size, Color.WHITE)
	if not _tools.is_empty():
		_draw_label(c, "MY TOOLS", Vector2(0, _tools[0].rect.position.y - 10), SIDEBAR_W, 22, Color.WHITE)
	for tool in _tools:
		var rect: Rect2 = tool.rect
		c.draw_circle(rect.get_center(), rect.size.x * 0.48, Color("#5a4b80"))
		c.draw_arc(rect.get_center(), rect.size.x * 0.48, 0, TAU, 32, Art.INK, 3.0, true)
		var icon := Art.equipment(tool.id)
		if icon:
			c.draw_texture_rect(icon, rect.grow(-6), false)


func _draw_dynamic() -> void:
	var c := _dynamic
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	var glow := Color(1.0, 0.95, 0.4, 0.35 + 0.35 * pulse)
	var targets := _valid_targets()
	for tool in _tools:
		if targets.tools.has(tool.id):
			c.draw_circle(tool.rect.get_center(), tool.rect.size.x * 0.58, glow)
	for station in _stations:
		if targets.stations.has(station.id):
			c.draw_rect(station.rect.grow(4), glow)
	for i in targets.slots:
		_draw_ellipse(c, _slots[i].center + Vector2(0, 30 * _slots[i].scale), Vector2(70, 26) * _slots[i].scale, glow, 0.0)
	if targets.serve and _serve_rect.has_area():
		c.draw_rect(_serve_rect.grow(8), glow)
	for mate in _mates:
		if targets.mates.has(mate.player):
			c.draw_rect(mate.rect.grow(8), glow)
		_draw_mate(c, mate)
	# Appliance timers.
	var pk := kitchen.players[_me]
	for station in _stations:
		var appliance: Array = pk.appliances[station.id]
		for index in appliance.size():
			var spot: Vector2 = station.spots[index] + Vector2(0, -6)
			var aslot: KitchenState.ApplianceSlot = appliance[index]
			if aslot == null:
				_draw_ellipse(c, spot + Vector2(0, 22), Vector2(26, 9), Color(Art.INK, 0.25), 0.0)
				continue
			_draw_appliance_timer(c, spot, aslot, pulse)
	_draw_hint(c, pulse)
	# Pause button.
	c.draw_rect(_pause_rect, Art.PAPER)
	c.draw_rect(_pause_rect, Art.INK, false, 4.0)
	c.draw_rect(Rect2(_pause_rect.position + Vector2(17, 14), Vector2(8, 30)), Art.INK)
	c.draw_rect(Rect2(_pause_rect.position + Vector2(33, 14), Vector2(8, 30)), Art.INK)


func _draw_appliance_timer(c: CanvasItem, spot: Vector2, aslot: KitchenState.ApplianceSlot, pulse: float) -> void:
	var proc := aslot.process
	var radius := 40.0
	var fraction := 0.0
	var color := Color.WHITE
	var label := ""
	if aslot.burnt:
		for i in 3:
			c.draw_circle(spot + Vector2(-14 + i * 14, -44 - fmod(_time * 30.0 + i * 12.0, 30.0)), 9.0, Color(0.3, 0.3, 0.3, 0.6))
		label = "BIN IT!"
		color = Color("#555")
		fraction = 1.0
	elif not aslot.done:
		var total: float = proc.cook_time if db.is_passive(proc) else proc.work
		fraction = aslot.progress / total
		color = Color.WHITE if db.is_passive(proc) else Art.SKY
		label = "" if db.is_passive(proc) else "TAP TO %s!" % proc.action.to_upper()
	elif db.is_passive(proc):
		if aslot.since_ready <= proc.perfect_window:
			color = Art.LEAF.lerp(Color.WHITE, pulse * 0.4)
			label = "TAKE IT!"
		else:
			color = Color("#ff8c1a").lerp(Art.TOMATO, pulse)
			label = "HURRY!"
		fraction = 1.0 - aslot.since_ready / proc.burn_time if proc.burn_time > 0.0 else 1.0
	else:
		color = Art.LEAF
		fraction = 1.0
		label = "TAKE IT!"
	c.draw_arc(spot, radius, 0, TAU, 40, Color(Art.INK, 0.5), 9.0, true)
	c.draw_arc(spot, radius, -PI / 2.0, -PI / 2.0 + TAU * clampf(fraction, 0.0, 1.0), 40, color, 7.0, true)
	if not label.is_empty():
		_draw_label(c, label, spot + Vector2(-80, -radius - 10), 160, 18, Color.WHITE, true)


func _draw_overlay() -> void:
	var c := _overlay
	if _dragging and _press.get("kind", "") == "slot":
		var hint := _hit(get_local_mouse_position())
		if hint.get("kind", "") in ["serve", "trash", "station", "tool", "mate"]:
			c.draw_arc(get_local_mouse_position(), 64, 0, TAU, 40, Art.SUN, 5.0, true)
	if not _session.paused:
		return
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(Art.INK, 0.7))
	var font := Art.comic_font()
	c.draw_string_outline(font, Vector2(0, size.y * 0.3), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, size.x, 80, 12, Art.INK)
	c.draw_string(font, Vector2(0, size.y * 0.3), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, size.x, 80, Art.SUN)
	if Net.is_online():
		c.draw_string(Art.ui_font(), Vector2(0, size.y * 0.3 + 36), "The kitchen is paused for both chefs.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color.WHITE)
	var buttons := _pause_buttons()
	for key in buttons:
		var rect: Rect2 = buttons[key]
		c.draw_rect(rect, Art.SUN if key == "resume" else Art.PAPER)
		c.draw_rect(rect, Art.INK, false, 5.0)
		c.draw_string(font, Vector2(rect.position.x, rect.get_center().y + 14), key.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 40, Art.INK)


func _pause_buttons() -> Dictionary:
	var w := 300.0
	var x := (size.x - w) * 0.5
	var buttons := {"resume": Rect2(x, size.y * 0.38, w, 70)}
	if not Net.is_client():
		buttons.restart = Rect2(x, size.y * 0.38 + 90, w, 70)
	buttons.quit = Rect2(x, size.y * 0.38 + 180, w, 70)
	return buttons


func _draw_label(c: CanvasItem, text: String, pos: Vector2, width: float, font_size: int, color: Color = Art.INK, outline: bool = false) -> void:
	var font := Art.comic_font()
	if outline:
		c.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 6, Art.INK)
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _draw_ellipse(c: CanvasItem, center: Vector2, radii: Vector2, fill: Color, outline_width: float) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	c.draw_colored_polygon(points, fill)
	if outline_width > 0.0:
		points.append(points[0])
		c.draw_polyline(points, Art.INK, outline_width, true)
