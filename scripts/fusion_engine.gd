class_name FusionEngine
extends RefCounted

const PAIRS := {"Fire|Water":"Steam", "Fire|Nature":"Wildfire", "Nature|Water":"Swamp"}
const ABILITY_FUSIONS := {"Burn|Freeze":"Scald", "Growth|Heal":"Regeneration", "Burn|Strike":"Flame Strike"}
const FUSED_ABILITY_REFS := {
	"Scald":{"id":"Scald", "cost":{}, "target":"none", "kind":"triggered", "strength":3},
	"Regeneration":{"id":"Regeneration", "cost":{}, "target":"self", "kind":"triggered"},
	"Flame Strike":{"id":"Flame Strike", "cost":{}, "target":"enemy_card", "kind":"triggered", "strength":2}
}

func fusion_element(a: String, b: String) -> String:
	var keys := [a, b]
	keys.sort()
	return PAIRS.get("|".join(keys), "")

func result_element(a: String, b: String) -> String:
	return a if a == b else fusion_element(a, b)

func merge_count(card: Dictionary) -> int:
	if bool(card.get("is_base", false)):
		return 0
	return int(card.get("merge_count", 1 if card.has("fusion_source_ids") else 0))

func name_candidates(a: Dictionary, b: Dictionary) -> Array[String]:
	return [str(a.name_parts[0]) + " " + str(b.name_parts[1]), str(b.name_parts[0]) + " " + str(a.name_parts[1])]

func ability_id(reference: Variant) -> String:
	return str(reference.get("id", "")) if reference is Dictionary else str(reference)

func full_cost(a: Dictionary, b: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in a.cost:
		result[key] = int(a.cost[key])
	for key in b.cost:
		result[key] = int(result.get(key, 0)) + int(b.cost[key])
	return result

func hybrid_costs(cost: Dictionary, element_a: String, element_b: String) -> Array[Dictionary]:
	var hybrid := fusion_element(element_a, element_b)
	if hybrid.is_empty():
		return []
	var pair_count: int = min(int(cost.get(element_a, 0)), int(cost.get(element_b, 0)))
	var variants: Array[Dictionary] = []
	for transformed in range(pair_count, 0, -1):
		var variant: Dictionary = cost.duplicate(true)
		variant[element_a] = int(variant.get(element_a, 0)) - transformed
		variant[element_b] = int(variant.get(element_b, 0)) - transformed
		variant[hybrid] = transformed
		for key in variant.keys():
			if variant[key] == 0:
				variant.erase(key)
		variants.append(variant)
	return variants

func combined_ability(a: Array, b: Array) -> String:
	for left in a:
		for right in b:
			var keys := [ability_id(left), ability_id(right)]
			keys.sort()
			var result: String = ABILITY_FUSIONS.get("|".join(keys), "")
			if not result.is_empty():
				return result
	return ""

func result_candidates(a: Dictionary, b: Dictionary, chosen_name: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if merge_count(a) >= 2 or merge_count(b) >= 2:
		return candidates
	if result_element(str(a.element_tags[0]), str(b.element_tags[0])).is_empty():
		return candidates
	var full := _resolved_base(a, b, chosen_name)
	full["candidate_label"] = "Confluence"
	full["fusion_mode"] = "confluence"
	candidates.append(full)
	if str(a.element_tags[0]) == str(b.element_tags[0]):
		return candidates
	var total_cost := full_cost(a, b)
	var costs := hybrid_costs(total_cost, a.element_tags[0], b.element_tags[0])
	var combo := combined_ability(a.abilities, b.abilities)
	var ability_sets: Array = [[FUSED_ABILITY_REFS[combo].duplicate(true)]] if not combo.is_empty() else [a.abilities.duplicate(true), b.abilities.duplicate(true)]
	var subtype_sets: Array = [a.get("subtypes", []).duplicate(), b.get("subtypes", []).duplicate()]
	for cost_index in costs.size():
		for ability_index in ability_sets.size():
			for subtype_index in subtype_sets.size():
				var hybrid := _resolved_base(a, b, chosen_name)
				hybrid.cost = costs[cost_index]
				hybrid.attack = max(int(a.attack), int(b.attack))
				hybrid.max_hp = max(int(a.max_hp), int(b.max_hp))
				hybrid.abilities = ability_sets[ability_index].duplicate(true)
				hybrid.subtypes = subtype_sets[subtype_index].duplicate()
				var ability_label := "combined ability" if not combo.is_empty() else "ability %s" % ("A" if ability_index == 0 else "B")
				hybrid["candidate_label"] = "Imprint %s | %s | subtype %s" % [format_cost(costs[cost_index]), ability_label, "A" if subtype_index == 0 else "B"]
				hybrid["fusion_mode"] = "imprint"
				candidates.append(hybrid)
	return candidates

func create_fusion(a: Dictionary, b: Dictionary, selected: Dictionary) -> Dictionary:
	var result := selected.duplicate(true)
	result.erase("candidate_label")
	var id := "fusion_" + str(Time.get_unix_time_from_system()) + "_" + str(randi_range(100, 999))
	result.id = id
	result.is_base = false
	result.is_pillar = false
	result.collectible = true
	result.deck_eligible = true
	result.merge_count = maxi(merge_count(a), merge_count(b)) + 1
	result.fusion_source_ids = [a.id, b.id]
	result.fusion_config = {"source_a":a.id, "source_b":b.id, "selected_mode":result.get("fusion_mode", "confluence"), "resolved_cost":result.cost.duplicate(true), "resolved_attack":result.attack, "resolved_hp":result.max_hp, "resolved_abilities":result.abilities.duplicate(true), "resolved_subtypes":result.subtypes.duplicate()}
	return result

func _resolved_base(a: Dictionary, b: Dictionary, chosen_name: String) -> Dictionary:
	var merged_subtypes: Array = []
	for subtype in a.get("subtypes", []) + b.get("subtypes", []):
		if subtype not in merged_subtypes:
			merged_subtypes.append(subtype)
	return {
		"id":"candidate", "display_name":chosen_name, "name_parts":chosen_name.split(" ", false, 1),
		"merge_count":maxi(merge_count(a), merge_count(b)) + 1,
		"card_type":"Creature", "subtypes":merged_subtypes, "element_tags":[result_element(a.element_tags[0], b.element_tags[0])],
		"cost":full_cost(a, b), "attack":int(a.attack) + int(b.attack), "max_hp":int(a.max_hp) + int(b.max_hp),
		"abilities":a.abilities.duplicate(true) + b.abilities.duplicate(true),
		"image":str(a.image) if chosen_name.begins_with(str(a.name_parts[0])) else str(b.image)
	}

func format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for element in ["Fire", "Water", "Nature", "Steam", "Wildfire", "Swamp"]:
		if int(cost.get(element, 0)) > 0:
			parts.append(str(int(cost[element])) + element.left(1))
	return " ".join(parts) if not parts.is_empty() else "Free"
