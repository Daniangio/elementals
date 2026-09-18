extends SceneTree

var failures := 0

func _init() -> void:
	var fusion := FusionEngine.new()
	var fire := {"id":"test_fire", "display_name":"Test Fire", "name_parts":["Test","Fire"], "card_type":"Creature", "subtypes":["Beast"], "element_tags":["Fire"], "cost":{"Fire":2}, "attack":4, "max_hp":3, "abilities":[{"id":"Burn","kind":"triggered","cost":{},"strength":2,"target":"enemy_player"}], "image":"res://icon.svg", "is_base":true}
	var water := {"id":"test_water", "display_name":"Test Water", "name_parts":["Test","Water"], "card_type":"Creature", "subtypes":["Spirit"], "element_tags":["Water"], "cost":{"Water":2}, "attack":2, "max_hp":5, "abilities":[{"id":"Freeze","kind":"activated","cost":{"Water":1},"strength":2,"target":"enemy_card"}], "image":"res://icon.svg", "is_base":true}
	var choices := fusion.result_candidates(fire, water, "Test Water").filter(func(choice): return choice.fusion_mode == "imprint")
	var wildtypes: Array = choices.filter(func(choice): return choice.abilities.is_empty())
	_check(not wildtypes.is_empty() and int(wildtypes[0].get("wildtype_stat_bonus", 0)) > 0 and int(wildtypes[0].attack) > 5 and int(wildtypes[0].max_hp) > 6, "Ability-free wildtypes convert unused ability value into better ATK and HP")
	_check(choices.any(func(choice): return choice.abilities.size() == 1 and str(choice.abilities[0].id) == "Burn"), "Packages include the first parent's ability alone")
	_check(choices.any(func(choice): return choice.abilities.size() == 1 and str(choice.abilities[0].id) == "Freeze"), "Packages include the second parent's ability alone")
	_check(choices.any(func(choice): return choice.abilities.any(func(ability): return str(ability.id) == "Burn") and choice.abilities.any(func(ability): return str(ability.id) == "Freeze")), "Packages include abilities from both parents together")
	var reversed := fusion.result_candidates(water, fire, "Test Fire").filter(func(choice): return choice.fusion_mode == "imprint")
	_check(reversed.any(func(choice): return choice.abilities.size() == 1 and str(choice.abilities[0].id) == "Burn") and reversed.any(func(choice): return choice.abilities.size() == 1 and str(choice.abilities[0].id) == "Freeze"), "Ability choices are independent of source order")
	print("ELEMENTALS HYBRID FUSION TESTS: %d failure(s)" % failures)
	quit(failures)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
