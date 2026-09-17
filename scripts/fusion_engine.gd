class_name FusionEngine
extends RefCounted

const PAIRS := {"Fire|Water":"Steam", "Fire|Nature":"Wildfire", "Nature|Water":"Swamp"}
const ABILITIES_PATH := "res://data/abilities.json"
const RULES_PATH := "res://data/fusion_rules.json"

var ability_definitions: Dictionary = {}
var rules: Dictionary = {}

func _init() -> void:
	ability_definitions = _read_json(ABILITIES_PATH)
	rules = _read_json(RULES_PATH)

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}

func fusion_element(a: String, b: String) -> String:
	var keys := [a, b]
	keys.sort()
	return PAIRS.get("|".join(keys), "")

func result_element(a: String, b: String) -> String:
	return a if a == b else fusion_element(a, b)

func merge_count(card: Dictionary) -> int:
	if bool(card.get("is_base", false)): return 0
	return int(card.get("merge_count", 1 if card.has("fusion_source_ids") else 0))

func name_candidates(a: Dictionary, b: Dictionary) -> Array[String]:
	return [str(a.name_parts[0]) + " " + str(b.name_parts[1]), str(b.name_parts[0]) + " " + str(a.name_parts[1])]

func ability_id(reference: Variant) -> String:
	return str(reference.get("id", "")) if reference is Dictionary else str(reference)

func full_cost(a: Dictionary, b: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in a.cost: result[key] = int(a.cost[key])
	for key in b.cost: result[key] = int(result.get(key, 0)) + int(b.cost[key])
	return result

func hybrid_costs(cost: Dictionary, element_a: String, element_b: String) -> Array[Dictionary]:
	var hybrid := fusion_element(element_a, element_b)
	if hybrid.is_empty(): return []
	var pair_count: int = mini(int(cost.get(element_a, 0)), int(cost.get(element_b, 0)))
	var variants: Array[Dictionary] = []
	for transformed in range(pair_count, 0, -1):
		var variant: Dictionary = cost.duplicate(true)
		variant[element_a] = int(variant.get(element_a, 0)) - transformed
		variant[element_b] = int(variant.get(element_b, 0)) - transformed
		variant[hybrid] = transformed
		for key in variant.keys():
			if int(variant[key]) == 0: variant.erase(key)
		variants.append(variant)
	return variants

func hybrid_fidelity(cost: Dictionary, element_a: String, element_b: String) -> float:
	return _fidelity_value(cost, element_a, element_b, "alpha")

func ability_fidelity(cost: Dictionary, element_a: String, element_b: String) -> float:
	return _fidelity_value(cost, element_a, element_b, "ability_alpha")

func _fidelity_value(cost: Dictionary, element_a: String, element_b: String, field: String) -> float:
	var hybrid := fusion_element(element_a, element_b)
	var pair_count: int = mini(int(cost.get(element_a, 0)) + int(cost.get(hybrid, 0)), int(cost.get(element_b, 0)) + int(cost.get(hybrid, 0)))
	if hybrid.is_empty() or pair_count <= 0: return 1.0
	var ratio := float(cost.get(hybrid, 0)) / float(pair_count)
	for tier in rules.get("hybrid_fidelity", []):
		if ratio <= float(tier.get("maximum_compression_ratio", 1.0)) + 0.0001: return float(tier.get(field, tier.get("alpha", 0.25)))
	return 0.5 if field == "ability_alpha" else 0.25

func ability_value(reference: Variant) -> float:
	var id := ability_id(reference)
	var definition: Dictionary = ability_definitions.get(id, {})
	var model: Dictionary = definition.get("value_model", {})
	match str(model.get("type", "fixed")):
		"linear":
			var parameter: Dictionary = definition.get("strength", {})
			var strength := int(reference.get("strength", parameter.get("min", 1))) if reference is Dictionary else int(parameter.get("min", 1))
			return float(model.get("base", 0.0)) + float(model.get("coefficient", 0.0)) * float(strength - int(model.get("base_strength", 1)))
		"lookup":
			var parameter: Dictionary = definition.get("strength", {})
			var strength := int(reference.get("strength", parameter.get("min", 1))) if reference is Dictionary else int(parameter.get("min", 1))
			return float(model.get("values", {}).get(str(strength), 0.0))
		_:
			return float(model.get("value", 0.0))

func package_value(abilities: Array) -> float:
	var total := 0.0
	for ability in abilities: total += ability_value(ability)
	return total

func combined_ability(a: Array, b: Array) -> String:
	var ids: Array[String] = []
	for ability in a + b: ids.append(ability_id(ability))
	for recipe in rules.get("ability_fusion_recipes", []):
		var inputs: Array = recipe.get("inputs", [])
		if inputs.size() == 2 and str(inputs[0]) in ids and str(inputs[1]) in ids: return ability_id(recipe.get("output", {}))
	return ""

func result_candidates(a: Dictionary, b: Dictionary, chosen_name: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if str(a.get("card_type", "")) != "Creature" or str(b.get("card_type", "")) != "Creature": return candidates
	if merge_count(a) >= 2 or merge_count(b) >= 2: return candidates
	if result_element(str(a.element_tags[0]), str(b.element_tags[0])).is_empty(): return candidates
	var full := _resolved_base(a, b, chosen_name)
	full["candidate_label"] = "Confluence"
	full["fusion_mode"] = "confluence"
	full["ability_value"] = package_value(full.abilities)
	candidates.append(full)
	if str(a.element_tags[0]) == str(b.element_tags[0]): return candidates
	var total_cost := full_cost(a, b)
	var costs := hybrid_costs(total_cost, a.element_tags[0], b.element_tags[0])
	var subtype_sets: Array = [a.get("subtypes", []).duplicate(), b.get("subtypes", []).duplicate()]
	var full_budget := package_value(a.abilities) + package_value(b.abilities)
	for hybrid_cost in costs:
		var alpha := hybrid_fidelity(hybrid_cost, str(a.element_tags[0]), str(b.element_tags[0]))
		var ability_alpha := ability_fidelity(hybrid_cost, str(a.element_tags[0]), str(b.element_tags[0]))
		var budget := ability_alpha * full_budget
		var packages := _ability_packages(a.abilities, b.abilities, budget)
		for package in packages:
			for subtype_index in subtype_sets.size():
				var hybrid := _resolved_base(a, b, chosen_name)
				hybrid.cost = hybrid_cost.duplicate(true)
				hybrid.attack = _compressed_stat(int(a.attack), int(b.attack), alpha)
				hybrid.max_hp = _compressed_stat(int(a.max_hp), int(b.max_hp), alpha)
				hybrid.abilities = package.abilities.duplicate(true)
				hybrid.subtypes = subtype_sets[subtype_index].duplicate()
				hybrid["hybrid_fidelity"] = alpha
				hybrid["ability_fidelity"] = ability_alpha
				hybrid["ability_budget"] = budget
				hybrid["ability_value"] = float(package.value)
				hybrid["candidate_label"] = "Imprint %s | %s | stats %.2f · abilities %.2f | %.2f/%.2f ability | subtype %s" % [format_cost(hybrid_cost), str(package.label), alpha, ability_alpha, float(package.value), budget, "A" if subtype_index == 0 else "B"]
				hybrid["fusion_mode"] = "imprint"
				candidates.append(hybrid)
	return candidates

func _compressed_stat(a: int, b: int, alpha: float) -> int:
	var raw := float(maxi(a, b)) + alpha * float(mini(a, b))
	match str(rules.get("stat_rounding", "nearest")):
		"floor": return floori(raw)
		"ceil": return ceili(raw)
		_: return roundi(raw)

func _ability_versions(reference: Variant) -> Array[Dictionary]:
	var original: Dictionary = reference.duplicate(true) if reference is Dictionary else {"id":str(reference)}
	original.get_or_add("cost", {})
	original.get_or_add("target", "none")
	original.get_or_add("kind", "triggered")
	var definition: Dictionary = ability_definitions.get(ability_id(original), {})
	if not bool(definition.get("scalable", false)): return [original]
	var parameter: Dictionary = definition.get("strength", {})
	var minimum := int(parameter.get("min", 1))
	var maximum := mini(int(parameter.get("max", minimum)), maxi(minimum, int(original.get("strength", minimum))))
	var step := maxi(1, int(parameter.get("step", 1)))
	var versions: Array[Dictionary] = []
	for strength in range(minimum, maximum + 1, step):
		var scaled := original.duplicate(true)
		scaled.strength = strength
		versions.append(scaled)
	return versions

func _ability_packages(a: Array, b: Array, budget: float) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for reference in a: entries.append({"origin":0, "versions":_ability_versions(reference)})
	for reference in b: entries.append({"origin":1, "versions":_ability_versions(reference)})
	var packages: Array[Dictionary] = [{"abilities":[], "origins":{}, "value":0.0}]
	for entry in entries:
		var expanded: Array[Dictionary] = []
		for package in packages:
			expanded.append(package.duplicate(true))
			for version in entry.versions:
				var value := float(package.value) + ability_value(version)
				if value > budget + 0.0001: continue
				var addition: Dictionary = package.duplicate(true)
				addition.abilities.append(version.duplicate(true))
				addition.origins[str(entry.origin)] = true
				addition.value = value
				expanded.append(addition)
		packages = expanded
	for recipe in rules.get("ability_fusion_recipes", []):
		var output: Dictionary = recipe.get("output", {}).duplicate(true)
		if _recipe_matches(recipe, a + b) and ability_value(output) <= budget + 0.0001:
			packages.append({"abilities":[output], "origins":{"0":true, "1":true}, "value":ability_value(output), "recipe":true})
	var unique: Dictionary = {}
	for package in packages:
		var signature := _package_signature(package.abilities)
		if not unique.has(signature) or int(package.origins.size()) > int(unique[signature].origins.size()): unique[signature] = package
	var result: Array[Dictionary] = []
	for package in unique.values(): result.append(package)
	result.sort_custom(func(left: Dictionary, right: Dictionary):
		if left.origins.size() != right.origins.size(): return left.origins.size() > right.origins.size()
		if not is_equal_approx(float(left.value), float(right.value)): return float(left.value) > float(right.value)
		if left.abilities.size() != right.abilities.size(): return left.abilities.size() > right.abilities.size()
		return _package_signature(left.abilities) < _package_signature(right.abilities))
	for package in result: package["label"] = _package_label(package.abilities, bool(package.get("recipe", false)))
	return result

func _recipe_matches(recipe: Dictionary, abilities: Array) -> bool:
	var ids: Array[String] = []
	for ability in abilities: ids.append(ability_id(ability))
	for input in recipe.get("inputs", []):
		if str(input) not in ids: return false
	return true

func _package_signature(abilities: Array) -> String:
	var parts: Array[String] = []
	for reference in abilities: parts.append("%s:%d:%s" % [ability_id(reference), int(reference.get("strength", 0)), JSON.stringify(reference.get("cost", {}))])
	parts.sort()
	return "|".join(parts)

func _package_label(abilities: Array, recipe: bool) -> String:
	if abilities.is_empty(): return "no abilities"
	var labels: Array[String] = []
	for ability in abilities:
		var strength := int(ability.get("strength", 0))
		labels.append(ability_id(ability) + (" %d" % strength if strength > 0 else ""))
	return ("recipe " if recipe else "") + " + ".join(labels)

func create_fusion(a: Dictionary, b: Dictionary, selected: Dictionary) -> Dictionary:
	var result := selected.duplicate(true)
	result.erase("candidate_label")
	result.id = "fusion_" + str(Time.get_unix_time_from_system()) + "_" + str(randi_range(100, 999))
	result.is_base = false
	result.is_pillar = false
	result.collectible = true
	result.deck_eligible = true
	result.merge_count = maxi(merge_count(a), merge_count(b)) + 1
	result.fusion_source_ids = [a.id, b.id]
	result.fusion_config = {"source_a":a.id, "source_b":b.id, "selected_mode":result.get("fusion_mode", "confluence"), "hybrid_fidelity":result.get("hybrid_fidelity", 1.0), "ability_fidelity":result.get("ability_fidelity", 1.0), "ability_budget":result.get("ability_budget", result.get("ability_value", 0.0)), "ability_value":result.get("ability_value", 0.0), "resolved_cost":result.cost.duplicate(true), "resolved_attack":result.attack, "resolved_hp":result.max_hp, "resolved_abilities":result.abilities.duplicate(true), "resolved_subtypes":result.subtypes.duplicate()}
	return result

func _resolved_base(a: Dictionary, b: Dictionary, chosen_name: String) -> Dictionary:
	var merged_subtypes: Array = []
	for subtype in a.get("subtypes", []) + b.get("subtypes", []):
		if subtype not in merged_subtypes: merged_subtypes.append(subtype)
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
		if int(cost.get(element, 0)) > 0: parts.append(str(int(cost[element])) + element.left(1))
	return " ".join(parts) if not parts.is_empty() else "Free"
