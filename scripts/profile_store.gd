class_name ProfileStore
extends RefCounted

const PROFILE_PATH := "user://profile.json"
const ACCOUNTS_PATH := "user://accounts.json"
const BOOTSTRAP_PATH := "res://data/bootstrap_profile.json"
const CONFIG_PATH := "res://data/game_config.json"
var profile: Dictionary = {}
var accounts: Dictionary = {}
var active_profile_id := ""
var config: Dictionary = {}

func load_profile() -> Dictionary:
	var bootstrap := _read_json(BOOTSTRAP_PATH)
	config = _read_json(CONFIG_PATH)
	if FileAccess.file_exists(ACCOUNTS_PATH):
		accounts = _read_json(ACCOUNTS_PATH)
		active_profile_id = str(accounts.get("active_profile_id", ""))
		if not accounts.get("profiles", {}).has(active_profile_id): active_profile_id = str(accounts.get("profiles", {}).keys()[0]) if not accounts.get("profiles", {}).is_empty() else ""
	else:
		var first := _read_json(PROFILE_PATH) if FileAccess.file_exists(PROFILE_PATH) else bootstrap.duplicate(true)
		active_profile_id = "profile_1"
		accounts = {"active_profile_id":active_profile_id, "profiles":{active_profile_id:first}}
	profile = accounts.profiles.get(active_profile_id, bootstrap.duplicate(true))
	_ensure_profile(profile, bootstrap)
	save_profile()
	return profile

func _ensure_profile(target: Dictionary, bootstrap: Dictionary) -> void:
	target.get_or_add("id", active_profile_id)
	target.get_or_add("name", "Adventurer" if FileAccess.file_exists(PROFILE_PATH) else "")
	var defaults: Dictionary = config.get("starting_profile", {})
	target.get_or_add("level", int(defaults.get("level", 1)))
	target.get_or_add("xp", int(defaults.get("xp", 0)))
	target.get_or_add("currency", int(defaults.get("currency", 1000)))
	target.get_or_add("inventory", {"packs":{}})
	profile.get_or_add("collection", {})
	profile.get_or_add("merged_cards", {})
	profile.get_or_add("decks", {})
	for id in bootstrap.get("collection", {}):
		if not profile.collection.has(id):
			profile.collection[id] = bootstrap.collection[id]
	for id in profile.merged_cards:
		if not profile.collection.has(id):
			profile.collection[id] = 1
	_migrate_card_ids()
	if profile.decks.is_empty():
		profile.decks = bootstrap.decks.duplicate(true)
	for deck in profile.decks.values():
		deck.get_or_add("foundation_id", "pillar_fire")
		deck.get_or_add("vanguard_id", "ember_pup")

func all_profiles() -> Dictionary:
	return accounts.get("profiles", {})

func create_profile(player_name: String) -> Dictionary:
	var bootstrap := _read_json(BOOTSTRAP_PATH).duplicate(true)
	active_profile_id = "profile_" + str(Time.get_unix_time_from_system()) + "_" + str(randi_range(100, 999))
	profile = bootstrap
	profile.id = active_profile_id
	profile.name = player_name.strip_edges()
	_ensure_profile(profile, bootstrap)
	accounts.get_or_add("profiles", {})[active_profile_id] = profile
	accounts.active_profile_id = active_profile_id
	save_profile()
	return profile

func switch_profile(id: String) -> Dictionary:
	if not accounts.get("profiles", {}).has(id): return profile
	active_profile_id = id
	accounts.active_profile_id = id
	profile = accounts.profiles[id]
	save_profile()
	return profile

func _migrate_card_ids() -> void:
	var renamed := {"fire_imp":"ember_pup", "flame_hound":"cinder_hound"}
	for old_id in renamed:
		if profile.collection.has(old_id):
			profile.collection[renamed[old_id]] = maxi(int(profile.collection.get(renamed[old_id], 0)), int(profile.collection[old_id]))
			profile.collection.erase(old_id)
	for deck in profile.decks.values():
		var migrated: Array = []
		for id in deck.get("card_ids", []):
			migrated.append(renamed.get(str(id), str(id)))
		deck.card_ids = migrated

func save_profile() -> bool:
	if active_profile_id.is_empty(): active_profile_id = str(profile.get("id", "profile_1"))
	accounts.get_or_add("profiles", {})[active_profile_id] = profile
	accounts.active_profile_id = active_profile_id
	var file := FileAccess.open(ACCOUNTS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(accounts, "  "))
	return true

func owned(id: String) -> int:
	return int(profile.get("collection", {}).get(id, 0))

func can_consume(ids: Array[String]) -> bool:
	var needed: Dictionary = {}
	for id in ids:
		needed[id] = int(needed.get(id, 0)) + 1
	for id in needed:
		if owned(id) < int(needed[id]):
			return false
	return true

func consume_and_add(source_ids: Array[String], merged: Dictionary) -> bool:
	if not can_consume(source_ids):
		return false
	var previous := profile.duplicate(true)
	_apply_fusion_to_collection(source_ids, merged)
	if save_profile():
		return true
	profile = previous
	return false

func apply_fusion_to_collection(source_ids: Array[String], merged: Dictionary) -> bool:
	if not can_consume(source_ids):
		return false
	_apply_fusion_to_collection(source_ids, merged)
	return true

func _apply_fusion_to_collection(source_ids: Array[String], merged: Dictionary) -> void:
	for id in source_ids:
		profile.collection[id] = owned(id) - 1
	profile.merged_cards[merged.id] = merged
	profile.collection[merged.id] = int(profile.collection.get(merged.id, 0)) + 1

func export_debug() -> String:
	var path := "user://elementals_debug_profile.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile, "  "))
	return ProjectSettings.globalize_path(path)

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
