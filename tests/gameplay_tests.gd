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
	var footer_y: float = game.end_turn_button.global_position.y
	for dense_slot in 18: game.match_state.player.board[dense_slot] = game._unit_record(game.database.get_card("ember_pup"))
	game._refresh_match()
	await process_frame
	_check(is_equal_approx(game.end_turn_button.global_position.y, footer_y) and game.end_turn_button.global_position.y + game.end_turn_button.size.y <= game.size.y, "Dense creature rows scroll inside a fixed battlefield without moving End Turn")
	game.match_state.player.board.fill(null)
	game._refresh_match()
	await process_frame
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

	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("sea_egg"))
	_check(game.match_state.player.board[0].clock == 3, "Sea Egg enters with Clock 3")
	game._apply_freeze_to_unit(game.match_state.player, 0, 2, true)
	_check(game.match_state.player.board[0].id == "sea_egg" and game.match_state.player.board[0].clock == 1 and game.match_state.player.board[0].frozen == 0, "Freeze accelerates a Sea Egg instead of freezing it")
	game._apply_freeze_to_unit(game.match_state.player, 0, 1, true)
	_check(game.match_state.player.board[0].id == "sea_drake" and game.match_state.player.board[0].attack == 5, "A Sea Egg hatches immediately when Freeze reduces Clock to zero")
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("sea_egg"))
	game.match_state.player.board[0].clock = 2
	await game._resolve_clocks_animated(game.match_state.player, "player")
	await game._resolve_clocks_animated(game.match_state.player, "player")
	_check(game.match_state.player.board[0].id == "sea_drake", "Sea Egg Clock advances and hatches at its owner's end turn")

	game.match_state.player.hp = 80
	game.match_state.player.burn = 4
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.board[1].burn = 3
	game._resolve_spell(game.database.get_card("clear_the_tide"), game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.player.hp == 86 and game.match_state.player.burn == 0 and game.match_state.player.board[1].burn == 0, "Clear the Tide removes friendly Burn and restores 6 player HP")
	game.match_state.player.board.fill(null)
	game._resolve_spell(game.database.get_card("sea_nursery"), game.match_state.player, game.match_state.bot, true)
	_check(_occupied(game.match_state.player.board) == 2 and game.match_state.player.board.all(func(unit): return unit == null or unit.id == "sea_egg"), "Sea Nursery creates two Sea Eggs")
	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("sea_egg"))
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.bot.board[2] = game._unit_record(game.database.get_card("inferno_tyrant"))
	var discard_before_deep_freeze: int = game.match_state.player.discard.size()
	game._begin_player_spell(game.database.get_card("deep_freeze"))
	game._resolve_player_effect_target("player", 0, false)
	game._resolve_player_effect_target("player", 1, false)
	game._resolve_player_effect_target("bot", 2, false)
	_check(game.match_state.player.board[0].clock == 1 and game.match_state.player.board[1].frozen == 2 and game.match_state.bot.board[2].frozen == 2 and game.match_state.targeting.is_empty() and game.match_state.player.discard.size() == discard_before_deep_freeze + 1, "Deep Freeze selects three creatures and accelerates friendly Eggs")
	game.match_state.player.board.fill(null)
	game._resolve_spell(game.database.get_card("mass_incubation"), game.match_state.player, game.match_state.bot, true)
	_check(_occupied(game.match_state.player.board) == 6, "Mass Incubation creates six Sea Eggs")
	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("sea_egg"))
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.bot.board[2] = game._unit_record(game.database.get_card("sea_egg"))
	game.match_state.bot.board[3] = game._unit_record(game.database.get_card("cinder_hound"))
	game._resolve_spell(game.database.get_card("blizzard"), game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.player.board[0].clock == 1 and game.match_state.bot.board[2].clock == 1 and game.match_state.player.board[1].frozen == 2 and game.match_state.bot.board[3].frozen == 2, "Blizzard freezes both boards while accelerating every Sea Egg")
	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.bot.board[0] = game._unit_record(game.database.get_card("sea_egg"))
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.board[2] = game._unit_record(game.database.get_card("inferno_tyrant"))
	game._resolve_bot_spell(game.database.get_card("deep_freeze"))
	_check(game.match_state.bot.board[0].clock == 1 and game.match_state.player.board[1].frozen == 2 and game.match_state.player.board[2].frozen == 2, "Bot Deep Freeze accelerates its Egg and freezes the highest-value opposing creatures")

	game.match_state.bot.board[19] = game._unit_record(game.database.get_card("ember_pup"))
	game._refresh_match()
	var bot_hand_before_bounce: int = game.match_state.bot.hand.size()
	game._apply_on_play(game.database.get_card("abyssal_leviathan"), game.match_state.bot)
	_check(game.match_state.bot.hand.size() == bot_hand_before_bounce + 2 and _occupied(game.match_state.bot.board) == 0, "Bounce 2 returns two opposing creatures to their owner's hand")
	_check(game.get_children().any(func(child): return child is PanelContainer and child.z_index == 700), "Bounced cards leave behind an animated portrait")
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("ember_pup"))
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
	game._bot_apply_burn_target(2)
	_check(game.match_state.player.board[1].burn == 2, "Bot Burn targeting prioritizes a lethal end-of-turn creature stack")
	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.bot.board[0] = game._unit_record(game.database.get_card("ember_pup"))
	game.match_state.player.cinder_ward_turns = 3
	game._refresh_match()
	await process_frame
	var ward_particles: Control = game.player_board_area.get_node_or_null("CinderWardParticles")
	_check(ward_particles != null and ward_particles.get_node_or_null("FireEdge") != null and ward_particles.find_children("FlameParticle_*", "Panel", true, false).size() == 30, "Cinder Ward renders particles along the bottom battlefield edge")
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
	_check(game.match_state.bot.hp == burn_hp_before - 10 and game.match_state.bot.burn == 1, "Burn adds a delayed stack instead of immediate attack damage")
	await game._resolve_combat_animated(game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.bot.burn == 2, "Burn stacks when the same creature attacks repeatedly")
	var stacked_burn_hp: int = game.match_state.bot.hp
	await game._resolve_burn_animated(game.match_state.bot, "bot")
	_check(game.match_state.bot.hp == stacked_burn_hp - 2 and game.match_state.bot.burn == 0, "Player Burn resolves and clears at the end of its owner's turn")

	game.match_state.player.board.fill(null)
	game.match_state.bot.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("ember_pup"))
	game._begin_player_spell(game.database.get_card("searing_brand"))
	game._resolve_player_effect_target("player", 0, false)
	_check(game.match_state.player.board[0].burn == 3, "Searing Brand can add Burn to a creature")
	await game._resolve_burn_animated(game.match_state.player, "player")
	_check(game.match_state.player.board[0] == null, "Creature Burn deals damage at the end of that creature owner's turn")
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("magma_reaver"))
	game._begin_player_spell(game.database.get_card("ember_infusion"))
	game._resolve_player_effect_target("player", 0, false)
	_check(game.match_state.player.board[0].bonus_burn == 2, "Ember Infusion grants a persistent additional Burn ability")
	var infusion_hp_before: int = game.match_state.bot.hp
	await game._resolve_combat_animated(game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.bot.hp == infusion_hp_before - 10 and game.match_state.bot.burn == 3, "Granted Burn stacks with printed Burn on attack")

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
	_check(_occupied(game.match_state.player.board) == 2 and game.match_state.player.board.any(func(unit): return unit != null and unit.id == "sapling"), "Enter Spawn Sapling creates a 1/1 token")
	game._refresh_match()
	await process_frame
	_check(game.player_board.find_children("NatureAnimation", "Control", true, false).size() > 0, "Spawn Sapling animates its arriving token")
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
	game._refresh_match()
	await process_frame
	_check(game.player_board.find_children("NatureAnimation", "Control", true, false).size() > 0, "Nurture animates its growth target")
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
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("vineling"))
	game._apply_turn_start(game.match_state.player)
	_check(game.match_state.player.board[0].attack == 2 and game.match_state.player.board[0].hp == 3 and game.match_state.player.board[0].max_hp == 3, "Growth grants +1 ATK and +1 current and maximum HP each turn")
	var hand_before_nature: int = game.match_state.player.hand.size()
	game._resolve_spell(game.database.get_card("first_sprout"), game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.player.hand.size() == hand_before_nature + 2 and game.match_state.player.hand[-1] == "seed_elf", "First Sprout adds two Seed Elves to hand")
	game.match_state.player.board.fill(null)
	game._resolve_spell(game.database.get_card("grove_muster"), game.match_state.player, game.match_state.bot, true)
	_check(_occupied(game.match_state.player.board) == 2 and game.match_state.player.board.any(func(unit): return unit != null and unit.id == "elder_sapling"), "Grove Muster creates two Elder Saplings")
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("leaf_elf"))
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("seed_elf"))
	game._resolve_spell(game.database.get_card("elf_chorus_spell"), game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.player.board[0].attack == 3 and game.match_state.player.board[1].attack == 2, "Elf Chorus permanently buffs every friendly Elf")
	game._resolve_spell(game.database.get_card("canopy_of_ages"), game.match_state.player, game.match_state.bot, true)
	_check(game.match_state.player.board[0].temporary_shell == 2 and game.match_state.player.board[0].temporary_shell_turns == 2, "Canopy of Ages grants temporary Shell 2 for two turns")
	game.match_state.bot.board.fill(null)
	game.match_state.bot.board[0] = game._unit_record(game.database.get_card("cinder_hound"))
	game._resolve_spell(game.database.get_card("spore_cloud"), game.match_state.player, game.match_state.bot, true)
	_check(_occupied(game.match_state.bot.board) == 3, "Spore Cloud creates two Spores on the opposing battlefield")
	await game._resolve_spore_attrition_animated(game.match_state.bot, "bot")
	_check(game.match_state.bot.board[0].attack == 1, "Each Spore applies permanent end-turn ATK attrition")
	game.match_state.player.board.fill(null)
	game.match_state.player.board[0] = game._unit_record(game.database.get_card("leaf_elf"))
	game.match_state.player.board[1] = game._unit_record(game.database.get_card("seedling"))
	var thorn_hp_before: int = game.match_state.bot.hp
	game._begin_player_spell(game.database.get_card("thorn_volley"))
	game._resolve_player_effect_target("bot", -1, true)
	_check(game.match_state.bot.hp == thorn_hp_before - 2, "Thorn Volley deals damage equal to friendly creature count")
	game._resolve_spell(game.database.get_card("verdant_surge"), game.match_state.player, game.match_state.bot, true)
	_check(_occupied(game.match_state.player.board) == 5 and game.match_state.player.board[0].max_hp == 3, "Verdant Surge creates three Seed Elves and grants team HP")
	game._resolve_spell(game.database.get_card("forest_armada"), game.match_state.player, game.match_state.bot, true)
	_check(_occupied(game.match_state.player.board) == 9 and game.match_state.player.board[0].attack == 3, "Forest Armada creates four Seed Elves and rewards a six-creature board")
	game._resolve_spell(game.database.get_card("worldroot_ascension"), game.match_state.player, game.match_state.bot, true)
	_check(_occupied(game.match_state.player.board) == 13 and game.match_state.player.board[0].attack == 6 and game.match_state.player.board[0].max_hp == 6, "Worldroot Ascension grants +3/+3 then creates four Seed Elves")

	var pillar: Dictionary = game.database.get_card("pillar_fire")
	game.store.profile.collection[pillar.id] = 10
	_check(game._deck_copy_limit(pillar) == game.store.owned(pillar.id), "Pillar deck limit equals owned copies, including the debug bonus")
	var creature: Dictionary = game.database.get_card("ember_pup")
	game.store.profile.collection[creature.id] = 10
	_check(game._deck_copy_limit(creature) == 6, "Ordinary card deck limit is six")
	game._show_screen("Collection")
	await process_frame
	var collection_pages: TabContainer
	for node in game.content.find_children("*", "TabContainer", true, false): collection_pages = node
	_check(collection_pages != null and collection_pages.get_tab_count() == 2, "Collection separates Cards and Items into full-height pages")
	var cards_page: Control = collection_pages.get_node("Cards")
	var collection_grid: GridContainer = cards_page.find_child("Cards", true, false)
	var fire_filter: Button
	for candidate in cards_page.find_children("*", "Button", true, false):
		if candidate.text == "Fire": fire_filter = candidate
	fire_filter.pressed.emit()
	await process_frame
	var only_fire := collection_grid.get_child_count() > 0
	for entry in collection_grid.get_children():
		var filtered_card: Dictionary = game.database.get_card(str(entry.get_meta("card_id", "")), game.profile.merged_cards)
		if "Fire" not in filtered_card.get("element_tags", []): only_fire = false
	_check(only_fire, "Collection reuses the deckbuilder element filters")
	game._show_card_hover(game.database.get_card("ancient_gardener"))
	await process_frame
	_check(game.hover_help_popups.is_empty(), "Ability help stays hidden during the initial card preview")
	await create_timer(2.1).timeout
	_check(game.hover_help_popups.size() == 2, "A stationary two-second hover opens help beside every card ability")
	game._hide_card_hover()
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
	game.profile.decks["test_active_deck"] = game.profile.decks[original_active].duplicate(true)
	game.profile.decks.test_active_deck.foundation_id = "pillar_water"
	game.profile.active_deck_id = "test_active_deck"
	game._new_match()
	_check(game.match_state.player.foundation == "pillar_water", "New matches load the profile's selected active deck")
	game.profile.decks.erase("test_active_deck")
	game.profile.active_deck_id = original_active
	var first_seed: int = game.match_state.rng.seed
	game._new_match()
	_check(game.match_state.rng.seed != first_seed, "Each match uses a newly randomized shuffle seed")
	var lan_deck: Dictionary = game._active_lan_deck_payload()
	game.lan.role = "host"
	game._begin_lan_match({"seed":4242, "host":lan_deck, "guest":lan_deck, "host_name":"Host", "guest_name":"Guest"})
	_check(game.lan_match_active and game.lan_local_turn and game.match_state.player_name == "Host" and game.match_state.opponent_name == "Guest", "LAN host starts locally with self on the bottom side")
	var lan_snapshot: Dictionary = game._lan_snapshot()
	game.lan_local_turn = false
	game._receive_lan_turn_state(lan_snapshot)
	_check(game.lan_local_turn and game.match_state.player_name == "Host" and game.match_state.player.has("board"), "LAN turn handoff mirrors the remote state back into the local bottom side")
	lan_snapshot.player.board[5] = game._unit_record(game.database.get_card("ember_pup"))
	game.lan_local_turn = false
	game._receive_lan_action({"kind":"card_play", "snapshot":lan_snapshot, "event":{"card_id":"ember_pup", "slot":5}})
	_check(game.match_state.bot.board[5] != null and str(game.match_state.bot.board[5].id) == "ember_pup", "LAN card actions synchronize immediately onto the opponent's top battlefield")
	game._receive_lan_match_finished({"sender_won":false, "reason":"surrender"})
	await process_frame
	var lan_result: Control = game.get_node_or_null("LanResultOverlay")
	_check(lan_result != null and game.surrender_button.disabled and game.match_state.message.begins_with("You win"), "Opponent surrender opens a blocking victory result and disables surrender")
	game._dismiss_lan_result()
	_check(game.current_screen == "Combat" and not game.lan_match_active, "LAN result returns to Combat only after confirmation")
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
	var imprint_grid: GridContainer = game.content.find_child("Imprint", true, false)
	_check(result_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and result_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO and imprint_grid.columns == 2, "Forge hybrid combinations use two columns with vertical scrolling")
	var forge_filter: Button
	for candidate in game.content.find_children("*", "Button", true, false):
		if candidate.text == "Fire" and candidate.toggle_mode: forge_filter = candidate
	var forge_collection: Control = game.content.find_child("ForgeCollectionScroll", true, false)
	var has_base_pillar := not forge_collection.find_children("*", "Button", true, false).filter(func(entry): return str(entry.get_meta("card_id", "")) == "pillar_fire").is_empty()
	_check(forge_filter != null and has_base_pillar, "Forge reuses the filtered deckbuilder collection panel and includes base Pillars")
	_check(game._preserved_fusion_sources(["ember_pup", "water_sprite"]).size() == 2, "Forge keeps both source selections while additional copies remain")
	var saved_currency := int(game.profile.get("currency", 0))
	var pillar_owned_before := int(game.profile.collection.get("pillar_fire", 0))
	game._show_screen("Bazaar")
	await process_frame
	var bazaar_pages: TabContainer
	for node in game.content.find_children("*", "TabContainer", true, false): bazaar_pages = node
	_check(bazaar_pages != null and bazaar_pages.get_tab_count() == 2 and bazaar_pages.has_node("Single Cards") and bazaar_pages.has_node("Items & Packs"), "Bazaar separates single cards from items and packs")
	game.profile.currency = 12
	game._buy_single_card("pillar_fire")
	_check(game.profile.currency == 0 and int(game.profile.collection.pillar_fire) == pillar_owned_before + 1, "Bazaar buys the configured base Pillar for 12 crowns")
	_check(game.get_node_or_null("PurchaseAnimation") != null, "Bazaar purchases show an acquisition animation")
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
