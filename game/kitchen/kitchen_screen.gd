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
## Each panel is a window into a 3D comic kitchen (KitchenStage): its own
## camera looking at its own set. Taps and drags are matched against where
## the stations show up on screen; timers, tips and speech balloons are drawn
## over the panels in 2D. Food moving to another panel flies over the
## gutter, across the page.

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
const PANEL_RIVAL := "rival"
const PANEL_TITLES := {PANEL_PANTRY: "PANTRY", PANEL_PREP: "PREP", PANEL_STOVE: "STOVE", PANEL_PASS: "PASS",
	PANEL_TEAM: "TEAM · THROW HERE", PANEL_RIVAL: "THE RIVAL"}
const PANEL_COLORS := {PANEL_PANTRY: Color("#efe2c8"), PANEL_PREP: Color("#f4e6cc"), PANEL_STOVE: Color("#f0dcc8"),
	PANEL_PASS: Color("#dfe9ee"), PANEL_TEAM: Color("#e8def2"), PANEL_RIVAL: Color("#f2d8e6")}
const FLY_SECONDS := 0.28
## What a teammate's chef does (in the team panel) when they act.
const MATE_ANIMATIONS := {"item_added": "pick-up", "item_moved": "interact-right", "item_worked": "interact-right",
	"item_processed": "emote-yes", "item_served": "pick-up"}

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
var _stage: KitchenStage
var _world: World3D
var _stage_holder: SubViewport
var _views: Array[Dictionary] = []  # one per panel: {container, viewport, camera}
var _views_layer: Control
var _fx_layer: Node2D
var _order_bar: OrderBar
var _minigame: Minigame
var _overlay: Control
var _ghost: Sprite2D

var _popped := {}  # "s<index>" / "i<uid>" / "c<crate>" -> true: highlighted right now

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
var _drag_uid := 0
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
# Overlays a tap puts away (so they don't hide the cooking): the tip until
# the next step, the prologue banner for the rest of the prologue, and each
# customer's balloon.
var _hint_rect := Rect2()
var _hint_dismissed := ""
var _banner_rect := Rect2()
var _banner_hidden := false
var _balloon_rects := {}  # order uid -> Rect2
var _dismissed_balloons := {}  # order uid -> true
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
	# The 3D kitchen: one world, held by an invisible viewport; every panel
	# gets its own viewport with a camera into that world.
	_world = World3D.new()
	_stage_holder = SubViewport.new()
	_stage_holder.size = Vector2i(2, 2)
	_stage_holder.world_3d = _world
	_stage_holder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_stage_holder)
	_stage = KitchenStage.new()
	_stage.setup(db, kitchen, _me)
	_stage_holder.add_child(_stage)
	_views_layer = _layer_control()
	_dynamic = _layer_control()
	_dynamic.draw.connect(_draw_dynamic)
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
	if shift.level.type == LevelDef.TYPE_COMPETITION:
		kinds.append(PANEL_RIVAL)
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
	if w < 10.0 or h < 10.0:
		return
	var pk := kitchen.players[_me]
	_order_bar.position = Vector2.ZERO
	_order_bar.size = Vector2(w, TOP_BAR_H)

	var page := Rect2(MARGIN, TOP_BAR_H + MARGIN, w - MARGIN * 2.0, h - TOP_BAR_H - MARGIN * 2.0)
	# Which panel each station is in.
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

	# The panels: the layout that shows everything biggest for this kitchen
	# (solo, team and competition kitchens come out differently).
	var others: Array[int] = []
	for p in kitchen.players.size():
		if p != _me:
			others.append(p)
	_panels = _stack_team(_plan_panels(page, _panel_kinds(), by_panel), others)

	# Build the 3D sets and a viewport per panel.
	var plan := []
	for panel in _panels:
		var rect: Rect2 = panel.rect
		plan.append({"kind": panel.kind, "stations": by_panel.get(panel.kind, []), "crates": pk.crates,
			"mates": [panel.player] if panel.has("player") else others, "aspect": rect.size.x / maxf(rect.size.y, 1.0)})
	_stage.build(plan)
	for view in _views:
		view.container.queue_free()
	_views.clear()
	for i in _panels.size():
		var rect: Rect2 = _panels[i].rect
		var container := SubViewportContainer.new()
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.position = rect.position
		container.size = rect.size
		var viewport := SubViewport.new()
		viewport.size = Vector2i(rect.size)
		viewport.world_3d = _world
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var camera: Camera3D = _stage.sets[i].camera
		viewport.add_child(camera)
		camera.current = true
		_views_layer.add_child(container)
		_views.append({"container": container, "viewport": viewport, "camera": camera})
		if _panels[i].kind == PANEL_RIVAL:
			# The rival is a 2D status card (see _draw_rival): nothing to render.
			container.visible = false
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	# Where the stations, crates and bin show up on screen (for taps and drags).
	_spots.clear()
	_spots.resize(pk.stations.size())
	for st in pk.stations:
		var set_index := _stage.set_of_station(st.index)
		if set_index < 0:
			continue
		var world := _stage.station_position(st.index)
		var center := _project(set_index, world)
		var reach := absf(_project(set_index, world + Vector3(0.5, 0, 0)).x - center.x)
		var rect := Rect2(center - Vector2(reach, reach * 1.25), Vector2(reach * 2.0, reach * 2.1))
		_spots[st.index] = {"index": st.index, "rect": rect, "center": center, "scale": reach / 60.0}
	_crates.clear()
	var pantry_set := _stage.set_index(PANEL_PANTRY)
	for id in pk.crates:
		var world := _stage.crate_position(id)
		var center := _project(pantry_set, world)
		var reach := absf(_project(pantry_set, world + Vector3(0.38, 0, 0)).x - center.x)
		_crates.append({"id": id, "center": center, "rect": Rect2(center - Vector2(reach, reach * 1.7), Vector2(reach * 2.0, reach * 1.9))})
	var prep_set := _stage.set_index(PANEL_PREP)
	var bin_center := _project(prep_set, _stage.bin_position())
	_bin_rect = Rect2(bin_center - Vector2(46, 56), Vector2(92, 112))

	# Teammates: one panel each, one above the other.
	_mates.clear()
	for panel in _panels:
		if panel.kind == PANEL_TEAM:
			_mates.append({"player": panel.player, "rect": (panel.rect as Rect2).grow(-4)})

	_pause_rect = Rect2(w - 66, TOP_BAR_H + MARGIN + 4, 54, 54)
	_skip_rect = Rect2(w * 0.5 - 90, TOP_BAR_H + 62, 180, 52)
	var mini_size := Vector2(minf(640.0, w - 120.0), minf(420.0, h - TOP_BAR_H - 50.0))
	_minigame.size = mini_size
	_minigame.position = Vector2((w - mini_size.x) * 0.5, TOP_BAR_H + 25)
	_backdrop.queue_redraw()


## Where a point of the 3D kitchen shows up on the page.
func _project(set_index: int, world: Vector3) -> Vector2:
	if set_index < 0 or set_index >= _views.size() or world == Vector3.INF:
		return Vector2(-1000, -1000)
	var camera: Camera3D = _views[set_index].camera
	return _panels[set_index].rect.position + camera.unproject_position(world)


## The team panel becomes a column of panels, one per teammate, one above
## the other (each its own camera), so every teammate is a big throw target.
func _stack_team(panels: Array[Dictionary], others: Array[int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for panel in panels:
		if panel.kind != PANEL_TEAM or others.is_empty():
			result.append(panel)
			continue
		var rect: Rect2 = panel.rect
		var each := (rect.size.y - GUTTER * (others.size() - 1)) / others.size()
		for i in others.size():
			var slot := Rect2(rect.position + Vector2(0, i * (each + GUTTER)), Vector2(rect.size.x, each))
			result.append({"kind": PANEL_TEAM, "rect": slot, "player": others[i]})
	return result


## Tries a few comic-page layouts with a range of panel sizes and keeps the
## one that shows the panels' contents biggest. Every panel's content (a row
## of counters, the pantry shelf, the team) has a natural shape, so the score
## of a layout is how large each content can be drawn in its panel, weighted
## by how much the player taps it.
func _plan_panels(page: Rect2, kinds: Array[String], by_panel: Dictionary) -> Array[Dictionary]:
	var pk := kitchen.players[_me]
	var counts := {
		PANEL_PREP: by_panel.get(PANEL_PREP, []).size() + 1,  # the bin
		PANEL_STOVE: by_panel.get(PANEL_STOVE, []).size(),
		PANEL_PASS: by_panel.get(PANEL_PASS, []).size(),
		PANEL_PANTRY: pk.crates.size(),
		PANEL_TEAM: maxi(kitchen.players.size() - 1, 1),
		PANEL_RIVAL: 1,
	}
	var others: Array[String] = []
	for kind in kinds:
		if kind not in [PANEL_PANTRY, PANEL_PREP]:
			others.append(kind)
	var best: Array[Dictionary] = []
	var best_score := -INF
	var steps := [0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75]
	for template in 5:
		for a in [0.13, 0.16, 0.19, 0.22, 0.26]:
			for b in steps:
				for c in steps:
					var rects := _layout_template(template, page, a, b, c, others)
					if rects.is_empty():
						continue
					var score := _layout_score(rects, counts)
					if score > best_score:
						best_score = score
						best = []
						for kind in kinds:
							if rects.has(kind):
								best.append({"kind": kind, "rect": rects[kind]})
	return best


## The panel rects of one layout, or {} if it doesn't fit these panels.
## a: pantry width, b and c: the template's two other splits (fractions).
func _layout_template(template: int, page: Rect2, a: float, b: float, c: float, others: Array[String]) -> Dictionary:
	var rects := {}
	var g := GUTTER
	var pantry := Rect2(page.position, Vector2(page.size.x * a, page.size.y))
	var rest := Rect2(pantry.end.x + g, page.position.y, page.end.x - pantry.end.x - g, page.size.y)
	match template:
		0:  # pantry | prep and the stove on top, the rest below
			rects[PANEL_PANTRY] = pantry
			var top_kinds: Array[String] = [PANEL_PREP]
			var bottom: Array[String] = []
			for kind in others:
				if kind == PANEL_STOVE:
					top_kinds.append(kind)
				else:
					bottom.append(kind)
			var split := b if not bottom.is_empty() else 1.0
			_split_row(rects, top_kinds, _top(rest, split, g), [c])
			_split_row(rects, bottom, _bottom(rest, split, g), [])
		1:  # pantry | prep, full height | everything else stacked
			rects[PANEL_PANTRY] = pantry
			if others.is_empty():
				return {}
			var prep := Rect2(rest.position, Vector2(rest.size.x * b, rest.size.y))
			rects[PANEL_PREP] = prep
			var column := Rect2(prep.end.x + g, rest.position.y, rest.end.x - prep.end.x - g, rest.size.y)
			_split_column(rects, others, column, [c])
		2:  # pantry | prep across the top, everything else in a row below
			rects[PANEL_PANTRY] = pantry
			if others.is_empty():
				return {}
			rects[PANEL_PREP] = _top(rest, b, g)
			_split_row(rects, others, _bottom(rest, b, g), [c])
		3:  # one row of tall panels
			rects[PANEL_PANTRY] = pantry
			var row: Array[String] = [PANEL_PREP]
			row.append_array(others)
			_split_row(rects, row, rest, [b, c])
		4:  # pantry over the pass on the left | prep on top, the rest below
			if not others.has(PANEL_PASS):
				return {}
			var left := Rect2(page.position, Vector2(page.size.x * (a + 0.1), page.size.y))
			rects[PANEL_PANTRY] = _top(left, b, g)
			rects[PANEL_PASS] = _bottom(left, b, g)
			var right := Rect2(left.end.x + g, page.position.y, page.end.x - left.end.x - g, page.size.y)
			var rest_kinds: Array[String] = []
			for kind in others:
				if kind != PANEL_PASS:
					rest_kinds.append(kind)
			if rest_kinds.is_empty():
				rects[PANEL_PREP] = right
			else:
				rects[PANEL_PREP] = _top(right, c, g)
				_split_row(rects, rest_kinds, _bottom(right, c, g), [])
	for kind in rects:
		var rect: Rect2 = rects[kind]
		if rect.size.x < 110.0 or rect.size.y < 110.0:
			return {}
	return rects


## How well a layout shows its panels: the log of each content's drawn size,
## weighted by how much the player uses the panel.
func _layout_score(rects: Dictionary, counts: Dictionary) -> float:
	# Prep is tapped the most. Teammates and the rival only need to be seen,
	# so they stop gaining once they're comfortably big (CAPS, pixels per
	# world unit); the pantry and the counters can always use more.
	const WEIGHTS := {PANEL_PREP: 1.5, PANEL_STOVE: 1.0, PANEL_PASS: 0.8, PANEL_PANTRY: 0.8, PANEL_TEAM: 0.4, PANEL_RIVAL: 0.25}
	const CAPS := {PANEL_TEAM: 120.0, PANEL_RIVAL: 70.0, PANEL_PANTRY: 190.0, PANEL_PREP: 200.0, PANEL_STOVE: 170.0, PANEL_PASS: 170.0}
	var score := 0.0
	for kind in rects:
		var rect: Rect2 = rects[kind]
		var aspect := rect.size.x / rect.size.y
		var n: int = counts.get(kind, 1)
		var extent: Vector2
		match kind:
			PANEL_PANTRY:
				extent = KitchenStage.pantry_extent(n, aspect)
			PANEL_TEAM:
				extent = Vector2(1.6, n * 1.8)  # the teammates stand one above the other
			PANEL_RIVAL:
				extent = Vector2(2.4, 1.6)  # a small status card
			_:
				var with_window: bool = kind == PANEL_PASS
				extent = KitchenStage.counter_extent(n, KitchenStage.best_rows(n, aspect, with_window), with_window)
		var fit := minf(minf(rect.size.x / extent.x, rect.size.y / extent.y), float(CAPS.get(kind, 400.0)))
		score += float(WEIGHTS.get(kind, 0.5)) * log(fit)
	return score


func _top(rect: Rect2, share: float, gutter: float) -> Rect2:
	return Rect2(rect.position, Vector2(rect.size.x, (rect.size.y - gutter) * share))


func _bottom(rect: Rect2, share: float, gutter: float) -> Rect2:
	var top := (rect.size.y - gutter) * share
	return Rect2(rect.position + Vector2(0, top + gutter), Vector2(rect.size.x, rect.size.y - top - gutter))


## Splits a rect into a row of panels. shares: the first panels' shares of
## the width (the rest share what's left equally).
func _split_row(rects: Dictionary, kinds: Array[String], rect: Rect2, shares: Array) -> void:
	if kinds.is_empty():
		return
	var total := rect.size.x - GUTTER * (kinds.size() - 1)
	var widths := _shares(kinds.size(), shares)
	var x := rect.position.x
	for i in kinds.size():
		var width: float = total * widths[i] if i < kinds.size() - 1 else rect.end.x - x
		rects[kinds[i]] = Rect2(x, rect.position.y, width, rect.size.y)
		x += width + GUTTER


func _split_column(rects: Dictionary, kinds: Array[String], rect: Rect2, shares: Array) -> void:
	if kinds.is_empty():
		return
	var total := rect.size.y - GUTTER * (kinds.size() - 1)
	var heights := _shares(kinds.size(), shares)
	var y := rect.position.y
	for i in kinds.size():
		var height: float = total * heights[i] if i < kinds.size() - 1 else rect.end.y - y
		rects[kinds[i]] = Rect2(rect.position.x, y, rect.size.x, height)
		y += height + GUTTER


## count shares: the given ones first (as long as they leave room), the rest
## split what's left equally.
func _shares(count: int, given: Array) -> Array[float]:
	var result: Array[float] = []
	var used := 0.0
	for i in count:
		if i < given.size() and i < count - 1 and used + float(given[i]) < 0.95:
			result.append(float(given[i]))
			used += float(given[i])
		else:
			var left := count - i
			for j in left:
				result.append((1.0 - used) / left)
			break
	return result


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
	_sync_stage(delta)
	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint_timer = 0.25
		_update_hint()
	_dynamic.queue_redraw()
	_overlay.queue_redraw()


func _sync_stage(delta: float) -> void:
	_stage.sync(delta)
	for jump in _stage.jumps:
		var item := _find_item(int(jump.uid))
		var texture := Art.item(kitchen.effective_id(item) if item else "")
		_fly(texture, _project(jump.from_set, jump.from), _project(jump.to_set, jump.to))
	_stage.jumps.clear()
	var pass_index := kitchen.players[_me].pass_station(db)
	if pass_index >= 0:
		_stage.sync_customers(shift.orders.orders, pass_index, delta)
	_update_pops()


## Highlights ("pop") what needs the player: where the selected food can go,
## boards and bowls ready to work, food that is done or about to burn.
func _update_pops() -> void:
	var wanted := {}
	var targets := _valid_targets()
	for index in targets.stations:
		wanted["s%d" % index] = 1.0
	for st in kitchen.players[_me].stations:
		if st.recipe.is_empty() and not st.burnt:
			continue
		if st.burnt or (db.station_kind(st.type) == ContentDB.STATION_MANUAL) or st.done:
			wanted["s%d" % st.index] = 0.8
			if st.item():
				wanted["i%d" % st.item().uid] = 0.8
	var selected := kitchen.item_at(_me, _selected) if _selected >= 0 else null
	if selected:
		wanted["i%d" % selected.uid] = 1.0
	for key in _popped.keys():
		if not wanted.has(key):
			_set_pop(key, 0.0)
	for key in wanted:
		_set_pop(key, wanted[key])
	_popped = wanted


func _set_pop(key: String, amount: float) -> void:
	var id := key.substr(1)
	match key[0]:
		"s":
			_stage.pop_station(int(id), amount)
		"i":
			_stage.pop_item(int(id), amount)
		"c":
			_stage.pop_crate(id, amount)


func _find_item(uid: int) -> KitchenItem:
	for st in kitchen.players[_me].stations:
		for item in st.contents:
			if item.uid == uid:
				return item
	return null


## A picture of the food flies over the page, across the panel gutters.
func _fly(texture: Texture2D, from: Vector2, to: Vector2, seconds: float = FLY_SECONDS) -> void:
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = from
	sprite.scale = Vector2(0.45, 0.45)
	sprite.z_index = 50
	_fx_layer.add_child(sprite)
	var tween := sprite.create_tween()
	var lift := Vector2(0, -minf(from.distance_to(to) * 0.35, 160.0))
	tween.tween_method(func(t: float):
		sprite.position = from.lerp(to, t) + lift * sin(t * PI)
		sprite.rotation = sin(t * PI) * 0.4, 0.0, 1.0, seconds)
	tween.tween_callback(sprite.queue_free)


# --- Events from the game rules ----------------------------------------------

func _handle_events(events: Array[Dictionary]) -> void:
	for event in events:
		if event.type == "item_thrown":
			_on_item_thrown(event)
			continue
		# Other chefs' kitchens aren't on this screen, but their chefs are.
		if int(event.get("player", _me)) != _me:
			if event.type in MATE_ANIMATIONS:
				_stage.mate_act(int(event.player), MATE_ANIMATIONS[event.type])
			continue
		match event.type:
			"item_added":
				var crate := _crate_rect(str(event.item.get("type", "")))
				if crate.has_area() and event.item.has("uid"):
					_stage.hide_item(int(event.item.uid), FLY_SECONDS)
					_fly(Art.item(str(event.item.type)), crate.get_center(), station_center(event.station))
				_stage.chef_act(event.station, "interact-left")
				Sfx.play("pop")
			"item_moved":
				_stage.chef_act(event.to, "interact-right")
				if event.get("combined", false):
					Sfx.play("thud")
					_bubble(station_center(event.to) + Vector2(0, -70), _pick(["SPLAT!", "PLOP!", "TA-DA!"]), Color.WHITE, 30)
				else:
					Sfx.play("pop", 0.2)
				if event.item.get("perfect", false) and not event.get("combined", false):
					_bubble(station_center(event.to) + Vector2(0, -80), "PERFECT!", Art.SUN, 36)
			"item_worked":
				_stage.chef_act(event.station, "interact-right")
			"item_processed":
				_stage.chef_act(event.station, "interact-right")
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
				_stage.set_item_visible(int(event.item.uid), false)
				_fly(_item_texture(event.item), station_center(event.station), _pass_center())
				_stage.chef_act(event.station, "interact-left")
				Sfx.play("bell", 0.0)
			"order_served":
				_stage.customer_leaves(int(event.order.uid), true)
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
					_stage.set_item_visible(int(item.uid), false)
					_fly(_item_texture(item), station_center(event.station), _bin_rect.get_center())
				Sfx.play("thud")
			"order_added":
				Sfx.play("pop", 0.2)
			"order_lost":
				_stage.customer_leaves(int(event.order.uid), false)
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
			"rival_dish_started":
				_stage.rival_act("interact-right")
			"rival_dish_done":
				_stage.rival_act("emote-yes")
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
	var texture := _item_texture(event.item)
	if event.player == _me:
		_stage.set_item_visible(uid, false)
		_fly(texture, station_center(event.station), mate_center(event.target))
		_stage.chef_act(event.station, "attack-melee-right")
		Sfx.play("whoosh")
		_bubble(mate_center(event.target) + Vector2(-40, -70), "WHOOSH!", Color.WHITE, 34)
	elif event.target == _me:
		_stage.hide_item(uid, FLY_SECONDS)
		_fly(texture, mate_center(event.player), station_center(event.target_station))
		_stage.mate_act(int(event.player), "attack-melee-right")
		Sfx.play("thud")
		Game.vibrate(40)
		_bubble(station_center(event.target_station) + Vector2(0, -80), _pick(["THWACK!", "CATCH!", "PLOP!"]), Art.SUN, 36)
	else:
		_stage.mate_act(int(event.player), "attack-melee-right")


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


func _item_texture(item_data: Dictionary) -> Texture2D:
	var id := db.effective_id(str(item_data.get("type", "")), item_data.get("contents", []))
	return Art.item(id if not id.is_empty() else str(item_data.get("type", "")))


# --- Input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var pos: Vector2 = event.position if "position" in event else Vector2.ZERO
	if _session.paused:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_pause_menu_click(pos)
		return
	if _minigame.visible:
		# The splash panel is tilted: work in its own (rotated) coordinates.
		var local := _minigame.get_transform().affine_inverse() * pos
		var outside_tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not Rect2(Vector2.ZERO, _minigame.size).has_point(local)
		if not outside_tap:
			_minigame.handle_input(event, local)
			return
		# Tapping the kitchen pauses the work; the tap then does its usual job.
		_minigame.pause()
	if shift.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _dismiss_overlay(pos) or _order_bar.tap(pos):
				_press = {}
				return
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
			_ghost.position = pos


func _start_drag() -> void:
	_dragging = true
	match _press.kind:
		"station":
			var item := kitchen.item_at(_me, _press.index)
			if item and kitchen.can_take(kitchen.station(_me, _press.index)):
				_drag_uid = item.uid
				_stage.set_item_visible(item.uid, false)
				_show_ghost(Art.item(kitchen.effective_id(item) if not kitchen.effective_id(item).is_empty() else item.type))
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
	if _drag_uid:
		_stage.set_item_visible(_drag_uid, true)
		_drag_uid = 0
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
	var view := _minigame.view_rect()
	var camera := _stage.closeup_camera(index, view.size.x / maxf(view.size.y, 1.0))
	var verb: String = RecipeText.VERBS.get(st.recipe.action, str(st.recipe.action).capitalize())
	var what := db.item_name(st.contents[0].type) if st.contents.size() == 1 else db.item_name(st.recipe.output)
	_minigame.open(st.recipe.action, st.recipe.work, st.progress, shown, Art.equipment(st.type), camera, _world,
		"%s the %s" % [verb, what])
	_stage.chef_act(index, "interact-right")


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
	_bubble(_minigame.get_transform() * Vector2(_rng.randf_range(80, _minigame.size.x - 80), _rng.randf_range(130, _minigame.size.y - 110)), _pick(words), Color.WHITE, 32)
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
	_find_hint()
	if not _hint_text.is_empty() and _hint_text == _hint_dismissed:
		_hint_text = ""
		_hint_points.clear()


## Tapping a tip, the prologue banner or a customer's balloon puts it away;
## that tap does nothing else. Returns true if the tap hit one.
func _dismiss_overlay(pos: Vector2) -> bool:
	if not _hint_text.is_empty() and _hint_rect.has_point(pos):
		_hint_dismissed = _hint_text
		_hint_text = ""
		_hint_points.clear()
		return true
	if shift.in_prologue() and not _banner_hidden and _banner_rect.has_point(pos):
		_banner_hidden = true
		return true
	for uid in _balloon_rects:
		if (_balloon_rects[uid] as Rect2).has_point(pos):
			_dismissed_balloons[uid] = true
			_balloon_rects.erase(uid)
			return true
	return false


func _find_hint() -> void:
	_hint_text = ""
	_hint_points.clear()
	if _start_timer > 0.0 or shift.finished or _minigame.visible or not shift.in_prologue():
		return
	var plan := _hint_bot.plan(shift)
	for action in plan:
		if action.player == _me:
			_describe(action)
			return
	if shift.orders.orders.is_empty():
		return
	# Nothing for you to do: something of yours is cooking, or (with
	# friends) it's someone else's turn.
	for st in kitchen.players[_me].stations:
		if db.is_cook_recipe(st.recipe) and not st.done and not st.burnt and st.item():
			_hint_text = "The %s is cooking in the %s. Take it out when the ring turns green!" % [_item_name(st.item()),
				db.station_name(st.type).to_upper()]
			_hint_points = [station_center(st.index)]
			return
	if kitchen.players.size() == 1:
		_hint_text = "Wait a moment..."
		return
	for action in plan:
		if action.type == "throw" and action.target == _me:
			_hint_text = "%s is throwing you the %s" % [_mate_name(action.player), _item_name(kitchen.item_at(action.player, action.station))]
			_hint_points = [mate_center(action.player)]
			return
	if not plan.is_empty():
		_hint_text = "Wait for %s..." % _mate_name(plan[0].player)
		_hint_points = [mate_center(plan[0].player)]
	else:
		_hint_text = "Wait for your teammate..."


func _item_name(item: KitchenItem) -> String:
	if item == null:
		return "FOOD"
	var id := kitchen.effective_id(item)
	return db.item_name(id if not id.is_empty() else item.type).to_upper()


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


## What a tap at pos means. A whole panel is a tap target: the tap goes to
## the nearest station, crate or bin in the panel it lands in, and height
## counts less than width, so the whole column above and below a station is
## its target.
func _hit(pos: Vector2) -> Dictionary:
	if _pause_rect.has_point(pos):
		return {"kind": "pause"}
	if shift.in_prologue() and _skip_rect.has_point(pos):
		return {"kind": "skip"}
	for mate in _mates:
		if mate.rect.has_point(pos):
			return {"kind": "mate", "player": mate.player}
	for i in _panels.size():
		if not _panels[i].rect.has_point(pos):
			continue
		var best := {}
		var best_distance := INF
		for spot in _spots:
			if spot is Dictionary and not spot.is_empty() and _stage.set_of_station(spot.index) == i:
				var d := _tap_distance(pos, spot.center)
				if d < best_distance:
					best_distance = d
					best = {"kind": "station", "index": spot.index}
		if _panels[i].kind == PANEL_PREP and _bin_rect.has_area() and _tap_distance(pos, _bin_rect.get_center()) < best_distance:
			best_distance = _tap_distance(pos, _bin_rect.get_center())
			best = {"kind": "bin"}
		if _panels[i].kind == PANEL_PANTRY:
			for crate in _crates:
				var d := _tap_distance(pos, crate.rect.get_center())
				if d < best_distance:
					best_distance = d
					best = {"kind": "crate", "id": crate.id}
		return best
	return {}


func _tap_distance(pos: Vector2, target: Vector2) -> float:
	return Vector2(pos.x - target.x, (pos.y - target.y) * 0.45).length()


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
	# The page between the panels: dark ink with halftone dots. The panels
	# themselves are 3D viewports drawn on top.
	UiStyle.draw_halftone(c, Rect2(0, TOP_BAR_H, size.x, size.y - TOP_BAR_H), Color("#262038"), Color("#2f2846"), 16.0)
	for panel in _panels:
		c.draw_rect(panel.rect, PANEL_COLORS.get(panel.kind, Art.PAPER))


func _draw_dynamic() -> void:
	var c := _dynamic
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	var glow := Color(1.0, 0.25, 0.75, 0.3 + 0.35 * pulse)  # hot magenta: things that need you
	if _panel_rect(PANEL_RIVAL).has_area():
		_draw_rival(c, _panel_rect(PANEL_RIVAL))
	# Panel frames and their caption boxes, over the 3D views.
	for panel in _panels:
		var rect: Rect2 = panel.rect
		c.draw_rect(rect, Art.INK, false, 6.0)
		var title: String = PANEL_TITLES.get(panel.kind, "")
		if panel.kind == PANEL_TEAM:
			title = "TEAM · THROW HERE" if panel.player == _mates[0].player else "THROW HERE"
		_draw_caption(c, rect.position + Vector2(8, 8), title)
	for crate in _crates:
		var rect: Rect2 = crate.rect
		_draw_label(c, db.item_name(crate.id).to_upper(), Vector2(rect.position.x - 10, crate.center.y + 15), rect.size.x + 20, 14, Color.WHITE, true)
	var targets := _valid_targets()
	if targets.bin:
		c.draw_rect(_bin_rect.grow(2), glow, false, 6.0)
	for mate in _mates:
		if targets.mates.has(mate.player):
			c.draw_rect(mate.rect.grow(4), glow, false, 10.0)
		_draw_mate(c, mate)
	_draw_customers(c)
	# Station timers and progress.
	for st in kitchen.players[_me].stations:
		if st.recipe.is_empty() and not st.burnt:
			continue
		if _spots[st.index] is Dictionary and not _spots[st.index].is_empty():
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


## A teammate's name tag under their 3D chef in the team panel.
func _draw_mate(c: CanvasItem, mate: Dictionary) -> void:
	var rect: Rect2 = mate.rect
	var player: int = mate.player
	var friend := Net.profile_of(player)
	var color: Color = Art.PLAYER_COLORS[player % Art.PLAYER_COLORS.size()]
	var free := kitchen.players[player].free_counter_count(db)
	# A small, see-through tag in the corner, so the chef stays in view.
	var font := Art.comic_font()
	var label := "%s · %s" % [str(friend.name).to_upper(), "%d FREE" % free if free > 0 else "FULL!"]
	var width := minf(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0, rect.size.x - 12.0)
	var tag := Rect2(rect.position + Vector2(6, rect.size.y - 30), Vector2(width, 24))
	c.draw_rect(tag, Color(color.lightened(0.55), 0.7))
	c.draw_rect(tag, Color(Art.INK, 0.7), false, 2.0)
	c.draw_string(font, tag.position + Vector2(8, 18), label, HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 12, 16,
		Art.INK if free > 0 else Art.TOMATO)


## Speech balloons over the customers at the window: what they're waiting for.
func _draw_customers(c: CanvasItem) -> void:
	var pass_index := kitchen.players[_me].pass_station(db)
	if pass_index < 0:
		return
	var set_index := _stage.set_of_station(pass_index)
	if set_index < 0:
		return
	var panel: Rect2 = _panels[set_index].rect
	_balloon_rects.clear()
	for order in shift.orders.orders:
		if _dismissed_balloons.has(int(order.uid)):
			continue
		var head := _stage.customer_head(int(order.uid))
		if head == Vector3.INF:
			continue
		var tip := _project(set_index, head)
		if not panel.has_point(tip):
			continue
		var icon := Art.item(str(order.dish))
		# Balloons stay inside the panel, like in a real comic.
		var center := Vector2(tip.x, maxf(tip.y - 34.0, panel.position.y + 32.0))
		if center.y < tip.y - 20.0:
			var points := PackedVector2Array([tip, center + Vector2(-8, 18), center + Vector2(8, 18)])
			c.draw_colored_polygon(points, Art.INK)
		_balloon_rects[int(order.uid)] = Rect2(center - Vector2(30, 30), Vector2(60, 60))
		c.draw_circle(center, 27.0, Art.INK)
		c.draw_circle(center, 24.0, Color.WHITE)
		if icon:
			c.draw_texture_rect(icon, Rect2(center - Vector2(19, 19), Vector2(38, 38)), false)


## The rival is a small status card, not a 3D scene: what they're cooking
## right now, how far along it is, and how many dishes they have done.
func _draw_rival(c: CanvasItem, rect: Rect2) -> void:
	var rival := shift.rival
	if rival == null:
		return
	UiStyle.draw_halftone(c, rect, Color("#c42f5e"), Color("#d4456f"), 12.0)
	var font := Art.comic_font()
	var inner := rect.grow(-12)
	var top := inner.position.y + 50.0
	c.draw_string(font, Vector2(inner.position.x, top), str(rival.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, 22, Color.WHITE)
	var dish := rival.current_dish()
	var icon_size := clampf(inner.size.y - 92.0, 32.0, 72.0)
	var line_y := top + 10.0
	if not dish.is_empty():
		var icon := Art.item(dish)
		if icon:
			c.draw_texture_rect(icon, Rect2(inner.position.x, line_y, icon_size, icon_size), false)
		c.draw_string(Art.ui_font(), Vector2(inner.position.x + icon_size + 8, line_y + icon_size * 0.5 + 6),
			"cooking %s" % db.item_name(dish), HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - icon_size - 8, 15, Color.WHITE)
	else:
		c.draw_string(font, Vector2(inner.position.x, line_y + icon_size * 0.6), "ALL DONE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Comic.YELLOW)
	# The progress bar of the current dish.
	var bar := Rect2(inner.position.x, inner.end.y - 34.0, inner.size.x, 14.0)
	c.draw_rect(bar.grow(3), Art.INK)
	c.draw_rect(bar, Color(1, 1, 1, 0.3))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * rival.dish_fraction(), bar.size.y)), Comic.YELLOW)
	var total := rival.dishes.size()
	c.draw_string(font, Vector2(inner.position.x, inner.end.y), "%d/%d DISHES · %d PTS" % [rival.done_count, total, rival.score],
		HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, 16, Color.WHITE)


func _draw_hint(c: CanvasItem, pulse: float) -> void:
	if _hint_text.is_empty():
		_hint_rect = Rect2()
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
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 52.0
	var anchor: Vector2 = _hint_points.back() if not _hint_points.is_empty() else size * 0.5
	var pos := Vector2(clampf(anchor.x - width * 0.5, 8.0, size.x - width - 8.0), clampf(anchor.y + 62.0, TOP_BAR_H + 8.0, size.y - 52.0))
	var rect := Rect2(pos, Vector2(width, 40))
	_hint_rect = rect.grow(6)
	c.draw_rect(rect.grow(3), Art.INK)
	c.draw_rect(rect, Art.SUN)
	c.draw_string(font, rect.position + Vector2(16, 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.INK)
	# A little X: tapping the tip puts it away until the next step.
	c.draw_string(font, rect.end - Vector2(22, 12), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Art.INK, 0.55))


func _draw_prologue_banner(c: CanvasItem) -> void:
	var dish := shift.prologue[0] if not shift.prologue.is_empty() else ""
	var text := "LEARNING: %s · the clock waits" % db.item_name(dish).to_upper()
	var font := Art.comic_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40.0
	var rect := Rect2(Vector2((size.x - width) * 0.5, TOP_BAR_H + 10), Vector2(width, 44))
	_banner_rect = Rect2() if _banner_hidden else rect.grow(4)
	if not _banner_hidden:
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
