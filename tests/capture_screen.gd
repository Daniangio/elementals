extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(OS.get_environment("CAPTURE_WIDTH")), int(OS.get_environment("CAPTURE_HEIGHT")))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var scene: Control = load("res://Main.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	var requested := OS.get_environment("ELEMENTALS_SCREEN")
	if requested == "Fusion":
		scene.fusion_sources.clear()
		scene.fusion_sources.append("magma_reaver")
		scene.fusion_sources.append("water_sprite")
		scene.fusion_selected = 1
		scene._show_screen("Fusion")
	elif requested == "Match":
		scene.match_state.player.pillars = [scene._pillar_record("pillar_fire"), scene._pillar_record("pillar_water")]
		scene.match_state.bot.pillars = [scene._pillar_record("pillar_steam_fire")]
		scene.match_state.player.board[5] = scene._unit_record(scene.database.get_card("water_sprite"))
		scene.match_state.bot.board[18] = scene._unit_record(scene.database.get_card("cinder_hound"))
		scene._refresh_match()
	await process_frame
	if OS.get_environment("ELEMENTALS_HOVER") == "1":
		var hover_id := OS.get_environment("ELEMENTALS_HOVER_CARD")
		if hover_id.is_empty(): hover_id = "cinder_hound"
		var hover_card: Dictionary = scene.database.get_card(hover_id)
		scene._show_card_hover(hover_card, scene._unit_record(hover_card))
		await process_frame
	if requested == "Match" and OS.get_environment("ELEMENTALS_ABILITY") == "1":
		scene._flash_board_ability(5, {"id":"Freeze", "cost":{"Water":1}}, true)
		await create_timer(0.12).timeout
	if requested == "Match" and OS.get_environment("ELEMENTALS_TARGETING") == "1":
		scene._apply_on_play(scene.database.get_card("ash_wisp"), scene.match_state.bot, true, 5)
		scene._refresh_match()
		await process_frame
	if requested == "Match" and OS.get_environment("ELEMENTALS_WARD") == "1":
		scene.match_state.player.cinder_ward_turns = 3
		scene._refresh_match()
		await process_frame
	if requested == "Match" and OS.get_environment("ELEMENTALS_ATTUNE") == "1":
		scene._begin_pillar_merge(0)
		scene._pillar_clicked(1)
		await process_frame
	if requested == "Match" and OS.get_environment("ELEMENTALS_ANIMATION") == "1":
		var attacker: Control = scene.player_slot_nodes[5]
		scene._attack_wave(attacker)
		scene._floating_damage(scene.bot_stats, 5)
		await create_timer(0.14).timeout
	if OS.get_environment("ELEMENTALS_PACK") == "1":
		var preview_cards: Array[String] = ["ember_spark", "ember_pup", "ash_wisp", "cinder_hound", "water_sprite", "vineling", "ash_phoenix", "fireball"]
		scene._show_unpacking_overlay("Elemental Core Pack", preview_cards)
		await process_frame
	if OS.get_environment("ELEMENTALS_FUSION_RESULT") == "1":
		scene._show_fusion_result_overlay(scene.database.get_card("magma_reaver"), scene.database.get_card("water_sprite"), scene.fusion_candidates[scene.fusion_selected])
		await create_timer(1.4).timeout
	await process_frame
	var image := viewport.get_texture().get_image()
	var output := OS.get_environment("ELEMENTALS_CAPTURE_PATH")
	var error := image.save_png(output)
	print("CAPTURE %s viewport=%s scene=%s minimum=%s content_min=%s child_min=%s error=%s" % [OS.get_environment("ELEMENTALS_SCREEN"), viewport.size, scene.size, scene.get_combined_minimum_size(), scene.content.get_combined_minimum_size(), scene.content.get_child(0).get_combined_minimum_size(), error])
	quit(0 if error == OK else 1)
