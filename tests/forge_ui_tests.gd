extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.fusion_sources.assign(["pillar_fire", "pillar_water"])
	game.fusion_selected = 0
	game._show_screen("Forge")
	await process_frame
	var result_scroll: ScrollContainer = game.content.find_child("ResultScroll", true, false)
	var imprint: GridContainer = game.content.find_child("Imprint", true, false)
	_check(result_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO and result_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and imprint.columns == 2, "Hybrid results use a two-column vertical browser")
	_check(game.fusion_candidates.size() == 2 and str(game.fusion_candidates[0].existing_card_id) == "pillar_steam_fire" and str(game.fusion_candidates[1].existing_card_id) == "pillar_steam_water", "Base Pillars expose both attuned hybrid results")
	var captions: Array = imprint.find_children("*", "Label", true, false).filter(func(label): return "stats " in str(label.text) or "abilities " in str(label.text))
	_check(captions.is_empty(), "Result previews show only final card content")
	var collection_scroll: ScrollContainer = game.content.find_child("ForgeCollectionScroll", true, false)
	var pillar_buttons: Array = collection_scroll.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("card_id", "")) == "pillar_fire")
	var fire_filters: Array = game.content.find_children("*", "Button", true, false).filter(func(button): return button.toggle_mode and button.text == "Fire")
	_check(not pillar_buttons.is_empty() and not fire_filters.is_empty(), "Forge uses the filtered deckbuilder collection and includes base Pillars")
	var source_ids: Array[String] = ["pillar_fire", "pillar_water"]
	_check(game._preserved_fusion_sources(source_ids).size() == 2 and game.fusion_selected == 0, "Sources and selected result can remain armed while copies remain")
	print("ELEMENTALS FORGE UI TESTS: %d failure(s)" % failures)
	quit(failures)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
