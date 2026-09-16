extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._show_screen("Match")
	await process_frame
	_check(not game.match_state.has("phase"), "Match has no action phases")
	_check(game.match_state.player.board.size() == 32, "Battlefield is a fixed 4 by 8 array")
	_check(game.opponent_hand.get_child_count() == game.match_state.bot.hand.size(), "Opponent hand shows one portrait per card")
	_check(game.match_state.player.foundation == "pillar_fire" and game.match_state.player.vanguard == "ember_pup", "Foundation and Vanguard begin outside the hand")
	_check(game.player_start_zone.get_child_count() == 2 and game.bot_start_zone.get_child_count() == 2, "Both public starting zones are rendered")

	game.match_state.player.hand = ["pillar_fire"]
	game.match_state.player.mana = {}
	game.match_state.player.pillars = []
	game._play_hand_card(0)
	_check(game.match_state.player.mana.is_empty(), "Pillar waits until end of turn to produce mana")
	_check(game.match_state.player.pillars.size() == 1, "Pillar enters its unlimited dedicated row")
	game._prepare_reserve(game.match_state.player)
	_check(game.match_state.player.reserve == {"Fire":1}, "Pillar produces next-turn reserve at end of turn")

	game.match_state.player.pillars = [game._pillar_record("pillar_fire"), game._pillar_record("pillar_water")]
	game.match_state.player.mana = {}
	game._begin_pillar_merge(0)
	game._pillar_clicked(1)
	_check(game.match_state.player.pillars.size() == 1 and game.match_state.player.pillars[0].element == "Steam", "Click selection merges compatible Pillars")
	_check(not game.match_state.player.mana.has("Steam"), "Merged Pillar does not produce mana immediately")
	game._prepare_reserve(game.match_state.player)
	_check(game.match_state.player.reserve == {"Steam":1}, "Merged Pillar produces hybrid reserve at end of turn")
	game.match_state.player.pillars = [game._pillar_record("pillar_fire"), game._pillar_record("pillar_fire"), game._pillar_record("pillar_fire")]
	game._refresh_match()
	await game._produce_pillar_mana_animated(game.match_state.player, game.player_pillars)
	_check(game.match_state.player.reserve == {"Fire":3}, "Grouped Pillar animation produces its full displayed quantity")

	game.match_state.player.board.fill(null)
	game.match_state.player.hand = ["ember_pup"]
	game.match_state.player.mana = {"Fire":1}
	game._play_hand_card(0)
	_check(_occupied(game.match_state.player.board) == 1, "Card is placed in one random empty slot")

	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[4] = game._unit_record(game.database.get_card("water_sprite"))
	game.match_state.player.board[5] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.bot.board[17] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.mana = {"Water":1}
	game._activate_ability(4, 0)
	_check(game.match_state.targeting.get("kind", "") == "ability", "Targeted ability enters selection mode")
	game._enemy_slot_clicked(17)
	_check(game.match_state.bot.board[17].frozen == true and game.match_state.player.mana.Water == 0, "Freeze spends its per-card cost on the selected target")
	var hp_before: int = game.match_state.bot.hp
	var combat_started := Time.get_ticks_msec()
	await game._resolve_combat_animated(game.match_state.player, game.match_state.bot, true)
	var combat_seconds := float(Time.get_ticks_msec() - combat_started) / 1000.0
	print("Combat duration: %.3f seconds" % combat_seconds)
	_check(game.COMBAT_DURATION == 2.0 and combat_seconds >= 1.5 and combat_seconds <= 2.6, "Automatic attack sequence is configured and paced across about two seconds")
	_check(game.match_state.bot.hp < hp_before, "Animated combat applies damage")

	game.match_state.bot.hp = 100
	game._apply_on_play(game.database.get_card("ash_wisp"), game.match_state.bot)
	_check(game.match_state.bot.hp == 98, "Scorch uses the strength stored on the card")

	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[2] = game._unit_record(game.database.get_card("cinder_hound"))
	game.match_state.bot.board[20] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.mana = {"Fire":1}
	game._activate_ability(2, 0)
	_check(game.match_state.player.board[2].strike_ready and game.match_state.player.mana.Fire == 0, "Strike pays its per-card cost and arms the creature")
	var face_before_strike: int = game.match_state.bot.hp
	await game._resolve_combat_animated(game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.bot.board[20] == null and game.match_state.bot.hp == face_before_strike, "Strike attacks an opposing creature instead of the opponent")
	_check(game.match_state.player.board[2].hp == 1, "Strike exchanges creature damage concurrently")

	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[3] = game._unit_record(game.database.get_card("magma_reaver"))
	var burn_hp_before: int = game.match_state.bot.hp
	await game._resolve_combat_animated(game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.bot.hp == burn_hp_before - 11, "Burn adds its numeric strength to a face attack")

	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("inferno_tyrant"))
	game.match_state.player.board[1].strike_ready = true
	game.match_state.bot.board[7] = game._unit_record(game.database.get_card("ash_phoenix"))
	var spark_hp_before: int = game.match_state.player.hp
	await game._resolve_combat_animated(game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.player.hp == spark_hp_before - 3, "Last Spark deals its numeric strength when destroyed")

	var pillar: Dictionary = game.database.get_card("pillar_fire")
	game.store.profile.collection[pillar.id] = 10
	_check(game._deck_copy_limit(pillar) == 10, "Pillar deck limit equals owned copies, not three")
	var creature: Dictionary = game.database.get_card("ember_pup")
	game.store.profile.collection[creature.id] = 10
	_check(game._deck_copy_limit(creature) == 3, "Ordinary card deck limit remains three")
	game.fusion_sources.assign(["ember_pup", "water_sprite"])
	game._show_screen("Forge")
	await process_frame
	var sources: HBoxContainer = game.content.find_child("Sources", true, false)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	sources.get_child(0).gui_input.emit(wheel)
	_check(game.fusion_sources.size() == 2, "Mouse wheel scrolling does not remove a Forge source")
	var result_scroll: ScrollContainer = game.content.find_child("ResultScroll", true, false)
	_check(result_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Forge combinations have a vertical scrollbar")
	print("ELEMENTALS GAMEPLAY TESTS: %d failure(s)" % failures)
	quit(failures)

func _occupied(board: Array) -> int:
	var count := 0
	for unit in board:
		if unit != null: count += 1
	return count

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
