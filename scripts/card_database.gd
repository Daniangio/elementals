class_name CardDatabase
extends RefCounted

var cards: Dictionary = {}
var abilities: Dictionary = {}

func load_all() -> void:
	cards.clear()
	for card in _read_json("res://data/cards.json"):
		cards[card.id] = card
	abilities = _read_json("res://data/abilities.json")

func all_cards(extra: Dictionary = {}) -> Array:
	var result: Array = cards.values()
	result.append_array(extra.values())
	return result

func get_card(id: String, extra: Dictionary = {}) -> Dictionary:
	if extra.has(id):
		return extra[id]
	return cards.get(id, {})

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}
