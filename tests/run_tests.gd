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
	var candidates := fusion.result_candidates(imp, sprite, "Magma Sprite")
	_check(candidates.size() == 3, "Confluence and both legal Imprint subtype choices are generated")
	_check(candidates[0].attack == 10 and candidates[0].max_hp == 8, "Confluence stats sum")
	_check(candidates[1].attack == 10 and candidates[1].max_hp == 5, "Imprint stats use component maxima")
	_check(fusion.ability_id(candidates[1].abilities[0]) == "Scald", "Burn and Freeze combine into Scald")
	_check(candidates[0].subtypes == ["Elemental", "Warrior", "Spirit"], "Confluence adds unique subtypes")
	_check(candidates[1].subtypes == ["Elemental", "Warrior"] and candidates[2].subtypes == ["Spirit"], "Imprint chooses one source's subtypes")
	_check(candidates[0].fusion_mode == "confluence" and candidates[1].fusion_mode == "imprint", "Merge expressions use documented names")
	_check(candidates[0].image == imp.image, "First-name source determines merged artwork")
	var same_element := fusion.result_candidates(db.get_card("ember_pup"), db.get_card("cinder_hound"), "Ember Hound")
	_check(same_element.size() == 1 and same_element[0].fusion_mode == "confluence" and same_element[0].element_tags == ["Fire"], "Same-element cards offer only Fire Confluence")
	var hound := db.get_card("cinder_hound")
	var mage := db.get_card("water_mage")
	var choices := fusion.result_candidates(hound, mage, "Cinder Mage")
	_check(choices.size() == 9, "Undefined pair produces ability and subtype choices for every Imprint cost")
	_check(choices[1].abilities[0].id == "Strike" and choices[3].abilities[0].id == "Freeze", "Imprint source ability choice is preserved")
	_check(int(sprite.abilities[0].cost.Water) == 1 and int(mage.abilities[0].cost.Water) == 2, "Ability cost is tunable per card")
	_check(db.get_card("pillar_steam").deck_eligible == false, "Hybrid Pillars cannot be put in decks")
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
	print("ELEMENTALS RULE TESTS: %d failure(s)" % failures)
	quit(failures)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
