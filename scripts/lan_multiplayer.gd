class_name LanMultiplayer
extends Node

signal rooms_changed
signal status_changed
signal match_started(payload: Dictionary)
signal action_received(payload: Dictionary)
signal turn_state_received(snapshot: Dictionary)
signal match_finished(payload: Dictionary)
signal connection_lost(message: String)

const SIGNATURE := "ELEMENTALS_LAN_ROOM_V1"

var config: Dictionary = {}
var role := "offline"
var status := "Offline"
var room_name := ""
var local_player_name := ""
var remote_player_name := ""
var local_deck: Dictionary = {}
var remote_deck: Dictionary = {}
var remote_peer_id := 0
var match_in_progress := false
var terminal_pending := false
var discovered_rooms: Dictionary = {}
var discovery_listener: PacketPeerUDP
var broadcaster: PacketPeerUDP
var broadcast_elapsed := 0.0

func configure(settings: Dictionary) -> void:
	config = settings.duplicate(true)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(true)

func start_discovery() -> void:
	if role != "offline" or is_instance_valid(discovery_listener): return
	discovery_listener = PacketPeerUDP.new()
	var error := discovery_listener.bind(_discovery_port(), "0.0.0.0")
	if error != OK:
		discovery_listener = null
		status = "LAN discovery unavailable: %s" % error_string(error)
		status_changed.emit()

func refresh_discovery() -> void:
	discovered_rooms.clear()
	rooms_changed.emit()
	if is_instance_valid(discovery_listener): discovery_listener.close()
	discovery_listener = null
	start_discovery()

func host_room(new_room_name: String, player_name: String, deck: Dictionary) -> Error:
	leave_network(false)
	terminal_pending = false
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(_game_port(), 1)
	if error != OK:
		status = "Could not host: %s" % error_string(error)
		status_changed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	role = "host"
	room_name = new_room_name.strip_edges() if not new_room_name.strip_edges().is_empty() else "%s's room" % player_name
	local_player_name = player_name
	local_deck = deck.duplicate(true)
	remote_deck.clear()
	remote_player_name = ""
	remote_peer_id = 0
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address("255.255.255.255", _discovery_port())
	broadcast_elapsed = 999.0
	status = "Room open · waiting for one opponent"
	status_changed.emit()
	return OK

func join_room(address: String, port: int, player_name: String, deck: Dictionary) -> Error:
	leave_network(false)
	terminal_pending = false
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		status = "Could not join: %s" % error_string(error)
		status_changed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	role = "client"
	local_player_name = player_name
	local_deck = deck.duplicate(true)
	remote_peer_id = 1
	status = "Connecting to %s…" % address
	status_changed.emit()
	return OK

func start_hosted_match() -> bool:
	if role != "host" or remote_peer_id <= 0 or remote_deck.is_empty(): return false
	var seed := randi()
	var payload := {"seed":seed, "host":local_deck.duplicate(true), "guest":remote_deck.duplicate(true), "host_name":local_player_name, "guest_name":remote_player_name}
	match_in_progress = true
	_begin_match.rpc_id(remote_peer_id, payload)
	match_started.emit(payload)
	return true

func send_turn_state(snapshot: Dictionary) -> void:
	if remote_peer_id <= 0: return
	_receive_turn_state.rpc_id(remote_peer_id, snapshot)

func send_action(kind: String, snapshot: Dictionary = {}, event: Dictionary = {}) -> void:
	if remote_peer_id <= 0: return
	_receive_action.rpc_id(remote_peer_id, {"kind":kind, "snapshot":snapshot, "event":event})

func send_match_finished(payload: Dictionary) -> void:
	if remote_peer_id > 0: _receive_match_finished.rpc_id(remote_peer_id, payload)

func mark_match_finished() -> void:
	terminal_pending = true
	match_in_progress = false

func leave_network(emit_status := true) -> void:
	if is_instance_valid(discovery_listener): discovery_listener.close()
	if is_instance_valid(broadcaster): broadcaster.close()
	discovery_listener = null
	broadcaster = null
	var peer := multiplayer.multiplayer_peer
	if peer != null: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = "offline"
	status = "Offline"
	remote_peer_id = 0
	match_in_progress = false
	terminal_pending = false
	remote_player_name = ""
	remote_deck.clear()
	if emit_status: status_changed.emit()

func room_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for room in discovered_rooms.values(): result.append(room)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("room_name", "")) < str(b.get("room_name", "")))
	return result

func has_guest() -> bool:
	return role == "host" and remote_peer_id > 0 and not remote_deck.is_empty()

func _process(delta: float) -> void:
	if role == "host" and is_instance_valid(broadcaster):
		broadcast_elapsed += delta
		if broadcast_elapsed >= float(config.get("broadcast_interval_seconds", 0.75)):
			broadcast_elapsed = 0.0
			var packet := {"signature":SIGNATURE, "room_name":room_name, "host_name":local_player_name, "port":_game_port()}
			broadcaster.put_packet(JSON.stringify(packet).to_utf8_buffer())
	if role == "offline" and is_instance_valid(discovery_listener):
		var changed := false
		while discovery_listener.get_available_packet_count() > 0:
			var raw := discovery_listener.get_packet().get_string_from_utf8()
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary and str(parsed.get("signature", "")) == SIGNATURE:
				var address := discovery_listener.get_packet_ip()
				var key := "%s:%d" % [address, int(parsed.get("port", _game_port()))]
				parsed["address"] = address
				parsed["last_seen"] = Time.get_ticks_msec()
				if not discovered_rooms.has(key) or str(discovered_rooms[key].get("room_name", "")) != str(parsed.get("room_name", "")): changed = true
				discovered_rooms[key] = parsed
		var timeout_ms := int(float(config.get("room_timeout_seconds", 2.5)) * 1000.0)
		for key in discovered_rooms.keys():
			if Time.get_ticks_msec() - int(discovered_rooms[key].get("last_seen", 0)) > timeout_ms:
				discovered_rooms.erase(key)
				changed = true
		if changed: rooms_changed.emit()

func _on_peer_connected(id: int) -> void:
	if role != "host": return
	remote_peer_id = id
	status = "Opponent connected · receiving deck"
	status_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	if id != remote_peer_id: return
	if terminal_pending: return
	if match_in_progress:
		call_deferred("_handle_match_disconnect", "The opponent disconnected.")
		return
	remote_peer_id = 0
	remote_deck.clear()
	remote_player_name = ""
	if role == "host":
		status = "Opponent left · room remains open"
		status_changed.emit()
	else:
		leave_network()
		connection_lost.emit("The opponent disconnected.")

func _handle_match_disconnect(message: String) -> void:
	leave_network()
	connection_lost.emit(message)

func _on_connected_to_server() -> void:
	status = "Connected · waiting for the host to start"
	status_changed.emit()
	_submit_deck.rpc_id(1, local_player_name, local_deck)

func _on_connection_failed() -> void:
	leave_network()
	connection_lost.emit("Could not connect to the LAN room.")

func _on_server_disconnected() -> void:
	if terminal_pending: return
	leave_network()
	connection_lost.emit("The host closed the LAN room.")

@rpc("any_peer", "call_remote", "reliable")
func _submit_deck(player_name: String, deck: Dictionary) -> void:
	if role != "host": return
	var sender := multiplayer.get_remote_sender_id()
	if sender != remote_peer_id: return
	remote_player_name = player_name.left(24)
	remote_deck = deck.duplicate(true)
	status = "%s joined · ready to start" % remote_player_name
	status_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _begin_match(payload: Dictionary) -> void:
	match_in_progress = true
	match_started.emit(payload)

@rpc("any_peer", "call_remote", "reliable")
func _receive_turn_state(snapshot: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != remote_peer_id: return
	turn_state_received.emit(snapshot)

@rpc("any_peer", "call_remote", "reliable")
func _receive_action(payload: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != remote_peer_id: return
	action_received.emit(payload)

@rpc("any_peer", "call_remote", "reliable")
func _receive_match_finished(payload: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != remote_peer_id: return
	match_finished.emit(payload)

func _game_port() -> int:
	return int(config.get("game_port", 8910))

func _discovery_port() -> int:
	return int(config.get("discovery_port", 8911))
