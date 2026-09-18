extends Control

const BG := Color("#0b1117")
const SURFACE := Color("#141e27")
const INK := Color("#eef3f5")
const MUTED := Color("#9eb0bb")
const FIRE := Color("#e94f37")
const WATER := Color("#28a9c7")
const NATURE := Color("#70b85b")
const GOLD := Color("#f2c14e")
const COMBAT_DURATION := 2.0

var database := CardDatabase.new()
var fusion_engine := FusionEngine.new()
var store := ProfileStore.new()
var profile: Dictionary
var game_config: Dictionary = {}
var bot_decks: Dictionary = {}
var challenges: Dictionary = {}
var pending_challenge_id := ""
var bazaar_tab := 0
var content: MarginContainer
var toast: Label
var brand_logo: TextureRect
var brand_label: Label
var nav_buttons: Array[Button] = []
var surrender_button: Button
var room_background: TextureRect
var current_screen := "Lobby"

var fusion_sources: Array[String] = []
var fusion_candidates: Array[Dictionary] = []
var fusion_selected := -1
var fusion_name_index := 0

var deck_cards: Array[String] = []
var deck_list: ItemList
var deck_count_label: Label
var available_list: ItemList
var available_ids: Array[String] = []
var deck_cards_container: HFlowContainer
var deck_collection_container: HFlowContainer
var deck_element_filter := "All"
var collection_element_filter := "All"
var deck_foundation := "pillar_fire"
var deck_vanguard := "ember_pup"
var deck_special_target := ""
var editing_deck_id := ""
var deck_foundation_box: VBoxContainer
var deck_vanguard_box: VBoxContainer
var hover_preview: Control
var hover_help_ticket := 0
var hover_help_popups: Array[Control] = []

var match_state: Dictionary = {}
var match_status: Label
var match_header: Label
var match_hand: VBoxContainer
var opponent_hand: VBoxContainer
var player_start_zone: HBoxContainer
var bot_start_zone: HBoxContainer
var player_board: HFlowContainer
var bot_board: HFlowContainer
var player_board_area: Control
var bot_board_area: Control
var player_pillars: HBoxContainer
var bot_pillars: HBoxContainer
var player_stats: Label
var bot_stats: Label
var player_mana: GridContainer
var bot_mana: GridContainer
var player_hp_bar: Control
var bot_hp_bar: Control
var end_turn_button: Button
var player_slot_nodes: Dictionary = {}
var bot_slot_nodes: Dictionary = {}
var pending_board_animations: Array[Dictionary] = []

func _ready() -> void:
	database.load_all()
	profile = store.load_profile()
	game_config = store.config
	bot_decks = _read_json_dictionary(str(game_config.get("bot_decks_path", "res://data/bot_decks.json"))).get("decks", {})
	challenges = _read_json_dictionary(str(game_config.get("challenges_path", "res://data/challenges.json"))).get("challenges", {})
	_build_shell()
	var requested := OS.get_environment("ELEMENTALS_SCREEN")
	_show_screen(requested if requested in ["Home", "Lobby", "Profile", "Collection", "Forge", "Fusion", "Deck", "DeckEditor", "Bazaar", "Combat", "Match"] else "Lobby")
	if str(profile.get("name", "")).strip_edges().is_empty(): call_deferred("_show_first_profile_dialog")
	elif not bool(profile.get("starter_deck_selected", false)): call_deferred("_show_starter_deck_dialog")
	_apply_responsive_header()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_responsive_header()

func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	room_background = TextureRect.new()
	room_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room_background.modulate = Color(0.55, 0.60, 0.65, 0.34)
	room_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room_background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 62
	header.add_theme_constant_override("separation", 8)
	var header_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		header_margin.add_theme_constant_override("margin_" + side, 10)
	header_margin.add_child(header)
	root.add_child(header_margin)
	brand_logo = TextureRect.new()
	brand_logo.texture = load("res://assets/elemental_mark.svg")
	brand_logo.custom_minimum_size = Vector2(42, 42)
	brand_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(brand_logo)
	brand_label = Label.new()
	brand_label.text = "ELEMENTAL FUSION"
	brand_label.add_theme_font_size_override("font_size", 20)
	brand_label.add_theme_color_override("font_color", INK)
	header.add_child(brand_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	for screen_name in ["Lobby", "Profile", "Collection", "Forge", "Deck", "Bazaar", "Combat"]:
		var button := _button(screen_name, _screen_color(screen_name))
		button.set_meta("screen_name", screen_name)
		button.pressed.connect(_show_screen.bind(screen_name))
		nav_buttons.append(button)
		header.add_child(button)
	surrender_button = _button("Surrender", FIRE)
	surrender_button.visible = false
	surrender_button.pressed.connect(_surrender_match)
	header.add_child(surrender_button)
	content = MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_top", 10)
	content.add_theme_constant_override("margin_bottom", 8)
	root.add_child(content)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", GOLD)
	toast.custom_minimum_size.y = 24
	root.add_child(toast)

func _apply_responsive_header() -> void:
	if not is_instance_valid(brand_label):
		return
	brand_label.visible = size.x >= 900
	brand_logo.visible = size.x >= 560
	for button in nav_buttons:
		var screen_name: String = button.get_meta("screen_name")
		button.custom_minimum_size.x = 72 if size.x < 900 else 104
		button.text = ("Cards" if screen_name == "Collection" else "Fuse" if screen_name == "Fusion" else screen_name) if size.x < 900 else screen_name

func _show_screen(screen_name: String) -> void:
	if screen_name == "Home": screen_name = "Lobby"
	if screen_name == "Fusion": screen_name = "Forge"
	current_screen = screen_name
	if screen_name != "Match":
		var attune_overlay := get_node_or_null("AttuneOverlay")
		if attune_overlay: attune_overlay.queue_free()
	_apply_room_background(screen_name)
	_hide_card_hover()
	for child in content.get_children():
		child.queue_free()
	toast.text = ""
	var screen: Control
	match screen_name:
		"Lobby": screen = _build_home()
		"Profile": screen = _build_profile()
		"Collection": screen = _build_collection()
		"Forge": screen = _build_fusion()
		"Deck": screen = _build_deck_library()
		"DeckEditor": screen = _build_deckbuilder()
		"Bazaar": screen = _build_bazaar()
		"Combat": screen = _build_combat()
		"Match": screen = _build_match()
	for button in nav_buttons: button.visible = screen_name != "Match"
	surrender_button.visible = screen_name == "Match"
	content.add_child(screen)

func _build_home() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	root.add_child(_section_title("Welcome, %s" % str(profile.get("name", "Adventurer")), "Level %d · %d XP · %d crowns" % [int(profile.get("level", 1)), int(profile.get("xp", 0)), int(profile.get("currency", 0))]))
	var rooms := GridContainer.new()
	rooms.columns = 3 if size.x >= 900 else 2
	rooms.add_theme_constant_override("h_separation", 14)
	rooms.add_theme_constant_override("v_separation", 14)
	for definition in game_config.get("rooms", []):
		var room := VBoxContainer.new()
		room.custom_minimum_size = Vector2(250, 112)
		var button := _button(str(definition.id), _screen_color(str(definition.id)))
		button.custom_minimum_size.y = 52
		button.disabled = not bool(definition.get("enabled", false))
		if not button.disabled: button.pressed.connect(_show_screen.bind(str(definition.id)))
		room.add_child(button)
		var description := Label.new()
		description.text = str(definition.description) + ("" if not button.disabled else "  (planned)")
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", MUTED)
		room.add_child(description)
		rooms.add_child(_panel(room))
	root.add_child(rooms)
	return root

func _apply_room_background(screen_name: String) -> void:
	if not is_instance_valid(room_background): return
	if screen_name == "DeckEditor": screen_name = "Deck"
	var path := str(game_config.get("backgrounds", {}).get(screen_name, ""))
	room_background.texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	room_background.visible = room_background.texture != null

func _show_first_profile_dialog() -> void:
	var shade := ColorRect.new()
	shade.name = "FirstProfileDialog"
	shade.color = Color(0.02, 0.04, 0.06, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 500
	add_child(shade)
	var dialog := VBoxContainer.new()
	dialog.custom_minimum_size = Vector2(380, 190)
	dialog.position = (size - dialog.custom_minimum_size) * 0.5
	dialog.add_theme_constant_override("separation", 12)
	dialog.add_child(_section_title("Create your profile", "Choose the name used by this offline account."))
	var input := LineEdit.new()
	input.placeholder_text = "Player name"
	input.max_length = 24
	dialog.add_child(input)
	var create := _button("Begin", GOLD)
	create.pressed.connect(func():
		var chosen := input.text.strip_edges()
		if chosen.is_empty(): return
		profile.name = chosen
		store.save_profile()
		shade.queue_free()
		_show_screen("Lobby")
		_show_starter_deck_dialog())
	dialog.add_child(create)
	shade.add_child(dialog)

func _build_profile() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.add_child(_section_title("Profile", "Offline accounts keep independent cards, decks, packs, and progression."))
	var summary := VBoxContainer.new()
	summary.add_child(_small_heading(str(profile.get("name", "Adventurer")).to_upper()))
	var stats := Label.new()
	stats.text = "Level %d    XP %d    Crowns %d    Cards %d" % [int(profile.get("level", 1)), int(profile.get("xp", 0)), int(profile.get("currency", 0)), _collection_total()]
	stats.add_theme_font_size_override("font_size", 20)
	summary.add_child(stats)
	var summary_panel := _panel(summary)
	summary_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(summary_panel)
	root.add_child(_small_heading("SWITCH PROFILE"))
	var profiles := HFlowContainer.new()
	for id in store.all_profiles():
		var account: Dictionary = store.all_profiles()[id]
		var button := _button("%s\nLevel %d%s" % [str(account.get("name", "Unnamed")), int(account.get("level", 1)), "  · active" if str(id) == store.active_profile_id else ""], GOLD if str(id) == store.active_profile_id else MUTED)
		button.custom_minimum_size = Vector2(180, 62)
		button.disabled = str(id) == store.active_profile_id
		button.pressed.connect(_switch_profile.bind(str(id)))
		profiles.add_child(button)
	var profile_scroll := ScrollContainer.new()
	profile_scroll.custom_minimum_size.y = 82
	profile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	profile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	profile_scroll.add_child(profiles)
	root.add_child(profile_scroll)
	var create_row := HBoxContainer.new()
	var name_input := LineEdit.new()
	name_input.placeholder_text = "New profile name"
	name_input.max_length = 24
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_row.add_child(name_input)
	var create := _button("Create profile", NATURE)
	create.pressed.connect(func():
		if name_input.text.strip_edges().is_empty(): return
		profile = store.create_profile(name_input.text)
		match_state.clear()
		_show_screen("Profile")
		_show_starter_deck_dialog())
	create_row.add_child(create)
	root.add_child(create_row)
	return root

func _switch_profile(id: String) -> void:
	profile = store.switch_profile(id)
	match_state.clear()
	deck_special_target = ""
	_show_screen("Profile")
	if not bool(profile.get("starter_deck_selected", false)): call_deferred("_show_starter_deck_dialog")

func _show_starter_deck_dialog() -> void:
	if bool(profile.get("starter_deck_selected", false)) or get_node_or_null("StarterDeckDialog") != null: return
	var shade := ColorRect.new()
	shade.name = "StarterDeckDialog"
	shade.color = Color(0.01, 0.02, 0.04, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 650
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(850, 420)
	box.add_theme_constant_override("separation", 16)
	box.add_child(_section_title("Choose your first deck", "Your collection starts empty. This one-time choice grants exactly this deck, its Foundation, and its Vanguard."))
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 14)
	for starter_id in store.starter_decks:
		var definition: Dictionary = store.starter_decks[starter_id]
		var choice := VBoxContainer.new()
		choice.custom_minimum_size.x = 250
		choice.add_child(_small_heading(str(definition.get("name", starter_id))))
		var preview := HBoxContainer.new()
		preview.alignment = BoxContainer.ALIGNMENT_CENTER
		preview.add_child(_portrait_button(database.get_card(str(definition.get("foundation_id", "")), profile.merged_cards), {}, false, false, 92))
		preview.add_child(_portrait_button(database.get_card(str(definition.get("vanguard_id", "")), profile.merged_cards), {}, false, true, 92))
		choice.add_child(preview)
		var description := Label.new()
		description.text = str(definition.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.y = 58
		choice.add_child(description)
		var select := _button("Choose %s" % str(definition.get("name", "deck")), _element_color(str(database.get_card(str(definition.get("foundation_id", "")), {}).get("element_tags", ["Neutral"])[0])))
		select.pressed.connect(_select_starter_deck.bind(str(starter_id), shade))
		choice.add_child(select)
		choices.add_child(_panel(choice))
	box.add_child(choices)
	center.add_child(box)

func _select_starter_deck(starter_id: String, shade: Control) -> void:
	if not store.apply_starter_deck(starter_id): return
	profile = store.profile
	shade.queue_free()
	_show_screen("Deck")
	_notify("Starter deck granted and set active.")

func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _collection_total() -> int:
	var total := 0
	for amount in profile.get("collection", {}).values(): total += int(amount)
	return total

func _build_bazaar() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.add_child(_section_title("Bazaar", "%s has %d crowns" % [str(profile.get("name", "Player")), int(profile.get("currency", 0))]))
	var pages := TabContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var singles := VBoxContainer.new()
	singles.name = "Single Cards"
	singles.add_theme_constant_override("separation", 10)
	singles.add_child(_small_heading("SINGLE CARD MARKET"))
	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var card_offers := HFlowContainer.new()
	card_offers.add_theme_constant_override("separation", 14)
	for card_id in game_config.get("single_cards", {}):
		var definition: Dictionary = game_config.single_cards[card_id]
		var card := database.get_card(str(card_id), profile.merged_cards)
		if card.is_empty(): continue
		var offer := VBoxContainer.new()
		offer.custom_minimum_size.x = 210
		offer.add_child(_full_card(card, -1))
		var owned := Label.new()
		owned.text = "Owned: %d" % int(profile.get("collection", {}).get(card_id, 0))
		owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owned.add_theme_color_override("font_color", MUTED)
		offer.add_child(owned)
		var buy_card := _button("Buy · %d crowns" % int(definition.get("price", 0)), _element_color(str(card.element_tags[0])))
		buy_card.disabled = int(profile.get("currency", 0)) < int(definition.get("price", 0))
		buy_card.pressed.connect(_buy_single_card.bind(str(card_id)))
		offer.add_child(buy_card)
		card_offers.add_child(_panel(offer))
	card_scroll.add_child(card_offers)
	singles.add_child(card_scroll)
	pages.add_child(singles)
	var items := VBoxContainer.new()
	items.name = "Items & Packs"
	items.add_theme_constant_override("separation", 10)
	items.add_child(_small_heading("BOOSTER PACKS"))
	var item_scroll := ScrollContainer.new()
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var offers := HFlowContainer.new()
	offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers.add_theme_constant_override("h_separation", 14)
	offers.add_theme_constant_override("v_separation", 14)
	for pack_id in game_config.get("packs", {}):
		var definition: Dictionary = game_config.packs[pack_id]
		var offer := VBoxContainer.new()
		offer.custom_minimum_size.x = 260
		var art := TextureRect.new()
		art.texture = load(str(definition.image))
		art.custom_minimum_size = Vector2(240, 180)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		offer.add_child(art)
		offer.add_child(_small_heading(str(definition.name)))
		var description := Label.new()
		description.text = "%s\nContains %d cards." % [str(definition.description), int(definition.size)]
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		offer.add_child(description)
		var buy := _button("Buy · %d crowns" % int(definition.price), GOLD)
		buy.disabled = int(profile.get("currency", 0)) < int(definition.price)
		buy.pressed.connect(_buy_pack.bind(str(pack_id)))
		offer.add_child(buy)
		offers.add_child(_panel(offer))
	item_scroll.add_child(offers)
	items.add_child(item_scroll)
	pages.add_child(items)
	pages.current_tab = clampi(bazaar_tab, 0, pages.get_tab_count() - 1)
	pages.tab_changed.connect(func(index: int): bazaar_tab = index)
	root.add_child(pages)
	return root

func _buy_single_card(card_id: String) -> void:
	bazaar_tab = 0
	var definition: Dictionary = game_config.get("single_cards", {}).get(card_id, {})
	var card := database.get_card(card_id, profile.merged_cards)
	var price := int(definition.get("price", -1))
	if definition.is_empty() or card.is_empty() or not bool(card.get("collectible", false)) or price < 0 or int(profile.get("currency", 0)) < price: return
	profile.currency = int(profile.get("currency", 0)) - price
	profile.get_or_add("collection", {})
	profile.collection[card_id] = int(profile.collection.get(card_id, 0)) + 1
	store.save_profile()
	_show_purchase_animation("card", str(card.display_name), str(card.image), "%s added to your collection." % str(card.display_name))

func _buy_pack(pack_id: String) -> void:
	bazaar_tab = 1
	var definition: Dictionary = game_config.get("packs", {}).get(pack_id, {})
	var price := int(definition.get("price", 0))
	if definition.is_empty() or int(profile.get("currency", 0)) < price: return
	profile.currency = int(profile.get("currency", 0)) - price
	profile.get_or_add("inventory", {"packs":{}})
	profile.inventory.get_or_add("packs", {})
	profile.inventory.packs[pack_id] = int(profile.inventory.packs.get(pack_id, 0)) + 1
	store.save_profile()
	_show_purchase_animation("pack", str(definition.get("name", "Booster Pack")), str(definition.get("image", "")), "Pack purchased. Open it from Collection.")

func _show_purchase_animation(kind: String, title: String, image_path: String, message: String) -> void:
	var shade := ColorRect.new()
	shade.name = "PurchaseAnimation"
	shade.color = Color(0.01, 0.02, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.z_index = 700
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 280)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(190, 190)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = load(image_path) if ResourceLoader.exists(image_path) else load("res://assets/elemental_mark.svg")
	box.add_child(art)
	var label := _small_heading("%s ACQUIRED · %s" % ["CARD" if kind == "card" else "ITEM", title])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	center.add_child(_panel(box))
	art.pivot_offset = art.custom_minimum_size * 0.5
	art.scale = Vector2(0.55, 0.55)
	art.modulate.a = 0.25
	var tween := create_tween().set_parallel(true)
	tween.tween_property(art, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(art, "modulate:a", 1.0, 0.25)
	tween.tween_property(box, "modulate", Color(1.15, 1.15, 1.15, 1.0), 0.22)
	await tween.finished
	await get_tree().create_timer(0.32).timeout
	shade.queue_free()
	_show_screen("Bazaar")
	_notify(message)

func _open_pack(pack_id: String) -> void:
	var owned_packs := int(profile.get("inventory", {}).get("packs", {}).get(pack_id, 0))
	var definition: Dictionary = game_config.get("packs", {}).get(pack_id, {})
	if owned_packs <= 0 or definition.is_empty(): return
	profile.inventory.packs[pack_id] = owned_packs - 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var found: Array[String] = []
	var pool: Array = definition.get("pool", [])
	for i in int(definition.get("size", 8)):
		var id := str(pool[rng.randi_range(0, pool.size() - 1)])
		found.append(id)
		profile.collection[id] = int(profile.collection.get(id, 0)) + 1
	store.save_profile()
	_show_unpacking_overlay(str(definition.name), found)

func _show_unpacking_overlay(pack_name: String, found: Array[String]) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.05, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 400
	add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 34)
	box.add_theme_constant_override("separation", 14)
	box.add_child(_section_title("%s opened" % pack_name, "These cards were added to your collection."))
	var cards := HFlowContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for id in found:
		cards.add_child(_portrait_button(database.get_card(id, profile.merged_cards), {}, false, int(database.get_card(id, profile.merged_cards).max_hp) > 0, 126))
	box.add_child(cards)
	var close := _button("Continue", GOLD)
	close.pressed.connect(func(): shade.queue_free(); _show_screen("Collection"))
	box.add_child(close)
	shade.add_child(box)

func _build_collection() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(_section_title("Collection", "Browse cards and stored items on their own full-size pages"))
	var pages := TabContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cards_page := VBoxContainer.new()
	cards_page.name = "Cards"
	var cards_layout := HBoxContainer.new()
	cards_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_layout.add_theme_constant_override("separation", 10)
	var filters := VBoxContainer.new()
	filters.custom_minimum_size.x = 118
	filters.add_child(_small_heading("ELEMENT"))
	var filter_group := ButtonGroup.new()
	filter_group.allow_unpress = false
	for element in _available_card_elements():
		var filter_button := Button.new()
		filter_button.text = element
		filter_button.toggle_mode = true
		filter_button.button_group = filter_group
		filter_button.button_pressed = element == collection_element_filter
		filters.add_child(filter_button)
	var filters_panel := _panel(filters)
	filters_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cards_layout.add_child(filters_panel)
	var cards_content := VBoxContainer.new()
	cards_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var search := LineEdit.new()
	search.placeholder_text = "Search collection"
	cards_content.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = 6 if size.x >= 1100 else 3 if size.x >= 650 else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_rebuild_collection_grid(grid, "")
	search.text_changed.connect(func(query): _rebuild_collection_grid(grid, query))
	for filter_button in filters.get_children():
		if filter_button is Button:
			filter_button.pressed.connect(_set_collection_filter.bind(str(filter_button.text), grid, search))
	scroll.add_child(grid)
	cards_content.add_child(scroll)
	cards_layout.add_child(cards_content)
	cards_page.add_child(cards_layout)
	pages.add_child(cards_page)
	var items_page := VBoxContainer.new()
	items_page.name = "Items"
	items_page.add_child(_small_heading("PACKS & ITEMS"))
	var item_scroll := ScrollContainer.new()
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var items := HFlowContainer.new()
	items.add_theme_constant_override("h_separation", 14)
	items.add_theme_constant_override("v_separation", 14)
	for pack_id in game_config.get("packs", {}):
		var amount := int(profile.get("inventory", {}).get("packs", {}).get(pack_id, 0))
		var definition: Dictionary = game_config.packs[pack_id]
		var item := VBoxContainer.new()
		item.custom_minimum_size.x = 260
		var art := TextureRect.new()
		art.texture = load(str(definition.image))
		art.custom_minimum_size = Vector2(240, 180)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		item.add_child(art)
		item.add_child(_small_heading("%s  ×%d" % [str(definition.name), amount]))
		var open := _button("Open pack", WATER)
		open.disabled = amount <= 0
		open.pressed.connect(_open_pack.bind(str(pack_id)))
		item.add_child(open)
		items.add_child(_panel(item))
	item_scroll.add_child(items)
	items_page.add_child(item_scroll)
	pages.add_child(items_page)
	root.add_child(pages)
	return root

func _rebuild_collection_grid(grid: GridContainer, query: String) -> void:
	for child in grid.get_children(): child.queue_free()
	for card in database.all_cards(profile.merged_cards):
		if collection_element_filter != "All" and collection_element_filter not in card.get("element_tags", []): continue
		if query.is_empty() or query.to_lower() in str(card.display_name).to_lower(): grid.add_child(_owned_full_card(card, false))

func _set_collection_filter(element: String, grid: GridContainer, search: LineEdit) -> void:
	collection_element_filter = element
	_rebuild_collection_grid(grid, search.text)

func _available_card_elements() -> Array[String]:
	var elements: Array[String] = ["All"]
	for card in database.all_cards(profile.merged_cards):
		for element in card.get("element_tags", []):
			if element not in elements: elements.append(element)
	return elements

func _build_fusion() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(_section_title("Forge", "Choose two cards, then select a name, artwork, and merge expression"))
	var work := VBoxContainer.new()
	work.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 10)
	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 10)
	var confluence_box := VBoxContainer.new()
	confluence_box.custom_minimum_size.x = 240
	confluence_box.add_child(_small_heading("CONFLUENCE"))
	var confluence_scroll := ScrollContainer.new()
	confluence_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var confluence := HBoxContainer.new()
	confluence.name = "Confluence"
	confluence_scroll.add_child(confluence)
	confluence_box.add_child(confluence_scroll)
	var confluence_panel := _panel(confluence_box)
	confluence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(confluence_panel)
	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 390
	center.add_child(_small_heading("MERGE SLOTS"))
	var sources := HBoxContainer.new()
	sources.name = "Sources"
	sources.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(sources)
	center.add_child(_small_heading("NAME & ARTWORK"))
	var name_picker := OptionButton.new()
	name_picker.name = "NamePicker"
	name_picker.item_selected.connect(func(index): fusion_name_index = index; fusion_selected = -1; _rebuild_fusion_work(work))
	center.add_child(name_picker)
	var center_panel := _panel(center)
	center_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(center_panel)
	var imprint_box := VBoxContainer.new()
	imprint_box.add_child(_small_heading("IMPRINT"))
	var result_scroll := ScrollContainer.new()
	result_scroll.name = "ResultScroll"
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	result_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var imprint := HBoxContainer.new()
	imprint.name = "Imprint"
	result_scroll.add_child(imprint)
	imprint_box.add_child(result_scroll)
	var imprint_panel := _panel(imprint_box)
	imprint_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(imprint_panel)
	work.add_child(top)
	var collection_box := VBoxContainer.new()
	collection_box.add_child(_small_heading("COLLECTION — CLICK TO FILL THE MERGE SLOTS"))
	var collection_scroll := ScrollContainer.new()
	collection_scroll.name = "ForgeCollectionScroll"
	collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	collection_scroll.custom_minimum_size.y = 300
	var collection_row := HBoxContainer.new()
	for card in database.all_cards(profile.merged_cards):
		if store.owned(card.id) > 0 and str(card.card_type) == "Creature":
			var item := _owned_full_card(card, true)
			item.gui_input.connect(_fusion_collection_input.bind(card.id))
			collection_row.add_child(item)
	collection_scroll.add_child(collection_row)
	collection_box.add_child(collection_scroll)
	work.add_child(_panel(collection_box))
	root.add_child(work)
	_rebuild_fusion_work(work)
	return root

func _fusion_collection_input(event: InputEvent, card_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_fusion_source(card_id)
	elif event is InputEventScreenTouch and event.pressed:
		_select_fusion_source(card_id)

func _select_fusion_source(card_id: String) -> void:
	var selected_card := database.get_card(card_id, profile.merged_cards)
	if str(selected_card.get("card_type", "")) != "Creature":
		_notify("Only creatures can enter the Forge.")
		return
	if fusion_engine.merge_count(selected_card) >= 2:
		_notify("%s has already reached its two-merge limit." % selected_card.display_name)
		return
	if store.owned(card_id) <= fusion_sources.count(card_id):
		_notify("No additional owned copy is available.")
		return
	if fusion_sources.size() < 2:
		fusion_sources.append(card_id)
	else:
		fusion_sources[1] = card_id
	fusion_selected = -1
	fusion_name_index = 0
	_show_screen("Fusion")

func _clear_fusion_source(index: int) -> void:
	if index < fusion_sources.size():
		fusion_sources.remove_at(index)
		fusion_selected = -1
		_show_screen("Fusion")

func _rebuild_fusion_work(work: VBoxContainer) -> void:
	var sources: HBoxContainer = work.find_child("Sources", true, false)
	for child in sources.get_children(): child.queue_free()
	for i in 2:
		if i < fusion_sources.size():
			var card := database.get_card(fusion_sources[i], profile.merged_cards)
			var preview := _owned_full_card(card, true)
			preview.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _clear_fusion_source(i))
			sources.add_child(preview)
		else:
			var empty := Label.new()
			empty.text = "Select card %s" % ("A" if i == 0 else "B")
			empty.custom_minimum_size = Vector2(176, 250)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sources.add_child(empty)
		if i == 0:
			var confirm := _button("Merge", GOLD)
			confirm.name = "Confirm"
			confirm.custom_minimum_size.x = 80
			confirm.visible = fusion_selected >= 0
			confirm.pressed.connect(_confirm_fusion)
			sources.add_child(confirm)
	var picker: OptionButton = work.find_child("NamePicker", true, false)
	picker.clear()
	var confluence: HBoxContainer = work.find_child("Confluence", true, false)
	var imprint: HBoxContainer = work.find_child("Imprint", true, false)
	for child in confluence.get_children(): child.queue_free()
	for child in imprint.get_children(): child.queue_free()
	fusion_candidates.clear()
	if fusion_sources.size() == 2:
		var a := database.get_card(fusion_sources[0], profile.merged_cards)
		var b := database.get_card(fusion_sources[1], profile.merged_cards)
		var names := fusion_engine.name_candidates(a, b)
		for candidate_name in names: picker.add_item(candidate_name + " — " + (str(a.display_name) if candidate_name.begins_with(str(a.name_parts[0])) else str(b.display_name)) + " artwork")
		picker.select(clampi(fusion_name_index, 0, names.size() - 1))
		var result_element := fusion_engine.result_element(a.element_tags[0], b.element_tags[0])
		if not result_element.is_empty() and fusion_engine.merge_count(a) < 2 and fusion_engine.merge_count(b) < 2:
			fusion_candidates = fusion_engine.result_candidates(a, b, names[picker.selected])
			for i in fusion_candidates.size():
				var card_panel := _full_card(fusion_candidates[i], 0, false, fusion_candidates[i].candidate_label)
				card_panel.add_theme_stylebox_override("panel", _box(GOLD.darkened(0.72) if i == fusion_selected else _element_color(result_element).darkened(0.62), 6, 2, GOLD if i == fusion_selected else _element_color(result_element)))
				_set_mouse_pass(card_panel)
				card_panel.gui_input.connect(_fusion_candidate_input.bind(i))
				(confluence if fusion_candidates[i].fusion_mode == "confluence" else imprint).add_child(card_panel)
		else:
			var note := Label.new()
			note.text = "These cards cannot merge, or one has reached its two-merge limit."
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			confluence.add_child(note)
	var confirm: Button = work.find_child("Confirm", true, false)
	if is_instance_valid(confirm):
		confirm.visible = fusion_selected >= 0 and fusion_selected < fusion_candidates.size()

func _fusion_candidate_input(event: InputEvent, index: int) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		fusion_selected = index
		_show_screen("Fusion")

func _confirm_fusion() -> void:
	if fusion_sources.size() != 2 or fusion_selected < 0 or fusion_selected >= fusion_candidates.size():
		return
	var a := database.get_card(fusion_sources[0], profile.merged_cards)
	var b := database.get_card(fusion_sources[1], profile.merged_cards)
	var merged := fusion_engine.create_fusion(a, b, fusion_candidates[fusion_selected])
	var source_ids: Array[String] = [str(a.id), str(b.id)]
	if store.consume_and_add(source_ids, merged):
		fusion_sources.clear()
		fusion_selected = -1
		_show_screen("Forge")
		_show_fusion_result_overlay(a, b, merged)
	else:
		_notify("The collection no longer contains both source cards.")

func _show_fusion_result_overlay(a: Dictionary, b: Dictionary, merged: Dictionary) -> void:
	var shade := ColorRect.new()
	shade.name = "FusionResultOverlay"
	shade.color = Color(0.01, 0.02, 0.04, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 600
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(700, 560)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.add_child(_section_title("The Forge awakens", "The resulting card has already been added to your collection."))
	var source_row := HBoxContainer.new()
	source_row.name = "AnimatedSources"
	source_row.alignment = BoxContainer.ALIGNMENT_CENTER
	source_row.add_theme_constant_override("separation", 100)
	source_row.add_child(_full_card(a, -1))
	source_row.add_child(_full_card(b, -1))
	box.add_child(source_row)
	var result := _full_card(merged, -1)
	result.name = "FusionResult"
	result.visible = false
	result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(result)
	var close := _button("Claim card", GOLD)
	close.name = "CloseFusionResult"
	close.visible = false
	close.pressed.connect(func(): shade.queue_free())
	box.add_child(close)
	center.add_child(_panel(box))
	call_deferred("_animate_fusion_result", shade, source_row, result, close)

func _animate_fusion_result(shade: Control, source_row: Control, result: Control, close: Button) -> void:
	await get_tree().process_frame
	for i in 28:
		var spark := ColorRect.new()
		spark.color = [FIRE, WATER, NATURE, GOLD][i % 4]
		spark.size = Vector2(5 + i % 4, 5 + i % 4)
		spark.position = size * 0.5 + Vector2(randf_range(-240, 240), randf_range(-150, 150))
		shade.add_child(spark)
		var spark_tween := create_tween().set_parallel(true)
		spark_tween.tween_property(spark, "position", size * 0.5 + Vector2(randf_range(-28, 28), randf_range(-28, 28)), 0.75)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.75)
		spark_tween.chain().tween_callback(spark.queue_free)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(source_row, "scale", Vector2(0.15, 0.15), 0.72).set_trans(Tween.TRANS_BACK)
	tween.tween_property(source_row, "modulate:a", 0.0, 0.72)
	await tween.finished
	source_row.visible = false
	result.visible = true
	result.scale = Vector2(0.25, 0.25)
	result.modulate.a = 0.0
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(result, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(result, "modulate:a", 1.0, 0.35)
	await reveal.finished
	close.visible = true

func _build_deck_library() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	var heading := HBoxContainer.new()
	var title := _section_title("Decks", "Choose the deck used for matches, or create and manage another one")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var create := _button("New deck", NATURE)
	create.pressed.connect(_create_deck)
	heading.add_child(create)
	root.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var decks := HFlowContainer.new()
	decks.add_theme_constant_override("h_separation", 14)
	decks.add_theme_constant_override("v_separation", 14)
	var active_id := str(profile.get("active_deck_id", "starter"))
	for id in profile.get("decks", {}):
		var deck: Dictionary = profile.decks[id]
		var deck_size: int = deck.get("card_ids", []).size()
		var valid := _deck_definition_valid(deck)
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 310
		var label := _small_heading(("ACTIVE · " if str(id) == active_id else "") + str(deck.get("name", "Untitled Deck")))
		label.add_theme_color_override("font_color", GOLD if str(id) == active_id else INK)
		card.add_child(label)
		var previews := HBoxContainer.new()
		previews.alignment = BoxContainer.ALIGNMENT_CENTER
		previews.add_theme_constant_override("separation", 18)
		previews.add_child(_portrait_button(database.get_card(str(deck.get("foundation_id", "pillar_fire")), profile.merged_cards), {}, false, false, 112))
		previews.add_child(_portrait_button(database.get_card(str(deck.get("vanguard_id", "ember_pup")), profile.merged_cards), {}, false, true, 112))
		card.add_child(previews)
		var count := Label.new()
		count.text = "%d cards  ·  %s" % [deck_size, "Ready" if valid else "Needs 30–120 cards"]
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_color_override("font_color", MUTED)
		card.add_child(count)
		var actions := HBoxContainer.new()
		var activate := _button("Active" if str(id) == active_id else "Use", GOLD if str(id) == active_id else NATURE)
		activate.disabled = str(id) == active_id or not valid
		activate.pressed.connect(_set_active_deck.bind(str(id)))
		actions.add_child(activate)
		var edit := _button("Edit", WATER)
		edit.pressed.connect(_edit_deck.bind(str(id)))
		actions.add_child(edit)
		var clone := _button("Clone", MUTED)
		clone.pressed.connect(_clone_deck.bind(str(id)))
		actions.add_child(clone)
		var remove := _button("Delete", FIRE)
		remove.disabled = profile.decks.size() <= 1
		remove.pressed.connect(_request_delete_deck.bind(str(id)))
		actions.add_child(remove)
		card.add_child(actions)
		decks.add_child(_panel(card))
	scroll.add_child(decks)
	root.add_child(scroll)
	return root

func _new_deck_id() -> String:
	var base := "deck_%d" % Time.get_ticks_usec()
	while profile.decks.has(base): base += "_copy"
	return base

func _create_deck() -> void:
	var id := _new_deck_id()
	var active: Dictionary = profile.get("decks", {}).get(str(profile.get("active_deck_id", "")), {})
	profile.decks[id] = {"id":id, "name":"Untitled Deck", "card_ids":[], "foundation_id":str(active.get("foundation_id", "")), "vanguard_id":str(active.get("vanguard_id", "")), "modified_at":Time.get_datetime_string_from_system()}
	store.save_profile()
	_edit_deck(id)

func _edit_deck(id: String) -> void:
	if not profile.get("decks", {}).has(id): return
	editing_deck_id = id
	_show_screen("DeckEditor")

func _set_active_deck(id: String) -> void:
	if not profile.get("decks", {}).has(id): return
	if not _deck_definition_valid(profile.decks[id]):
		_notify("Only a valid 30–120 card deck that respects copy limits can become active.")
		return
	profile.active_deck_id = id
	store.save_profile()
	_show_screen("Deck")

func _clone_deck(id: String) -> void:
	if not profile.get("decks", {}).has(id): return
	var clone: Dictionary = profile.decks[id].duplicate(true)
	var clone_id := _new_deck_id()
	clone.id = clone_id
	clone.name = str(clone.get("name", "Deck")) + " Copy"
	clone.modified_at = Time.get_datetime_string_from_system()
	profile.decks[clone_id] = clone
	store.save_profile()
	_show_screen("Deck")

func _request_delete_deck(id: String) -> void:
	if profile.get("decks", {}).size() <= 1 or not profile.decks.has(id): return
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 600
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(430, 180)
	box.add_theme_constant_override("separation", 12)
	box.add_child(_section_title("Delete %s?" % str(profile.decks[id].get("name", "this deck")), "This removes the deck from this profile and cannot be undone."))
	var actions := HBoxContainer.new()
	var cancel := _button("Keep deck", MUTED)
	cancel.pressed.connect(shade.queue_free)
	actions.add_child(cancel)
	var remove := _button("Delete deck", FIRE)
	remove.pressed.connect(func(): shade.queue_free(); _delete_deck(id))
	actions.add_child(remove)
	box.add_child(actions)
	center.add_child(_panel(box))

func _delete_deck(id: String) -> void:
	if profile.get("decks", {}).size() <= 1 or not profile.decks.has(id): return
	profile.decks.erase(id)
	if str(profile.get("active_deck_id", "")) == id:
		profile.active_deck_id = str(profile.decks.keys()[0])
	if editing_deck_id == id: editing_deck_id = ""
	store.save_profile()
	_show_screen("Deck")

func _build_deckbuilder() -> Control:
	deck_special_target = ""
	if editing_deck_id.is_empty() or not profile.get("decks", {}).has(editing_deck_id):
		editing_deck_id = str(profile.get("active_deck_id", "starter"))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	var heading := HBoxContainer.new()
	var back := _button("← Decks", MUTED)
	back.pressed.connect(_show_screen.bind("Deck"))
	heading.add_child(back)
	var title := _section_title("Deckbuilder · %s" % str(profile.decks[editing_deck_id].get("name", "Untitled Deck")), "Click a collection card to add it; click a deck card to remove one copy")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var save := _button("Save & name deck", GOLD)
	save.pressed.connect(_save_deck)
	heading.add_child(save)
	root.add_child(heading)
	deck_cards.clear()
	var saved_deck: Dictionary = profile.decks.get(editing_deck_id, {})
	for id in saved_deck.get("card_ids", []): deck_cards.append(str(id))
	deck_foundation = str(saved_deck.get("foundation_id", "pillar_fire"))
	deck_vanguard = str(saved_deck.get("vanguard_id", "ember_pup"))
	var deck_panel_row := HBoxContainer.new()
	deck_panel_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_panel_row.add_theme_constant_override("separation", 14)
	var deck_box := VBoxContainer.new()
	deck_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_count_label = _small_heading("")
	deck_box.add_child(deck_count_label)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.custom_minimum_size.y = 230
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_cards_container = HFlowContainer.new()
	deck_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_cards_container.add_theme_constant_override("h_separation", 14)
	deck_cards_container.add_theme_constant_override("v_separation", 8)
	deck_scroll.add_child(deck_cards_container)
	deck_box.add_child(deck_scroll)
	deck_panel_row.add_child(deck_box)
	var starts := VBoxContainer.new()
	starts.custom_minimum_size.x = 230
	starts.add_theme_constant_override("separation", 8)
	deck_foundation_box = VBoxContainer.new()
	deck_vanguard_box = VBoxContainer.new()
	_render_deck_special_box(deck_foundation_box, "foundation")
	_render_deck_special_box(deck_vanguard_box, "vanguard")
	starts.add_child(deck_foundation_box)
	starts.add_child(deck_vanguard_box)
	deck_panel_row.add_child(starts)
	var deck_panel := _panel(deck_panel_row)
	deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(deck_panel)

	var collection_section := HBoxContainer.new()
	collection_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_section.add_theme_constant_override("separation", 10)
	var filters := VBoxContainer.new()
	filters.custom_minimum_size.x = 118
	filters.add_child(_small_heading("ELEMENT"))
	var filter_group := ButtonGroup.new()
	filter_group.allow_unpress = false
	for element in _available_card_elements():
		var filter_button := Button.new()
		filter_button.text = element
		filter_button.toggle_mode = true
		filter_button.button_group = filter_group
		filter_button.button_pressed = element == deck_element_filter
		filter_button.pressed.connect(_set_deck_filter.bind(element))
		filters.add_child(filter_button)
	var filters_panel := _panel(filters)
	filters_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	collection_section.add_child(filters_panel)
	var collection_box := VBoxContainer.new()
	collection_box.add_child(_small_heading("COLLECTION"))
	var collection_scroll := ScrollContainer.new()
	collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_collection_container = HFlowContainer.new()
	deck_collection_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_collection_container.add_theme_constant_override("h_separation", 14)
	deck_collection_container.add_theme_constant_override("v_separation", 8)
	collection_scroll.add_child(deck_collection_container)
	collection_box.add_child(collection_scroll)
	var collection_panel := _panel(collection_box)
	collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_section.add_child(collection_panel)
	root.add_child(collection_section)
	_refresh_deck_cards()
	return root

func _set_deck_filter(element: String) -> void:
	deck_element_filter = element
	_refresh_deck_cards()

func _add_card_to_deck(id: String) -> void:
	var card := database.get_card(id, profile.merged_cards)
	if not deck_special_target.is_empty():
		if not _valid_special_choice(card, deck_special_target):
			_notify("Choose %s." % ("a base Pillar" if deck_special_target == "foundation" else "a non-Pillar card"))
			return
		if deck_special_target == "foundation": deck_foundation = id
		else: deck_vanguard = id
		deck_special_target = ""
		_render_deck_special_box(deck_foundation_box, "foundation")
		_render_deck_special_box(deck_vanguard_box, "vanguard")
		_refresh_deck_cards()
		_notify("Starting card updated. Save the deck to keep it.")
		return
	if deck_cards.size() >= 120:
		_notify("The deck already contains the maximum 120 cards.")
		return
	if not card.is_pillar and _deck_name_count(str(card.display_name)) >= _ordinary_copy_limit():
		_notify("A deck can contain at most %d cards named %s." % [_ordinary_copy_limit(), card.display_name])
		return
	if deck_cards.count(id) >= _deck_copy_limit(card):
		_notify("Every owned copy is already in the deck.")
		return
	deck_cards.append(id)
	_refresh_deck_cards()

func _deck_copy_limit(card: Dictionary) -> int:
	return store.owned(card.id) if card.is_pillar else mini(_ordinary_copy_limit(), store.owned(card.id))

func _deck_name_count(display_name: String) -> int:
	var count := 0
	for id in deck_cards:
		if str(database.get_card(id, profile.merged_cards).display_name) == display_name: count += 1
	return count

func _remove_card_from_deck(id: String) -> void:
	var index := deck_cards.find(id)
	if index >= 0:
		deck_cards.remove_at(index)
		_refresh_deck_cards()

func _refresh_deck_cards() -> void:
	if not is_instance_valid(deck_cards_container) or not is_instance_valid(deck_collection_container): return
	for child in deck_cards_container.get_children(): child.queue_free()
	for child in deck_collection_container.get_children(): child.queue_free()
	var counts := _card_counts(deck_cards)
	for id in counts:
		var card := database.get_card(id, profile.merged_cards)
		deck_cards_container.add_child(_deck_portrait_entry(card, int(counts[id]), false))
	for card in database.all_cards(profile.merged_cards):
		if not bool(card.get("deck_eligible", true)) or store.owned(card.id) <= 0: continue
		if deck_element_filter != "All" and deck_element_filter not in card.get("element_tags", []): continue
		deck_collection_container.add_child(_deck_portrait_entry(card, store.owned(card.id), true, not deck_special_target.is_empty() and _valid_special_choice(card, deck_special_target)))
	deck_count_label.text = "CURRENT DECK  %d  (30 minimum · 120 maximum)" % deck_cards.size()
	deck_count_label.add_theme_color_override("font_color", NATURE if deck_cards.size() >= 30 and deck_cards.size() <= 120 else GOLD)

func _card_counts(ids: Array[String]) -> Dictionary:
	var result := {}
	for id in ids: result[id] = int(result.get(id, 0)) + 1
	return result

func _deck_portrait_entry(card: Dictionary, copies: int, from_collection: bool, highlighted := false) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var portrait := _portrait_button(card, {}, highlighted, int(card.max_hp) > 0)
	if from_collection:
		portrait.pressed.connect(_add_card_to_deck.bind(str(card.id)))
	else:
		portrait.pressed.connect(_remove_card_from_deck.bind(str(card.id)))
	row.add_child(portrait)
	var count := Label.new()
	count.text = ("Owned: %d" if from_collection else "Copies: %d") % copies
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 14)
	count.add_theme_color_override("font_color", INK)
	row.add_child(count)
	return row

func _save_deck() -> void:
	if deck_cards.size() < 30 or deck_cards.size() > 120:
		_notify("A valid deck must contain between 30 and 120 cards.")
		return
	if deck_foundation.is_empty() or deck_vanguard.is_empty():
		_notify("Choose both a Foundation and a Vanguard.")
		return
	var names := {}
	for id in deck_cards:
		var card := database.get_card(id, profile.merged_cards)
		if card.is_pillar: continue
		var card_name := str(card.display_name)
		names[card_name] = int(names.get(card_name, 0)) + 1
		if int(names[card_name]) > _ordinary_copy_limit():
			_notify("A deck can contain at most %d cards named %s." % [_ordinary_copy_limit(), card_name])
			return
	_show_deck_name_dialog(str(profile.decks.get(editing_deck_id, {}).get("name", "Untitled Deck")))

func _show_deck_name_dialog(current_name: String) -> void:
	var shade := ColorRect.new()
	shade.name = "DeckNameDialog"
	shade.color = Color(0.01, 0.02, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 600
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 190)
	box.add_theme_constant_override("separation", 12)
	box.add_child(_section_title("Name this deck", "The name appears in your Deck Library."))
	var input := LineEdit.new()
	input.name = "DeckNameInput"
	input.text = current_name
	input.max_length = 40
	input.select_all()
	box.add_child(input)
	var actions := HBoxContainer.new()
	var cancel := _button("Cancel", MUTED)
	cancel.pressed.connect(shade.queue_free)
	actions.add_child(cancel)
	var commit := _button("Save deck", GOLD)
	commit.pressed.connect(func():
		var chosen := input.text.strip_edges()
		if chosen.is_empty(): return
		shade.queue_free()
		_commit_deck_save(chosen))
	actions.add_child(commit)
	box.add_child(actions)
	center.add_child(_panel(box))
	input.grab_focus()

func _commit_deck_save(deck_name: String) -> void:
	if editing_deck_id.is_empty(): editing_deck_id = _new_deck_id()
	profile.decks[editing_deck_id] = {"id":editing_deck_id, "name":deck_name, "card_ids":deck_cards.duplicate(), "foundation_id":deck_foundation, "vanguard_id":deck_vanguard, "modified_at":Time.get_datetime_string_from_system()}
	if str(profile.get("active_deck_id", "")).is_empty(): profile.active_deck_id = editing_deck_id
	store.save_profile()
	_show_screen("Deck")
	_notify("%s saved." % deck_name)

func _render_deck_special_box(box: VBoxContainer, zone: String) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var foundation := zone == "foundation"
	var title := "FOUNDATION" if foundation else "VANGUARD"
	var subtitle := "Your starting base Pillar" if foundation else "Your other always-available starting card"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_small_heading(title))
	var note := Label.new()
	note.text = subtitle
	note.add_theme_color_override("font_color", MUTED)
	box.add_child(note)
	var selected_id := deck_foundation if foundation else deck_vanguard
	if not selected_id.is_empty():
		var preview := _portrait_button(database.get_card(selected_id, profile.merged_cards), {}, false, not foundation, 82)
		preview.name = "Preview"
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(preview)
	var update := _button("Select from collection" if deck_special_target != zone else "Selecting… click a highlighted card", GOLD if deck_special_target == zone else MUTED)
	update.pressed.connect(_begin_special_selection.bind(zone))
	box.add_child(update)

func _begin_special_selection(zone: String) -> void:
	deck_special_target = "" if deck_special_target == zone else zone
	_render_deck_special_box(deck_foundation_box, "foundation")
	_render_deck_special_box(deck_vanguard_box, "vanguard")
	_refresh_deck_cards()

func _valid_special_choice(card: Dictionary, zone: String) -> bool:
	return bool(card.is_pillar) and bool(card.is_base) if zone == "foundation" else not bool(card.is_pillar)

func _build_combat() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.add_child(_section_title("Combat Hall", "Choose a challenge. Opponent behavior is unchanged; difficulty comes from the randomly selected deck."))
	var active_id := str(profile.get("active_deck_id", ""))
	var active: Dictionary = profile.get("decks", {}).get(active_id, {})
	var deck_ready := _deck_definition_valid(active)
	var status := Label.new()
	status.text = "Active deck: %s · %d cards · %d crowns" % [str(active.get("name", "None")), active.get("card_ids", []).size(), int(profile.get("currency", 0))]
	status.add_theme_color_override("font_color", NATURE if deck_ready else FIRE)
	root.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := HFlowContainer.new()
	list.add_theme_constant_override("h_separation", 16)
	list.add_theme_constant_override("v_separation", 16)
	for challenge_id in challenges:
		var definition: Dictionary = challenges[challenge_id]
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(330, 230)
		card.add_child(_small_heading(str(definition.get("name", challenge_id))))
		var difficulty := Label.new()
		difficulty.text = "Difficulty: %s" % str(definition.get("difficulty", "Unknown"))
		difficulty.add_theme_color_override("font_color", GOLD)
		card.add_child(difficulty)
		var description := Label.new()
		description.text = str(definition.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.y = 68
		card.add_child(description)
		var pool := Label.new()
		pool.text = "%d possible opponent decks" % definition.get("bot_deck_ids", []).size()
		pool.add_theme_color_override("font_color", MUTED)
		card.add_child(pool)
		var entry := int(definition.get("entry_cost", 0))
		var prize := int(definition.get("win_prize", 0))
		var fight := _button("Enter %d · Win %d crowns" % [entry, prize], FIRE)
		fight.disabled = not deck_ready or int(profile.get("currency", 0)) < entry
		fight.pressed.connect(_start_challenge.bind(str(challenge_id)))
		card.add_child(fight)
		list.add_child(_panel(card))
	scroll.add_child(list)
	root.add_child(scroll)
	return root

func _start_challenge(challenge_id: String) -> void:
	if not challenges.has(challenge_id): return
	var active: Dictionary = profile.get("decks", {}).get(str(profile.get("active_deck_id", "")), {})
	if not _deck_definition_valid(active):
		_notify("Select a valid 30–120 card active deck first.")
		return
	var entry := int(challenges[challenge_id].get("entry_cost", 0))
	if int(profile.get("currency", 0)) < entry:
		_notify("Not enough crowns for this challenge.")
		return
	profile.currency = int(profile.get("currency", 0)) - entry
	if not store.save_profile():
		profile.currency = int(profile.get("currency", 0)) + entry
		_notify("The entry fee could not be saved.")
		return
	pending_challenge_id = challenge_id
	match_state.clear()
	_show_screen("Match")

func _deck_definition_valid(deck: Dictionary) -> bool:
	var ids: Array = deck.get("card_ids", [])
	var minimum := int(game_config.get("deck_rules", {}).get("minimum_cards", 30))
	var maximum := int(game_config.get("deck_rules", {}).get("maximum_cards", 120))
	if ids.size() < minimum or ids.size() > maximum: return false
	if str(deck.get("foundation_id", "")).is_empty() or str(deck.get("vanguard_id", "")).is_empty(): return false
	var names := {}
	var copy_limit := _ordinary_copy_limit()
	for id in ids:
		var card := database.get_card(str(id), profile.get("merged_cards", {}))
		if card.is_empty(): return false
		if bool(card.get("is_pillar", false)): continue
		var display_name := str(card.get("display_name", id))
		names[display_name] = int(names.get(display_name, 0)) + 1
		if int(names[display_name]) > copy_limit: return false
	return true

func _ordinary_copy_limit() -> int:
	return int(game_config.get("deck_rules", {}).get("maximum_copies_per_name", 6))

func _build_match() -> Control:
	if match_state.is_empty() or bool(match_state.get("finished", false)):
		_new_match()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	match_header = _small_heading("")
	match_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(match_header)
	root.add_child(top)
	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 10)
	var left_rail := VBoxContainer.new()
	left_rail.custom_minimum_size.x = 170
	left_rail.add_child(_small_heading("OPPONENT HAND"))
	var opponent_scroll := ScrollContainer.new()
	opponent_scroll.custom_minimum_size = Vector2(165, 210)
	opponent_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	opponent_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	opponent_hand = VBoxContainer.new()
	opponent_hand.add_theme_constant_override("separation", -84)
	opponent_scroll.add_child(opponent_hand)
	left_rail.add_child(opponent_scroll)
	bot_start_zone = HBoxContainer.new()
	bot_start_zone.add_theme_constant_override("separation", 4)
	left_rail.add_child(bot_start_zone)
	var left_spacer := Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_rail.add_child(left_spacer)
	left_rail.add_child(_small_heading("YOUR MANA"))
	player_mana = GridContainer.new()
	player_mana.columns = 2
	left_rail.add_child(player_mana)
	player_hp_bar = _hp_bar()
	player_hp_bar.gui_input.connect(_hp_target_input.bind("player"))
	left_rail.add_child(player_hp_bar)
	var left_panel := _panel(left_rail)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	arena.add_child(left_panel)

	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.clip_contents = true
	bot_stats = Label.new()
	field.add_child(bot_stats)
	bot_pillars = HBoxContainer.new()
	bot_pillars.custom_minimum_size.y = 54
	field.add_child(bot_pillars)
	field.add_child(_board_region(false))
	match_status = Label.new()
	match_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_status.add_theme_color_override("font_color", GOLD)
	match_status.custom_minimum_size.y = 24
	field.add_child(match_status)
	field.add_child(_board_region(true))
	player_pillars = HBoxContainer.new()
	player_pillars.custom_minimum_size.y = 54
	field.add_child(player_pillars)
	var player_footer := HBoxContainer.new()
	player_footer.custom_minimum_size.y = 38
	player_stats = Label.new()
	player_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_footer.add_child(player_stats)
	end_turn_button = _button("End Turn (Spacebar)", GOLD)
	end_turn_button.pressed.connect(_end_turn)
	player_footer.add_child(end_turn_button)
	field.add_child(player_footer)
	var field_panel := _panel(field)
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.add_child(field_panel)

	var right_rail := VBoxContainer.new()
	right_rail.custom_minimum_size.x = 178
	right_rail.add_child(_small_heading("OPPONENT MANA"))
	bot_mana = GridContainer.new()
	bot_mana.columns = 2
	right_rail.add_child(bot_mana)
	bot_hp_bar = _hp_bar()
	bot_hp_bar.gui_input.connect(_hp_target_input.bind("bot"))
	right_rail.add_child(bot_hp_bar)
	var right_spacer := Control.new()
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_rail.add_child(right_spacer)
	player_start_zone = HBoxContainer.new()
	player_start_zone.alignment = BoxContainer.ALIGNMENT_END
	player_start_zone.add_theme_constant_override("separation", 4)
	right_rail.add_child(player_start_zone)
	right_rail.add_child(_small_heading("YOUR HAND"))
	var hand_scroll := ScrollContainer.new()
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.custom_minimum_size = Vector2(172, 300)
	match_hand = VBoxContainer.new()
	match_hand.add_theme_constant_override("separation", -84)
	hand_scroll.add_child(match_hand)
	right_rail.add_child(hand_scroll)
	var right_panel := _panel(right_rail)
	right_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	arena.add_child(right_panel)
	root.add_child(arena)
	_refresh_match()
	return root

func _board_region(player_owned: bool) -> Control:
	var region := Control.new()
	region.name = "PlayerBattlefield" if player_owned else "OpponentBattlefield"
	region.custom_minimum_size.y = 118
	region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	region.size_flags_stretch_ratio = 1.0
	region.clip_contents = true
	var scroll := ScrollContainer.new()
	scroll.name = "CreatureScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	region.add_child(scroll)
	var board := _board_flow()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(board)
	if player_owned:
		player_board = board
		player_board_area = region
	else:
		bot_board = board
		bot_board_area = region
	return region

func _new_match() -> void:
	var active_id := str(profile.get("active_deck_id", "starter"))
	var saved: Dictionary = profile.decks.get(active_id, profile.decks.get("starter", {}))
	var source: Array = saved.get("card_ids", []).duplicate()
	var foundation_id := str(saved.get("foundation_id", "pillar_fire"))
	var vanguard_id := str(saved.get("vanguard_id", "ember_pup"))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_shuffle_with_rng(source, rng)
	var challenge_id := pending_challenge_id if challenges.has(pending_challenge_id) else "training_ring"
	var challenge: Dictionary = challenges.get(challenge_id, {})
	var pool: Array = challenge.get("bot_deck_ids", [])
	var bot_definition: Dictionary = {}
	var bot_deck_id := "mirror"
	if not pool.is_empty():
		bot_deck_id = str(pool[rng.randi_range(0, pool.size() - 1)])
		bot_definition = bot_decks.get(bot_deck_id, {})
	var bot_deck: Array = bot_definition.get("card_ids", source).duplicate()
	_shuffle_with_rng(bot_deck, rng)
	var bot_foundation := str(bot_definition.get("foundation_id", foundation_id))
	var bot_vanguard := str(bot_definition.get("vanguard_id", vanguard_id))
	match_state = {"turn":1, "finished":false, "busy":false, "message":"%s · Opponent deck selected: %s" % [str(challenge.get("name", "Practice")), str(bot_definition.get("name", "Mirror"))], "targeting":{}, "rng":rng, "challenge_id":challenge_id, "challenge_name":str(challenge.get("name", "Practice")), "entry_cost":int(challenge.get("entry_cost", 0)), "win_prize":int(challenge.get("win_prize", game_config.get("match_rewards", {}).get("win_currency", 0))), "win_xp":int(challenge.get("win_xp", game_config.get("match_rewards", {}).get("win_xp", 0))), "loss_xp":int(challenge.get("loss_xp", game_config.get("match_rewards", {}).get("loss_xp", 0))), "bot_deck_id":bot_deck_id, "player":_new_player(source, foundation_id, vanguard_id), "bot":_new_player(bot_deck, bot_foundation, bot_vanguard)}
	pending_challenge_id = ""
	for i in 7:
		_draw_card(match_state.player)
		_draw_card(match_state.bot)

func _new_player(deck: Array, foundation_id := "pillar_fire", vanguard_id := "ember_pup") -> Dictionary:
	var board: Array = []
	board.resize(32)
	board.fill(null)
	return {"hp":100, "max_hp":100, "burn":0, "deck":deck, "hand":[], "board":board, "pillars":[], "mana":{}, "discard":[], "foundation":foundation_id, "vanguard":vanguard_id}

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and is_instance_valid(end_turn_button) and end_turn_button.visible:
		_end_turn()
		get_viewport().set_input_as_handled()

func _surrender_match() -> void:
	if match_state.is_empty() or bool(match_state.get("finished", false)): return
	match_state.clear()
	_show_screen("Lobby")
	_notify("You surrendered the match.")

func _draw_card(player: Dictionary) -> void:
	if not player.deck.is_empty(): player.hand.append(player.deck.pop_back())

func _play_hand_card(index: int) -> void:
	if bool(match_state.busy) or not match_state.targeting.is_empty() or index < 0 or index >= match_state.player.hand.size(): return
	var id: String = match_state.player.hand[index]
	_play_player_card(id, "hand", index)

func _play_start_card(zone: String) -> void:
	if bool(match_state.busy) or bool(match_state.finished) or not match_state.targeting.is_empty(): return
	var id := str(match_state.player.get(zone, ""))
	if not id.is_empty(): _play_player_card(id, zone, -1)

func _remove_available_card(source: String, index: int) -> void:
	if source == "hand": match_state.player.hand.remove_at(index)
	else: match_state.player[source] = ""

func _restore_available_card(id: String, source: String) -> void:
	if source == "hand": match_state.player.hand.append(id)
	else: match_state.player[source] = id

func _play_player_card(id: String, source: String, index: int) -> void:
	var card := database.get_card(id, profile.merged_cards)
	if card.is_pillar:
		if not _can_pay(match_state.player.mana, card.cost):
			match_state.message = "Not enough mana for %s." % card.display_name
			_refresh_match()
			return
		_pay(match_state.player.mana, card.cost)
		_remove_available_card(source, index)
		match_state.player.pillars.append(_pillar_record(card.id))
		match_state.message = "%s entered. It will produce mana at end of turn." % card.display_name
	else:
		var cost: Dictionary = card.cost
		if not _can_pay(match_state.player.mana, cost):
			match_state.message = "Not enough mana for %s." % card.display_name
			_refresh_match()
			return
		_pay(match_state.player.mana, cost)
		_remove_available_card(source, index)
		if card.card_type == "Spell":
			if not _begin_player_spell(card):
				_resolve_spell(card, match_state.player, match_state.bot, true)
				match_state.player.discard.append(id)
		else:
			var slot := _random_empty_slot(match_state.player.board)
			if slot < 0:
				match_state.message = "The battlefield is full."
				_restore_available_card(id, source)
				_refund(match_state.player.mana, cost)
			else:
				match_state.player.board[slot] = _unit_record(card)
				_apply_on_play(card, match_state.bot, true, slot)
				if match_state.bot.hp <= 0:
					_finish_match("You win.", true)
				elif match_state.targeting.get("kind", "") != "effect":
					match_state.message = "%s entered." % card.display_name
	_refresh_match()

func _pillar_record(card_id: String) -> Dictionary:
	var card := database.get_card(card_id, profile.merged_cards)
	return {"uid":str(Time.get_ticks_usec()) + str(randi_range(10, 99)), "card_id":card_id, "element":card.element_tags[0]}

func _unit_record(card: Dictionary) -> Dictionary:
	var unit := {"uid":str(Time.get_ticks_usec()) + str(randi_range(10, 99)), "id":card.id, "attack":int(card.attack), "hp":int(card.max_hp), "max_hp":int(card.max_hp), "burn":0, "bonus_burn":0, "frozen":0, "strike_ready":false, "abilities_used":{}}
	var clock := _card_ability_strength(card, "Clock")
	if clock > 0: unit["clock"] = clock
	return unit

func _apply_on_play(card: Dictionary, opponent: Dictionary, opponent_is_bot := true, source_slot := -1) -> void:
	var owner: Dictionary = match_state.player if opponent_is_bot else match_state.bot
	for reference in card.abilities:
		var ability := _ability_ref(reference)
		if ability.kind != "on_play": continue
		match str(ability.id):
			"Scorch":
				var damage := _ability_strength(ability)
				if opponent_is_bot:
					_begin_effect_target("damage", damage, "any_damageable", str(card.id), source_slot)
				else:
					_bot_apply_damage_target(damage)
			"Freeze":
				if opponent_is_bot:
					if _highest_threat_slot(opponent) >= 0: _begin_effect_target("freeze", _ability_strength(ability), "enemy_creature", str(card.id), source_slot)
				else:
					_apply_freeze_on_play(opponent, _ability_strength(ability))
			"Bounce":
				_apply_bounce_on_play(opponent, _ability_strength(ability), opponent_is_bot)
			"Ignite":
				if opponent_is_bot:
					_begin_effect_target("burn", _ability_strength(ability), "any_damageable", str(card.id), source_slot)
				else:
					_bot_apply_burn_target(_ability_strength(ability))
			"Spawn Sapling":
				_spawn_token(owner, "sapling", opponent_is_bot)
			"Elder Call":
				_queue_board_animation(owner, source_slot, opponent_is_bot, "ability", 0, "ELDER CALL")
				_spawn_token(owner, "elder_sapling", opponent_is_bot)
			"Grove Blessing":
				_queue_board_animation(owner, source_slot, opponent_is_bot, "ability", 0, "GROVE BLESSING")
				for friendly_slot in owner.board.size():
					var friendly: Variant = owner.board[friendly_slot]
					if friendly == null: continue
					var friendly_card := database.get_card(friendly.id, profile.merged_cards)
					if str(friendly_card.card_type) != "Creature": continue
					friendly.max_hp = int(friendly.max_hp) + _ability_strength(ability)
					friendly.hp = int(friendly.hp) + _ability_strength(ability)
					_queue_board_animation(owner, friendly_slot, opponent_is_bot, "grow", _ability_strength(ability), "+%d HP" % _ability_strength(ability))
	_refresh_nature_bonuses(owner, opponent_is_bot)

func _spawn_token(owner: Dictionary, token_id: String, player_owned := true, animation_label := "SPROUT") -> bool:
	var slot := _random_empty_slot(owner.board)
	if slot < 0: return false
	owner.board[slot] = _unit_record(database.get_card(token_id, profile.merged_cards))
	_queue_board_animation(owner, slot, player_owned, "spawn", 0, animation_label)
	return true

func _queue_board_animation(owner: Dictionary, slot: int, player_owned: bool, kind: String, amount := 0, label := "") -> void:
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	pending_board_animations.append({"slot":slot, "player_owned":player_owned, "kind":kind, "amount":amount, "label":label, "uid":str(owner.board[slot].get("uid", ""))})

func _highest_threat_slot(owner: Dictionary) -> int:
	var best_slot := -1
	var best_score := -INF
	for slot in owner.board.size():
		var unit: Variant = owner.board[slot]
		if unit == null: continue
		var candidate := database.get_card(str(unit.id), profile.merged_cards)
		if str(candidate.card_type) != "Creature": continue
		var score := _unit_threat(unit, candidate, owner)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot

func _highest_value_slot(owner: Dictionary, opponent: Dictionary = {}) -> int:
	var best_slot := -1
	var best_score := -INF
	for slot in owner.board.size():
		var unit: Variant = owner.board[slot]
		if unit == null: continue
		var candidate := database.get_card(str(unit.id), profile.merged_cards)
		var score := _unit_threat(unit, candidate, owner, opponent)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot

func _apply_freeze_on_play(opponent: Dictionary, duration: int) -> void:
	var slot := _highest_threat_slot(opponent)
	if slot >= 0: _apply_freeze_to_unit(opponent, slot, duration, true)

func _apply_freeze_to_unit(owner: Dictionary, slot: int, duration: int, player_owned: bool) -> void:
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	var unit: Dictionary = owner.board[slot]
	var card := database.get_card(unit.id, profile.merged_cards)
	if _has_ability(card, "Frozen Incubation") or _has_ability(card, "Clock"):
		unit.clock = maxi(0, int(unit.get("clock", _card_ability_strength(card, "Clock"))) - duration)
		call_deferred("_flash_board_ability", slot, {"id":"CLOCK −%d" % duration, "cost":{"Water":1}}, player_owned)
		if int(unit.clock) <= 0: _hatch_sea_egg(owner, slot, player_owned)
	else:
		unit.frozen = maxi(int(unit.get("frozen", 0)), maxi(1, duration))
		call_deferred("_flash_board_ability", slot, {"id":"FREEZE %d" % duration, "cost":{"Water":1}}, player_owned)

func _hatch_sea_egg(owner: Dictionary, slot: int, player_owned: bool) -> void:
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	owner.board[slot] = _unit_record(database.get_card("sea_drake", profile.merged_cards))
	call_deferred("_flash_board_ability", slot, {"id":"HATCH", "cost":{"Water":1}}, player_owned)

func _apply_bounce_on_play(opponent: Dictionary, count: int, opponent_is_bot := true) -> void:
	for ignored in count:
		var slot := _highest_threat_slot(opponent)
		if slot < 0: return
		_animate_bounced_card("bot" if opponent_is_bot else "player", slot, database.get_card(opponent.board[slot].id, profile.merged_cards))
		opponent.hand.append(str(opponent.board[slot].id))
		opponent.board[slot] = null

func _animate_bounced_card(side: String, slot: int, card: Dictionary) -> void:
	var nodes := bot_slot_nodes if side == "bot" else player_slot_nodes
	var source: Control = nodes.get(slot)
	if not is_instance_valid(source): return
	_ability_flash(source, {"id":"Bounce", "cost":{}})
	var ghost := _portrait_visual(card, {}, true, 104)
	ghost.position = source.global_position
	ghost.size = source.size
	ghost.z_index = 700
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	_ability_flash(ghost, {"id":"Bounce", "cost":{}})
	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "position:y", ghost.position.y - 70.0, 0.42)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.42)
	tween.chain().tween_callback(ghost.queue_free)

func _begin_player_spell(card: Dictionary) -> bool:
	var ability: Dictionary = _ability_ref(card.abilities[0]) if not card.abilities.is_empty() else {}
	match str(card.id):
		"fireball": _begin_effect_target("damage", _ability_strength(ability), "any_damageable", str(card.id), -1, true)
		"ember_offering": _begin_effect_target("sacrifice_mana", _ability_strength(ability), "friendly_creature", str(card.id), -1, true)
		"ashen_bargain": _begin_effect_target("sacrifice_draw", _ability_strength(ability), "friendly_creature", str(card.id), -1, true)
		"berserker_draught": _begin_effect_target("rage", _ability_strength(ability), "any_card", str(card.id), -1, true)
		"searing_brand": _begin_effect_target("burn", _ability_strength(ability), "any_damageable", str(card.id), -1, true)
		"ember_infusion": _begin_effect_target("grant_burn", _ability_strength(ability), "any_creature", str(card.id), -1, true)
		"deep_freeze": _begin_effect_target("freeze_multi", _ability_strength(ability), "any_creature", str(card.id), -1, true, int(ability.get("target_count", 3)))
		"protective_canopy": _begin_effect_target("shell_multi", _ability_strength(ability), "friendly_creature", str(card.id), -1, true, int(ability.get("target_count", 3)))
		"nurturing_touch": _begin_effect_target("nature_buff", _ability_strength(ability), "friendly_creature", str(card.id), -1, true)
		"thorn_volley", "wildheart_strike": _begin_effect_target("swarm_damage", _ability_strength(ability), "any_damageable", str(card.id), -1, true)
		_: return false
	return true

func _begin_effect_target(effect: String, strength: int, rule: String, card_id: String, source_slot := -1, pending_spell := false, target_count := 1) -> void:
	match_state.targeting = {"kind":"effect", "effect":effect, "strength":strength, "rule":rule, "card_id":card_id, "source":source_slot, "pending_spell":pending_spell, "remaining":target_count, "selected":[]}
	match_state.message = "Select a highlighted target for %s." % database.get_card(card_id, profile.merged_cards).display_name

func _board_target_clicked(side: String, slot: int) -> void:
	if match_state.targeting.get("kind", "") == "ability":
		if side == "bot": _enemy_slot_clicked(slot)
		return
	if match_state.targeting.get("kind", "") != "effect" or not _is_effect_targetable(side, slot): return
	_resolve_player_effect_target(side, slot, false)

func _hp_target_input(event: InputEvent, side: String) -> void:
	if ((event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)) and _is_hp_targetable():
		_resolve_player_effect_target(side, -1, true)

func _is_hp_targetable() -> bool:
	return match_state.targeting.get("kind", "") == "effect" and str(match_state.targeting.get("rule", "")) == "any_damageable"

func _is_effect_targetable(side: String, slot: int) -> bool:
	if match_state.targeting.get("kind", "") != "effect": return false
	var owner: Dictionary = match_state.player if side == "player" else match_state.bot
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return false
	var card := database.get_card(owner.board[slot].id, profile.merged_cards)
	var rule := str(match_state.targeting.get("rule", ""))
	if "%s:%d" % [side, slot] in match_state.targeting.get("selected", []): return false
	if rule == "friendly_creature": return side == "player" and str(card.card_type) == "Creature"
	if rule == "enemy_creature": return side == "bot" and str(card.card_type) == "Creature"
	if rule == "any_creature": return str(card.card_type) == "Creature"
	if rule in ["any_damageable", "any_card"]: return int(card.max_hp) > 0
	return false

func _resolve_player_effect_target(side: String, slot: int, targets_player: bool) -> void:
	var targeting: Dictionary = match_state.targeting.duplicate(true)
	match_state.targeting = {}
	var effect := str(targeting.effect)
	var strength := int(targeting.strength)
	if effect == "damage":
		if targets_player: _deal_player_damage(side, strength)
		else: _deal_unit_damage(side, slot, strength)
	elif effect == "swarm_damage":
		var swarm_damage := _friendly_creature_count(match_state.player) * strength
		if targets_player: _deal_player_damage(side, swarm_damage)
		else: _deal_unit_damage(side, slot, swarm_damage)
		match_state.message = "The swarm deals %d damage." % swarm_damage
	elif effect == "burn":
		if targets_player:
			var player_owner: Dictionary = match_state.player if side == "player" else match_state.bot
			player_owner.burn = int(player_owner.get("burn", 0)) + strength
			call_deferred("_flash_burn_target", side, -1, true, strength)
		else:
			var burn_owner: Dictionary = match_state.player if side == "player" else match_state.bot
			burn_owner.board[slot].burn = int(burn_owner.board[slot].get("burn", 0)) + strength
			call_deferred("_flash_burn_target", side, slot, false, strength)
		match_state.message = "Added %d Burn. It will resolve at the end of that side's turn." % strength
	elif effect == "grant_burn":
		var grant_owner: Dictionary = match_state.player if side == "player" else match_state.bot
		grant_owner.board[slot].bonus_burn = int(grant_owner.board[slot].get("bonus_burn", 0)) + strength
		call_deferred("_flash_burn_target", side, slot, false, strength)
		match_state.message = "The target permanently gained Burn %d." % strength
	elif effect in ["freeze", "freeze_multi"]:
		var freeze_owner: Dictionary = match_state.player if side == "player" else match_state.bot
		_apply_freeze_to_unit(freeze_owner, slot, strength, side == "player")
		match_state.message = "Target frozen for %d combat phase%s." % [strength, "" if strength == 1 else "s"]
		if effect == "freeze_multi":
			var selected: Array = targeting.get("selected", [])
			selected.append("%s:%d" % [side, slot])
			targeting.selected = selected
			targeting.remaining = int(targeting.get("remaining", 1)) - 1
			match_state.targeting = targeting
			if int(targeting.remaining) > 0 and _has_effect_targets():
				match_state.message = "Deep Freeze: select up to %d more creature%s." % [int(targeting.remaining), "" if int(targeting.remaining) == 1 else "s"]
				_refresh_match()
				return
			match_state.targeting = {}
	elif effect == "shell_multi":
		_apply_temporary_shell(match_state.player, slot, strength, 2, true)
		var selected: Array = targeting.get("selected", [])
		selected.append("%s:%d" % [side, slot])
		targeting.selected = selected
		targeting.remaining = int(targeting.get("remaining", 1)) - 1
		match_state.targeting = targeting
		if int(targeting.remaining) > 0 and _has_effect_targets():
			match_state.message = "Protective Canopy: choose up to %d more creature%s." % [int(targeting.remaining), "" if int(targeting.remaining) == 1 else "s"]
			_refresh_match()
			return
		match_state.targeting = {}
	elif effect == "nature_buff":
		_apply_permanent_unit_buff(match_state.player, slot, strength, strength, true, "NURTURED")
	elif effect in ["sacrifice_mana", "sacrifice_draw"]:
		_sacrifice_unit("player", slot)
		if effect == "sacrifice_mana":
			_gain_mana(match_state.player.mana, "Fire", strength)
			match_state.message = "The offering yields %d Fire mana." % strength
		else:
			for i in strength: _draw_card(match_state.player)
			match_state.message = "Ashen Bargain draws %d cards." % strength
	elif effect == "rage":
		var owner: Dictionary = match_state.player if side == "player" else match_state.bot
		if owner.board[slot] != null:
			owner.board[slot].attack = int(owner.board[slot].attack) + strength
			owner.board[slot].hp = int(owner.board[slot].hp) - 3
			if int(owner.board[slot].hp) <= 0: _destroy_unit(side, slot)
			match_state.message = "Berserker Draught grants +%d ATK and deals 3 damage." % strength
	if bool(targeting.get("pending_spell", false)):
		match_state.player.discard.append(str(targeting.card_id))
	_refresh_match()

func _has_effect_targets() -> bool:
	for side in ["player", "bot"]:
		var owner: Dictionary = match_state.player if side == "player" else match_state.bot
		for slot in owner.board.size():
			if _is_effect_targetable(side, slot): return true
	return false

func _deal_player_damage(side: String, amount: int) -> void:
	var owner: Dictionary = match_state.player if side == "player" else match_state.bot
	owner.hp = int(owner.hp) - amount
	_sync_hp_ui()
	_animate_hp_damage(player_hp_bar if side == "player" else bot_hp_bar, amount)
	if int(owner.hp) <= 0:
		_finish_match("The bot wins." if side == "player" else "You win.", side == "bot")

func _deal_unit_damage(side: String, slot: int, amount: int) -> void:
	var owner: Dictionary = match_state.player if side == "player" else match_state.bot
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	owner.board[slot].hp = int(owner.board[slot].hp) - amount
	if int(owner.board[slot].hp) <= 0: _destroy_unit(side, slot)
	_refresh_match()
	var nodes := player_slot_nodes if side == "player" else bot_slot_nodes
	var portrait: Control = nodes.get(slot)
	if is_instance_valid(portrait): _floating_damage(portrait, amount)

func _resolve_burn_animated(owner: Dictionary, side: String) -> void:
	var player_burn := int(owner.get("burn", 0))
	var burned_slots: Array[Dictionary] = []
	owner.burn = 0
	for slot in owner.board.size():
		var unit: Variant = owner.board[slot]
		if unit == null: continue
		var amount := int(unit.get("burn", 0))
		if amount <= 0: continue
		unit.burn = 0
		unit.hp = int(unit.hp) - amount
		burned_slots.append({"slot":slot, "amount":amount})
	if player_burn <= 0 and burned_slots.is_empty(): return
	match_state.message = "%s Burn ignites." % ("Your" if side == "player" else "Opponent")
	if is_instance_valid(match_status): match_status.text = match_state.message
	if player_burn > 0:
		owner.hp = int(owner.hp) - player_burn
		_sync_hp_ui()
		_animate_hp_damage(player_hp_bar if side == "player" else bot_hp_bar, player_burn)
	for event in burned_slots:
		var slot := int(event.slot)
		_sync_unit_portrait(side, slot)
		var nodes: Dictionary = player_slot_nodes if side == "player" else bot_slot_nodes
		var portrait: Variant = nodes.get(slot)
		if is_instance_valid(portrait):
			_ability_flash(portrait, {"id":"BURN", "cost":{"Fire":1}})
			_floating_damage(portrait, int(event.amount))
	await get_tree().create_timer(0.48).timeout
	for event in burned_slots:
		var slot := int(event.slot)
		if slot < owner.board.size() and owner.board[slot] != null and int(owner.board[slot].hp) <= 0:
			_destroy_unit(side, slot)
	if int(owner.hp) <= 0:
		_finish_match("The bot wins." if side == "player" else "You win.", side == "bot")
	_refresh_match()

func _resolve_clocks_animated(owner: Dictionary, side: String) -> void:
	var ticking_slots: Array[int] = []
	var player_owned := side == "player"
	for slot in owner.board.size():
		var unit: Variant = owner.board[slot]
		if unit == null: continue
		var card := database.get_card(unit.id, profile.merged_cards)
		if not _has_ability(card, "Clock"): continue
		unit.clock = maxi(0, int(unit.get("clock", _card_ability_strength(card, "Clock"))) - 1)
		ticking_slots.append(slot)
		if int(unit.clock) <= 0:
			_hatch_sea_egg(owner, slot, player_owned)
		else:
			call_deferred("_flash_board_ability", slot, {"id":"CLOCK %d" % int(unit.clock), "cost":{"Water":1}}, player_owned)
	if ticking_slots.is_empty(): return
	match_state.message = "%s Sea Egg clocks advance." % ("Your" if player_owned else "Opponent")
	_refresh_match()
	await get_tree().create_timer(0.55).timeout

func _sacrifice_unit(side: String, slot: int) -> void:
	var owner: Dictionary = match_state.player if side == "player" else match_state.bot
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	owner.discard.append(str(owner.board[slot].id))
	owner.board[slot] = null

func _destroy_unit(side: String, slot: int) -> void:
	var owner: Dictionary = match_state.player if side == "player" else match_state.bot
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	var unit: Dictionary = owner.board[slot]
	var card := database.get_card(unit.id, profile.merged_cards)
	owner.discard.append(str(unit.id))
	owner.board[slot] = null
	var spark := _card_ability_strength(card, "Last Spark")
	if spark > 0: _deal_player_damage("bot" if side == "player" else "player", spark)

func _bot_apply_damage_target(damage: int) -> void:
	var target := _bot_damage_target(damage)
	if bool(target.get("player", false)): _deal_player_damage("player", damage)
	else: _deal_unit_damage("player", int(target.get("slot", -1)), damage)

func _bot_apply_burn_target(amount: int) -> void:
	var target := _bot_burn_target(amount)
	if bool(target.get("player", false)):
		match_state.player.burn = int(match_state.player.get("burn", 0)) + amount
		call_deferred("_flash_burn_target", "player", -1, true, amount)
	else:
		var slot := int(target.get("slot", -1))
		if slot >= 0 and match_state.player.board[slot] != null:
			match_state.player.board[slot].burn = int(match_state.player.board[slot].get("burn", 0)) + amount
			call_deferred("_flash_burn_target", "player", slot, false, amount)

func _bot_burn_target(amount: int) -> Dictionary:
	var pending_player := int(match_state.player.get("burn", 0)) + amount
	if int(match_state.player.hp) <= pending_player: return {"player":true}
	var best := {"player":true, "score":-750.0 + float(pending_player)}
	for slot in match_state.player.board.size():
		var unit: Variant = match_state.player.board[slot]
		if unit == null: continue
		var card := database.get_card(unit.id, profile.merged_cards)
		if int(card.max_hp) <= 0: continue
		var pending := int(unit.get("burn", 0)) + amount
		var threat := _unit_threat(unit, card, match_state.player, match_state.bot)
		var score := threat - float(unit.hp) + float(pending) * 1.5
		if int(unit.hp) <= pending: score += 1000.0 + threat * 3.0
		if score > float(best.score): best = {"player":false, "slot":slot, "score":score}
	return best

func _flash_burn_target(side: String, slot: int, targets_player: bool, amount: int) -> void:
	var target: Variant = (player_hp_bar if side == "player" else bot_hp_bar) if targets_player else (player_slot_nodes if side == "player" else bot_slot_nodes).get(slot)
	if not is_instance_valid(target): return
	_ability_flash(target, {"id":"BURN +%d" % amount, "cost":{"Fire":1}})

func _bot_damage_target(damage: int) -> Dictionary:
	if int(match_state.player.hp) <= damage: return {"player":true}
	var best := {"player":true, "score":-1000.0}
	for slot in match_state.player.board.size():
		var unit: Variant = match_state.player.board[slot]
		if unit == null: continue
		var card := database.get_card(unit.id, profile.merged_cards)
		if int(card.max_hp) <= 0: continue
		var threat := _unit_threat(unit, card, match_state.player, match_state.bot)
		var score := threat - float(unit.hp) * 1.5
		if int(unit.hp) <= damage: score += 1000.0 + threat * 3.0
		if score > float(best.score): best = {"player":false, "slot":slot, "score":score}
	return best

func _unit_threat(unit: Dictionary, card: Dictionary, owner: Dictionary = {}, opponent: Dictionary = {}) -> float:
	var score := float(unit.get("attack", 0)) * 4.0 + float(unit.get("hp", 0))
	score += float(unit.get("bonus_burn", 0)) * 3.0
	score -= float(mini(int(unit.get("burn", 0)), int(unit.get("hp", 0))))
	for reference in card.get("abilities", []):
		var ability := _ability_ref(reference)
		score += float(_ability_strength(ability)) * (3.0 if str(ability.id) in ["Burn", "Scald", "Flame Strike", "Fury", "Growth"] else 1.5)
		if str(ability.id) in ["Freeze", "Strike", "Regeneration"]: score += 6.0
	if str(card.card_type) == "Structure": score += 5.0
	if not owner.is_empty():
		var damaged_allies := 0
		var matching_subtypes := 0
		for ally in owner.get("board", []):
			if ally == null: continue
			if int(ally.hp) < int(ally.max_hp): damaged_allies += 1
			var ally_card := database.get_card(ally.id, profile.merged_cards)
			for subtype in card.get("subtypes", []):
				if subtype in ally_card.get("subtypes", []): matching_subtypes += 1
		if _has_ability(card, "Regeneration"): score += float(damaged_allies) * 2.0 + (4.0 if int(owner.get("hp", 100)) < 70 else 0.0)
		score += float(maxi(0, matching_subtypes - card.get("subtypes", []).size())) * 0.75
	if not opponent.is_empty() and _has_ability(card, "Freeze"):
		var largest_attack := 0
		for enemy in opponent.get("board", []):
			if enemy != null: largest_attack = maxi(largest_attack, int(enemy.attack))
		score += float(largest_attack) * 0.5
	return score

func _random_empty_slot(board: Array) -> int:
	var empty: Array[int] = []
	for i in board.size():
		if board[i] == null: empty.append(i)
	if empty.is_empty(): return -1
	return empty[match_state.rng.randi_range(0, empty.size() - 1)]

func _begin_pillar_merge(index: int) -> void:
	if bool(match_state.busy): return
	match_state.targeting = {"kind":"pillar_merge", "source":index}
	match_state.message = "Select a compatible base Pillar to complete the merge."
	_refresh_match()

func _pillar_clicked(index: int) -> void:
	if match_state.targeting.get("kind", "") != "pillar_merge": return
	var source := int(match_state.targeting.source)
	if source == index or source >= match_state.player.pillars.size() or index >= match_state.player.pillars.size(): return
	var first: Dictionary = match_state.player.pillars[source]
	var second: Dictionary = match_state.player.pillars[index]
	var hybrid := fusion_engine.fusion_element(first.element, second.element)
	if hybrid.is_empty():
		match_state.message = "Those Pillars are not a compatible base pair."
		_refresh_match()
		return
	match_state.targeting = {"kind":"pillar_attune", "source":source, "target":index, "hybrid":hybrid, "elements":[str(first.element), str(second.element)]}
	match_state.message = "Choose which source element the %s Pillar will Attune to." % hybrid
	_refresh_match()
	_show_attune_overlay(source, index, hybrid, [str(first.element), str(second.element)])

func _attuned_pillar_id(hybrid: String, attunement: String) -> String:
	return "pillar_%s_%s" % [hybrid.to_lower(), attunement.to_lower()]

func _show_attune_overlay(source: int, target: int, hybrid: String, elements: Array) -> void:
	var previous := get_node_or_null("AttuneOverlay")
	if previous: previous.queue_free()
	var shade := ColorRect.new()
	shade.name = "AttuneOverlay"
	shade.color = Color(0.01, 0.02, 0.04, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 650
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 500)
	box.add_theme_constant_override("separation", 14)
	box.add_child(_section_title("Attune the %s Pillar" % hybrid, "Choose which source element pays for this Pillar when included in a deck."))
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 28)
	for element in elements:
		var id := _attuned_pillar_id(hybrid, str(element))
		var card := database.get_card(id, profile.merged_cards)
		var choice := VBoxContainer.new()
		choice.add_child(_full_card(card, -1))
		var attune := _button("Attune to %s" % element, _element_color(str(element)))
		attune.pressed.connect(_complete_pillar_attunement.bind(source, target, id))
		choice.add_child(attune)
		choices.add_child(choice)
	box.add_child(choices)
	var cancel := _button("Cancel merge", MUTED)
	cancel.pressed.connect(_cancel_pillar_attunement)
	box.add_child(cancel)
	center.add_child(_panel(box))

func _complete_pillar_attunement(source: int, target: int, hybrid_id: String) -> void:
	if source < 0 or target < 0 or source == target or source >= match_state.player.pillars.size() or target >= match_state.player.pillars.size():
		_cancel_pillar_attunement()
		return
	for remove_index in [maxi(source, target), mini(source, target)]: match_state.player.pillars.remove_at(remove_index)
	match_state.player.pillars.append(_pillar_record(hybrid_id))
	match_state.targeting = {}
	var card := database.get_card(hybrid_id, profile.merged_cards)
	match_state.message = "%s created. It will produce mana at end of turn." % card.display_name
	var overlay := get_node_or_null("AttuneOverlay")
	if overlay: overlay.queue_free()
	_refresh_match()

func _cancel_pillar_attunement() -> void:
	match_state.targeting = {}
	match_state.message = "Pillar merge cancelled."
	var overlay := get_node_or_null("AttuneOverlay")
	if overlay: overlay.queue_free()
	_refresh_match()

func _activate_ability(slot: int, ability_index: int) -> void:
	if bool(match_state.busy) or not match_state.targeting.is_empty() or slot < 0 or slot >= 32: return
	var unit: Variant = match_state.player.board[slot]
	if unit == null: return
	var card := database.get_card(unit.id, profile.merged_cards)
	if ability_index >= card.abilities.size(): return
	var ability := _ability_ref(card.abilities[ability_index])
	if ability.kind != "activated": return
	if int(unit.get("frozen", 0)) > 0:
		match_state.message = "%s is frozen and cannot activate abilities." % card.display_name
		_refresh_match()
		return
	if bool(unit.get("abilities_used", {}).get(str(ability_index), false)) and not bool(ability.get("repeatable", false)):
		match_state.message = "%s has already used that ability this turn." % card.display_name
		_refresh_match()
		return
	if ability.id == "Strike" and bool(unit.get("strike_ready", false)):
		match_state.message = "Strike is already prepared for this combat."
		_refresh_match()
		return
	if not _can_pay(match_state.player.mana, ability.cost):
		match_state.message = "Not enough mana for %s." % ability.id
		_refresh_match()
		return
	if ability.target == "enemy_card":
		match_state.targeting = {"kind":"ability", "source":slot, "ability":ability}
		match_state.message = "Select an opposing card for %s." % ability.id
	else:
		_pay(match_state.player.mana, ability.cost)
		_execute_ability(slot, ability, -1)
	_refresh_match()

func _enemy_slot_clicked(slot: int) -> void:
	if match_state.targeting.get("kind", "") != "ability" or match_state.bot.board[slot] == null: return
	var ability: Dictionary = match_state.targeting.ability
	if not _can_pay(match_state.player.mana, ability.cost): return
	_pay(match_state.player.mana, ability.cost)
	_execute_ability(int(match_state.targeting.source), ability, slot)
	match_state.targeting = {}
	_refresh_match()

func _execute_ability(source_slot: int, ability: Dictionary, target_slot: int) -> void:
	var source_card := database.get_card(match_state.player.board[source_slot].id, profile.merged_cards)
	for ability_index in source_card.abilities.size():
		if _ability_ref(source_card.abilities[ability_index]).id == ability.id:
			match_state.player.board[source_slot].get_or_add("abilities_used", {})[str(ability_index)] = true
			break
	call_deferred("_flash_board_ability", source_slot, ability, true)
	match ability.id:
		"Freeze":
			var duration := maxi(1, _ability_strength(ability))
			_apply_freeze_to_unit(match_state.bot, target_slot, duration, false)
			match_state.message = "The target is frozen for %d turn%s." % [duration, "" if duration == 1 else "s"]
		"Strike":
			match_state.player.board[source_slot].strike_ready = true
			match_state.message = "Strike prepared: a random opposing creature will be attacked this combat."
		"Heal":
			var healing := _ability_strength(ability)
			match_state.player.hp = mini(100, int(match_state.player.hp) + healing)
			match_state.message = "Restored %d HP." % healing
		"Spawn Sapling":
			if _spawn_token(match_state.player, "sapling", true):
				match_state.message = "A Sapling joins your battlefield."
			else:
				match_state.message = "The battlefield is full."

func _end_turn() -> void:
	if bool(match_state.busy) or bool(match_state.finished) or not match_state.targeting.is_empty(): return
	match_state.busy = true
	match_state.targeting = {}
	_refresh_match()
	await _resolve_combat_animated(match_state.player, match_state.bot, true)
	if match_state.finished:
		match_state.busy = false
		_refresh_match()
		return
	await _resolve_burn_animated(match_state.player, "player")
	if match_state.finished:
		match_state.busy = false
		_refresh_match()
		return
	await _resolve_clocks_animated(match_state.player, "player")
	await _resolve_spore_attrition_animated(match_state.player, "player")
	await _produce_pillar_mana_animated(match_state.player, player_pillars)
	await _bot_turn()
	if match_state.finished:
		match_state.busy = false
		_refresh_match()
		return
	match_state.turn += 1
	_apply_turn_start(match_state.player, true)
	_draw_card(match_state.player)
	match_state.busy = false
	match_state.message = "Turn %d. Play cards and abilities in any order." % match_state.turn
	_refresh_match()

func _bot_turn() -> void:
	var bot: Dictionary = match_state.bot
	var player: Dictionary = match_state.player
	_apply_turn_start(bot, false)
	_draw_card(bot)
	if not str(bot.get("foundation", "")).is_empty():
		var foundation := database.get_card(str(bot.foundation), profile.merged_cards)
		bot.pillars.append(_pillar_record(foundation.id))
		bot.foundation = ""
	if not str(bot.get("vanguard", "")).is_empty():
		bot.hand.append(str(bot.vanguard))
		bot.vanguard = ""
	for i in range(bot.hand.size() - 1, -1, -1):
		var card := database.get_card(bot.hand[i], profile.merged_cards)
		if card.is_pillar and _can_pay(bot.mana, card.cost):
			_pay(bot.mana, card.cost)
			bot.hand.remove_at(i)
			bot.pillars.append(_pillar_record(card.id))
	_bot_merge_pillars(bot)
	for i in range(bot.hand.size() - 1, -1, -1):
		var card := database.get_card(bot.hand[i], profile.merged_cards)
		if not card.is_pillar and _can_pay(bot.mana, card.cost):
			if card.card_type == "Spell" and not _bot_can_use_spell(card): continue
			var slot := _random_empty_slot(bot.board)
			if card.card_type != "Spell" and slot < 0: continue
			_pay(bot.mana, card.cost)
			bot.hand.remove_at(i)
			if card.card_type == "Spell":
				_resolve_bot_spell(card)
				bot.discard.append(card.id)
			else:
				bot.board[slot] = _unit_record(card)
				_apply_on_play(card, player, false, slot)
				if player.hp <= 0:
					_finish_match("The bot wins.", false)
					return
	_refresh_match()
	_bot_activate_board_abilities(bot, player)
	_refresh_match()
	await _resolve_combat_animated(bot, player, false)
	if match_state.finished: return
	await _resolve_burn_animated(bot, "bot")
	if match_state.finished: return
	await _resolve_clocks_animated(bot, "bot")
	await _resolve_spore_attrition_animated(bot, "bot")
	await _produce_pillar_mana_animated(bot, bot_pillars)

func _bot_activate_board_abilities(bot: Dictionary, player: Dictionary) -> void:
	for slot in 32:
		if bot.board[slot] != null:
			if int(bot.board[slot].get("frozen", 0)) > 0: continue
			var card := database.get_card(bot.board[slot].id, profile.merged_cards)
			for ability_index in card.abilities.size():
				var ability := _ability_ref(card.abilities[ability_index])
				if ability.kind != "activated" or bool(bot.board[slot].get("abilities_used", {}).get(str(ability_index), false)) or not _can_pay(bot.mana, ability.cost): continue
				var activated := false
				match str(ability.id):
					"Strike":
						bot.board[slot].strike_ready = true
						activated = true
					"Freeze":
						var target := _highest_value_slot(player, bot)
						if target >= 0:
							_apply_freeze_to_unit(player, target, maxi(1, _ability_strength(ability)), true)
							activated = true
					"Spawn Sapling":
						activated = _spawn_token(bot, "sapling", false)
				if activated:
					_pay(bot.mana, ability.cost)
					bot.board[slot].get_or_add("abilities_used", {})[str(ability_index)] = true
					var bot_portrait: Control = bot_slot_nodes.get(slot)
					if is_instance_valid(bot_portrait): _ability_flash(bot_portrait, ability)

func _flash_board_ability(slot: int, ability: Dictionary, player_owned: bool) -> void:
	var nodes := player_slot_nodes if player_owned else bot_slot_nodes
	# Deferred ability flashes can outlive a board redraw, so keep the lookup as a
	# Variant until validity has been checked instead of assigning a freed object.
	var portrait: Variant = nodes.get(slot)
	if is_instance_valid(portrait): _ability_flash(portrait, ability)

func _resolve_combat_animated(attacker: Dictionary, defender: Dictionary, player_attacking: bool) -> void:
	var ward_active := int(defender.get("cinder_ward_turns", 0)) > 0
	var provoke_targets: Array[int] = []
	for defender_slot in defender.board.size():
		if defender.board[defender_slot] == null: continue
		var provoke_card := database.get_card(defender.board[defender_slot].id, profile.merged_cards)
		for ignored in _card_ability_strength(provoke_card, "Provoke"): provoke_targets.append(defender_slot)
	var slots: Array[int] = []
	for i in 32:
		if attacker.board[i] != null:
			var card := database.get_card(attacker.board[i].id, profile.merged_cards)
			if card.card_type != "Structure": slots.append(i)
	var delay := COMBAT_DURATION / maxf(1.0, float(slots.size()))
	for slot in slots:
		var unit: Dictionary = attacker.board[slot]
		if int(unit.get("frozen", 0)) > 0:
			await get_tree().create_timer(delay).timeout
			continue
		var slot_nodes: Dictionary = player_slot_nodes if player_attacking else bot_slot_nodes
		var tile: Control = slot_nodes.get(slot)
		if tile: _attack_wave(tile)
		var card := database.get_card(unit.id, profile.merged_cards)
		var damage := int(unit.attack)
		while not provoke_targets.is_empty() and defender.board[provoke_targets[0]] == null: provoke_targets.pop_front()
		var target_slot: int = int(provoke_targets.pop_front()) if not provoke_targets.is_empty() else (_random_occupied_slot(defender.board) if bool(unit.get("strike_ready", false)) else -1)
		if target_slot >= 0 and target_slot < 32 and defender.board[target_slot] != null:
			damage += _card_ability_strength(card, "Flame Strike")
			var target_unit: Dictionary = defender.board[target_slot]
			var target_card := database.get_card(target_unit.id, profile.merged_cards)
			var return_damage := int(target_unit.attack)
			damage = maxi(0, damage - maxi(_card_ability_strength(target_card, "Shell"), int(target_unit.get("temporary_shell", 0))))
			return_damage = maxi(0, return_damage - maxi(_card_ability_strength(card, "Shell"), int(unit.get("temporary_shell", 0))))
			target_unit.hp -= damage
			unit.hp -= return_damage
			_sync_unit_portrait("bot" if player_attacking else "player", target_slot)
			_sync_unit_portrait("player" if player_attacking else "bot", slot)
			unit.strike_ready = false
			var target_nodes: Dictionary = bot_slot_nodes if player_attacking else player_slot_nodes
			var target_tile: Control = target_nodes.get(target_slot)
			if target_tile and _has_ability(target_card, "Provoke"): _ability_flash(target_tile, _card_ability(target_card, "Provoke"))
			if target_tile: _floating_damage(target_tile, damage)
			if return_damage > 0 and tile: _floating_damage(tile, return_damage)
			var target_destroyed: bool = int(target_unit.hp) <= 0
			var attacker_destroyed: bool = int(unit.hp) <= 0
			if target_destroyed:
				var target_spark := _card_ability_strength(target_card, "Last Spark")
				attacker.hp -= target_spark
				if target_spark > 0: _animate_hp_damage(player_hp_bar if player_attacking else bot_hp_bar, target_spark)
				defender.discard.append(target_unit.id)
				defender.board[target_slot] = null
			if attacker_destroyed:
				var attacker_spark := _card_ability_strength(card, "Last Spark")
				defender.hp -= attacker_spark
				if attacker_spark > 0: _animate_hp_damage(bot_hp_bar if player_attacking else player_hp_bar, attacker_spark)
				attacker.discard.append(unit.id)
				attacker.board[slot] = null
			if attacker.hp <= 0 or defender.hp <= 0:
				if attacker.hp <= 0 and defender.hp <= 0:
					_finish_match("The battle ends in a draw.", false)
				elif defender.hp <= 0:
					_finish_match("You win." if player_attacking else "The bot wins.", player_attacking)
				else:
					_finish_match("The bot wins." if player_attacking else "You win.", not player_attacking)
				return
		else:
			damage += _card_ability_strength(card, "Scald")
			defender.hp -= damage
			var inflicted_burn := _unit_burn_strength(unit, card)
			if inflicted_burn > 0:
				defender.burn = int(defender.get("burn", 0)) + inflicted_burn
				var defender_bar := bot_hp_bar if player_attacking else player_hp_bar
				if is_instance_valid(defender_bar): _ability_flash(defender_bar, {"id":"BURN +%d" % inflicted_burn, "cost":{"Fire":1}})
			unit.attack += _card_ability_strength(card, "Fury")
			unit.strike_ready = false
			_animate_hp_damage(bot_hp_bar if player_attacking else player_hp_bar, damage)
			if ward_active:
				unit.hp = int(unit.hp) - 2
				_sync_unit_portrait("player" if player_attacking else "bot", slot)
				if tile: _floating_damage(tile, 2)
				if int(unit.hp) <= 0: _destroy_unit("player" if player_attacking else "bot", slot)
		if defender.hp <= 0:
			_finish_match("You win." if player_attacking else "The bot wins.", player_attacking)
			return
		await get_tree().create_timer(delay).timeout
		_refresh_match()
	for frozen_unit in attacker.board:
		if frozen_unit != null and int(frozen_unit.get("frozen", 0)) > 0: frozen_unit.frozen = maxi(0, int(frozen_unit.frozen) - 1)
	if ward_active: defender.cinder_ward_turns = maxi(0, int(defender.cinder_ward_turns) - 1)
	_refresh_match()

func _attack_wave(tile: Control) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.add_child(overlay)
	for x in [0.0, maxf(0.0, tile.size.x - 4.0)]:
		var wave := ColorRect.new()
		wave.color = Color(GOLD, 0.9)
		wave.position = Vector2(x, tile.size.y - 6.0)
		wave.size = Vector2(4, 6)
		wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(wave)
		var tween := tile.create_tween()
		tween.set_parallel(true)
		tween.tween_property(wave, "position:y", 0.0, 0.28)
		tween.tween_property(wave, "size:y", tile.size.y, 0.28)
		tween.tween_property(wave, "modulate:a", 0.0, 0.34)
	var cleanup := tile.create_tween()
	cleanup.tween_interval(0.36)
	cleanup.tween_callback(overlay.queue_free)

func _ability_flash(portrait: Control, ability: Dictionary) -> void:
	var overlay := PanelContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var element := _first_cost_element(ability.get("cost", {}))
	var color := _element_color(element) if not element.is_empty() else GOLD
	overlay.add_theme_stylebox_override("panel", _box(Color(color, 0.28), 8, 3, color))
	var label := Label.new()
	label.text = str(ability.id).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)
	portrait.add_child(overlay)
	overlay.modulate.a = 0.0
	var tween := portrait.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.10)
	tween.tween_interval(0.22)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.24)
	tween.tween_callback(overlay.queue_free)

func _play_pending_board_animations() -> void:
	if pending_board_animations.is_empty() or match_state.is_empty(): return
	var events := pending_board_animations.duplicate(true)
	pending_board_animations.clear()
	for event in events:
		var player_owned := bool(event.get("player_owned", true))
		var owner: Dictionary = match_state.player if player_owned else match_state.bot
		var slot := int(event.get("slot", -1))
		if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: continue
		if str(owner.board[slot].get("uid", "")) != str(event.get("uid", "")): continue
		var nodes: Dictionary = player_slot_nodes if player_owned else bot_slot_nodes
		var portrait: Variant = nodes.get(slot)
		if not is_instance_valid(portrait): continue
		_animate_nature_event(portrait, str(event.get("kind", "buff")), int(event.get("amount", 0)), str(event.get("label", "")))

func _animate_nature_event(portrait: Control, kind: String, amount: int, label_text: String) -> void:
	if kind == "ability":
		_ability_flash(portrait, {"id":label_text, "cost":{"Nature":1}})
		return
	var overlay := Control.new()
	overlay.name = "NatureAnimation"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 40
	portrait.add_child(overlay)
	var glow := Panel.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _box(Color(NATURE, 0.18 if kind == "buff" else 0.30), 8, 3, Color("#b8f28e")))
	overlay.add_child(glow)
	var label := Label.new()
	label.text = label_text if not label_text.is_empty() else ("+%d" % amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#e9ffd6"))
	label.add_theme_color_override("font_shadow_color", Color("#173d16"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = Vector2(0, portrait.size.y * 0.45)
	label.size = Vector2(portrait.size.x, 28)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec() + portrait.get_instance_id()
	for i in 12:
		var mote := Panel.new()
		var radius := rng.randf_range(2.0, 4.5)
		mote.size = Vector2(radius, radius)
		mote.position = Vector2(rng.randf_range(8.0, maxf(9.0, portrait.size.x - 8.0)), portrait.size.y * rng.randf_range(0.55, 0.95))
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.add_theme_stylebox_override("panel", _box(Color("#9ee56f"), int(ceil(radius)), 0))
		overlay.add_child(mote)
		var mote_tween := mote.create_tween().set_parallel(true)
		mote_tween.tween_property(mote, "position:y", mote.position.y - rng.randf_range(28.0, 66.0), rng.randf_range(0.45, 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		mote_tween.tween_property(mote, "modulate:a", 0.0, rng.randf_range(0.45, 0.8))
	portrait.pivot_offset = portrait.size * 0.5
	if kind == "spawn": portrait.scale = Vector2(0.72, 0.72)
	var tween := portrait.create_tween()
	tween.set_parallel(true)
	tween.tween_property(portrait, "scale", Vector2(1.08, 1.08), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", 0.25, 0.42)
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_property(portrait, "scale", Vector2.ONE, 0.16)
	tween.chain().tween_callback(overlay.queue_free)

func _floating_damage(target: Control, amount: int, random_offset := false) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target.add_child(overlay)
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", FIRE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var offset := Vector2.ZERO
	if random_offset:
		var rng: RandomNumberGenerator = match_state.get("rng", RandomNumberGenerator.new())
		offset = Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-4.0, 5.0))
	label.position = Vector2(target.size.x * 0.5, 0) + offset
	overlay.add_child(label)
	var tween := target.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -34.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(overlay.queue_free)

func _animate_hp_damage(bar: Control, amount: int) -> void:
	if not is_instance_valid(bar) or amount <= 0: return
	_sync_hp_ui()
	var flash := Panel.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.add_theme_stylebox_override("panel", _box(Color(FIRE, 0.30), 7, 3, Color.WHITE))
	bar.add_child(flash)
	var tween := bar.create_tween()
	tween.tween_property(flash, "modulate:a", 0.15, 0.12)
	tween.tween_property(flash, "modulate:a", 1.0, 0.12)
	tween.tween_property(flash, "modulate:a", 0.0, 0.32)
	tween.tween_callback(flash.queue_free)
	_floating_damage(bar, amount, true)

func _sync_hp_ui() -> void:
	if match_state.is_empty() or not is_instance_valid(player_hp_bar) or not is_instance_valid(bot_hp_bar): return
	_rebuild_hp_bar(player_hp_bar, match_state.player, _incoming_face_damage(match_state.bot, match_state.player))
	_rebuild_hp_bar(bot_hp_bar, match_state.bot, _incoming_face_damage(match_state.player, match_state.bot))
	if is_instance_valid(player_stats): player_stats.text = "YOU  %d HP    Deck %d    Discard %d" % [match_state.player.hp, match_state.player.deck.size(), match_state.player.discard.size()]
	if is_instance_valid(bot_stats): bot_stats.text = "BOT  %d HP    Hand %d    Deck %d" % [match_state.bot.hp, match_state.bot.hand.size(), match_state.bot.deck.size()]

func _sync_unit_portrait(side: String, slot: int) -> void:
	var owner: Dictionary = match_state.player if side == "player" else match_state.bot
	var nodes: Dictionary = player_slot_nodes if side == "player" else bot_slot_nodes
	var portrait: Control = nodes.get(slot)
	if not is_instance_valid(portrait) or slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	var stats: Label = portrait.find_child("Stats", true, false)
	if stats: stats.text = "%d / %d" % [int(owner.board[slot].attack), int(owner.board[slot].hp)]

func _add_pillar_mana(player: Dictionary) -> void:
	for pillar in player.pillars: _gain_mana(player.mana, pillar.element, 1)

func _produce_pillar_mana_animated(player: Dictionary, container: HBoxContainer) -> void:
	match_state.message = "Pillars are producing mana."
	if is_instance_valid(match_status): match_status.text = match_state.message
	for pillar in player.pillars:
		_gain_mana(player.mana, str(pillar.element), 1)
	for stack in container.get_children():
		if not stack.is_queued_for_deletion() and stack is VBoxContainer and bool(stack.get_meta("is_pillar", false)) and stack.get_child_count() > 0 and stack.get_child(0) is Control:
			_pillar_production_flash(stack.get_child(0))
	_rebuild_mana(player_mana if container == player_pillars else bot_mana, player.mana)
	await get_tree().create_timer(1.0).timeout

func _pillar_production_flash(portrait: Control) -> void:
	var glow := Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.add_theme_stylebox_override("panel", _box(Color(GOLD, 0.18), 8, 3, GOLD))
	portrait.add_child(glow)
	glow.modulate.a = 0.0
	var tween := portrait.create_tween()
	tween.tween_property(glow, "modulate:a", 1.0, 0.25)
	tween.tween_property(glow, "modulate:a", 0.45, 0.50)
	tween.tween_property(glow, "modulate:a", 0.0, 0.25)
	tween.tween_callback(glow.queue_free)

func _apply_turn_start(player: Dictionary, player_owned := true) -> void:
	for slot in player.board.size():
		var unit: Variant = player.board[slot]
		if unit == null: continue
		unit.abilities_used = {}
		if int(unit.get("temporary_shell_turns", 0)) > 0:
			unit.temporary_shell_turns = int(unit.temporary_shell_turns) - 1
			if int(unit.temporary_shell_turns) <= 0: unit.temporary_shell = 0
		var card := database.get_card(unit.id, profile.merged_cards)
		var growth := _card_ability_strength(card, "Growth")
		if growth > 0:
			unit.attack = int(unit.attack) + growth
			unit.max_hp = int(unit.max_hp) + growth
			unit.hp = int(unit.hp) + growth
			_queue_board_animation(player, slot, player_owned, "grow", growth, "+%d/+%d" % [growth, growth])
		if _has_ability(card, "Regeneration"):
			player.hp = mini(100, int(player.hp) + 2)
			unit.hp = mini(int(unit.max_hp), int(unit.hp) + 1)
		var sprout_count := _card_ability_strength(card, "Sprout")
		if sprout_count > 0:
			_queue_board_animation(player, slot, player_owned, "ability", 0, "SPROUT %d" % sprout_count)
		for ignored in sprout_count: _spawn_token(player, "sapling", player_owned)
		var nurture := _card_ability_strength(card, "Nurture")
		if nurture > 0:
			var target := _highest_friendly_value_slot(player, slot)
			if target >= 0:
				_queue_board_animation(player, slot, player_owned, "ability", 0, "NURTURE %d" % nurture)
				player.board[target].attack = int(player.board[target].attack) + nurture
				player.board[target].max_hp = int(player.board[target].max_hp) + nurture
				player.board[target].hp = int(player.board[target].hp) + nurture
				_queue_board_animation(player, target, player_owned, "grow", nurture, "+%d/+%d" % [nurture, nurture])
	_refresh_nature_bonuses(player, player_owned)

func _highest_friendly_value_slot(owner: Dictionary, excluded_slot: int) -> int:
	var best_slot := -1
	var best_score := -INF
	for slot in owner.board.size():
		if slot == excluded_slot or owner.board[slot] == null: continue
		var card := database.get_card(owner.board[slot].id, profile.merged_cards)
		if str(card.card_type) != "Creature": continue
		var score := _unit_threat(owner.board[slot], card, owner)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot

func _refresh_nature_bonuses(owner: Dictionary, player_owned := true) -> void:
	if owner.is_empty() or not owner.has("board"): return
	for slot in owner.board.size():
		var unit: Variant = owner.board[slot]
		if unit == null: continue
		var card := database.get_card(unit.id, profile.merged_cards)
		if str(card.card_type) != "Creature": continue
		var desired_attack := 0
		var desired_hp := 0
		var pack_strength := _card_ability_strength(card, "Pack Growth")
		var living_strength := _card_ability_strength(card, "Living Grove")
		for other_slot in owner.board.size():
			if other_slot == slot or owner.board[other_slot] == null: continue
			var other_card := database.get_card(owner.board[other_slot].id, profile.merged_cards)
			if str(other_card.card_type) != "Creature": continue
			if living_strength > 0:
				desired_attack += living_strength
				desired_hp += living_strength
			if pack_strength > 0:
				for subtype in card.get("subtypes", []):
					if subtype in other_card.get("subtypes", []):
						desired_attack += pack_strength
						desired_hp += pack_strength
						break
			if "Elf" in card.get("subtypes", []): desired_attack += _card_ability_strength(other_card, "Elf Chorus")
		var attack_delta := desired_attack - int(unit.get("nature_attack_bonus", 0))
		var hp_delta := desired_hp - int(unit.get("nature_hp_bonus", 0))
		if attack_delta != 0: unit.attack = int(unit.attack) + attack_delta
		if hp_delta != 0:
			unit.max_hp = maxi(1, int(unit.max_hp) + hp_delta)
			unit.hp = clampi(int(unit.hp) + hp_delta, 1, int(unit.max_hp))
		if attack_delta > 0 or hp_delta > 0:
			var bonus_label := "+%d/+%d" % [maxi(0, attack_delta), maxi(0, hp_delta)]
			_queue_board_animation(owner, slot, player_owned, "buff", maxi(attack_delta, hp_delta), bonus_label)
		unit.nature_attack_bonus = desired_attack
		unit.nature_hp_bonus = desired_hp

func _bot_merge_pillars(player: Dictionary) -> void:
	for i in player.pillars.size():
		for j in range(i + 1, player.pillars.size()):
			var hybrid := fusion_engine.fusion_element(player.pillars[i].element, player.pillars[j].element)
			if not hybrid.is_empty():
				var elements: Array[String] = [str(player.pillars[i].element), str(player.pillars[j].element)]
				var attunement := _bot_attunement_choice(player, elements)
				player.pillars.remove_at(j)
				player.pillars.remove_at(i)
				player.pillars.append(_pillar_record(_attuned_pillar_id(hybrid, attunement)))
				return

func _bot_attunement_choice(player: Dictionary, elements: Array[String]) -> String:
	var scores := {}
	for element in elements: scores[element] = -float(player.mana.get(element, 0))
	for id in player.hand:
		var card := database.get_card(str(id), profile.merged_cards)
		for element in elements: scores[element] = float(scores[element]) + float(card.cost.get(element, 0))
	if float(scores[elements[1]]) > float(scores[elements[0]]): return elements[1]
	return elements[0]

func _resolve_spell(card: Dictionary, owner: Dictionary, opponent: Dictionary, opponent_is_bot: bool) -> void:
	var strength := _ability_strength(_ability_ref(card.abilities[0])) if not card.abilities.is_empty() else 0
	match card.id:
		"fire_rain":
			var opposing_side := "bot" if opponent_is_bot else "player"
			var targets: Array[int] = []
			for slot in opponent.board.size():
				if opponent.board[slot] != null and str(database.get_card(opponent.board[slot].id, profile.merged_cards).card_type) in ["Creature", "Structure"]: targets.append(slot)
			for slot in targets: _deal_unit_damage(opposing_side, slot, strength)
		"cinder_ward": owner.cinder_ward_turns = maxi(int(owner.get("cinder_ward_turns", 0)), int(_ability_ref(card.abilities[0]).get("duration", 3)))
		"healing_rain": owner.hp = mini(100, int(owner.hp) + strength)
		"clear_the_tide": _clear_the_tide(owner, opponent_is_bot, strength)
		"sea_nursery": _spawn_sea_eggs(owner, strength, opponent_is_bot)
		"mass_incubation": _spawn_sea_eggs(owner, strength, opponent_is_bot)
		"blizzard": _apply_blizzard(owner, opponent, opponent_is_bot, strength)
		"first_sprout":
			for ignored in strength: owner.hand.append("seed_elf")
		"grove_muster":
			for ignored in strength: _spawn_token(owner, "elder_sapling", opponent_is_bot, "MUSTER")
		"spore_cloud":
			for ignored in strength: _spawn_token(opponent, "spore", not opponent_is_bot, "SPORE")
		"elf_chorus_spell": _buff_matching_subtype(owner, "Elf", strength, opponent_is_bot)
		"verdant_surge":
			for ignored in strength: _spawn_token(owner, "seed_elf", opponent_is_bot, "SEED ELF")
			_buff_all_friendly_creatures(owner, 0, 1, opponent_is_bot, "VERDANT SURGE")
		"canopy_of_ages":
			for slot in owner.board.size():
				if owner.board[slot] != null and str(database.get_card(owner.board[slot].id, profile.merged_cards).card_type) == "Creature": _apply_temporary_shell(owner, slot, strength, int(_ability_ref(card.abilities[0]).get("duration", 2)), opponent_is_bot)
			owner.hp = mini(int(owner.get("max_hp", 100)), int(owner.hp) + int(_ability_ref(card.abilities[0]).get("healing", 5)))
		"forest_armada":
			for ignored in strength: _spawn_token(owner, "seed_elf", opponent_is_bot, "ARMADA")
			if _friendly_creature_count(owner) >= int(_ability_ref(card.abilities[0]).get("threshold", 6)): _buff_all_friendly_creatures(owner, 1, 0, opponent_is_bot, "ARMADA +1 ATK")
		"worldroot_ascension":
			_buff_all_friendly_creatures(owner, strength, strength, opponent_is_bot, "ASCENSION")
			for ignored in int(_ability_ref(card.abilities[0]).get("spawn_count", 4)): _spawn_token(owner, "seed_elf", opponent_is_bot, "SEED ELF")
		"regrowth":
			var target := _first_occupied_slot(owner.board)
			if target >= 0: owner.board[target].hp = mini(int(owner.board[target].max_hp), int(owner.board[target].hp) + strength)
	match_state.message = "%s resolved." % card.display_name

func _resolve_bot_spell(card: Dictionary) -> void:
	var ability: Dictionary = _ability_ref(card.abilities[0]) if not card.abilities.is_empty() else {}
	var strength := _ability_strength(ability)
	match str(card.id):
		"fireball": _bot_apply_damage_target(strength)
		"ember_offering":
			var slot := _bot_sacrifice_slot()
			if slot >= 0:
				_sacrifice_unit("bot", slot)
				_gain_mana(match_state.bot.mana, "Fire", strength)
		"ashen_bargain":
			var slot := _bot_sacrifice_slot()
			if slot >= 0:
				_sacrifice_unit("bot", slot)
				for i in strength: _draw_card(match_state.bot)
		"berserker_draught":
			var slot := _bot_buff_slot()
			if slot >= 0:
				match_state.bot.board[slot].attack = int(match_state.bot.board[slot].attack) + strength
				match_state.bot.board[slot].hp = int(match_state.bot.board[slot].hp) - 3
				if int(match_state.bot.board[slot].hp) <= 0: _destroy_unit("bot", slot)
		"searing_brand": _bot_apply_burn_target(strength)
		"ember_infusion":
			var slot := _highest_value_slot(match_state.bot, match_state.player)
			if slot >= 0:
				match_state.bot.board[slot].bonus_burn = int(match_state.bot.board[slot].get("bonus_burn", 0)) + strength
				call_deferred("_flash_burn_target", "bot", slot, false, strength)
		"deep_freeze": _bot_deep_freeze(strength, int(ability.get("target_count", 3)))
		"protective_canopy":
			var selected: Array[int] = []
			for ignored in int(ability.get("target_count", 3)):
				var slot := _highest_value_unselected_slot(match_state.bot, match_state.player, selected)
				if slot < 0: break
				selected.append(slot)
				_apply_temporary_shell(match_state.bot, slot, strength, int(ability.get("duration", 2)), false)
		"nurturing_touch":
			var slot := _highest_value_slot(match_state.bot, match_state.player)
			if slot >= 0: _apply_permanent_unit_buff(match_state.bot, slot, strength, strength, false, "NURTURED")
		"thorn_volley", "wildheart_strike": _bot_apply_damage_target(_friendly_creature_count(match_state.bot) * strength)
		_: _resolve_spell(card, match_state.bot, match_state.player, false)

func _friendly_creature_count(owner: Dictionary) -> int:
	var count := 0
	for unit in owner.board:
		if unit != null and str(database.get_card(unit.id, profile.merged_cards).card_type) == "Creature": count += 1
	return count

func _apply_permanent_unit_buff(owner: Dictionary, slot: int, attack: int, hp: int, player_owned: bool, label: String) -> void:
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	owner.board[slot].attack = int(owner.board[slot].attack) + attack
	owner.board[slot].max_hp = int(owner.board[slot].max_hp) + hp
	owner.board[slot].hp = int(owner.board[slot].hp) + hp
	_queue_board_animation(owner, slot, player_owned, "grow", maxi(attack, hp), label)

func _buff_all_friendly_creatures(owner: Dictionary, attack: int, hp: int, player_owned: bool, label: String) -> void:
	for slot in owner.board.size():
		if owner.board[slot] == null: continue
		if str(database.get_card(owner.board[slot].id, profile.merged_cards).card_type) != "Creature": continue
		_apply_permanent_unit_buff(owner, slot, attack, hp, player_owned, label)

func _buff_matching_subtype(owner: Dictionary, subtype: String, attack: int, player_owned: bool) -> void:
	for slot in owner.board.size():
		if owner.board[slot] == null: continue
		var card := database.get_card(owner.board[slot].id, profile.merged_cards)
		if subtype in card.get("subtypes", []): _apply_permanent_unit_buff(owner, slot, attack, 0, player_owned, "ELF CHORUS")

func _apply_temporary_shell(owner: Dictionary, slot: int, strength: int, duration: int, player_owned: bool) -> void:
	if slot < 0 or slot >= owner.board.size() or owner.board[slot] == null: return
	owner.board[slot].temporary_shell = maxi(int(owner.board[slot].get("temporary_shell", 0)), strength)
	owner.board[slot].temporary_shell_turns = maxi(int(owner.board[slot].get("temporary_shell_turns", 0)), duration)
	_queue_board_animation(owner, slot, player_owned, "ability", strength, "SHELL %d" % strength)

func _highest_value_unselected_slot(owner: Dictionary, opponent: Dictionary, excluded: Array[int]) -> int:
	var best_slot := -1
	var best_score := -INF
	for slot in owner.board.size():
		if slot in excluded or owner.board[slot] == null: continue
		var card := database.get_card(owner.board[slot].id, profile.merged_cards)
		if str(card.card_type) != "Creature": continue
		var score := _unit_threat(owner.board[slot], card, owner, opponent)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot

func _resolve_spore_attrition_animated(owner: Dictionary, side: String) -> void:
	var spore_slots: Array[int] = []
	var candidates: Array[int] = []
	for slot in owner.board.size():
		if owner.board[slot] == null: continue
		if str(owner.board[slot].id) == "spore": spore_slots.append(slot)
		if int(owner.board[slot].attack) > 0: candidates.append(slot)
	if spore_slots.is_empty() or candidates.is_empty(): return
	var rng: RandomNumberGenerator = match_state.get("rng", RandomNumberGenerator.new())
	for spore_slot in spore_slots:
		if candidates.is_empty(): break
		var target := candidates[rng.randi_range(0, candidates.size() - 1)]
		owner.board[target].attack = maxi(0, int(owner.board[target].attack) - 1)
		_queue_board_animation(owner, spore_slot, side == "player", "ability", 1, "SPORE")
		_queue_board_animation(owner, target, side == "player", "grow", -1, "-1 ATK")
		if int(owner.board[target].attack) <= 0: candidates.erase(target)
	match_state.message = "%s Spores weaken their own side." % ("Your" if side == "player" else "Opponent")
	_refresh_match()
	await get_tree().create_timer(0.5).timeout

func _clear_the_tide(owner: Dictionary, player_owned: bool, healing: int) -> void:
	owner.burn = 0
	owner.hp = mini(int(owner.get("max_hp", 100)), int(owner.hp) + healing)
	for unit in owner.board:
		if unit != null: unit.burn = 0
	var bar := player_hp_bar if player_owned else bot_hp_bar
	if is_instance_valid(bar): _ability_flash(bar, {"id":"CLEANSE +%d HP" % healing, "cost":{"Water":1}})

func _spawn_sea_eggs(owner: Dictionary, count: int, player_owned: bool) -> void:
	for ignored in count:
		if not _spawn_token(owner, "sea_egg", player_owned, "SEA EGG"): break

func _apply_blizzard(owner: Dictionary, opponent: Dictionary, owner_is_player: bool, duration: int) -> void:
	for slot in owner.board.size():
		if owner.board[slot] != null: _apply_freeze_to_unit(owner, slot, duration, owner_is_player)
	for slot in opponent.board.size():
		if opponent.board[slot] != null: _apply_freeze_to_unit(opponent, slot, duration, not owner_is_player)

func _bot_deep_freeze(duration: int, count: int) -> void:
	var targets_left := count
	var egg_slots: Array[int] = []
	for slot in match_state.bot.board.size():
		if match_state.bot.board[slot] == null: continue
		var card := database.get_card(match_state.bot.board[slot].id, profile.merged_cards)
		if _has_ability(card, "Clock"): egg_slots.append(slot)
	egg_slots.sort_custom(func(a: int, b: int): return int(match_state.bot.board[a].get("clock", 99)) < int(match_state.bot.board[b].get("clock", 99)))
	for slot in egg_slots:
		if targets_left <= 0: break
		_apply_freeze_to_unit(match_state.bot, slot, duration, false)
		targets_left -= 1
	var selected_enemy_slots: Array[int] = []
	while targets_left > 0:
		var target := -1
		var best_score := -INF
		for slot in match_state.player.board.size():
			if slot in selected_enemy_slots or match_state.player.board[slot] == null: continue
			var target_card := database.get_card(match_state.player.board[slot].id, profile.merged_cards)
			if str(target_card.card_type) != "Creature": continue
			var score := _unit_threat(match_state.player.board[slot], target_card, match_state.player, match_state.bot)
			if score > best_score:
				best_score = score
				target = slot
		if target < 0: break
		selected_enemy_slots.append(target)
		_apply_freeze_to_unit(match_state.player, target, duration, true)
		targets_left -= 1

func _bot_sacrifice_slot() -> int:
	var best_slot := -1
	var best_score := INF
	for slot in match_state.bot.board.size():
		var unit: Variant = match_state.bot.board[slot]
		if unit == null: continue
		var card := database.get_card(unit.id, profile.merged_cards)
		if str(card.card_type) != "Creature": continue
		var score := _unit_threat(unit, card, match_state.bot, match_state.player)
		if score < best_score:
			best_score = score
			best_slot = slot
	return best_slot

func _bot_buff_slot() -> int:
	var best_slot := -1
	var best_score := -INF
	for slot in match_state.bot.board.size():
		var unit: Variant = match_state.bot.board[slot]
		if unit == null: continue
		var card := database.get_card(unit.id, profile.merged_cards)
		if int(card.max_hp) <= 0: continue
		var survival_bonus := 100.0 if int(unit.hp) > 3 else 0.0
		var score := survival_bonus + _unit_threat(unit, card, match_state.bot, match_state.player)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot

func _finish_match(message: String, player_won: bool) -> void:
	if bool(match_state.get("finished", false)): return
	match_state.finished = true
	match_state.message = message
	if not bool(match_state.get("reward_applied", false)):
		profile.xp = int(profile.get("xp", 0)) + int(match_state.get("win_xp" if player_won else "loss_xp", 0))
		if player_won: profile.currency = int(profile.get("currency", 0)) + int(match_state.get("win_prize", 0))
		var next_level_xp := int(profile.get("level", 1)) * 500
		while int(profile.xp) >= next_level_xp:
			profile.level = int(profile.get("level", 1)) + 1
			next_level_xp = int(profile.level) * 500
		match_state.reward_applied = true
		store.save_profile()
	call_deferred("_return_to_lobby_after_match", message)

func _return_to_lobby_after_match(message: String) -> void:
	await get_tree().create_timer(1.15).timeout
	if match_state.is_empty() or not bool(match_state.get("finished", false)): return
	match_state.clear()
	_show_screen("Lobby")
	_notify(message)

func _refresh_match() -> void:
	if match_header == null: return
	_refresh_nature_bonuses(match_state.player, true)
	_refresh_nature_bonuses(match_state.bot, false)
	match_header.text = "%s  |  TURN %d  |  YOUR ACTIONS" % [str(match_state.get("challenge_name", "PRACTICE")).to_upper(), match_state.turn]
	end_turn_button.disabled = bool(match_state.busy) or not match_state.targeting.is_empty()
	player_stats.text = "YOU  %d HP    Deck %d    Discard %d" % [match_state.player.hp, match_state.player.deck.size(), match_state.player.discard.size()]
	bot_stats.text = "BOT  %d HP    Hand %d    Deck %d" % [match_state.bot.hp, match_state.bot.hand.size(), match_state.bot.deck.size()]
	match_status.text = match_state.message
	_rebuild_mana(player_mana, match_state.player.mana)
	_rebuild_mana(bot_mana, match_state.bot.mana)
	_rebuild_hp_bar(player_hp_bar, match_state.player, _incoming_face_damage(match_state.bot, match_state.player))
	_rebuild_hp_bar(bot_hp_bar, match_state.bot, _incoming_face_damage(match_state.player, match_state.bot))
	_update_hp_aim(player_hp_bar)
	_update_hp_aim(bot_hp_bar)
	for child in opponent_hand.get_children(): child.queue_free()
	for i in match_state.bot.hand.size():
		var opponent_card := database.get_card(match_state.bot.hand[i], profile.merged_cards)
		opponent_hand.add_child(_hand_card(opponent_card, i, false))
	_rebuild_start_zone(bot_start_zone, match_state.bot, false)
	_rebuild_board(bot_board, match_state.bot.board, false)
	_rebuild_pillars(bot_pillars, match_state.bot.pillars, false, match_state.bot.board)
	_rebuild_board(player_board, match_state.player.board, true)
	_rebuild_pillars(player_pillars, match_state.player.pillars, true, match_state.player.board)
	for child in match_hand.get_children(): child.queue_free()
	for i in match_state.player.hand.size():
		var card := database.get_card(match_state.player.hand[i], profile.merged_cards)
		match_hand.add_child(_hand_card(card, i, true))
	_rebuild_start_zone(player_start_zone, match_state.player, true)
	if not pending_board_animations.is_empty(): call_deferred("_play_pending_board_animations")

func _rebuild_start_zone(container: HBoxContainer, owner: Dictionary, player_owned: bool) -> void:
	for child in container.get_children(): child.queue_free()
	var zones: Array = ["vanguard", "foundation"] if player_owned else ["foundation", "vanguard"]
	for zone in zones:
		var id := str(owner.get(zone, ""))
		if id.is_empty(): continue
		var card := database.get_card(id, profile.merged_cards)
		var stack := VBoxContainer.new()
		var caption := Label.new()
		caption.text = zone.capitalize()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 9)
		caption.add_theme_color_override("font_color", MUTED)
		stack.add_child(caption)
		var portrait := _portrait_button(card, {}, player_owned and _is_card_playable(card), int(card.max_hp) > 0, 70)
		if player_owned: portrait.pressed.connect(_play_start_card.bind(zone))
		stack.add_child(portrait)
		container.add_child(stack)

func _rebuild_pillars(container: HBoxContainer, pillars: Array, player_owned: bool, board: Array = []) -> void:
	for child in container.get_children(): child.queue_free()
	var groups := {}
	for i in pillars.size():
		var id := str(pillars[i].card_id)
		var group: Dictionary = groups.get(id, {"count":0, "index":i})
		group["count"] = int(group.get("count", 0)) + 1
		groups[id] = group
	for card_id in groups:
		var i: int = int(groups[card_id]["index"])
		var record: Dictionary = pillars[i]
		var card := database.get_card(record.card_id, profile.merged_cards)
		var stack := VBoxContainer.new()
		stack.set_meta("is_pillar", true)
		stack.set_meta("pillar_element", str(record.element))
		stack.set_meta("pillar_count", int(groups[card_id]["count"]))
		stack.add_theme_constant_override("separation", 2)
		var portrait := _portrait_button(card, {}, false, false, 74)
		var count := int(groups[card_id]["count"])
		if count > 1:
			var count_back := PanelContainer.new()
			count_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count_back.anchor_left = 0.08
			count_back.anchor_right = 0.92
			count_back.anchor_top = 0.68
			count_back.anchor_bottom = 0.94
			count_back.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.78), 5, 0))
			var count_label := Label.new()
			count_label.text = "×%d" % count
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			count_label.add_theme_font_size_override("font_size", 16)
			count_label.add_theme_color_override("font_color", Color("#111820"))
			count_back.add_child(count_label)
			portrait.add_child(count_back)
		stack.add_child(portrait)
		if bool(card.is_base):
			var merge := _ability_button({"id":"Merge", "cost":{}, "kind":"activated"})
			merge.disabled = not player_owned
			if player_owned: merge.pressed.connect(_on_pillar_button.bind(i, true))
			stack.add_child(merge)
		container.add_child(stack)
	for slot in board.size():
		if board[slot] == null: continue
		var structure := database.get_card(board[slot].id, profile.merged_cards)
		if structure.card_type not in ["Structure", "Item"]: continue
		var structure_panel := _battlefield_card(structure, board[slot], player_owned, slot)
		container.add_child(structure_panel)
		var slot_nodes: Dictionary = player_slot_nodes if player_owned else bot_slot_nodes
		slot_nodes[slot] = structure_panel.get_meta("portrait", structure_panel)
	if pillars.is_empty() and not _board_has_back_row_card(board):
		var empty := Label.new()
		empty.text = "Pillars / structures"
		empty.add_theme_color_override("font_color", MUTED)
		container.add_child(empty)

func _on_pillar_button(index: int, is_base: bool) -> void:
	if match_state.targeting.get("kind", "") == "pillar_merge":
		_pillar_clicked(index)
	elif is_base:
		_begin_pillar_merge(index)

func _rebuild_board(field: HFlowContainer, board: Array, player_owned: bool) -> void:
	for child in field.get_children(): child.queue_free()
	var slot_nodes: Dictionary = player_slot_nodes if player_owned else bot_slot_nodes
	slot_nodes.clear()
	var owner: Dictionary = match_state.player if player_owned else match_state.bot
	_render_fire_ward(player_board_area if player_owned else bot_board_area, int(owner.get("cinder_ward_turns", 0)), player_owned)
	for slot in 32:
		var unit: Variant = board[slot]
		if unit == null: continue
		var card := database.get_card(unit.id, profile.merged_cards)
		if card.card_type in ["Structure", "Item"]: continue
		var panel := _battlefield_card(card, unit, player_owned, slot)
		field.add_child(panel)
		slot_nodes[slot] = panel.get_meta("portrait", panel)
	if field.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "No creatures in play"
		empty.add_theme_color_override("font_color", MUTED)
		field.add_child(empty)

func _render_fire_ward(area: Control, turns: int, player_owned: bool) -> void:
	if not is_instance_valid(area): return
	var previous := area.get_node_or_null("CinderWardParticles")
	if previous != null: previous.queue_free()
	if turns <= 0: return
	var layer := Control.new()
	layer.name = "CinderWardParticles"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 30
	area.add_child(layer)
	var edge := Panel.new()
	edge.name = "FireEdge"
	edge.anchor_left = 0.0
	edge.anchor_right = 1.0
	if player_owned:
		edge.anchor_top = 1.0
		edge.anchor_bottom = 1.0
		edge.offset_top = -7.0
	else:
		edge.anchor_top = 0.0
		edge.anchor_bottom = 0.0
		edge.offset_bottom = 7.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_theme_stylebox_override("panel", _box(Color(0.82, 0.12, 0.02, 0.72), 4, 2, Color("#ffb32c")))
	layer.add_child(edge)
	var counter := Label.new()
	counter.text = "🔥 %d" % turns
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override("font_size", 12)
	counter.add_theme_color_override("font_color", Color("#ffe3a1"))
	counter.position = Vector2(8, -20 if player_owned else 7)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_child(counter)
	_start_fire_ward_particles(layer, player_owned)

func _start_fire_ward_particles(layer: Control, player_owned: bool) -> void:
	if not is_instance_valid(layer): return
	var width := maxf(220.0, layer.size.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331 + (1 if player_owned else 2)
	for i in 30:
		var spark := Panel.new()
		spark.name = "FlameParticle_%d" % i
		var radius := rng.randf_range(2.0, 5.5)
		spark.size = Vector2(radius, radius * rng.randf_range(1.4, 2.5))
		spark.position = Vector2(rng.randf_range(4.0, width - 8.0), layer.size.y - 8.0 if player_owned else 2.0)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.add_theme_stylebox_override("panel", _box(Color("#ff7a18"), int(radius), 0))
		layer.add_child(spark)
		var origin := spark.position
		var travel := rng.randf_range(24.0, 58.0) * (-1.0 if player_owned else 1.0)
		var duration := rng.randf_range(0.55, 1.15)
		var delay := rng.randf_range(0.0, 0.9)
		var tween := spark.create_tween().set_loops()
		tween.tween_interval(delay)
		tween.tween_callback(func():
			if is_instance_valid(spark):
				spark.position = origin
				spark.modulate = Color(1.0, rng.randf_range(0.45, 0.9), 0.12, 0.95)
		)
		tween.tween_property(spark, "position:y", origin.y + travel, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, duration)

func _board_flow() -> HFlowContainer:
	var field := HFlowContainer.new()
	field.add_theme_constant_override("h_separation", 14)
	field.add_theme_constant_override("v_separation", 10)
	field.alignment = FlowContainer.ALIGNMENT_CENTER
	return field

func _battlefield_card(card: Dictionary, unit: Dictionary, player_owned: bool, slot: int) -> Control:
	var stack := VBoxContainer.new()
	stack.name = "Slot_%d" % slot
	stack.custom_minimum_size.x = 116
	stack.add_theme_constant_override("separation", 2)
	var portrait := _portrait_button(card, unit, false, true)
	stack.set_meta("portrait", portrait)
	portrait.pressed.connect(_board_target_clicked.bind("player" if player_owned else "bot", slot))
	var ability_target: bool = match_state.targeting.get("kind", "") == "ability" and not player_owned
	if ability_target or _is_effect_targetable("player" if player_owned else "bot", slot): _add_aim_marker(portrait)
	stack.add_child(portrait)
	for ability_index in card.abilities.size():
		var ability := _ability_ref(card.abilities[ability_index])
		if ability.kind == "activated":
			var ability_button := _ability_button(ability)
			var already_used := bool(unit.get("abilities_used", {}).get(str(ability_index), false)) and not bool(ability.get("repeatable", false))
			ability_button.disabled = not player_owned or not match_state.targeting.is_empty() or already_used or int(unit.get("frozen", 0)) > 0
			ability_button.pressed.connect(_activate_ability.bind(slot, ability_index))
			stack.add_child(ability_button)
	return stack

func _add_aim_marker(target: Control) -> void:
	var marker := Label.new()
	marker.name = "AimMarker"
	marker.text = "⌖"
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 38)
	marker.add_theme_color_override("font_color", Color.WHITE)
	marker.add_theme_color_override("font_shadow_color", FIRE)
	marker.add_theme_constant_override("shadow_offset_x", 2)
	marker.add_theme_constant_override("shadow_offset_y", 2)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(marker)

func _update_hp_aim(bar: Control) -> void:
	var old := bar.get_node_or_null("AimMarker")
	if old: old.queue_free()
	bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _is_hp_targetable() else Control.CURSOR_ARROW
	if _is_hp_targetable(): _add_aim_marker(bar)

func _board_has_back_row_card(board: Array) -> bool:
	for unit in board:
		if unit != null and database.get_card(unit.id, profile.merged_cards).card_type in ["Structure", "Item"]:
			return true
	return false

func _hand_card(card: Dictionary, index: int, player_owned: bool) -> Control:
	var playable := player_owned and _is_card_playable(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var portrait := _portrait_button(card, {}, playable, int(card.max_hp) > 0)
	var cost := _cost_badge(card.cost, playable, true)
	if player_owned:
		row.add_child(cost)
		row.add_child(portrait)
		portrait.pressed.connect(_play_hand_card.bind(index))
	else:
		row.add_child(portrait)
		row.add_child(cost)
	return row

func _is_card_playable(card: Dictionary) -> bool:
	if bool(match_state.get("busy", false)) or bool(match_state.get("finished", false)) or not match_state.get("targeting", {}).is_empty(): return false
	if bool(card.get("is_pillar", false)): return _can_pay(match_state.player.mana, card.cost)
	if not _can_pay(match_state.player.mana, card.cost): return false
	if card.card_type == "Spell":
		if str(card.id) in ["ember_offering", "ashen_bargain"]: return _first_creature_slot(match_state.player.board) >= 0
		if str(card.id) == "berserker_draught": return _first_hp_card_slot(match_state.player.board) >= 0 or _first_hp_card_slot(match_state.bot.board) >= 0
		if str(card.id) == "ember_infusion": return _first_creature_slot(match_state.player.board) >= 0 or _first_creature_slot(match_state.bot.board) >= 0
		if str(card.id) == "deep_freeze": return _first_creature_slot(match_state.player.board) >= 0 or _first_creature_slot(match_state.bot.board) >= 0
		if str(card.id) in ["sea_nursery", "mass_incubation"]: return _first_empty_slot(match_state.player.board) >= 0
		if str(card.id) == "blizzard": return _first_creature_slot(match_state.player.board) >= 0 or _first_creature_slot(match_state.bot.board) >= 0
		if str(card.id) in ["protective_canopy", "nurturing_touch"]: return _first_creature_slot(match_state.player.board) >= 0
		if str(card.id) == "grove_muster": return _first_empty_slot(match_state.player.board) >= 0
		if str(card.id) == "spore_cloud": return _first_empty_slot(match_state.bot.board) >= 0
		return true
	return _first_empty_slot(match_state.player.board) >= 0

func _bot_can_use_spell(card: Dictionary) -> bool:
	if str(card.id) in ["ember_offering", "ashen_bargain"]: return _first_creature_slot(match_state.bot.board) >= 0
	if str(card.id) == "berserker_draught": return _first_hp_card_slot(match_state.bot.board) >= 0
	if str(card.id) == "ember_infusion": return _first_creature_slot(match_state.bot.board) >= 0
	if str(card.id) == "deep_freeze": return _first_creature_slot(match_state.player.board) >= 0 or _first_creature_slot(match_state.bot.board) >= 0
	if str(card.id) in ["sea_nursery", "mass_incubation"]: return _first_empty_slot(match_state.bot.board) >= 0
	if str(card.id) == "blizzard": return _first_creature_slot(match_state.player.board) >= 0 or _first_creature_slot(match_state.bot.board) >= 0
	if str(card.id) in ["protective_canopy", "nurturing_touch"]: return _first_creature_slot(match_state.bot.board) >= 0
	if str(card.id) == "grove_muster": return _first_empty_slot(match_state.bot.board) >= 0
	if str(card.id) == "spore_cloud": return _first_empty_slot(match_state.player.board) >= 0
	if str(card.id) == "clear_the_tide":
		if int(match_state.bot.get("burn", 0)) > 0 or int(match_state.bot.hp) < int(match_state.bot.get("max_hp", 100)): return true
		for unit in match_state.bot.board:
			if unit != null and int(unit.get("burn", 0)) > 0: return true
		return false
	return true

func _portrait_button(card: Dictionary, unit: Dictionary = {}, highlighted := false, show_stats := true, edge := 112) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(edge, edge)
	button.add_theme_stylebox_override("normal", _box(Color("#00000000"), 8, 3 if highlighted else 1, GOLD if highlighted else _element_color(str(card.element_tags[0]))))
	button.add_theme_stylebox_override("hover", _box(Color("#00000000"), 8, 3, INK))
	var portrait := _portrait_visual(card, unit, show_stats, edge - 8)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	button.add_child(portrait)
	_attach_card_hover(button, card, unit)
	return button

func _portrait_visual(card: Dictionary, unit: Dictionary = {}, show_stats := true, edge := 104) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(edge, edge)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color("#0d151b"), 6, 0))
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(edge, edge)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	var image_path := str(card.get("image", "res://assets/elemental_mark.svg"))
	# Card definitions intentionally point at their final artwork names even while
	# an art set is being produced. Missing files use the elemental mark quietly.
	if not ResourceLoader.exists(image_path):
		image_path = "res://assets/elemental_mark.svg"
	art.texture = load(image_path)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var rounded_material := ShaderMaterial.new()
	rounded_material.shader = load("res://assets/ui/rounded_portrait.gdshader")
	art.material = rounded_material
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(art)
	if not unit.is_empty() and int(unit.get("frozen", 0)) > 0:
		var ice := ColorRect.new()
		ice.name = "FreezeOverlay"
		ice.color = Color(0.50, 0.88, 1.0, 0.34)
		ice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(ice)
		var frozen_label := Label.new()
		frozen_label.text = "❄ %d" % int(unit.frozen)
		frozen_label.position = Vector2(7, 5)
		frozen_label.add_theme_font_size_override("font_size", 18)
		frozen_label.add_theme_color_override("font_color", Color.WHITE)
		frozen_label.add_theme_color_override("font_shadow_color", Color("#126a93"))
		frozen_label.add_theme_constant_override("shadow_offset_x", 2)
		frozen_label.add_theme_constant_override("shadow_offset_y", 2)
		frozen_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ice.add_child(frozen_label)
		var ice_tween := ice.create_tween().set_loops()
		ice_tween.tween_property(ice, "modulate", Color(0.78, 0.94, 1.0, 0.72), 0.75)
		ice_tween.tween_property(ice, "modulate", Color.WHITE, 0.75)
	if not unit.is_empty() and int(unit.get("burn", 0)) > 0:
		var burn_badge := Label.new()
		burn_badge.name = "BurnStatus"
		burn_badge.text = "🔥 %d" % int(unit.burn)
		burn_badge.position = Vector2(6, 5)
		burn_badge.add_theme_font_size_override("font_size", 16)
		burn_badge.add_theme_color_override("font_color", Color("#fff0c2"))
		burn_badge.add_theme_color_override("font_outline_color", Color("#8b1d08"))
		burn_badge.add_theme_constant_override("outline_size", 4)
		burn_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(burn_badge)
	if not unit.is_empty() and unit.has("clock"):
		var clock_badge := Label.new()
		clock_badge.name = "ClockStatus"
		clock_badge.text = "◷ %d" % int(unit.clock)
		clock_badge.position = Vector2(edge - 48, 5)
		clock_badge.size = Vector2(42, 24)
		clock_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		clock_badge.add_theme_font_size_override("font_size", 16)
		clock_badge.add_theme_color_override("font_color", Color("#dff8ff"))
		clock_badge.add_theme_color_override("font_outline_color", Color("#07516b"))
		clock_badge.add_theme_constant_override("outline_size", 4)
		clock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(clock_badge)
	if not unit.is_empty() and int(unit.get("bonus_burn", 0)) > 0:
		var granted_burn := Label.new()
		granted_burn.name = "GrantedBurn"
		granted_burn.text = "Burn %d" % int(unit.bonus_burn)
		granted_burn.position = Vector2(5, edge - 51)
		granted_burn.add_theme_font_size_override("font_size", 11)
		granted_burn.add_theme_color_override("font_color", Color("#ffd08a"))
		granted_burn.add_theme_color_override("font_outline_color", Color("#55150a"))
		granted_burn.add_theme_constant_override("outline_size", 3)
		granted_burn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(granted_burn)
	if _has_ability(card, "Shell") or int(unit.get("temporary_shell", 0)) > 0:
		var shell := Label.new()
		shell.name = "ShellOverlay"
		shell.text = "⬡"
		shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shell.add_theme_font_size_override("font_size", int(edge * 0.72))
		shell.add_theme_color_override("font_color", Color(0.65, 0.92, 1.0, 0.40))
		shell.add_theme_color_override("font_outline_color", Color(0.15, 0.55, 0.76, 0.70))
		shell.add_theme_constant_override("outline_size", 3)
		shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(shell)
	if _has_ability(card, "Provoke"):
		var provoke := Label.new()
		provoke.name = "ProvokeIcon"
		provoke.text = "!"
		provoke.position = Vector2(edge - 29, 6)
		provoke.size = Vector2(22, 22)
		provoke.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		provoke.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		provoke.add_theme_font_size_override("font_size", 20)
		provoke.add_theme_color_override("font_color", Color("#ffd166"))
		provoke.add_theme_color_override("font_outline_color", Color("#6d270b"))
		provoke.add_theme_constant_override("outline_size", 4)
		provoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(provoke)
	if show_stats and int(card.get("max_hp", 0)) > 0:
		var stat_back := ColorRect.new()
		stat_back.color = Color(1, 1, 1, 0.76)
		stat_back.anchor_right = 1.0
		stat_back.anchor_top = 1.0
		stat_back.anchor_bottom = 1.0
		stat_back.offset_top = -30
		stat_back.offset_left = 3
		stat_back.offset_right = -3
		stat_back.offset_bottom = -3
		stat_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(stat_back)
		var stats := Label.new()
		stats.name = "Stats"
		stats.text = "%d / %d" % [int(unit.get("attack", card.attack)), int(unit.get("hp", card.max_hp))]
		stats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 19)
		stats.add_theme_color_override("font_color", Color("#111820"))
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_back.add_child(stats)
	panel.add_child(canvas)
	return panel

func _cost_badge(cost: Dictionary, highlighted := false, compact := false) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(38, 15 if compact else 32)
	if compact: badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var element := _first_cost_element(cost)
	var color := _element_color(element) if not element.is_empty() else MUTED
	badge.add_theme_stylebox_override("panel", _box(color.darkened(0.68), 8, 2 if highlighted else 1, GOLD if highlighted else color))
	var cost_content := _cost_content(cost, 10 if compact else 15, "0")
	cost_content.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(cost_content)
	return badge

func _ability_button(ability: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 27
	button.tooltip_text = "%s\n%s" % [_ability_label(ability), _ability_description(ability)]
	button.mouse_default_cursor_shape = Control.CURSOR_HELP
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_cost_content(ability.get("cost", {}), 13, "0"))
	var name := Label.new()
	name.text = str(ability.id)
	name.add_theme_font_size_override("font_size", 10)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name)
	button.add_child(content)
	return button

func _cost_content(cost: Dictionary, icon_size: int, zero_text := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cost.is_empty():
		var zero := Label.new()
		zero.text = zero_text
		zero.add_theme_font_size_override("font_size", icon_size)
		zero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(zero)
		return row
	for element in ["Fire", "Water", "Nature", "Steam", "Wildfire", "Swamp"]:
		var amount := int(cost.get(element, 0))
		if amount <= 0: continue
		var number := Label.new()
		number.text = str(amount)
		number.add_theme_font_size_override("font_size", icon_size)
		number.add_theme_color_override("font_color", _element_color(element).lightened(0.2))
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(number)
		var icon := TextureRect.new()
		icon.texture = load(_mana_icon_path(element))
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	return row

func _full_card(card: Dictionary, copies: int, compact := false, caption := "", unit: Dictionary = {}) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(176 if compact else 208, 250 if compact else 320)
	var element := str(card.element_tags[0]) if not card.element_tags.is_empty() else ""
	panel.add_theme_stylebox_override("panel", _box(_element_color(element).darkened(0.72), 12, 2, _element_color(element)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var title := HBoxContainer.new()
	var name := Label.new()
	name.text = card.display_name
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", 16)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name)
	title.add_child(_cost_badge(card.cost, false))
	box.add_child(title)
	box.add_child(_portrait_visual(card, unit, int(card.max_hp) > 0, 152 if compact else 184))
	if not caption.is_empty():
		var caption_label := Label.new()
		caption_label.text = caption
		caption_label.add_theme_color_override("font_color", INK)
		box.add_child(caption_label)
	var details_row := HBoxContainer.new()
	var type_icon := TextureRect.new()
	type_icon.texture = load(_card_type_icon(str(card.card_type)))
	type_icon.custom_minimum_size = Vector2(19, 19)
	type_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	type_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	type_icon.tooltip_text = str(card.card_type)
	details_row.add_child(type_icon)
	var details := Label.new()
	details.text = _subtype_line(card)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.autowrap_mode = TextServer.AUTOWRAP_OFF
	details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_theme_color_override("font_color", MUTED)
	details_row.add_child(details)
	box.add_child(details_row)
	var ability_list := VBoxContainer.new()
	ability_list.add_theme_constant_override("separation", 2)
	if not card.abilities.is_empty():
		for reference in card.abilities:
			var ability := _ability_ref(reference)
			var ability_row := HBoxContainer.new()
			if ability.kind == "activated": ability_row.add_child(_cost_content(ability.cost, 14, "0"))
			var ability_name := Label.new()
			ability_name.name = "AbilityText"
			var is_spell_text := str(card.card_type) == "Spell" or str(ability.kind) == "spell"
			ability_name.text = _ability_description(ability) if is_spell_text else _ability_label(ability)
			ability_name.add_theme_color_override("font_color", GOLD)
			ability_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ability_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ability_name.tooltip_text = _ability_description(ability) if is_spell_text else "%s\n%s" % [_ability_label(ability), _ability_description(ability)]
			ability_name.set_meta("ability_help_title", _ability_label(ability))
			ability_name.set_meta("ability_help_text", _ability_description(ability))
			ability_name.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_spell_text else Control.CURSOR_HELP
			ability_row.add_child(ability_name)
			ability_list.add_child(ability_row)
	if not unit.is_empty() and int(unit.get("bonus_burn", 0)) > 0:
		var granted_row := Label.new()
		granted_row.name = "GrantedAbilityText"
		granted_row.text = "Burn %d" % int(unit.bonus_burn)
		granted_row.tooltip_text = _ability_description({"id":"Burn", "strength":int(unit.bonus_burn), "cost":{}, "kind":"triggered"})
		granted_row.set_meta("ability_help_title", "Burn %d" % int(unit.bonus_burn))
		granted_row.set_meta("ability_help_text", granted_row.tooltip_text)
		granted_row.add_theme_color_override("font_color", FIRE.lightened(0.25))
		granted_row.mouse_default_cursor_shape = Control.CURSOR_HELP
		ability_list.add_child(granted_row)
	box.add_child(ability_list)
	panel.add_child(box)
	var merges := fusion_engine.merge_count(card)
	if merges > 0:
		var overlay := Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var marks := HBoxContainer.new()
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marks.anchor_left = 1.0
		marks.anchor_right = 1.0
		marks.anchor_top = 1.0
		marks.anchor_bottom = 1.0
		marks.offset_left = -18.0 * merges - 8.0
		marks.offset_right = -6.0
		marks.offset_top = -23.0
		marks.offset_bottom = -5.0
		marks.add_theme_constant_override("separation", 2)
		for merge_index in merges:
			var mark := TextureRect.new()
			mark.texture = load("res://assets/ui/merge_mark.svg")
			mark.custom_minimum_size = Vector2(16, 16)
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marks.add_child(mark)
		overlay.add_child(marks)
		panel.add_child(overlay)
	return panel

func _owned_full_card(card: Dictionary, compact: bool) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.set_meta("card_id", str(card.id))
	entry.add_theme_constant_override("separation", 3)
	entry.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_panel := _full_card(card, -1, compact)
	_set_mouse_pass(card_panel)
	entry.add_child(card_panel)
	var owned := Label.new()
	owned.text = "Owned: %d" % store.owned(card.id)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.add_theme_color_override("font_color", INK if store.owned(card.id) > 0 else MUTED)
	owned.mouse_filter = Control.MOUSE_FILTER_PASS
	entry.add_child(owned)
	return entry

func _set_mouse_pass(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children(): _set_mouse_pass(child)

func _card_type_icon(card_type: String) -> String:
	var key := card_type.to_lower()
	if key not in ["creature", "spell", "pillar", "structure", "item"]: key = "item"
	return "res://assets/types/%s.svg" % key

func _attach_card_hover(control: Control, card: Dictionary, unit: Dictionary = {}) -> void:
	control.tooltip_text = ""
	control.mouse_entered.connect(_show_card_hover.bind(card, unit))
	control.mouse_exited.connect(_hide_card_hover)

func _show_card_hover(card: Dictionary, unit: Dictionary = {}) -> void:
	_hide_card_hover()
	hover_preview = _full_card(card, -1, false, "", unit)
	hover_preview.z_index = 200
	hover_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_ignore(hover_preview)
	add_child(hover_preview)
	call_deferred("_position_card_hover")
	hover_help_ticket += 1
	var ticket := hover_help_ticket
	call_deferred("_wait_for_hover_ability_help", ticket, get_viewport().get_mouse_position())

func _position_card_hover() -> void:
	if not is_instance_valid(hover_preview): return
	var preview_size := hover_preview.get_combined_minimum_size()
	hover_preview.size = preview_size
	var mouse := get_viewport().get_mouse_position()
	var position := mouse + Vector2(18, 18)
	if position.x + preview_size.x > size.x - 8: position.x = mouse.x - preview_size.x - 18
	if position.y + preview_size.y > size.y - 8: position.y = mouse.y - preview_size.y - 18
	hover_preview.position = Vector2(clampf(position.x, 8, maxf(8, size.x - preview_size.x - 8)), clampf(position.y, 8, maxf(8, size.y - preview_size.y - 8)))

func _hide_card_hover() -> void:
	hover_help_ticket += 1
	for popup in hover_help_popups:
		if is_instance_valid(popup): popup.queue_free()
	hover_help_popups.clear()
	if is_instance_valid(hover_preview): hover_preview.queue_free()
	hover_preview = null

func _wait_for_hover_ability_help(ticket: int, stationary_position: Vector2) -> void:
	await get_tree().create_timer(2.0).timeout
	if ticket != hover_help_ticket or not is_instance_valid(hover_preview): return
	var current_position := get_viewport().get_mouse_position()
	if current_position.distance_to(stationary_position) > 6.0:
		call_deferred("_wait_for_hover_ability_help", ticket, current_position)
		return
	_show_hover_ability_help(ticket)

func _show_hover_ability_help(ticket: int) -> void:
	if ticket != hover_help_ticket or not is_instance_valid(hover_preview) or not hover_help_popups.is_empty(): return
	var ability_labels: Array = hover_preview.find_children("*", "Label", true, false).filter(func(node): return node.has_meta("ability_help_text"))
	if ability_labels.is_empty(): return
	var preview_rect := hover_preview.get_global_rect()
	var popup_x := preview_rect.end.x + 10.0
	var place_right := popup_x + 286.0 <= size.x - 8.0
	if not place_right: popup_x = preview_rect.position.x - 296.0
	var next_y := 8.0
	for ability_label in ability_labels:
		var popup := PanelContainer.new()
		popup.name = "AbilityHelpPopup"
		popup.custom_minimum_size.x = 286
		popup.z_index = 230
		popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_theme_stylebox_override("panel", _box(Color("#101820f2"), 9, 2, GOLD))
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 8)
		var text_box := VBoxContainer.new()
		text_box.add_theme_constant_override("separation", 3)
		var title := Label.new()
		title.text = str(ability_label.get_meta("ability_help_title", "Ability"))
		title.add_theme_color_override("font_color", GOLD)
		title.add_theme_font_size_override("font_size", 14)
		text_box.add_child(title)
		var description := Label.new()
		description.text = str(ability_label.get_meta("ability_help_text", ""))
		description.custom_minimum_size.x = 266
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", INK)
		description.add_theme_font_size_override("font_size", 12)
		text_box.add_child(description)
		margin.add_child(text_box)
		popup.add_child(margin)
		add_child(popup)
		popup.size = popup.get_combined_minimum_size()
		var desired_y: float = ability_label.get_global_rect().position.y - 8.0
		var popup_y: float = maxf(desired_y, next_y)
		popup.position = Vector2(popup_x, popup_y) - global_position
		next_y = popup_y + popup.size.y + 6.0
		_set_mouse_ignore(popup)
		hover_help_popups.append(popup)
	var overflow := next_y - 6.0 - (size.y - 8.0)
	if overflow > 0:
		for popup in hover_help_popups: popup.position.y = maxf(8.0, popup.position.y - overflow)

func _set_mouse_ignore(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _set_mouse_ignore(child)

func _ability_ref(reference: Variant) -> Dictionary:
	if reference is Dictionary:
		var result: Dictionary = reference.duplicate(true)
		result.get_or_add("cost", {})
		result.get_or_add("target", "none")
		result.get_or_add("kind", "triggered")
		result.get_or_add("strength", 0)
		return result
	return {"id":str(reference), "cost":{}, "target":"none", "kind":"triggered", "strength":0}

func _has_ability(card: Dictionary, id: String) -> bool:
	for reference in card.abilities:
		if _ability_ref(reference).id == id: return true
	return false

func _card_tooltip(card: Dictionary) -> String:
	var descriptions: Array[String] = []
	for reference in card.abilities:
		var ability := _ability_ref(reference)
		var description := _ability_description(ability)
		descriptions.append("%s%s: %s" % [_symbol_cost(ability.cost, true) + " " if ability.kind == "activated" else "", _ability_label(ability), description])
	return "%s\n%s\n%s" % [card.display_name, _subtype_line(card), "\n".join(descriptions)]

func _ability_description(ability: Dictionary) -> String:
	var description := str(database.abilities.get(str(ability.id), {}).get("description", "No rules description available."))
	description = description.replace("{strength}", str(_ability_strength(ability)))
	description = description.replace("{duration}", str(int(ability.get("duration", 0))))
	description = description.replace("{hp_change}", str(int(ability.get("hp_change", 0))))
	return description

func _ability_strength(ability: Dictionary) -> int:
	return int(ability.get("strength", 0))

func _card_ability_strength(card: Dictionary, id: String) -> int:
	for reference in card.abilities:
		var ability := _ability_ref(reference)
		if ability.id == id:
			return _ability_strength(ability)
	return 0

func _unit_burn_strength(unit: Dictionary, card: Dictionary) -> int:
	return _card_ability_strength(card, "Burn") + int(unit.get("bonus_burn", 0))

func _card_ability(card: Dictionary, id: String) -> Dictionary:
	for reference in card.abilities:
		var ability := _ability_ref(reference)
		if ability.id == id: return ability
	return {"id":id, "cost":{}, "kind":"triggered", "strength":0}

func _ability_label(ability: Dictionary) -> String:
	var strength := _ability_strength(ability)
	return "%s %d" % [ability.id, strength] if strength > 0 else str(ability.id)

func _abilities_line(card: Dictionary) -> String:
	var labels: Array[String] = []
	for reference in card.abilities:
		var ability := _ability_ref(reference)
		labels.append(((_symbol_cost(ability.cost, true) + " ") if ability.kind == "activated" else "") + _ability_label(ability))
	return " · ".join(labels) if not labels.is_empty() else ""

func _subtype_line(card: Dictionary) -> String:
	return " / ".join(card.get("subtypes", [])) if not card.get("subtypes", []).is_empty() else str(card.card_type)

func _symbol_cost(cost: Dictionary, symbols_only := false, zero_text := "") -> String:
	if cost.is_empty(): return zero_text if symbols_only else "Free"
	var symbols := {"Fire":"▲", "Water":"●", "Nature":"♣", "Steam":"◒", "Wildfire":"✦", "Swamp":"◆"}
	var parts: Array[String] = []
	for element in ["Fire", "Water", "Nature", "Steam", "Wildfire", "Swamp"]:
		var amount := int(cost.get(element, 0))
		if amount <= 0: continue
		parts.append(str(amount) + str(symbols[element]))
	return " ".join(parts)

func _first_cost_element(cost: Dictionary) -> String:
	for element in ["Fire", "Water", "Nature", "Steam", "Wildfire", "Swamp"]:
		if int(cost.get(element, 0)) > 0: return element
	return ""

func _rebuild_mana(container: GridContainer, mana: Dictionary) -> void:
	for child in container.get_children(): child.queue_free()
	for element in ["Fire", "Water", "Nature", "Steam", "Wildfire", "Swamp"]:
		var amount := int(mana.get(element, 0))
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(64, 34)
		cell.tooltip_text = "%s mana" % element
		cell.add_theme_stylebox_override("panel", _box(_element_color(element).darkened(0.72), 6, 1, _element_color(element).darkened(0.2)))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.texture = load(_mana_icon_path(element))
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var number := Label.new()
		number.text = str(amount)
		number.add_theme_font_size_override("font_size", 17)
		number.add_theme_color_override("font_color", INK if amount > 0 else MUTED)
		row.add_child(number)
		cell.add_child(row)
		container.add_child(cell)

func _mana_icon_path(element: String) -> String:
	return "res://assets/mana/%s.svg" % element.to_lower() if element in ["Fire", "Water", "Nature", "Steam", "Wildfire", "Swamp"] else "res://assets/mana/hybrid.svg"

func _hp_bar() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(136, 30)
	var damage := ProgressBar.new()
	damage.name = "Damage"
	damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage.show_percentage = false
	damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage.add_theme_stylebox_override("background", _box(Color("#101820"), 6, 1, Color("#55616a")))
	damage.add_theme_stylebox_override("fill", _box(Color("#c84949"), 6, 0))
	root.add_child(damage)
	var projected := ProgressBar.new()
	projected.name = "Projected"
	projected.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	projected.show_percentage = false
	projected.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projected.add_theme_stylebox_override("background", _box(Color("#00000000"), 6, 0))
	projected.add_theme_stylebox_override("fill", _box(Color("#69b85d"), 6, 0))
	root.add_child(projected)
	var label := Label.new()
	label.name = "Label"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return root

func _rebuild_hp_bar(bar: Control, owner: Dictionary, incoming: int) -> void:
	var maximum := int(owner.get("max_hp", 100))
	var current := clampi(int(owner.hp), 0, maximum)
	var projected := clampi(current - incoming, 0, maximum)
	var damage_bar: ProgressBar = bar.get_node("Damage")
	var projected_bar: ProgressBar = bar.get_node("Projected")
	damage_bar.max_value = maximum
	damage_bar.value = current
	projected_bar.max_value = maximum
	projected_bar.value = projected
	var label: Label = bar.get_node("Label")
	var burn := int(owner.get("burn", 0))
	label.text = "%d / %d%s%s" % [current, maximum, "  −%d" % incoming if incoming > 0 else "", "  🔥%d" % burn if burn > 0 else ""]

func _incoming_face_damage(attacker: Dictionary, defender: Dictionary) -> int:
	var total := 0
	var defender_has_creature := false
	for unit in defender.board:
		if unit != null and database.get_card(unit.id, profile.merged_cards).card_type == "Creature":
			defender_has_creature = true
			break
	for unit in attacker.board:
		if unit == null or bool(unit.get("frozen", false)): continue
		var card := database.get_card(unit.id, profile.merged_cards)
		if card.card_type != "Creature": continue
		if bool(unit.get("strike_ready", false)) and defender_has_creature: continue
		total += int(unit.attack) + _card_ability_strength(card, "Scald")
	return total

func _first_occupied_slot(board: Array) -> int:
	for i in board.size():
		if board[i] != null: return i
	return -1

func _first_creature_slot(board: Array) -> int:
	for i in board.size():
		if board[i] != null and str(database.get_card(board[i].id, profile.merged_cards).card_type) == "Creature": return i
	return -1

func _first_hp_card_slot(board: Array) -> int:
	for i in board.size():
		if board[i] != null and int(database.get_card(board[i].id, profile.merged_cards).max_hp) > 0: return i
	return -1

func _first_empty_slot(board: Array) -> int:
	for i in board.size():
		if board[i] == null: return i
	return -1

func _random_occupied_slot(board: Array) -> int:
	var occupied: Array[int] = []
	for i in board.size():
		if board[i] != null and database.get_card(board[i].id, profile.merged_cards).card_type == "Creature":
			occupied.append(i)
	return occupied[match_state.rng.randi_range(0, occupied.size() - 1)] if not occupied.is_empty() else -1

func _gain_mana(pool: Dictionary, element: String, amount: int) -> void:
	pool[element] = int(pool.get(element, 0)) + amount

func _can_pay(pool: Dictionary, cost: Dictionary) -> bool:
	for element in cost:
		if int(pool.get(element, 0)) < int(cost[element]): return false
	return true

func _pay(pool: Dictionary, cost: Dictionary) -> void:
	for element in cost: pool[element] = int(pool.get(element, 0)) - int(cost[element])

func _refund(pool: Dictionary, cost: Dictionary) -> void:
	for element in cost: _gain_mana(pool, element, int(cost[element]))

func _shuffle_with_rng(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value = items[i]
		items[i] = items[j]
		items[j] = value

func _section_title(title: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", INK)
	box.add_child(heading)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_color_override("font_color", MUTED)
	box.add_child(sub)
	return box

func _small_heading(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	return label

func _panel(child: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(SURFACE, 7, 1))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_child(child)
	panel.add_child(margin)
	return panel

func _button(label: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(104, 38)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _box(accent.darkened(0.58), 5, 1, accent.darkened(0.25)))
	button.add_theme_stylebox_override("hover", _box(accent.darkened(0.4), 5, 1, accent))
	return button

func _box(color: Color, radius: int, border := 0, border_color := Color("#32424d")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_width_left = border
	box.border_width_right = border
	box.border_width_top = border
	box.border_width_bottom = border
	box.border_color = border_color
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

func _element_color(element: String) -> Color:
	match element:
		"Fire": return FIRE
		"Water": return WATER
		"Nature": return NATURE
		"Steam": return Color("#9bd8dc")
		"Wildfire": return Color("#e28b3d")
		"Swamp": return Color("#7d8f55")
	return MUTED

func _screen_color(screen_name: String) -> Color:
	match screen_name:
		"Forge", "Fusion": return WATER
		"Home", "Lobby": return GOLD
		"Profile": return Color("#a98bd4")
		"Bazaar": return Color("#d99a45")
		"Deck": return NATURE
		"Match", "Combat": return FIRE
	return MUTED

func _notify(message: String) -> void:
	toast.text = message
