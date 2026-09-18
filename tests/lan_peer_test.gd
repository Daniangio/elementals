extends SceneTree

var lan: LanMultiplayer
var role := ""
var completed := false
var match_payload_valid := false
var saw_card_action := false

func _init() -> void:
	role = OS.get_environment("ELEMENTALS_LAN_TEST_ROLE")
	call_deferred("_start")

func _start() -> void:
	lan = LanMultiplayer.new()
	lan.name = "LanMultiplayer"
	root.add_child(lan, true)
	lan.configure({"game_port":18910, "discovery_port":18911, "broadcast_interval_seconds":0.15, "room_timeout_seconds":1.0})
	lan.match_started.connect(_on_match_started)
	lan.action_received.connect(_on_action_received)
	lan.match_finished.connect(_on_match_finished)
	lan.status_changed.connect(_on_status_changed)
	lan.rooms_changed.connect(_on_rooms_changed)
	if role == "host":
		var error := lan.host_room("Integration Room", "Host", _deck("pillar_fire", "ember_pup"))
		if error != OK: _finish(false, "host create failed: %s" % error_string(error))
	else:
		lan.start_discovery()
	call_deferred("_timeout")

func _deck(foundation: String, vanguard: String) -> Dictionary:
	var ids: Array[String] = []
	for i in 30: ids.append("pillar_fire" if i < 12 else "ember_pup")
	return {"name":"LAN Test", "foundation_id":foundation, "vanguard_id":vanguard, "card_ids":ids, "merged_cards":{}}

func _on_rooms_changed() -> void:
	if role != "client" or lan.room_list().is_empty(): return
	var room: Dictionary = lan.room_list()[0]
	lan.join_room(str(room.address), int(room.port), "Guest", _deck("pillar_water", "cold_current"))

func _on_status_changed() -> void:
	if role == "host" and lan.has_guest(): lan.start_hosted_match()

func _on_match_started(payload: Dictionary) -> void:
	match_payload_valid = payload.has("host") and payload.has("guest") and int(payload.get("seed", 0)) != 0
	if not match_payload_valid:
		_finish(false, "invalid match payload")
		return
	if role == "host":
		await create_timer(0.25).timeout
		lan.send_action("card_play", {}, {"card_id":"ember_pup", "slot":4})
		await create_timer(0.25).timeout
		lan.send_match_finished({"sender_won":false, "reason":"surrender"})
		lan.mark_match_finished()

func _on_action_received(payload: Dictionary) -> void:
	if role == "client" and str(payload.get("kind", "")) == "card_play":
		saw_card_action = str(payload.get("event", {}).get("card_id", "")) == "ember_pup"
	elif role == "host" and str(payload.get("kind", "")) == "terminal_ack":
		_finish(match_payload_valid, "match, action, and surrender payloads received")

func _on_match_finished(payload: Dictionary) -> void:
	if role != "client": return
	var surrender_ok := not bool(payload.get("sender_won", true)) and str(payload.get("reason", "")) == "surrender"
	lan.send_action("terminal_ack")
	lan.mark_match_finished()
	await create_timer(0.15).timeout
	_finish(match_payload_valid and saw_card_action and surrender_ok, "match, action, and surrender payloads received")

func _timeout() -> void:
	await create_timer(8.0).timeout
	if not completed: _finish(false, "timed out in state: %s" % lan.status)

func _finish(success: bool, message: String) -> void:
	if completed: return
	completed = true
	print("LAN INTEGRATION %s: %s" % ["PASS" if success else "FAIL", message])
	lan.leave_network(false)
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if success else 1)
