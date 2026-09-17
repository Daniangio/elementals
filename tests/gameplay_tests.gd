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
	var active_deck: Dictionary = game.profile.decks[str(game.profile.get("active_deck_id", "starter"))]
	_check(game.match_state.player.foundation == str(active_deck.foundation_id) and game.match_state.player.vanguard == str(active_deck.vanguard_id), "Foundation and Vanguard come from the active deck outside the hand")
	_check(game.player_start_zone.get_child_count() == 2 and game.bot_start_zone.get_child_count() == 2, "Both public starting zones are rendered")
	var fireball_card: Control = game._full_card(game.database.get_card("fireball"), -1)
	var fireball_text: Label = fireball_card.find_child("AbilityText", true, false)
	_check(fireball_text != null and "6 damage" in fireball_text.text and not fireball_text.text.begins_with("Fireball"), "Spell cards print their rules description instead of the spell ability name")
	var scorch_card: Control = game._full_card(game.database.get_card("ash_wisp"), -1)
	var scorch_text: Label = scorch_card.find_child("AbilityText", true, false)
	_check(scorch_text != null and scorch_text.text == "Scorch 2" and "any player or card with HP" in scorch_text.tooltip_text, "Keyword labels expose a textual rules panel on hover")
	fireball_card.queue_free()
	scorch_card.queue_free()

	game.match_state.player.hand = ["pillar_fire"]
	game.match_state.player.mana = {}
	game.match_state.player.pillars = []
	game._play_hand_card(0)
	_check(game.match_state.player.mana.is_empty(), "Pillar waits until end of turn to produce mana")
	_check(game.match_state.player.pillars.size() == 1, "Pillar enters its unlimited dedicated row")
	game._add_pillar_mana(game.match_state.player)
	_check(game.match_state.player.mana == {"Fire":1}, "Pillar adds mana at end of turn")

	game.match_state.player.pillars = [game._pillar_record("pillar_fire"), game._pillar_record("pillar_water")]
	game.match_state.player.mana = {}
	game._begin_pillar_merge(0)
	game._pillar_clicked(1)
	_check(game.match_state.targeting.get("kind", "") == "pillar_attune" and game.get_node_or_null("AttuneOverlay") != null, "Merging compatible Pillars opens the Attune choice")
	game._complete_pillar_attunement(0, 1, "pillar_steam_fire")
	_check(game.match_state.player.pillars.size() == 1 and game.match_state.player.pillars[0].element == "Steam" and game.match_state.player.pillars[0].card_id == "pillar_steam_fire", "Fire Attunement creates the matching Steam Pillar")
	_check(not game.match_state.player.mana.has("Steam"), "Merged Pillar does not produce mana immediately")
	game._add_pillar_mana(game.match_state.player)
	_check(game.match_state.player.mana == {"Steam":1}, "Merged Pillar produces hybrid mana at end of turn")
	game.match_state.player.hand = ["pillar_steam_fire"]
	game.match_state.player.mana = {}
	game._play_hand_card(0)
	_check(game.match_state.player.hand.size() == 1, "Attuned Steam Pillar cannot be played without its base mana cost")
	game.match_state.player.mana = {"Fire":1}
	game._play_hand_card(0)
	_check(game.match_state.player.hand.is_empty() and game.match_state.player.mana.Fire == 0 and game.match_state.player.pillars[-1].card_id == "pillar_steam_fire", "Decked Fire-attuned Steam Pillar costs 1 Fire to play")
	game.match_state.player.pillars = [game._pillar_record("pillar_fire"), game._pillar_record("pillar_fire"), game._pillar_record("pillar_fire"), game._pillar_record("pillar_fire"), game._pillar_record("pillar_fire")]
	game.match_state.player.mana = {"Fire":2}
	game._refresh_match()
	await game._produce_pillar_mana_animated(game.match_state.player, game.player_pillars)
	_check(game.match_state.player.mana == {"Fire":7}, "Five Pillars accumulate on two unspent mana to make seven")
	var displayed_fire := false
	for cell in game.player_mana.get_children():
		if cell.tooltip_text == "Fire mana" and cell.get_child(0).get_child(1).text == "7": displayed_fire = true
	_check(displayed_fire, "Mana UI updates when the production animation begins")

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
	_check(int(game.match_state.bot.board[17].frozen) == 1 and game.match_state.player.mana.Water == 0, "Freeze spends its per-card cost on the selected target")
	game.match_state.player.mana = {"Water":1}
	game._activate_ability(4, 0)
	_check(game.match_state.targeting.is_empty() and game.match_state.player.mana.Water == 1, "An activated ability can be used only once per turn")
	game.match_state.bot.board[18] = game._unit_record(game.database.get_card("inferno_tyrant"))
	game.match_state.player.board[6] = game._unit_record(game.database.get_card("ancient_sea_drake"))
	game.match_state.player.mana = {"Water":1}
	game._activate_ability(6, 0)
	_check(game.match_state.targeting.get("kind", "") == "ability" and int(game.match_state.targeting.ability.strength) == 2, "Freeze 2 is an activated targeted ability")
	game._enemy_slot_clicked(18)
	_check(int(game.match_state.bot.board[18].frozen) == 2 and int(game.match_state.bot.board[17].frozen) == 1, "Freeze strength sets the chosen creature's remaining frozen combats")
	game.match_state.player.board[7] = game._unit_record(game.database.get_card("cold_current"))
	game.match_state.player.board[7].frozen = 1
	game.match_state.player.mana = {"Water":1}
	game._activate_ability(7, 0)
	_check(game.match_state.targeting.is_empty() and game.match_state.player.mana.Water == 1, "Frozen cards cannot activate abilities")
	game._refresh_match()
	_check(game.bot_slot_nodes[18].find_child("FreezeOverlay", true, false) != null, "A frozen card keeps a visible ice overlay and duration")
	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.bot.board[2] = game._unit_record(game.database.get_card("cold_current"))
	game.match_state.bot.mana = {"Water":1}
	game.match_state.player.board[3] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.board[4] = game._unit_record(game.database.get_card("inferno_tyrant"))
	game._bot_activate_board_abilities(game.match_state.bot, game.match_state.player)
	_check(int(game.match_state.player.board[4].frozen) == 1 and int(game.match_state.player.board[3].frozen) == 0 and game.match_state.bot.mana.Water == 0, "Bot Freeze pays its cost and targets the highest-value opponent")
	game.match_state.bot.board[2].frozen = 1
	game.match_state.bot.board[2].abilities_used = {}
	game.match_state.bot.mana = {"Water":1}
	game._bot_activate_board_abilities(game.match_state.bot, game.match_state.player)
	_check(game.match_state.bot.mana.Water == 1 and game.match_state.bot.board[2].abilities_used.is_empty(), "Frozen bot cards cannot activate abilities")
	game.match_state.bot.board[19] = game._unit_record(game.database.get_card("ember_pup"))
	game._refresh_match()
	var bot_hand_before_bounce: int = game.match_state.bot.hand.size()
	game._apply_on_play(game.database.get_card("abyssal_leviathan"), game.match_state.bot)
	_check(game.match_state.bot.hand.size() == bot_hand_before_bounce + 2 and _occupied(game.match_state.bot.board) == 0, "Bounce 2 returns two opposing creatures to their owner's hand")
	_check(game.get_children().any(func(child): return child is PanelContainer and child.z_index == 700), "Bounced cards leave behind an animated portrait")
	game.match_state.bot.board.fill(null)
	var hp_before: int = game.match_state.bot.hp
	var combat_started := Time.get_ticks_msec()
	await game._resolve_combat_animated(game.match_state.player, game.match_state.bot, true)
	var combat_seconds := float(Time.get_ticks_msec() - combat_started) / 1000.0
	print("Combat duration: %.3f seconds" % combat_seconds)
	_check(game.COMBAT_DURATION == 2.0 and combat_seconds >= 1.5 and combat_seconds <= 2.6, "Automatic attack sequence is configured and paced across about two seconds")
	_check(game.match_state.bot.hp < hp_before, "Animated combat applies damage")

	game.match_state.bot.hp = 100
	game._apply_on_play(game.database.get_card("ash_wisp"), game.match_state.bot)
	game._refresh_match()
	_check(game.match_state.targeting.get("effect", "") == "damage" and game.bot_hp_bar.get_node_or_null("AimMarker") != null, "Scorch exposes aim markers for selectable targets")
	game._resolve_player_effect_target("bot", -1, true)
	_check(game.match_state.bot.hp == 98 and int(game.bot_hp_bar.get_node("Damage").value) == 98, "Scorch damage and HP UI update together")
	_check(game.bot_hp_bar.get_child_count() > 3, "Scorch animates damage at the opponent HP bar")

	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.bot.board[4] = game._unit_record(game.database.get_card("ember_pup"))
	game._begin_player_spell(game.database.get_card("fireball"))
	game._resolve_player_effect_target("bot", 4, false)
	_check(game.match_state.bot.board[4] == null, "Fireball can target and destroy a card")
	game.match_state.bot.board[2] = game._unit_record(game.database.get_card("cinder_hound"))
	game.match_state.bot.board[3] = game._unit_record(game.database.get_card("ancient_tree"))
	game._resolve_spell(game.database.get_card("fire_rain"), game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.bot.board[2].hp == 1 and game.match_state.bot.board[3].hp == 8, "Fire Rain damages all enemy creatures and structures")
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.mana = {}
	game._begin_player_spell(game.database.get_card("ember_offering"))
	game._resolve_player_effect_target("player", 1, false)
	_check(game.match_state.player.board[1] == null and game.match_state.player.mana.Fire == 8, "Ember Offering sacrifices a creature and grants 8 Fire")
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("cinder_hound"))
	game._begin_player_spell(game.database.get_card("berserker_draught"))
	game._resolve_player_effect_target("player", 1, false)
	_check(game.match_state.player.board[1] == null, "Berserker Draught applies +5 ATK and -3 HP, including lethal HP loss")
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.deck = ["ember_pup", "cinder_hound"]
	var hand_before_bargain: int = game.match_state.player.hand.size()
	game._begin_player_spell(game.database.get_card("ashen_bargain"))
	game._resolve_player_effect_target("player", 1, false)
	_check(game.match_state.player.board[1] == null and game.match_state.player.hand.size() == hand_before_bargain + 2, "Ashen Bargain sacrifices a creature and draws two cards")
	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.board[2] = game._unit_record(game.database.get_card("magma_reaver"))
	game.match_state.player.board[2].hp = 5
	var heuristic_target: Dictionary = game._bot_damage_target(2)
	_check(not heuristic_target.player and int(heuristic_target.slot) == 1, "Bot damage targeting prioritizes a low-HP kill before nonlethal threats")
	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.bot.board[0] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.cinder_ward_turns = 3
	game._refresh_match()
	_check(game.player_board.get_node_or_null("CinderWard") != null, "Cinder Ward renders an animated fire line on the battlefield")
	var ward_hp_before: int = game.match_state.player.hp
	await game._resolve_combat_animated(game.match_state.bot, game.match_state.player, false)
	_check(game.match_state.player.hp == ward_hp_before - 2 and game.match_state.bot.board[0] == null, "Cinder Ward retaliates concurrently against face attackers")
	_check(game.match_state.player.cinder_ward_turns == 2, "Cinder Ward lasts three opposing combat phases")

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
	game.match_state.player.board[6] = game._unit_record(game.database.get_card("cinder_hound"))
	game.match_state.bot.board[10] = game._unit_record(game.database.get_card("leviathan_whelp"))
	game._refresh_match()
	_check(game.bot_slot_nodes[10].find_child("ShellOverlay", true, false) != null and game.bot_slot_nodes[10].find_child("ProvokeIcon", true, false) != null, "Shell and Provoke have persistent battlefield indicators")
	var provoke_face_before: int = game.match_state.bot.hp
	await game._resolve_combat_animated(game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.bot.hp == provoke_face_before, "Provoke redirects an ordinary face attacker into creature combat")
	_check(game.match_state.bot.board[10] != null and game.match_state.bot.board[10].hp == 11, "Shell 2 reduces three incoming combat damage to one")

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

	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("sprout_caller"))
	game._apply_on_play(game.database.get_card("sprout_caller"), game.match_state.bot, true, 0)
	_check(_occupied(game.match_state.player.board) == 2 and game.match_state.player.board.any(func(unit): return unit != null and unit.id == "sapling_token"), "Enter Spawn Sapling creates a 1/1 token")
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("ancient_gardener"))
	game.match_state.player.mana = {"Nature":1}
	game._activate_ability(0, 1)
	_check(game.match_state.player.mana.Nature == 0 and _occupied(game.match_state.player.board) == 2, "Activated Spawn Sapling pays one Nature and creates a token")
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("young_grovekeeper"))
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("inferno_tyrant"))
	game._apply_turn_start(game.match_state.player)
	_check(game.match_state.player.board[1].attack == 19 and game.match_state.player.board[1].max_hp == 9, "Nurture permanently gives the highest-value other creature +1/+1")
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("spore_druid"))
	game._apply_turn_start(game.match_state.player)
	_check(_occupied(game.match_state.player.board) == 2, "Sprout creates a Sapling at turn start")
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("elf_banneret"))
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("leaf_elf"))
	game._refresh_nature_bonuses(game.match_state.player)
	_check(game.match_state.player.board[1].attack == 3 and game.match_state.player.board[0].attack == 2, "Elf Chorus buffs other Elves but not its source")
	game.match_state.player.board[2] = game._unit_record(game.database.get_card("wildheart_beast"))
	game.match_state.player.board[3] = game._unit_record(game.database.get_card("fire_charger"))
	game._refresh_nature_bonuses(game.match_state.player)
	_check(game.match_state.player.board[2].attack == 6 and game.match_state.player.board[2].max_hp == 7, "Pack Growth gains +1/+1 for another shared-subtype creature")
	game.match_state.player.board[4] = game._unit_record(game.database.get_card("worldroot_treant"))
	game._apply_on_play(game.database.get_card("worldroot_treant"), game.match_state.bot, true, 4)
	_check(game.match_state.player.board[1].max_hp == 3, "Grove Blessing grants permanent HP to every friendly creature")
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("ancient_forest_spirit"))
	game._apply_on_play(game.database.get_card("ancient_forest_spirit"), game.match_state.bot, true, 0)
	_check(_occupied(game.match_state.player.board) == 2 and game.match_state.player.board[0].attack == 8 and game.match_state.player.board[0].max_hp == 11, "Elder Call creates a 2/2 token and Living Grove grants +1/+1")

	var pillar: Dictionary = game.database.get_card("pillar_fire")
	game.store.profile.collection[pillar.id] = 10
	_check(game._deck_copy_limit(pillar) == 10, "Pillar deck limit equals owned copies, not three")
	var creature: Dictionary = game.database.get_card("ember_pup")
	game.store.profile.collection[creature.id] = 10
	_check(game._deck_copy_limit(creature) == 3, "Ordinary card deck limit remains three")
	game._show_screen("Collection")
	await process_frame
	var collection_pages: TabContainer
	for node in game.content.find_children("*", "TabContainer", true, false): collection_pages = node
	_check(collection_pages != null and collection_pages.get_tab_count() == 2, "Collection separates Cards and Items into full-height pages")
	game.editing_deck_id = "starter"
	game._show_screen("DeckEditor")
	await process_frame
	game._begin_special_selection("foundation")
	game._add_card_to_deck("pillar_water")
	_check(game.deck_foundation == "pillar_water" and game.deck_special_target.is_empty(), "Collection click replaces the selected Foundation")
	_check(game.deck_foundation_box.get_children().filter(func(child): return child.name == "Preview").size() == 1, "Foundation selector renders exactly one card")
	game._save_deck()
	_check(game.get_node_or_null("DeckNameDialog") != null, "Saving a valid deck asks for its display name")
	if game.get_node_or_null("DeckNameDialog") != null: game.get_node("DeckNameDialog").queue_free()
	var original_active := str(game.profile.get("active_deck_id", "starter"))
	game.profile.decks["test_active_deck"] = game.profile.decks.starter.duplicate(true)
	game.profile.decks.test_active_deck.foundation_id = "pillar_water"
	game.profile.active_deck_id = "test_active_deck"
	game._new_match()
	_check(game.match_state.player.foundation == "pillar_water", "New matches load the profile's selected active deck")
	game.profile.decks.erase("test_active_deck")
	game.profile.active_deck_id = original_active
	var first_seed: int = game.match_state.rng.seed
	game._new_match()
	_check(game.match_state.rng.seed != first_seed, "Each match uses a newly randomized shuffle seed")
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
	_check(result_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO and result_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Forge Imprint combinations scroll horizontally")
	var saved_currency := int(game.profile.get("currency", 0))
	var pillar_owned_before := int(game.profile.collection.get("pillar_fire", 0))
	game.profile.currency = 12
	game._buy_single_card("pillar_fire")
	_check(game.profile.currency == 0 and int(game.profile.collection.pillar_fire) == pillar_owned_before + 1, "Bazaar buys the configured base Pillar for 12 crowns")
	game._buy_single_card("pillar_fire")
	_check(int(game.profile.collection.pillar_fire) == pillar_owned_before + 1, "Bazaar rejects a single-card purchase without enough crowns")
	_check(game.game_config.single_cards.size() == 3 and not game.game_config.single_cards.has("pillar_steam_fire"), "Initial single-card catalog contains only the three base Pillars")
	game.profile.collection.pillar_fire = pillar_owned_before
	game.profile.currency = saved_currency
	var saved_xp := int(game.profile.get("xp", 0))
	game._finish_match("You win.", true)
	await create_timer(1.25).timeout
	_check(game.current_screen == "Lobby", "A completed match returns to the Lobby")
	game.profile.xp = saved_xp
	game.profile.currency = saved_currency
	game.store.save_profile()
	game._show_screen("Match")
	game._surrender_match()
	_check(game.current_screen == "Lobby", "Surrender returns to the Lobby")
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
