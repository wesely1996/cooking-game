extends Node
## LAN networking (autoload "Net"): hosting or joining a game over ENet,
## a handshake that checks both phones run the same version, and finding
## games on the local network through UDP broadcast "beacons".
##
## All messages are plain Dictionaries (see HostSession) sent as bytes with
## var_to_bytes, which never decodes objects, so a bad packet can't run code.

signal peer_joined(peer_id: int)
signal joined(player: int)
signal join_failed(reason: String)
signal disconnected(reason: String)
signal message_received(peer_id: int, message: Dictionary)

const GAME_PORT := 24568
const DISCOVERY_PORT := 24569
const PROTOCOL := 1
const MAX_CLIENTS := 1  # two-player LAN for now
const BEACON_INTERVAL := 1.0
const GAME_TIMEOUT := 4.0
const GAME_ID := "pass-the-plate"

enum Role { NONE, HOST, CLIENT }

var role := Role.NONE
var local_player := 0
var client_peers: Array[int] = []  # host only: accepted clients
## Every chef in the game: player index -> {"name", "look"} (see ChefLook).
var profiles := {}
## Games announced on the network: game id -> {"address", "name", "version", "seen"}.
var found_games := {}

var _beacon: PacketPeerUDP
var _listener: PacketPeerUDP
var _beacon_timer := 0.0
var _clock := 0.0
var _game_id := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func is_online() -> bool:
	return role != Role.NONE


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


## This phone's chef, as shared with the other phone.
func my_profile() -> Dictionary:
	return {"name": Game.profile.name, "look": ChefLook.sanitize(Game.profile.look)}


## A chef's name and look, e.g. for a teammate's portrait.
func profile_of(player: int) -> Dictionary:
	return profiles.get(player, {"name": "Chef %d" % (player + 1), "look": ChefLook.default_look()})


func device_name() -> String:
	var model := OS.get_model_name()
	return model if model != "GenericDevice" and not model.is_empty() else "%s's kitchen" % OS.get_name()


# --- Hosting and joining -----------------------------------------------------

func host_game() -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	local_player = 0
	profiles = {0: my_profile()}
	_game_id = "%08x" % randi()
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_timer = 0.0
	return OK


func join_game(address: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), GAME_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.NONE
	local_player = 0
	client_peers.clear()
	profiles.clear()
	if _beacon:
		_beacon.close()
		_beacon = null


## Starts listening for games announced on the local network.
func start_discovery() -> void:
	stop_discovery()
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null


func stop_discovery() -> void:
	if _listener:
		_listener.close()
		_listener = null
	found_games.clear()


## The phone's addresses on the local network, for joining by hand.
static func local_addresses() -> Array[String]:
	var result: Array[String] = []
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or _is_172_private(address):
			result.append(address)
	return result


static func _is_172_private(address: String) -> bool:
	var parts := address.split(".")
	return parts.size() == 4 and parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31


# --- Messages ----------------------------------------------------------------

func send(peer_id: int, message: Dictionary) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_receive.rpc_id(peer_id, var_to_bytes(message))


func send_to_host(message: Dictionary) -> void:
	send(1, message)


func send_to_clients(message: Dictionary) -> void:
	for peer_id in client_peers:
		send(peer_id, message)


@rpc("any_peer", "call_remote", "reliable")
func _receive(bytes: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var message: Variant = bytes_to_var(bytes)
	if not message is Dictionary:
		return
	match role:
		Role.HOST:
			if message.get("t", "") == "hello":
				_on_hello(sender, message)
			elif client_peers.has(sender):
				message_received.emit(sender, message)
		Role.CLIENT:
			if sender != 1:
				return
			match str(message.get("t", "")):
				"welcome":
					local_player = int(message.get("player", 1))
					profiles = {0: _clean_profile(message.get("host", {})), local_player: my_profile()}
					joined.emit(local_player)
				"reject":
					var reason := str(message.get("reason", "The host refused the connection."))
					leave()
					join_failed.emit(reason)
				_:
					message_received.emit(sender, message)


func _on_hello(peer_id: int, message: Dictionary) -> void:
	var reason := ""
	if int(message.get("protocol", 0)) != PROTOCOL or str(message.get("version", "")) != version():
		reason = "Different game versions (host %s, you %s). Update both phones." % [version(), message.get("version", "?")]
	elif client_peers.size() >= MAX_CLIENTS:
		reason = "This game is full."
	if not reason.is_empty():
		send(peer_id, {"t": "reject", "reason": reason})
		get_tree().create_timer(0.5).timeout.connect(func():
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				multiplayer.multiplayer_peer.disconnect_peer(peer_id))
		return
	client_peers.append(peer_id)
	var player := client_peers.size()
	profiles[player] = _clean_profile(message.get("profile", {}))
	send(peer_id, {"t": "welcome", "player": player, "host": my_profile()})
	peer_joined.emit(peer_id)


static func _clean_profile(data: Variant) -> Dictionary:
	var profile: Dictionary = data if data is Dictionary else {}
	return {"name": PlayerProfile.clean_name(str(profile.get("name", ""))), "look": ChefLook.sanitize(profile.get("look", {}))}


func _on_peer_connected(peer_id: int) -> void:
	if role == Role.CLIENT and peer_id == 1:
		pass  # handled by connected_to_server


func _on_connected_to_server() -> void:
	send_to_host({"t": "hello", "protocol": PROTOCOL, "version": version(), "name": device_name(), "profile": my_profile()})


func _on_peer_disconnected(peer_id: int) -> void:
	if role == Role.HOST and client_peers.has(peer_id):
		client_peers.erase(peer_id)
		disconnected.emit("Your friend left the kitchen.")


func _on_connection_failed() -> void:
	leave()
	join_failed.emit("Couldn't reach that kitchen. Are both phones on the same Wi-Fi?")


func _on_server_disconnected() -> void:
	leave()
	disconnected.emit("The host closed the kitchen.")


# --- Discovery ---------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if _beacon and role == Role.HOST and client_peers.size() < MAX_CLIENTS:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = BEACON_INTERVAL
			_send_beacon()
	if _listener:
		while _listener.get_available_packet_count() > 0:
			var packet := _listener.get_packet()
			var address := _listener.get_packet_ip()
			var data: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if data is Dictionary and data.get("game", "") == GAME_ID:
				# One game can arrive twice (broadcast and loopback); list it once.
				var id := str(data.get("id", address))
				var known: Dictionary = found_games.get(id, {})
				found_games[id] = {
					"address": known.get("address", address),
					"name": str(data.get("name", address)),
					"version": str(data.get("version", "?")),
					"seen": _clock,
				}
		for id in found_games.keys():
			if _clock - found_games[id].seen > GAME_TIMEOUT:
				found_games.erase(id)


## Whether a game at this address has been found.
func has_found_address(address: String) -> bool:
	return found_games.values().any(func(game): return game.address == address)


func _send_beacon() -> void:
	var packet := JSON.stringify({"game": GAME_ID, "id": _game_id, "name": "%s's kitchen" % Game.profile.name, "version": version(), "port": GAME_PORT}).to_utf8_buffer()
	# The broadcast reaches other phones; loopback lets a second copy of the
	# game on the same computer find it (handy for testing).
	for address in ["255.255.255.255", "127.0.0.1"]:
		_beacon.set_dest_address(address, DISCOVERY_PORT)
		_beacon.put_packet(packet)
