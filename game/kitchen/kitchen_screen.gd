extends Control
## The player's kitchen, laid out as a comic page: orders across the top,
## then panels for the pantry (crates), prep (boards, bowl, gadgets, counter
## spots), the stove (pots, pans, oven...), the pass (serving window) and the
## teammates. Food sits on the stations inside the panels.
##
## Every action goes through a session: a HostSession runs the rules (solo,
## or the host of a LAN game) and a ClientSession mirrors the host's shift
## on the other phone. Controls work with taps or drags:
## - tap a crate to take an ingredient (or drag it onto a station),
## - tap food to select it; where it can go glows,
## - then tap (or drag the food onto) another station, the serving window,
##   the bin, or a teammate's panel (that throws it to them),
## - tap a full board, bowl or gadget to work it with a gesture mini-game;
##   pots, pans and ovens cook on their own,
## - work can be paused (LATER, or a tap anywhere else) and picked up again
##   by tapping the station.
##
## The look is a placeholder: v0.6 replaces the drawing with the 3D comic
## kitchen, but keeps this layout and these controls.

const TOP_BAR_H := 118.0
const MARGIN := 10.0
const GUTTER := 12.0
const TAP_DISTANCE := 14.0
const START_DELAY := 1.8
const END_DELAY := 2.2

const PANEL_PANTRY := "pantry"
const PANEL_PREP := "prep"
const PANEL_STOVE := "stove"
const PANEL_PASS := "pass"
const PANEL_TEAM := "team"
const PANEL_TITLES := {PANEL_PANTRY: "PANTRY", PANEL_PREP: "PREP", PANEL_STOVE: "STOVE", PANEL_PASS: "PASS", PANEL_TEAM: "TEAM"}
const PANEL_COLORS := {PANEL_PANTRY: Color("#efe6d2"), PANEL_PREP: Color("#f6ecd8"), PANEL_STOVE: Color("#f2e0d0"),
	PANEL_PASS: Color("#e3eef2"), PANEL_TEAM: Color("#ece4f4")}

const ACTION_SOUNDS := {"chop": "chop", "slice": "slice", "knead": "squish", "roll": "roll", "stir": "swirl", "crank": "swirl",
	"press": "thud", "mash": "squish", "grate": "slice", "whisk": "swirl", "blend": "swirl"}
const COOK_WORDS := {"oven": "FWOOSH!", "pot": "BLOOP!", "pan": "SIZZLE!", "grill": "TSSSS!", "fryer": "BLUBBLUB!"}
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
var _panels: Array[Dictionary] = []  # {kind, rect, title, player (team insets)}
var _crates: Array[Dictionary] = []  # {id, rect}
var _spots: Array[Dictionary] = []  # one per station: {index, rect, center, scale}
var _mates: Array[Dictionary] = []  # {player, rect}: teammates to throw to
var _bin_rect := Rect2()
var _pause_rect := Rect2()
var _skip_rect := Rect2()

# Interaction state.
var _press: Dictionary = {}  # what was under the finger when it went down
var _press_pos := Vector2.ZERO
var _dragging := false
var _drag_view: ItemView
var _selected := -1  # station index of the selected food
var _work: Dictionary = {}  # what the open mini-game works on: {station, recipe}
var _start_timer := START_DELAY
var _end_timer := -1.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()

# Tips while learning a new dish: the bot's planner suggests the next step.
var _hint_bot := KitchenBot.new()
var _hint_text := ""
var _hint_points: Array[Vector2] = []
var _hint_timer := 0.0


func _ready() -> void:
	db = Game.db
	shift = Shift.new(db, Game.current_level, Game.player_count, Game.shift_seed, Game.prologue_dishes)
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
	_hint_bot.order_filter = func(order: Dictionary) -> bool: return order.get("tutorial", false)
	_order_bar.is_new = func(dish: String) -> bool: return not Game.progression.is_discovered(dish)
	resized.connect(_layout)
	_layout()
	_handle_events(_session.drain_events())
	_bubble(size * 0.5, "LET'S LEARN!" if shift.in_prologue() else "READY?", Art.SUN, 64)


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
			_close_minigame()
			_session.set_paused(true)


# --- Layout ------------------------------------------------------------------

## The panels this chef's page needs, busiest first within each row.
func _panel_kinds() -> Array[String]:
	var pk := kitchen.players[_me]
	var kinds: Array[String] = [PANEL_PANTRY, PANEL_PREP]
	if pk.stations.any(func(st): return db.station_kind(st.type) == ContentDB.STATION_COOK):
		kinds.append(PANEL_STOVE)
	if pk.serves:
		kinds.append(PANEL_PASS)
	if kitchen.players.size() > 1:
		kinds.append(PANEL_TEAM)
	return kinds


## Which panel a station belongs in. Counters are shared between the prep
## panel and the pass (food is plated there).
func _panel_of(st: KitchenState.Station, counters_seen: int, counters_total: int, has_pass: bool) -> String:
	match db.station_kind(st.type):
		ContentDB.STATION_COOK:
			return PANEL_STOVE
		ContentDB.STATION_PASS:
			return PANEL_PASS
		ContentDB.STATION_COUNTER:
			if has_pass and counters_seen >= ceili(counters_total / 2.0):
				return PANEL_PASS
	return PANEL_PREP


func _layout() -> void:
	var w := size.x
	var h := size.y
	var pk := kitchen.players[_me]
	_order_bar.position = Vector2.ZERO
	_order_bar.size = Vector2(w, TOP_BAR_H)

	# The page: a narrow pantry on the left; on the right a top row (prep and
	# stove) and a bottom row (pass and team).
	var page := Rect2(MARGIN, TOP_BAR_H + MARGIN, w - MARGIN * 2.0, h - TOP_BAR_H - MARGIN * 2.0)
	var kinds := _panel_kinds()
	var pantry_w := clampf(page.size.x * 0.17, 150.0, 230.0)
	var right := Rect2(page.position.x + pantry_w + GUTTER, page.position.y, page.size.x - pantry_w - GUTTER, page.size.y)
	var top_row: Array[String] = []
	var bottom_row: Array[String] = []
	for kind in kinds:
		if kind in [PANEL_PREP, PANEL_STOVE]:
			top_row.append(kind)
		elif kind != PANEL_PANTRY:
			bottom_row.append(kind)
	var top_h := right.size.y * (0.56 if not bottom_row.is_empty() else 1.0)
	_panels.clear()
	_panels.append({"kind": PANEL_PANTRY, "rect": Rect2(page.position, Vector2(pantry_w, page.size.y))})
	_add_row(top_row, Rect2(right.position, Vector2(right.size.x, top_h)), [0.58, 0.42])
	if not bottom_row.is_empty():
		_add_row(bottom_row, Rect2(right.position + Vector2(0, top_h + GUTTER), Vector2(right.size.x, right.size.y - top_h - GUTTER)), [0.5, 0.5])

	# Crates in the pantry.
	_crates.clear()
	var pantry: Rect2 = _panel_rect(PANEL_PANTRY).grow(-10)
	pantry.position.y += 34
	pantry.size.y -= 34
	var crate_cells := _grid(pk.crates.size(), pantry, 2)
	for i in pk.crates.size():
		_crates.append({"id": pk.crates[i], "rect": crate_cells[i]})

	# Stations in their panels.
	var has_pass := pk.serves
	var counters_total := pk.stations.filter(func(st): return db.station_kind(st.type) == ContentDB.STATION_COUNTER).size()
	var by_panel := {}
	var counters_seen := 0
	for st in pk.stations:
		var kind := _panel_of(st, counters_seen, counters_total, has_pass)
		if db.station_kind(st.type) == ContentDB.STATION_COUNTER:
			counters_seen += 1
		if not by_panel.has(kind):
			by_panel[kind] = []
		by_panel[kind].append(st.index)
	_spots.clear()
	_spots.resize(pk.stations.size())
	for kind in by_panel:
		var area: Rect2 = _panel_rect(kind).grow(-10)
		area.position.y += 34
		area.size.y -= 34
		if kind == PANEL_PREP:
			area.size.x -= 86  # room for the bin
		var indices: Array = by_panel[kind]
		var cells := _grid(indices.size(), area, 0)
		for i in indices.size():
			var cell: Rect2 = cells[i]
			var side := minf(cell.size.x, cell.size.y)
			_spots[indices[i]] = {"index": indices[i], "rect": cell, "center": cell.get_center(), "scale": clampf(side / 120.0, 0.45, 1.15)}
	var prep := _panel_rect(PANEL_PREP)
	_bin_rect = Rect2(prep.end - Vector2(90, 100), Vector2(80, 90))

	# Teammates, stacked in the team panel.
	_mates.clear()
	var team := _panel_rect(PANEL_TEAM)
	if team.has_area():
		var others: Array[int] = []
		for p in kitchen.players.size():
			if p != _me:
				others.append(p)
		var inner := team.grow(-8)
		inner.position.y += 30
		inner.size.y -= 30
		var each := (inner.size.y - GUTTER * (others.size() - 1)) / others.size()
		for i in others.size():
			_mates.append({"player": others[i], "rect": Rect2(inner.position + Vector2(0, i * (each + GUTTER)), Vector2(inner.size.x, each))})

	_pause_rect = Rect2(w - 66, TOP_BAR_H + MARGIN + 4, 54, 54)
	_skip_rect = Rect2(w * 0.5 - 90, TOP_BAR_H + 62, 180, 52)
	var mini_size := Vector2(minf(560.0, w - 120.0), 330.0)
	_minigame.size = mini_size
	_minigame.position = Vector2((w - mini_size.x) * 0.5, TOP_BAR_H + 40)
	_backdrop.queue_redraw()


func _add_row(kinds: Array[String], rect: Rect2, shares: Array) -> void:
	if kinds.is_empty():
		return
	var x := rect.position.x
	var total := rect.size.x - GUTTER * (kinds.size() - 1)
	for i in kinds.size():
		var share: float = shares[i] if kinds.size() == shares.size() else 1.0 / kinds.size()
		var width := total * share if i < kinds.size() - 1 else rect.end.x - x
		_panels.append({"kind": kinds[i], "rect": Rect2(x, rect.position.y, width, rect.size.y)})
		x += width + GUTTER


## Splits an area into `count` square-ish cells (`columns` 0 = automatic).
func _grid(count: int, area: Rect2, columns: int) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	if count <= 0:
		return cells
	var cols := columns
	if cols <= 0:
		cols = 1
		while cols < count and area.size.x / cols > area.size.y / ceili(float(count) / cols) * 1.15:
			cols += 1
	var rows := ceili(float(count) / cols)
	var cell := Vector2(area.size.x / cols, area.size.y / rows)
	for i in count:
		var r := Rect2(area.position + Vector2((i % cols) * cell.x, (i / cols) * cell.y), cell)
		cells.append(r.grow(-4))
	return cells


func _panel_rect(kind: String) -> Rect2:
	for panel in _panels:
		if panel.kind == kind:
			return panel.rect
	return Rect2()


# --- Frame update ------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if not _session.paused:
		if _start_timer > 0.0:
			_start_timer -= delta
			if _start_timer <= 0.0 and not shift.in_prologue():
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
	for st in kitchen.players[_me].stations:
		var spot: Dictionary = _spots[st.index]
		var n := st.contents.size()
		for i in n:
			var item: KitchenItem = st.contents[i]
			seen[item.uid] = true
			var view := _view_for(item, spot.center)
			var offset := Vector2.ZERO
			var scale_factor := 1.0
			if n > 1:
				# Several things in a bowl or pot: side by side, smaller.
				scale_factor = 0.62
				offset = Vector2((i - (n - 1) * 0.5) * 46.0 * spot.scale, 6.0 * spot.scale)
			if not view.held:
				view.target = spot.center + offset
			view.display_scale = spot.scale * scale_factor
			view.selected = st.index == _selected and n == 1
			view.update_item(item)
	for uid in _item_views.keys():
		if not seen.has(uid):
			_item_views[uid].queue_free()
			_item_views.erase(uid)
	if _selected >= 0 and kitchen.item_at(_me, _selected) == null:
		_selected = -1


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
		# Other chefs' kitchens aren't on this screen.
		if int(event.get("player", _me)) != _me:
			continue
		match event.type:
			"item_added":
				var crate := _crate_rect(str(event.item.get("type", "")))
				if crate.has_area() and event.item.has("uid"):
					_spawn_from[int(event.item.uid)] = crate.get_center()
				Sfx.play("pop")
			"item_moved":
				if event.get("combined", false):
					Sfx.play("thud")
					_bubble(station_center(event.to) + Vector2(0, -70), _pick(["SPLAT!", "PLOP!", "TA-DA!"]), Color.WHITE, 30)
				else:
					Sfx.play("pop", 0.2)
				if event.item.get("perfect", false) and not event.get("combined", false):
					_bubble(station_center(event.to) + Vector2(0, -80), "PERFECT!", Art.SUN, 36)
			"item_processed":
				Sfx.play("pop")
				Game.vibrate(40)
				_bubble(station_center(event.station) + Vector2(0, -80), "DONE!", Art.LEAF, 34)
			"cook_started":
				Sfx.play("whoosh")
				var type: String = kitchen.players[_me].stations[event.station].type
				_bubble(station_center(event.station) + Vector2(0, -70), COOK_WORDS.get(type, "SPLOSH!"), Art.SUN, 28)
			"cook_ready":
				Sfx.play("ding", 0.0)
				Game.vibrate(60)
				_bubble(station_center(event.station) + Vector2(0, -80), "DING!", Art.SUN, 40)
			"cook_burnt":
				Sfx.play("sizzle")
				Game.vibrate(200)
				_bubble(station_center(event.station) + Vector2(0, -80), "BURNT!", Color("#555"), 40)
			"item_served":
				_fly_away(int(event.item.uid), _pass_center())
				Sfx.play("bell", 0.0)
			"order_served":
				Sfx.play("coin")
				Game.vibrate(30)
				_bubble(_pass_center() + Vector2(-20, -90), "+%d" % event.points, Art.SUN, 46)
				_discovered(event.order.dish)
			"prologue_served":
				Sfx.play("coin")
				_discovered(event.dish)
			"prologue_dish":
				_bubble(size * 0.5 + Vector2(0, 40), "NEW DISH: %s" % db.item_name(event.dish).to_upper(), Art.SUN, 40)
			"shift_started":
				if _start_timer <= 0.0:
					_bubble(size * 0.5, "NOW FOR REAL: COOK!", Art.TOMATO, 60)
					Sfx.play("bell")
			"item_trashed":
				for item in event.get("items", []):
					_fly_away(int(item.uid), _bin_rect.get_center())
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


func _discovered(dish: String) -> void:
	if Game.discover(dish):
		Sfx.play("cheer")
		_bubble(size * 0.5 + Vector2(0, -40), "NEW DISH: %s!" % db.item_name(dish).to_upper(), Art.SUN, 44)
		_hint_text = ""
		_hint_points.clear()


func _on_item_thrown(event: Dictionary) -> void:
	var uid := int(event.item.uid)
	if event.player == _me:
		_fly_away(uid, mate_center(event.target))
		Sfx.play("whoosh")
		_bubble(mate_center(event.target) + Vector2(-40, -70), "WHOOSH!", Color.WHITE, 34)
	elif event.target == _me:
		_spawn_from[uid] = mate_center(event.player)
		Sfx.play("thud")
		Game.vibrate(40)
		_bubble(station_center(event.target_station) + Vector2(0, -80), _pick(["THWACK!", "CATCH!", "PLOP!"]), Art.SUN, 36)


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
	if shift.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = _hit(pos)
			_press_pos = pos
			_dragging = false
			match _press.get("kind", ""):
				"pause":
					_session.set_paused(true)
					_press = {}
				"skip":
					_intent({"type": "skip_prologue"})
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
		"station":
			var item := kitchen.item_at(_me, _press.index)
			if item and kitchen.can_take(kitchen.station(_me, _press.index)) and _item_views.has(item.uid):
				_drag_view = _item_views[item.uid]
				_drag_view.held = true
				_selected = _press.index
		"crate":
			_show_ghost(Art.item(_press.id))


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
	if not _dragging:
		_tap(press)
		return
	var target := _hit(pos)
	match press.kind:
		"station":
			_send_food(press.index, target)
		"crate":
			if target.get("kind", "") == "station":
				_intent({"type": "take", "ingredient": press.id, "station": target.index}, true)
			elif target.get("kind", "") == "crate":
				_intent({"type": "take", "ingredient": press.id}, true)
	_selected = -1


## Sends the food on a station to wherever it was dropped or tapped.
func _send_food(from: int, target: Dictionary) -> void:
	match target.get("kind", ""):
		"station":
			if target.index == from:
				return
			var st := kitchen.station(_me, target.index)
			if db.station_kind(st.type) == ContentDB.STATION_PASS:
				_intent({"type": "serve", "station": from}, true)
			else:
				_intent({"type": "move", "from": from, "to": target.index}, true)
		"bin":
			_intent({"type": "trash", "station": from})
		"mate":
			_intent({"type": "throw", "station": from, "target": target.player}, true)


func _tap(press: Dictionary) -> void:
	match press.kind:
		"crate":
			if _selected >= 0:
				_selected = -1
			_intent({"type": "take", "ingredient": press.id}, true)
		"station":
			_tap_station(press.index)
		"bin":
			if _selected >= 0:
				_intent({"type": "trash", "station": _selected})
				_selected = -1
		"mate":
			if _selected >= 0:
				_intent({"type": "throw", "station": _selected, "target": press.player}, true)
				_selected = -1
			else:
				_bubble(mate_center(press.player) + Vector2(-40, -60), "PICK FOOD TO THROW!", Color.WHITE, 22)


func _tap_station(index: int) -> void:
	var st := kitchen.station(_me, index)
	if _selected >= 0 and _selected != index:
		_send_food(_selected, {"kind": "station", "index": index})
		_selected = -1
		return
	if st.burnt:
		_intent({"type": "trash", "station": index})
		return
	if not st.recipe.is_empty() and db.station_kind(st.type) == ContentDB.STATION_MANUAL:
		_selected = -1
		_start_work(index)
		return
	if _selected == index:
		_selected = -1
	elif kitchen.can_take(st):
		_selected = index
		Sfx.play("pop", 0.3)


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
		return true
	if not result.ok and nope_on_fail:
		_nope(str(result.get("error", "")))
	return result.ok


func _on_intent_answered(intent: Dictionary, result: Dictionary) -> void:
	if not result.ok and intent.type in ["take", "move", "throw", "serve"]:
		_nope(str(result.get("error", "")))


func _nope(error: String) -> void:
	Sfx.play("nope", 0.0)
	Game.vibrate(80)
	_bubble(get_local_mouse_position() + Vector2(0, -50), _nope_text(error), Color.WHITE, 30)


func _nope_text(error: String) -> String:
	match error:
		"counter_full":
			return "NO ROOM!"
		"station_full":
			return "IT'S FULL!"
		"cannot_place", "cannot_combine":
			return "THAT DOESN'T GO THERE!"
		"no_matching_order":
			return "NOBODY ORDERED THAT!"
		"target_full":
			return "THEIR KITCHEN IS FULL!"
		"burnt":
			return "BIN IT!"
	return "NOPE!"


func _start_work(index: int) -> void:
	var st := kitchen.station(_me, index)
	if st.recipe.is_empty():
		return
	var shown: Texture2D = Art.item(kitchen.effective_id(st.contents[0])) if st.contents.size() == 1 else Art.item(st.recipe.output)
	_work = {"station": index, "recipe": st.recipe}
	_minigame.open(st.recipe.action, st.recipe.work, st.progress, shown, Art.equipment(st.type))


func _on_minigame_work(units: int) -> void:
	if _work.is_empty():
		return
	if Game.settings.easy_minigames:
		units *= 2  # every gesture counts double
	var recipe: Dictionary = _work.recipe
	if not _intent({"type": "work", "station": _work.station, "amount": units}):
		_close_minigame()
		return
	Sfx.play(ACTION_SOUNDS.get(recipe.action, "pop"))
	Game.vibrate(15)
	var words: Array = ACTION_WORDS.get(recipe.action, ["POW!"])
	_bubble(_minigame.position + Vector2(_rng.randf_range(80, _minigame.size.x - 80), _rng.randf_range(125, 235)), _pick(words), Color.WHITE, 32)
	# Count the gesture right away; on a client the host confirms a moment later.
	_minigame.set_progress(minf(_minigame.done + units, recipe.work))
	_check_work_done()


## Closes the mini-game once the station has made its food.
func _check_work_done() -> void:
	if _work.is_empty():
		return
	var st := kitchen.station(_me, _work.station)
	if st.recipe.get("id", "") != _work.recipe.id:
		var recipe: Dictionary = _work.recipe
		_work = {}
		_minigame.set_progress(recipe.work)
		_minigame.finish()


func _close_minigame() -> void:
	_work = {}
	_minigame.visible = false


## The mini-game was left early: the station keeps the progress for later.
func _on_work_paused() -> void:
	if _work.is_empty() or _minigame.done <= 0.0:
		return
	_bubble(station_center(_work.station) + Vector2(0, -80), "LATER!", Art.SKY, 30)
	Sfx.play("pop", 0.2)


# --- Tips --------------------------------------------------------------------

func _update_hint() -> void:
	_hint_text = ""
	_hint_points.clear()
	if _start_timer > 0.0 or shift.finished or _minigame.visible or not shift.in_prologue():
		return
	for action in _hint_bot.plan(shift):
		if action.player == _me:
			_describe(action)
			return
	if not shift.orders.orders.is_empty():
		_hint_text = "Wait for your teammate..."


func _describe(action: Dictionary) -> void:
	var food := func(index: int) -> String:
		var item := kitchen.item_at(_me, index)
		if item == null:
			return "food"
		var id := kitchen.effective_id(item)
		return db.item_name(id if not id.is_empty() else item.type).to_upper()
	var station_name := func(index: int) -> String:
		return db.station_name(kitchen.players[_me].stations[index].type).to_upper()
	match action.type:
		"take":
			var crate := _crate_rect(action.ingredient).get_center()
			if action.get("station", -1) >= 0:
				_hint_text = "Drag the %s onto the %s" % [db.item_name(action.ingredient).to_upper(), station_name.call(action.station)]
				_hint_points = [crate, station_center(action.station)]
			else:
				_hint_text = "Tap the %s crate" % db.item_name(action.ingredient).to_upper()
				_hint_points = [crate]
		"move":
			var to := kitchen.station(_me, action.to)
			var target: String = food.call(action.to) if to.item() and db.station_kind(to.type) != ContentDB.STATION_COOK else station_name.call(action.to)
			_hint_text = "Drag the %s onto the %s" % [food.call(action.from), target]
			_hint_points = [station_center(action.from), station_center(action.to)]
		"work":
			var st := kitchen.station(_me, action.station)
			_hint_text = "Tap the %s to %s" % [station_name.call(action.station), st.recipe.get("action", "work")]
			_hint_points = [station_center(action.station)]
		"serve":
			_hint_text = "Drag the %s to the SERVING WINDOW!" % food.call(action.station)
			_hint_points = [station_center(action.station), _pass_center()]
		"trash":
			_hint_text = "Throw that in the BIN"
			_hint_points = [station_center(action.station), _bin_rect.get_center()]
		"throw":
			_hint_text = "Throw the %s to %s" % [food.call(action.station), _mate_name(action.target)]
			_hint_points = [station_center(action.station), mate_center(action.target)]


# --- Queries (also used by the automated screen tests) -----------------------

func station_center(index: int) -> Vector2:
	if index >= 0 and index < _spots.size() and _spots[index] is Dictionary and not _spots[index].is_empty():
		return _spots[index].center
	return size * 0.5


func crate_center(id: String) -> Vector2:
	return _crate_rect(id).get_center()


func mate_center(player: int) -> Vector2:
	for mate in _mates:
		if mate.player == player:
			return mate.rect.get_center()
	return Vector2(size.x - 120, size.y - 120)


func bin_center() -> Vector2:
	return _bin_rect.get_center()


## Index of this chef's first station of a type (e.g. "board"), or -1.
func station_of(type: String) -> int:
	var list := kitchen.players[_me].stations_of(type)
	return list[0].index if not list.is_empty() else -1


func _pass_center() -> Vector2:
	var index := kitchen.players[_me].pass_station(db)
	return station_center(index) if index >= 0 else Vector2(size.x - 120, TOP_BAR_H + 120)


func _hit(pos: Vector2) -> Dictionary:
	if _pause_rect.has_point(pos):
		return {"kind": "pause"}
	if shift.in_prologue() and _skip_rect.has_point(pos):
		return {"kind": "skip"}
	for mate in _mates:
		if mate.rect.has_point(pos):
			return {"kind": "mate", "player": mate.player}
	if _bin_rect.has_point(pos):
		return {"kind": "bin"}
	var best := -1
	for spot in _spots:
		if spot is Dictionary and not spot.is_empty() and spot.rect.has_point(pos):
			if best < 0 or pos.distance_to(spot.center) < pos.distance_to(_spots[best].center):
				best = spot.index
	if best >= 0:
		return {"kind": "station", "index": best}
	for crate in _crates:
		if crate.rect.has_point(pos):
			return {"kind": "crate", "id": crate.id}
	return {}


## Where the selected (or dragged) food could go, for highlighting.
func _valid_targets() -> Dictionary:
	var targets := {"stations": [], "mates": [], "bin": false}
	if _selected < 0:
		return targets
	var item := kitchen.item_at(_me, _selected)
	if item == null:
		return targets
	var effective := kitchen.effective_id(item)
	targets.bin = true
	for st in kitchen.players[_me].stations:
		if st.index == _selected:
			continue
		match db.station_kind(st.type):
			ContentDB.STATION_PASS:
				if shift.orders.orders.any(func(o): return o.dish == effective):
					targets.stations.append(st.index)
			_:
				var fits := db.accepts(st.type, kitchen.contents_ids(st), effective)
				var resident := st.item()
				if not fits and resident and not st.burnt:
					fits = db.combine(resident.type, resident.contents, item.type, item.contents).ok
				if fits:
					targets.stations.append(st.index)
	for mate in _mates:
		if kitchen.players[mate.player].free_counter(db) >= 0:
			targets.mates.append(mate.player)
	return targets


func _mate_name(player: int) -> String:
	return "%s (%s)" % [str(Net.profile_of(player).name).to_upper(), kitchen.players[player].role.to_upper()]


func _crate_rect(id: String) -> Rect2:
	for crate in _crates:
		if crate.id == id:
			return crate.rect
	return Rect2()


func _bubble(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	ComicBubble.spawn(_fx_layer, pos, text, color, font_size)


func _pick(options: Array) -> String:
	return options[_rng.randi() % options.size()]


# --- Drawing -----------------------------------------------------------------

func _draw_backdrop() -> void:
	var c := _backdrop
	# The page between the panels: dark ink with halftone dots.
	UiStyle.draw_halftone(c, Rect2(0, TOP_BAR_H, size.x, size.y - TOP_BAR_H), Color("#262038"), Color("#2f2846"), 16.0)
	for panel in _panels:
		var rect: Rect2 = panel.rect
		c.draw_rect(rect, PANEL_COLORS.get(panel.kind, Art.PAPER))
		c.draw_rect(rect, Art.INK, false, 6.0)
		var title: String = PANEL_TITLES.get(panel.kind, "")
		if panel.kind == PANEL_TEAM:
			title = "TEAM · THROW HERE"
		_draw_caption(c, rect.position + Vector2(8, 8), title)
	# Crates.
	for crate in _crates:
		var rect: Rect2 = crate.rect
		var box := Art.equipment("crate") if crate.id != ContentDB.PLATE else null
		if box:
			c.draw_texture_rect(box, _square(rect, 0.9), false)
		var icon := Art.item(crate.id)
		if icon:
			c.draw_texture_rect(icon, _square(rect, 0.62).grow(-2), false)
		_draw_label(c, db.item_name(crate.id).to_upper(), Vector2(rect.position.x - 4, rect.end.y - 2), rect.size.x + 8, 13, Art.INK)
	# Stations.
	var pk := kitchen.players[_me]
	for spot in _spots:
		if not (spot is Dictionary) or spot.is_empty():
			continue
		var st: KitchenState.Station = pk.stations[spot.index]
		var rect: Rect2 = spot.rect
		match db.station_kind(st.type):
			ContentDB.STATION_COUNTER:
				_draw_ellipse(c, spot.center + Vector2(0, 26 * spot.scale), Vector2(52, 18) * spot.scale, Color("#e2cfae"), 3.0)
			ContentDB.STATION_PASS:
				var window := _square(rect, 0.92)
				c.draw_rect(window, Color("#7fc8f8"))
				c.draw_rect(Rect2(window.position, Vector2(window.size.x, 22)), Art.TOMATO)
				c.draw_rect(window, Art.INK, false, 5.0)
				var bell := Art.equipment("serving_window")
				if bell:
					c.draw_texture_rect(bell, _square(window, 0.55), false)
				_draw_label(c, "SERVE", Vector2(window.position.x, window.end.y - 8), window.size.x, 22)
			_:
				var art := Art.equipment(st.type)
				if art:
					c.draw_texture_rect(art, _square(rect, 0.95, 150.0), false, Color(1, 1, 1, 0.85))
				_draw_label(c, db.station_name(st.type).to_upper(), Vector2(rect.position.x, rect.end.y - 2), rect.size.x, 13)
	# Bin.
	if _bin_rect.has_area():
		var bin := Art.equipment("trash")
		if bin:
			c.draw_texture_rect(bin, _square(_bin_rect, 0.85), false)
		_draw_label(c, "BIN", Vector2(_bin_rect.position.x, _bin_rect.end.y - 2), _bin_rect.size.x, 16)


func _draw_dynamic() -> void:
	var c := _dynamic
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	var glow := Color(1.0, 0.25, 0.75, 0.3 + 0.35 * pulse)  # hot magenta: things that need you
	var targets := _valid_targets()
	for index in targets.stations:
		c.draw_rect(_spots[index].rect.grow(2), glow, false, 8.0)
	if targets.bin:
		c.draw_rect(_bin_rect.grow(2), glow, false, 6.0)
	for mate in _mates:
		if targets.mates.has(mate.player):
			c.draw_rect(mate.rect.grow(4), glow, false, 10.0)
		_draw_mate(c, mate)
	# Station timers and progress.
	for st in kitchen.players[_me].stations:
		if st.recipe.is_empty() and not st.burnt:
			continue
		_draw_station_timer(c, st, _spots[st.index], pulse)
	_draw_hint(c, pulse)
	# Pause button.
	c.draw_rect(_pause_rect, Art.PAPER)
	c.draw_rect(_pause_rect, Art.INK, false, 4.0)
	c.draw_rect(Rect2(_pause_rect.position + Vector2(15, 12), Vector2(8, 30)), Art.INK)
	c.draw_rect(Rect2(_pause_rect.position + Vector2(31, 12), Vector2(8, 30)), Art.INK)
	if shift.in_prologue() and _start_timer <= 0.0:
		_draw_prologue_banner(c)


func _draw_station_timer(c: CanvasItem, st: KitchenState.Station, spot: Dictionary, pulse: float) -> void:
	var center: Vector2 = spot.center + Vector2(0, -6)
	var radius: float = 46.0 * spot.scale
	var fraction := 0.0
	var color := Color.WHITE
	var label := ""
	if st.burnt:
		for i in 3:
			c.draw_circle(center + Vector2(-14 + i * 14, -radius - fmod(_time * 30.0 + i * 12.0, 30.0)), 9.0, Color(0.3, 0.3, 0.3, 0.6))
		label = "BIN IT!"
		color = Color("#555")
		fraction = 1.0
	elif not db.is_cook_recipe(st.recipe):
		fraction = st.progress / float(st.recipe.work)
		color = Art.SKY
		label = "TAP TO %s!" % str(st.recipe.action).to_upper() if st.progress <= 0.0 else "TAP TO GO ON!"
	elif not st.done:
		fraction = st.progress / float(st.recipe.cook_time)
	elif st.since_ready <= float(st.recipe.perfect_window):
		color = Art.LEAF.lerp(Color.WHITE, pulse * 0.4)
		label = "TAKE IT!"
		fraction = 1.0
	else:
		color = Color("#ff3fa4").lerp(Art.TOMATO, pulse)
		label = "HURRY!"
		var burn := float(st.recipe.burn_time)
		fraction = 1.0 - st.since_ready / burn if burn > 0.0 else 1.0
	c.draw_arc(center, radius, 0, TAU, 40, Color(Art.INK, 0.5), 9.0, true)
	c.draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * clampf(fraction, 0.0, 1.0), 40, color, 7.0, true)
	if not label.is_empty():
		_draw_label(c, label, center + Vector2(-80, -radius - 8), 160, 16, Color.WHITE, true)


func _draw_mate(c: CanvasItem, mate: Dictionary) -> void:
	var rect: Rect2 = mate.rect
	var player: int = mate.player
	var friend := Net.profile_of(player)
	var color: Color = Art.PLAYER_COLORS[player % Art.PLAYER_COLORS.size()]
	c.draw_rect(rect, color.lightened(0.6))
	c.draw_rect(rect, Art.INK, false, 4.0)
	var free := kitchen.players[player].free_counter_count(db)
	var portrait := minf(rect.size.y * 0.8, 90.0)
	ChefLook.draw(c, rect.position + Vector2(portrait * 0.55, rect.size.y * 0.45), portrait, friend.look, 1.0 if free > 0 else 0.2)
	var x := portrait * 1.1 + 8.0
	var font := Art.comic_font()
	c.draw_string(font, rect.position + Vector2(x, 30), str(friend.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - x - 6, 22, Art.INK)
	c.draw_string(Art.ui_font(), rect.position + Vector2(x, 52), kitchen.players[player].role, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - x - 6, 14, Art.INK)
	c.draw_string(Art.ui_font(), rect.position + Vector2(x, 74), "%d free spots" % free if free > 0 else "FULL!", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - x - 6, 14,
		Art.INK if free > 0 else Art.TOMATO)


func _draw_hint(c: CanvasItem, pulse: float) -> void:
	if _hint_text.is_empty():
		return
	var hot := Color("#ff3fa4")
	for point in _hint_points:
		c.draw_arc(point, 50.0 + pulse * 8.0, 0, TAU, 40, Color(hot, 0.9), 6.0, true)
	if _hint_points.size() == 2:
		var a := _hint_points[0]
		var b := _hint_points[1]
		var dir := (b - a).normalized()
		var tip := b - dir * 58.0
		var start := a + dir * 58.0
		c.draw_line(start, tip, hot, 8.0, true)
		c.draw_colored_polygon(PackedVector2Array([tip + dir * 18.0, tip + dir.orthogonal() * 14.0, tip - dir.orthogonal() * 14.0]), hot)
	# A caption box near the step, like a comic narrator box.
	var font := Art.ui_font()
	var text := _hint_text
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 32.0
	var anchor: Vector2 = _hint_points.back() if not _hint_points.is_empty() else size * 0.5
	var pos := Vector2(clampf(anchor.x - width * 0.5, 8.0, size.x - width - 8.0), clampf(anchor.y + 62.0, TOP_BAR_H + 8.0, size.y - 52.0))
	var rect := Rect2(pos, Vector2(width, 40))
	c.draw_rect(rect.grow(3), Art.INK)
	c.draw_rect(rect, Art.SUN)
	c.draw_string(font, rect.position + Vector2(16, 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.INK)


func _draw_prologue_banner(c: CanvasItem) -> void:
	var dish := shift.prologue[0] if not shift.prologue.is_empty() else ""
	var text := "LEARNING: %s · the clock waits" % db.item_name(dish).to_upper()
	var font := Art.comic_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40.0
	var rect := Rect2(Vector2((size.x - width) * 0.5, TOP_BAR_H + 10), Vector2(width, 44))
	c.draw_rect(rect.grow(3), Art.INK)
	c.draw_rect(rect, Art.SUN)
	c.draw_string(font, rect.position + Vector2(20, 32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Art.INK)
	c.draw_rect(_skip_rect.grow(3), Art.INK)
	c.draw_rect(_skip_rect, Art.PAPER)
	c.draw_string(font, Vector2(_skip_rect.position.x, _skip_rect.get_center().y + 11), "SKIP ▶▶", HORIZONTAL_ALIGNMENT_CENTER, _skip_rect.size.x, 30, Art.INK)


func _draw_overlay() -> void:
	var c := _overlay
	if _dragging and _press.get("kind", "") == "station":
		var hint := _hit(get_local_mouse_position())
		if hint.get("kind", "") in ["station", "bin", "mate"]:
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


func _draw_caption(c: CanvasItem, pos: Vector2, text: String) -> void:
	var font := Art.comic_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 18.0
	var rect := Rect2(pos, Vector2(width, 26))
	c.draw_rect(rect, Art.SUN)
	c.draw_rect(rect, Art.INK, false, 3.0)
	c.draw_string(font, rect.position + Vector2(9, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.INK)


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


static func _square(rect: Rect2, fraction: float, max_side: float = INF) -> Rect2:
	var side := minf(minf(rect.size.x, rect.size.y) * fraction, max_side)
	return Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
