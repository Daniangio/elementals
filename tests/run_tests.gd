extends SceneTree

var failures := 0

func _init() -> void:
	var db := CardDatabase.new()
	db.load_all()
	var fusion := FusionEngine.new()
	var imp := db.get_card("magma_reaver")
	var sprite := db.get_card("water_sprite")
	var full_cost := fusion.full_cost(imp, sprite)
	_check(full_cost == {"Fire":6, "Water":1}, "Confluence cost sums components")
	_check(fusion.hybrid_costs({"Fire":2, "Water":2}, "Fire", "Water") == [{"Steam":2}, {"Fire":1, "Water":1, "Steam":1}], "Imprint costs enumerate every transformed pair count")
	var candidates := fusion.result_candidates(imp, sprite, fusion.name_candidates(imp, sprite)[0])
	_check(candidates.size() == 5, "Confluence and the stronger legal Imprint ability packages are generated")
	_check(candidates[0].attack == 10 and candidates[0].max_hp == 8, "Confluence stats sum")
	_check(candidates[1].attack == 10 and candidates[1].max_hp == 6 and is_equal_approx(float(candidates[1].hybrid_fidelity), 0.25), "Fully compressed Imprint stats use max plus one-quarter of min")
	_check(is_equal_approx(float(candidates[1].ability_fidelity), 0.5) and is_equal_approx(float(candidates[1].ability_budget), 1.5), "Fully compressed Imprints retain half of the full ability budget")
	_check(candidates.any(func(choice): return choice.fusion_mode == "imprint" and choice.abilities.size() == 1 and choice.abilities[0].id == "Burn"), "Raised ability fidelity preserves a legal parent ability")
	_check(candidates[0].subtypes == ["Elemental", "Warrior", "Spirit"], "Confluence adds unique subtypes")
	_check(candidates.filter(func(choice): return choice.fusion_mode == "imprint").all(func(choice): return choice.subtypes == ["Elemental", "Warrior"] or choice.subtypes == ["Spirit"]), "Imprint chooses one source's subtypes")
	_check(candidates[0].fusion_mode == "confluence" and candidates[1].fusion_mode == "imprint", "Merge expressions use documented names")
	_check(candidates[0].image == imp.image, "First-name source determines merged artwork")
	var same_element := fusion.result_candidates(db.get_card("ember_pup"), db.get_card("cinder_hound"), "Ember Hound")
	_check(same_element.size() == 1 and same_element[0].fusion_mode == "confluence" and same_element[0].element_tags == ["Fire"], "Same-element cards offer only Fire Confluence")
	var hound := db.get_card("cinder_hound")
	var mage := db.get_card("water_mage")
	var choices := fusion.result_candidates(hound, mage, "Cinder Mage")
	_check(choices.size() == 11, "Each Imprint cost emits the stronger ability packages that fit its budget")
	_check(choices.any(func(choice): return choice.fusion_mode == "imprint" and choice.abilities.size() == 1 and choice.abilities[0].id == "Strike"), "A legal fixed parent ability is retained as an Imprint package")
	_check(int(sprite.abilities[0].cost.Water) == 1 and int(mage.abilities[0].cost.Water) == 1, "Freeze carries its explicit one-Water activation cost")
	_check(is_equal_approx(fusion.ability_value({"id":"Burn","strength":2}), 2.0) and is_equal_approx(fusion.ability_value({"id":"Freeze","strength":2}), 3.25), "Ability values use configured linear and lookup scaling")
	var budget_a := {"id":"budget_fire","display_name":"Budget Fire","name_parts":["Budget","Fire"],"card_type":"Creature","subtypes":["Elemental"],"element_tags":["Fire"],"cost":{"Fire":3},"attack":5,"max_hp":4,"abilities":[{"id":"Burn","kind":"triggered","cost":{},"strength":2,"target":"enemy_player"}],"image":imp.image,"is_base":true}
	var budget_b := {"id":"budget_water","display_name":"Budget Water","name_parts":["Budget","Water"],"card_type":"Creature","subtypes":["Spirit"],"element_tags":["Water"],"cost":{"Water":3},"attack":3,"max_hp":6,"abilities":[{"id":"Freeze","kind":"activated","cost":{"Water":1},"strength":1,"target":"enemy_card"}],"image":sprite.image,"is_base":true}
	var budget_choices := fusion.result_candidates(budget_a, budget_b, "Budget Water")
	_check(budget_choices.any(func(choice): return choice.fusion_mode == "imprint" and is_equal_approx(float(choice.hybrid_fidelity), 0.75) and choice.abilities.size() == 2), "Higher-fidelity Imprint first preserves both scaled source abilities")
	_check(is_equal_approx(fusion.ability_fidelity({"Fire":2,"Water":2,"Steam":1}, "Fire", "Water"), 0.9) and is_equal_approx(fusion.ability_fidelity({"Steam":3}, "Fire", "Water"), 0.5), "Ability fidelity uses the improved partial and full compression ratios")
	_check(budget_choices.any(func(choice): return choice.fusion_mode == "imprint" and choice.abilities.size() == 1 and choice.abilities[0].id == "Scald"), "Explicit fusion recipes are offered when their configured value fits")
	_check(budget_choices.any(func(choice): return choice.abilities.size() == 1 and choice.abilities[0].id == "Scald" and int(choice.abilities[0].strength) == 5), "Burn plus Freeze produces the strengthened Scald 5 recipe")
	var configured_ids: Dictionary = fusion.ability_definitions
	var missing_ability_metadata: Array[String] = []
	for card in db.all_cards():
		for ability in card.abilities:
			if not configured_ids.has(str(ability.id)) and str(ability.id) not in missing_ability_metadata: missing_ability_metadata.append(str(ability.id))
	_check(missing_ability_metadata.is_empty(), "Every card ability has description and valuation metadata")
	_check(db.get_card("pillar_steam").deck_eligible == false, "Legacy unattuned hybrid Pillars remain unavailable")
	_check(db.get_card("pillar_steam_fire").deck_eligible and int(db.get_card("pillar_steam_fire").cost.Fire) == 1 and db.get_card("pillar_steam_fire").element_tags == ["Steam"], "Fire-attuned Steam Pillar costs 1 Fire and produces Steam")
	_check(db.get_card("pillar_steam_water").deck_eligible and int(db.get_card("pillar_steam_water").cost.Water) == 1, "Water-attuned Steam Pillar costs 1 Water")
	_check(int(db.get_card("fireball").cost.Fire) == 3 and str(db.get_card("fireball").abilities[0].target) == "any_damageable", "Fireball costs 3 Fire and can target any damageable entity")
	_check(int(db.get_card("pyre_stalker").abilities[0].strength) == 2 and str(db.get_card("coalbrand_imp").abilities[0].id) == "Ignite", "New Fire creatures support printed and targeted Burn")
	_check(str(db.get_card("searing_brand").abilities[0].target) == "any_damageable" and str(db.get_card("ember_infusion").abilities[0].id) == "Grant Burn", "New Fire spells apply Burn counters and grant the Burn ability")
	var water_design_cards := db.all_cards().filter(func(card): return str(card.get("design_id", "")).begins_with("W") and str(card.get("design_id", "")).length() == 4)
	_check(water_design_cards.size() == 15, "All 15 Water design-sheet creatures are registered")
	_check(db.get_card("tide_tadpole").cost.is_empty() and db.get_card("abyssal_leviathan").attack == 9 and db.get_card("abyssal_leviathan").max_hp == 16, "Water roster preserves its free opener and top-end stats")
	_check(db.get_card("deepwater_spirit").abilities.size() == 2 and db.get_card("leviathan_whelp").abilities.size() == 2, "Multi-keyword Water cards retain both abilities")
	_check(ResourceLoader.exists(str(db.get_card("ancient_sea_drake").image)), "Water cards use the supplied artwork")
	_check(db.get_card("sea_egg").subtypes == ["Egg"] and int(db.get_card("sea_egg").abilities[0].strength) == 3 and db.get_card("sea_drake").attack == 5 and db.get_card("sea_drake").max_hp == 6, "Sea Egg and Sea Drake token-sheet definitions are registered")
	_check(str(db.get_card("sea_egg").image) == "res://assets/cards/water/sea_egg.jpg" and str(db.get_card("blizzard").image) == "res://assets/cards/water/blizzard.jpg", "New Water cards use predictable future artwork paths")
	_check(int(db.get_card("deep_freeze").abilities[0].target_count) == 3 and int(db.get_card("mass_incubation").abilities[0].strength) == 6, "All Water spell-sheet target and spawn counts are registered")
	var nature_design_cards := db.all_cards().filter(func(card): return str(card.get("design_id", "")).begins_with("N") and not str(card.get("design_id", "")).begins_with("NS"))
	_check(nature_design_cards.size() == 15, "All 15 Nature design-sheet creatures are registered")
	_check(db.get_card("seedling").cost.is_empty() and db.get_card("avatar_of_the_grove").attack == 8 and db.get_card("avatar_of_the_grove").max_hp == 11, "Nature roster preserves its free opener and top-end stats")
	_check(db.get_card("ancient_gardener").abilities.size() == 2 and int(db.get_card("ancient_gardener").abilities[1].cost.Nature) == 1, "Ancient Gardener has Nurture and costed Sapling activation")
	_check(str(db.get_card("worldroot_treant").image) == "res://assets/cards/nature/worldroot_treant.jpg", "Nature artwork follows predictable card ID filenames")
	_check(not db.get_card("sapling").collectible and not db.get_card("sapling").deck_eligible, "Nature tokens cannot enter collections or decks")
	var nature_spells := db.all_cards().filter(func(card): return str(card.get("design_id", "")).begins_with("NS"))
	_check(nature_spells.size() == 12, "All 12 Nature spell-sheet cards are registered")
	_check(db.get_card("seed_elf").subtypes == ["Elf"] and db.get_card("seed_elf").attack == 1 and db.get_card("spore").max_hp == 1, "Nature spell tokens are registered with their authored stats")
	_check(str(db.get_card("worldroot_ascension").image) == "res://assets/cards/nature/worldroot_ascension.jpg", "Nature spells use predictable future artwork paths")
	_check(fusion.result_candidates(db.get_card("fireball"), db.get_card("ember_pup"), "Fire Pup").is_empty(), "Forge accepts creatures only")
	var profile_store := ProfileStore.new()
	profile_store.profile = {"collection":{"magma_reaver":2, "water_sprite":1}, "merged_cards":{}, "decks":{}}
	var merged := fusion.create_fusion(imp, sprite, candidates[1])
	_check(merged.merge_count == 1, "First merge receives one merge mark")
	var first_fire_merge := fusion.create_fusion(db.get_card("ember_pup"), db.get_card("cinder_hound"), same_element[0])
	var second_candidates := fusion.result_candidates(first_fire_merge, sprite, "Ember Sprite")
	var twice_merged := fusion.create_fusion(first_fire_merge, sprite, second_candidates[0])
	_check(twice_merged.merge_count == 2 and fusion.result_candidates(twice_merged, sprite, "Magma Sprite").is_empty(), "Two merge marks enforce the lifetime merge limit")
	_check(profile_store.apply_fusion_to_collection(["magma_reaver", "water_sprite"], merged), "Fusion collection transaction succeeds with owned sources")
	_check(profile_store.owned("magma_reaver") == 1 and profile_store.owned("water_sprite") == 0 and profile_store.owned(merged.id) == 1, "Fusion consumes sources and adds one merged card")
	var starter_data: Dictionary = _read_json("res://data/starter_decks.json").get("decks", {})
	var bot_data: Dictionary = _read_json("res://data/bot_decks.json").get("decks", {})
	var challenge_data: Dictionary = _read_json("res://data/challenges.json").get("challenges", {})
	_check(starter_data.size() >= 3 and starter_data.values().all(func(deck): return deck.get("card_ids", []).size() >= 30), "Starter choices are data-driven valid-size decks")
	_check(bot_data.size() >= 6 and bot_data.values().all(func(deck): return deck.get("card_ids", []).size() >= 30), "Bot difficulty pools provide several valid-size decks")
	_check(challenge_data.size() >= 3 and challenge_data.values().all(func(challenge): return challenge.get("bot_deck_ids", []).size() >= 2), "Challenges define costs, prizes, and random multi-deck pools")
	_check(_read_json("res://data/bootstrap_profile.json").get("collection", {}).is_empty(), "Fresh profile bootstrap starts with no cards")
	var debug_store := ProfileStore.new()
	debug_store.profile = {"collection":{"ember_pup":2}, "merged_cards":{}}
	debug_store.config = {"debug":{"enabled":true, "owned_card_bonus":100}}
	debug_store.debug_collectible_ids = {"ember_pup":true}
	_check(debug_store.owned("ember_pup") == 102 and debug_store.owned("sapling") == 0, "Debug ownership adds 100 only to collectible cards")
	print("ELEMENTALS RULE TESTS: %d failure(s)" % failures)
	quit(failures)

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
