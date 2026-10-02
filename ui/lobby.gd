extends Control
## "Play with a friend": host a kitchen on this phone or join one on the same
## Wi-Fi. Once both chefs are in, the host picks a story level or arcade.

enum Page { CHOOSE, HOSTING, HOST_READY, JOIN, CONNECTING, CLIENT_READY }

const PLAYERS := 2

var page := Page.CHOOSE
var _content: VBoxContainer
var _status: Label
var _games_box: VBoxContainer
var _ip_edit: LineEdit
var _shown_games := ""
var _connecting_to := ""


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	var back := UiStyle.button("◀ BACK", Art.PAPER, 26)
	back.pressed.connect(_on_back)
	header.add_child(back)
	var title := UiStyle.title("PLAY WITH A FRIEND", 56, Art.SUN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_child(header)
	root.add_child(margin)
	_status = UiStyle.title("", 26, Color.WHITE)
	root.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	center.add_child(_content)

	Net.peer_joined.connect(_on_peer_joined)
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)

	if Net.is_host() and not Net.client_peers.is_empty():
		_show(Page.HOST_READY)
	elif Net.is_client():
		_show(Page.CLIENT_READY)
	else:
		_show(Page.CHOOSE)


func _show(new_page: Page) -> void:
	page = new_page
	for child in _content.get_children():
		child.queue_free()
	_shown_games = ""
	_games_box = null
	_status.text = Game.lobby_message
	_status.add_theme_color_override("font_color", Art.SUN if Game.lobby_message.is_empty() else Color("#ffd1e8"))
	Game.lobby_message = ""
	match page:
		Page.CHOOSE:
			Net.stop_discovery()
			_add_text("Both phones must be on the same Wi-Fi.\nOne phone hosts the kitchen, the other joins it.", 24)
			_add_button("HOST A KITCHEN", Art.SUN, 40, _on_host)
			_add_button("JOIN A KITCHEN", Color("#7fc8f8"), 40, func(): _show(Page.JOIN))
		Page.HOSTING:
			_add_title("WAITING FOR A FRIEND...", 44)
			_add_text("On the other phone: Play with a friend → Join a kitchen.\nYour kitchen should appear there by itself.", 22)
			var addresses := Net.local_addresses()
			if not addresses.is_empty():
				_add_text("If it doesn't, type this address on the other phone:", 20)
				_add_title("  ·  ".join(addresses), 40, Color.WHITE)
			_add_button("CANCEL", Art.PAPER, 26, func():
				Net.leave()
				_show(Page.CHOOSE))
		Page.HOST_READY:
			_add_title("%s HAS JOINED!" % str(Net.profile_of(1).name).to_upper(), 44)
			_add_text("Pick what to cook together:", 22)
			for i in Game.progression.regions.size():
				if Game.progression.is_region_unlocked(i):
					_add_title(str(Game.progression.regions[i].name).to_upper(), 30, Color.WHITE)
					_content.add_child(_level_row(Game.progression.regions[i]))
			_add_title("ARCADE", 30, Color.WHITE)
			var arcade_row := HBoxContainer.new()
			arcade_row.alignment = BoxContainer.ALIGNMENT_CENTER
			arcade_row.add_theme_constant_override("separation", 12)
			for pack in Game.progression.unlocked_arcade_packs():
				var level_id := Game.arcade_level_id(pack)
				var button := UiStyle.button("%s · BEST %d" % [Game.cuisine_name(pack).to_upper(), Game.best_arcade_score(level_id, PLAYERS)], Color("#7fc8f8"), 24)
				button.name = "Arcade_" + pack
				button.pressed.connect(func(): Game.start_level(level_id, PLAYERS))
				arcade_row.add_child(button)
			_content.add_child(arcade_row)
		Page.JOIN:
			Net.start_discovery()
			_add_title("KITCHENS NEARBY", 40)
			_games_box = VBoxContainer.new()
			_games_box.add_theme_constant_override("separation", 10)
			_content.add_child(_games_box)
			_refresh_games()
			_add_text("Not listed? Type the address shown on the host's phone:", 20)
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 12)
			_ip_edit = UiStyle.line_edit("192.168.1.23", 28)
			_ip_edit.custom_minimum_size = Vector2(300, 56)
			_ip_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
			row.add_child(_ip_edit)
			var join := UiStyle.button("JOIN", Art.SUN, 30)
			join.pressed.connect(func(): _join(_ip_edit.text))
			row.add_child(join)
			_content.add_child(row)
		Page.CONNECTING:
			_add_title("CONNECTING TO %s..." % _connecting_to, 40)
			_add_button("CANCEL", Art.PAPER, 26, func():
				Net.leave()
				_show(Page.JOIN))
		Page.CLIENT_READY:
			Net.stop_discovery()
			_add_title("YOU'RE IN %s'S KITCHEN!" % str(Net.profile_of(0).name).to_upper(), 44)
			_add_text("Waiting for the host to pick a level...", 24)


func _process(_delta: float) -> void:
	if page == Page.JOIN and _games_box:
		_refresh_games()
	queue_redraw()


func _refresh_games() -> void:
	var key := JSON.stringify(Net.found_games.keys())
	if key == _shown_games:
		return
	_shown_games = key
	for child in _games_box.get_children():
		child.queue_free()
	if Net.found_games.is_empty():
		_games_box.add_child(UiStyle.text("Looking for kitchens on this Wi-Fi...", 22, Color.WHITE))
		return
	for id in Net.found_games:
		var game: Dictionary = Net.found_games[id]
		var address: String = game.address
		var label := "%s  (%s)" % [str(game.name).to_upper(), address]
		if game.version != Net.version():
			label += "  · v%s" % game.version
		var button := UiStyle.button(label, Art.SUN, 28)
		button.pressed.connect(func(): _join(address))
		var box := CenterContainer.new()
		box.add_child(button)
		_games_box.add_child(box)


func _level_row(region: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for id in region.levels.map(func(entry): return entry.id):
		var level: LevelDef = Game.levels[id]
		var unlocked := Game.progression.is_level_unlocked(id)
		var stars := int(Game.progression.best_stars.get(id, 0))
		var text := "%s\n%s" % [level.name.to_upper(), "★".repeat(stars) + "☆".repeat(3 - stars) if unlocked else "LOCKED"]
		var button := UiStyle.button(text, Art.PAPER if unlocked else Color("#b9b2a4"), 20)
		button.custom_minimum_size = Vector2(170, 90)
		button.disabled = not unlocked
		button.icon = Art.item(level.dish_ids()[0])
		button.expand_icon = true
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(170, 150)
		button.pressed.connect(func(): Game.start_level(id, PLAYERS))
		button.name = "Level_" + id
		row.add_child(button)
	return row


func _on_host() -> void:
	var err := Net.host_game()
	if err != OK:
		Game.lobby_message = "Couldn't open a kitchen on this phone (error %d)." % err
		_show(Page.CHOOSE)
		return
	_show(Page.HOSTING)


func _join(address: String) -> void:
	address = address.strip_edges()
	if not address.is_valid_ip_address():
		Game.lobby_message = "That doesn't look like an address (like 192.168.1.23)."
		_show(Page.JOIN)
		return
	_connecting_to = address
	if Net.join_game(address) != OK:
		Game.lobby_message = "Couldn't start connecting."
		_show(Page.JOIN)
		return
	Net.stop_discovery()
	_show(Page.CONNECTING)


func _on_peer_joined(_peer_id: int) -> void:
	_show(Page.HOST_READY)


func _on_joined(_player: int) -> void:
	_show(Page.CLIENT_READY)


func _on_join_failed(reason: String) -> void:
	Game.lobby_message = reason
	_show(Page.JOIN)


func _on_back() -> void:
	Game.leave_to_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _add_title(text: String, font_size: int, color: Color = Art.SUN) -> Label:
	var label := UiStyle.title(text, font_size, color)
	_content.add_child(label)
	return label


func _add_text(text: String, font_size: int) -> Label:
	var label := UiStyle.text(text, font_size, Color.WHITE)
	label.custom_minimum_size = Vector2(900, 0)
	_content.add_child(label)
	return label


func _add_button(text: String, color: Color, font_size: int, action: Callable) -> Button:
	var button := UiStyle.button(text, color, font_size)
	button.pressed.connect(action)
	var box := CenterContainer.new()
	box.add_child(button)
	_content.add_child(box)
	return button


func _draw() -> void:
	UiStyle.draw_halftone(self, Rect2(Vector2.ZERO, size), Color("#3f8fe0"), Color("#5aa2ea"), 22.0)
