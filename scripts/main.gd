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
var content: MarginContainer
var toast: Label
var brand_logo: TextureRect
var brand_label: Label
var nav_buttons: Array[Button] = []
var surrender_button: Button

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
var deck_foundation := "pillar_fire"
var deck_vanguard := "ember_pup"
var hover_preview: Control

var match_state: Dictionary = {}
var match_status: Label
var match_header: Label
var match_hand: VBoxContainer
var opponent_hand: VBoxContainer
var player_start_zone: HBoxContainer
var bot_start_zone: HBoxContainer
var player_board: HFlowContainer
var bot_board: HFlowContainer
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

func _ready() -> void:
	database.load_all()
	profile = store.load_profile()
	_build_shell()
	var requested := OS.get_environment("ELEMENTALS_SCREEN")
	_show_screen(requested if requested in ["Home", "Collection", "Forge", "Fusion", "Deck", "Match"] else "Home")
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
	for screen_name in ["Home", "Collection", "Forge", "Deck", "Match"]:
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
	if screen_name == "Fusion": screen_name = "Forge"
	_hide_card_hover()
	for child in content.get_children():
		child.queue_free()
	toast.text = ""
	var screen: Control
	match screen_name:
		"Home": screen = _build_home()
		"Collection": screen = _build_collection()
		"Forge": screen = _build_fusion()
		"Deck": screen = _build_deckbuilder()
		"Match": screen = _build_match()
	for button in nav_buttons: button.visible = screen_name != "Match"
	surrender_button.visible = screen_name == "Match"
	content.add_child(screen)

func _build_home() -> Control:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 14)
	root.add_child(_section_title("Elemental Fusion", "Choose where to go"))
	for destination in ["Collection", "Deck", "Forge", "Match"]:
		var button := _button(destination, _screen_color(destination))
		button.custom_minimum_size = Vector2(300, 58)
		button.pressed.connect(_show_screen.bind(destination))
		root.add_child(button)
	return root

func _build_collection() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(_section_title("Collection", "Owned cards, merged creations, and match-only Pillars"))
	var search := LineEdit.new()
	search.placeholder_text = "Search collection"
	root.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = 6 if size.x >= 1100 else 3 if size.x >= 650 else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_rebuild_collection_grid(grid, "")
	search.text_changed.connect(func(query): _rebuild_collection_grid(grid, query))
	scroll.add_child(grid)
	root.add_child(scroll)
	return root

func _rebuild_collection_grid(grid: GridContainer, query: String) -> void:
	for child in grid.get_children(): child.queue_free()
	for card in database.all_cards(profile.merged_cards):
		if query.is_empty() or query.to_lower() in str(card.display_name).to_lower():
			grid.add_child(_owned_full_card(card, false))

func _build_fusion() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(_section_title("Forge", "Choose two cards, then select a name, artwork, and merge expression"))
	var body: BoxContainer = VBoxContainer.new() if size.x < 900 else HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	var collection_box := VBoxContainer.new()
	collection_box.custom_minimum_size.x = 330
	collection_box.add_child(_small_heading("OWNED CARDS"))
	var collection_scroll := ScrollContainer.new()
	collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var collection_grid := GridContainer.new()
	collection_grid.columns = 2
	for card in database.all_cards(profile.merged_cards):
		if store.owned(card.id) > 0 and not card.is_pillar:
			var item := _owned_full_card(card, true)
			item.gui_input.connect(_fusion_collection_input.bind(card.id))
			collection_grid.add_child(item)
	collection_scroll.add_child(collection_grid)
	collection_box.add_child(collection_scroll)
	body.add_child(_panel(collection_box))

	var work := VBoxContainer.new()
	work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.add_child(_small_heading("SELECTED CARDS"))
	var sources := HBoxContainer.new()
	sources.name = "Sources"
	work.add_child(sources)
	work.add_child(_small_heading("NAME & ARTWORK"))
	var name_picker := OptionButton.new()
	name_picker.name = "NamePicker"
	name_picker.item_selected.connect(func(index): fusion_name_index = index; fusion_selected = -1; _rebuild_fusion_work(work))
	work.add_child(name_picker)
	work.add_child(_small_heading("POSSIBLE RESULTS"))
	var result_scroll := ScrollContainer.new()
	result_scroll.name = "ResultScroll"
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	result_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	result_scroll.custom_minimum_size.y = 400
	var results := VBoxContainer.new()
	results.name = "Results"
	var confluence_label := _small_heading("CONFLUENCE — both cards combine completely")
	confluence_label.name = "ConfluenceLabel"
	results.add_child(confluence_label)
	var confluence := HBoxContainer.new()
	confluence.name = "Confluence"
	results.add_child(confluence)
	var imprint_label := _small_heading("IMPRINT — one rules identity shapes the result")
	imprint_label.name = "ImprintLabel"
	results.add_child(imprint_label)
	var imprint := HBoxContainer.new()
	imprint.name = "Imprint"
	results.add_child(imprint)
	result_scroll.add_child(results)
	work.add_child(result_scroll)
	var confirm := _button("Confirm merge", GOLD)
	confirm.name = "Confirm"
	confirm.pressed.connect(_confirm_fusion)
	work.add_child(confirm)
	body.add_child(_panel(work))
	root.add_child(body)
	_rebuild_fusion_work(work)
	return root

func _fusion_collection_input(event: InputEvent, card_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_fusion_source(card_id)
	elif event is InputEventScreenTouch and event.pressed:
		_select_fusion_source(card_id)

func _select_fusion_source(card_id: String) -> void:
	var selected_card := database.get_card(card_id, profile.merged_cards)
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
	var sources: HBoxContainer = work.get_node("Sources")
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
	var picker: OptionButton = work.get_node("NamePicker")
	picker.clear()
	var confluence: HBoxContainer = work.get_node("ResultScroll/Results/Confluence")
	var imprint: HBoxContainer = work.get_node("ResultScroll/Results/Imprint")
	var imprint_label: Label = work.get_node("ResultScroll/Results/ImprintLabel")
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
			imprint_label.visible = imprint.get_child_count() > 0
		else:
			imprint_label.visible = false
			var note := Label.new()
			note.text = "These cards cannot merge, or one has reached its two-merge limit."
			confluence.add_child(note)
	var confirm: Button = work.get_node("Confirm")
	if fusion_sources.size() < 2: imprint_label.visible = false
	confirm.disabled = fusion_selected < 0 or fusion_selected >= fusion_candidates.size()

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
		_show_screen("Collection")
		_notify("Created %s. The two source cards were consumed." % merged.display_name)
	else:
		_notify("The collection no longer contains both source cards.")

func _build_deckbuilder() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	var heading := HBoxContainer.new()
	var title := _section_title("Deckbuilder", "Click a collection card to add it; click a deck card to remove one copy")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var save := _button("Save deck", GOLD)
	save.pressed.connect(_save_deck)
	heading.add_child(save)
	root.add_child(heading)
	deck_cards.clear()
	var saved_deck: Dictionary = profile.decks.get("starter", {})
	for id in saved_deck.get("card_ids", []): deck_cards.append(str(id))
	deck_foundation = str(saved_deck.get("foundation_id", "pillar_fire"))
	deck_vanguard = str(saved_deck.get("vanguard_id", "ember_pup"))
	var starts := HBoxContainer.new()
	starts.add_theme_constant_override("separation", 14)
	starts.add_child(_deck_special_picker("FOUNDATION", "Your starting base Pillar", true))
	starts.add_child(_deck_special_picker("VANGUARD", "Your other always-available starting card", false))
	root.add_child(_panel(starts))
	var deck_box := VBoxContainer.new()
	deck_count_label = _small_heading("")
	deck_box.add_child(deck_count_label)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.custom_minimum_size.y = 250
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_cards_container = HFlowContainer.new()
	deck_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_cards_container.add_theme_constant_override("h_separation", 14)
	deck_cards_container.add_theme_constant_override("v_separation", 8)
	deck_scroll.add_child(deck_cards_container)
	deck_box.add_child(deck_scroll)
	root.add_child(_panel(deck_box))

	var collection_section := HBoxContainer.new()
	collection_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_section.add_theme_constant_override("separation", 10)
	var filters := VBoxContainer.new()
	filters.custom_minimum_size.x = 118
	filters.add_child(_small_heading("ELEMENT"))
	var elements: Array[String] = ["All"]
	for card in database.all_cards(profile.merged_cards):
		for element in card.get("element_tags", []):
			if element not in elements: elements.append(element)
	var filter_group := ButtonGroup.new()
	filter_group.allow_unpress = false
	for element in elements:
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
	if deck_cards.size() >= 120:
		_notify("The deck already contains the maximum 120 cards.")
		return
	var card := database.get_card(id, profile.merged_cards)
	if not card.is_pillar and _deck_name_count(str(card.display_name)) >= 3:
		_notify("A deck can contain at most three cards named %s." % card.display_name)
		return
	if deck_cards.count(id) >= _deck_copy_limit(card):
		_notify("Every owned copy is already in the deck.")
		return
	deck_cards.append(id)
	_refresh_deck_cards()

func _deck_copy_limit(card: Dictionary) -> int:
	return store.owned(card.id) if card.is_pillar else mini(3, store.owned(card.id))

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
		deck_collection_container.add_child(_deck_portrait_entry(card, store.owned(card.id), true))
	deck_count_label.text = "CURRENT DECK  %d  (30 minimum · 120 maximum)" % deck_cards.size()
	deck_count_label.add_theme_color_override("font_color", NATURE if deck_cards.size() >= 30 and deck_cards.size() <= 120 else GOLD)

func _card_counts(ids: Array[String]) -> Dictionary:
	var result := {}
	for id in ids: result[id] = int(result.get(id, 0)) + 1
	return result

func _deck_portrait_entry(card: Dictionary, copies: int, from_collection: bool) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var portrait := _portrait_button(card, {}, false, int(card.max_hp) > 0)
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
		if int(names[card_name]) > 3:
			_notify("A deck can contain at most three cards named %s." % card_name)
			return
	profile.decks.starter = {"id":"starter", "name":"First Fusion", "card_ids":deck_cards.duplicate(), "foundation_id":deck_foundation, "vanguard_id":deck_vanguard, "modified_at":Time.get_datetime_string_from_system()}
	store.save_profile()
	_notify("Deck saved.")

func _deck_special_picker(title: String, subtitle: String, foundation: bool) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_small_heading(title))
	var note := Label.new()
	note.text = subtitle
	note.add_theme_color_override("font_color", MUTED)
	box.add_child(note)
	var picker := OptionButton.new()
	var ids: Array[String] = []
	for card in database.all_cards(profile.merged_cards):
		if store.owned(card.id) <= 0: continue
		if foundation and (not card.is_pillar or not card.is_base): continue
		if not foundation and card.is_pillar: continue
		picker.add_item(str(card.display_name))
		ids.append(str(card.id))
	var selected_id := deck_foundation if foundation else deck_vanguard
	var selected_index := ids.find(selected_id)
	if selected_index >= 0: picker.select(selected_index)
	picker.item_selected.connect(func(index: int):
		if foundation: deck_foundation = ids[index]
		else: deck_vanguard = ids[index]
		_refresh_deck_special_preview(box, ids[index], foundation))
	box.add_child(picker)
	if not selected_id.is_empty():
		var preview := _portrait_button(database.get_card(selected_id, profile.merged_cards), {}, false, not foundation, 82)
		preview.name = "Preview"
		box.add_child(preview)
	return box

func _refresh_deck_special_preview(box: VBoxContainer, id: String, foundation: bool) -> void:
	var old := box.get_node_or_null("Preview")
	if old: old.queue_free()
	var preview := _portrait_button(database.get_card(id, profile.merged_cards), {}, false, not foundation, 82)
	preview.name = "Preview"
	box.add_child(preview)

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
	left_rail.add_child(player_hp_bar)
	var left_panel := _panel(left_rail)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	arena.add_child(left_panel)

	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_stats = Label.new()
	field.add_child(bot_stats)
	bot_pillars = HBoxContainer.new()
	bot_pillars.custom_minimum_size.y = 54
	field.add_child(bot_pillars)
	bot_board = _board_flow()
	bot_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_child(bot_board)
	match_status = Label.new()
	match_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_status.add_theme_color_override("font_color", GOLD)
	match_status.custom_minimum_size.y = 24
	field.add_child(match_status)
	player_board = _board_flow()
	player_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_child(player_board)
	player_pillars = HBoxContainer.new()
	player_pillars.custom_minimum_size.y = 54
	field.add_child(player_pillars)
	var player_footer := HBoxContainer.new()
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

func _new_match() -> void:
	var saved: Dictionary = profile.decks.get("starter", {})
	var source: Array = saved.get("card_ids", []).duplicate()
	var foundation_id := str(saved.get("foundation_id", "pillar_fire"))
	var vanguard_id := str(saved.get("vanguard_id", "ember_pup"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	_shuffle_with_rng(source, rng)
	var bot_deck := source.duplicate()
	_shuffle_with_rng(bot_deck, rng)
	match_state = {"turn":1, "finished":false, "busy":false, "message":"Play cards or activate abilities in any order.", "targeting":{}, "rng":rng, "player":_new_player(source, foundation_id, vanguard_id), "bot":_new_player(bot_deck, foundation_id, vanguard_id)}
	for i in 7:
		_draw_card(match_state.player)
		_draw_card(match_state.bot)

func _new_player(deck: Array, foundation_id := "pillar_fire", vanguard_id := "ember_pup") -> Dictionary:
	var board: Array = []
	board.resize(32)
	board.fill(null)
	return {"hp":100, "max_hp":100, "deck":deck, "hand":[], "board":board, "pillars":[], "mana":{}, "reserve":{}, "discard":[], "foundation":foundation_id, "vanguard":vanguard_id}

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and is_instance_valid(end_turn_button) and end_turn_button.visible:
		_end_turn()
		get_viewport().set_input_as_handled()

func _surrender_match() -> void:
	if match_state.is_empty() or bool(match_state.get("finished", false)): return
	match_state.clear()
	_show_screen("Home")
	_notify("You surrendered the match.")

func _draw_card(player: Dictionary) -> void:
	if not player.deck.is_empty(): player.hand.append(player.deck.pop_back())

func _play_hand_card(index: int) -> void:
	if bool(match_state.busy) or index < 0 or index >= match_state.player.hand.size(): return
	var id: String = match_state.player.hand[index]
	_play_player_card(id, "hand", index)

func _play_start_card(zone: String) -> void:
	if bool(match_state.busy) or bool(match_state.finished): return
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
			_resolve_spell(card, match_state.player, match_state.bot)
			match_state.player.discard.append(id)
		else:
			var slot := _random_empty_slot(match_state.player.board)
			if slot < 0:
				match_state.message = "The battlefield is full."
				_restore_available_card(id, source)
				_refund(match_state.player.mana, cost)
			else:
				match_state.player.board[slot] = _unit_record(card)
				_apply_on_play(card, match_state.bot)
				if match_state.bot.hp <= 0:
					match_state.finished = true
					match_state.message = "You win."
				else:
					match_state.message = "%s entered." % card.display_name
	_refresh_match()

func _pillar_record(card_id: String) -> Dictionary:
	var card := database.get_card(card_id, profile.merged_cards)
	return {"uid":str(Time.get_ticks_usec()) + str(randi_range(10, 99)), "card_id":card_id, "element":card.element_tags[0]}

func _unit_record(card: Dictionary) -> Dictionary:
	return {"id":card.id, "attack":int(card.attack), "hp":int(card.max_hp), "max_hp":int(card.max_hp), "frozen":false, "strike_ready":false}

func _apply_on_play(card: Dictionary, opponent: Dictionary) -> void:
	for reference in card.abilities:
		var ability := _ability_ref(reference)
		if ability.kind == "on_play" and ability.id == "Scorch":
			opponent.hp -= _ability_strength(ability)

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
	for remove_index in [maxi(source, index), mini(source, index)]: match_state.player.pillars.remove_at(remove_index)
	var hybrid_id := "pillar_" + hybrid.to_lower()
	match_state.player.pillars.append(_pillar_record(hybrid_id))
	match_state.targeting = {}
	match_state.message = "%s Pillar created. It will produce mana at end of turn." % hybrid
	_refresh_match()

func _activate_ability(slot: int, ability_index: int) -> void:
	if bool(match_state.busy) or slot < 0 or slot >= 32: return
	var unit: Variant = match_state.player.board[slot]
	if unit == null: return
	var card := database.get_card(unit.id, profile.merged_cards)
	if ability_index >= card.abilities.size(): return
	var ability := _ability_ref(card.abilities[ability_index])
	if ability.kind != "activated": return
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
	call_deferred("_flash_board_ability", source_slot, ability, true)
	match ability.id:
		"Freeze":
			match_state.bot.board[target_slot].frozen = true
			match_state.message = "The target is frozen for its next combat."
		"Strike":
			match_state.player.board[source_slot].strike_ready = true
			match_state.message = "Strike prepared: a random opposing creature will be attacked this combat."
		"Heal":
			var healing := _ability_strength(ability)
			match_state.player.hp = mini(100, int(match_state.player.hp) + healing)
			match_state.message = "Restored %d HP." % healing

func _end_turn() -> void:
	if bool(match_state.busy) or bool(match_state.finished): return
	match_state.busy = true
	match_state.targeting = {}
	_refresh_match()
	await _resolve_combat_animated(match_state.player, match_state.bot, true)
	if match_state.finished:
		match_state.busy = false
		_refresh_match()
		return
	await _produce_pillar_mana_animated(match_state.player, player_pillars)
	await _bot_turn()
	if match_state.finished:
		match_state.busy = false
		_refresh_match()
		return
	match_state.turn += 1
	match_state.player.mana = match_state.player.reserve.duplicate(true)
	match_state.player.reserve.clear()
	_apply_turn_start(match_state.player)
	_draw_card(match_state.player)
	match_state.busy = false
	match_state.message = "Turn %d. Play cards and abilities in any order." % match_state.turn
	_refresh_match()

func _bot_turn() -> void:
	var bot: Dictionary = match_state.bot
	var player: Dictionary = match_state.player
	bot.mana = bot.reserve.duplicate(true)
	bot.reserve.clear()
	_apply_turn_start(bot)
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
		if card.is_pillar:
			bot.hand.remove_at(i)
			bot.pillars.append(_pillar_record(card.id))
	_bot_merge_pillars(bot)
	for i in range(bot.hand.size() - 1, -1, -1):
		var card := database.get_card(bot.hand[i], profile.merged_cards)
		if not card.is_pillar and _can_pay(bot.mana, card.cost):
			var slot := _random_empty_slot(bot.board)
			if card.card_type != "Spell" and slot < 0: continue
			_pay(bot.mana, card.cost)
			bot.hand.remove_at(i)
			if card.card_type == "Spell":
				_resolve_spell(card, bot, player)
				bot.discard.append(card.id)
			else:
				bot.board[slot] = _unit_record(card)
				_apply_on_play(card, player)
				if player.hp <= 0:
					match_state.finished = true
					match_state.message = "The bot wins."
					return
	_refresh_match()
	for slot in 32:
		if bot.board[slot] != null:
			var card := database.get_card(bot.board[slot].id, profile.merged_cards)
			for reference in card.abilities:
				var ability := _ability_ref(reference)
				if ability.id == "Strike" and _can_pay(bot.mana, ability.cost):
					_pay(bot.mana, ability.cost)
					bot.board[slot].strike_ready = true
					var bot_portrait: Control = bot_slot_nodes.get(slot)
					if is_instance_valid(bot_portrait): _ability_flash(bot_portrait, ability)
	await _resolve_combat_animated(bot, player, false)
	await _produce_pillar_mana_animated(bot, bot_pillars)

func _flash_board_ability(slot: int, ability: Dictionary, player_owned: bool) -> void:
	var nodes := player_slot_nodes if player_owned else bot_slot_nodes
	var portrait: Control = nodes.get(slot)
	if is_instance_valid(portrait): _ability_flash(portrait, ability)

func _resolve_combat_animated(attacker: Dictionary, defender: Dictionary, player_attacking: bool) -> void:
	var slots: Array[int] = []
	for i in 32:
		if attacker.board[i] != null:
			var card := database.get_card(attacker.board[i].id, profile.merged_cards)
			if card.card_type != "Structure": slots.append(i)
	var delay := COMBAT_DURATION / maxf(1.0, float(slots.size()))
	for slot in slots:
		var unit: Dictionary = attacker.board[slot]
		if bool(unit.frozen):
			unit.frozen = false
			await get_tree().create_timer(delay).timeout
			continue
		var slot_nodes: Dictionary = player_slot_nodes if player_attacking else bot_slot_nodes
		var tile: Control = slot_nodes.get(slot)
		if tile: _attack_wave(tile)
		var card := database.get_card(unit.id, profile.merged_cards)
		var damage := int(unit.attack)
		var target_slot := _random_occupied_slot(defender.board) if bool(unit.get("strike_ready", false)) else -1
		if target_slot >= 0 and target_slot < 32 and defender.board[target_slot] != null:
			damage += _card_ability_strength(card, "Flame Strike")
			var target_unit: Dictionary = defender.board[target_slot]
			var target_card := database.get_card(target_unit.id, profile.merged_cards)
			var return_damage := int(target_unit.attack)
			target_unit.hp -= damage
			unit.hp -= return_damage
			unit.strike_ready = false
			var target_nodes: Dictionary = bot_slot_nodes if player_attacking else player_slot_nodes
			var target_tile: Control = target_nodes.get(target_slot)
			if target_tile: _floating_damage(target_tile, damage)
			if return_damage > 0 and tile: _floating_damage(tile, return_damage)
			var target_destroyed: bool = int(target_unit.hp) <= 0
			var attacker_destroyed: bool = int(unit.hp) <= 0
			if target_destroyed:
				attacker.hp -= _card_ability_strength(target_card, "Last Spark")
				defender.discard.append(target_unit.id)
				defender.board[target_slot] = null
			if attacker_destroyed:
				defender.hp -= _card_ability_strength(card, "Last Spark")
				attacker.discard.append(unit.id)
				attacker.board[slot] = null
			if attacker.hp <= 0 or defender.hp <= 0:
				match_state.finished = true
				if attacker.hp <= 0 and defender.hp <= 0:
					match_state.message = "The battle ends in a draw."
				elif defender.hp <= 0:
					match_state.message = "You win." if player_attacking else "The bot wins."
				else:
					match_state.message = "The bot wins." if player_attacking else "You win."
				return
		else:
			damage += _card_ability_strength(card, "Burn")
			damage += _card_ability_strength(card, "Scald")
			defender.hp -= damage
			unit.attack += _card_ability_strength(card, "Fury")
			unit.strike_ready = false
			_floating_damage(bot_stats if player_attacking else player_stats, damage)
		if defender.hp <= 0:
			match_state.finished = true
			match_state.message = "You win." if player_attacking else "The bot wins."
			return
		await get_tree().create_timer(delay).timeout
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

func _floating_damage(target: Control, amount: int) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target.add_child(overlay)
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", FIRE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(target.size.x * 0.5, 0)
	overlay.add_child(label)
	var tween := target.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -34.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(overlay.queue_free)

func _prepare_reserve(player: Dictionary) -> void:
	player.reserve.clear()
	for pillar in player.pillars: _gain_mana(player.reserve, pillar.element, 1)
	player.mana.clear()

func _produce_pillar_mana_animated(player: Dictionary, container: HBoxContainer) -> void:
	player.reserve.clear()
	player.mana.clear()
	match_state.message = "Pillars are producing mana."
	if is_instance_valid(match_status): match_status.text = match_state.message
	for pillar in player.pillars:
		_gain_mana(player.reserve, str(pillar.element), 1)
	for stack in container.get_children():
		if not stack.is_queued_for_deletion() and stack is VBoxContainer and bool(stack.get_meta("is_pillar", false)) and stack.get_child_count() > 0 and stack.get_child(0) is Control:
			_pillar_production_flash(stack.get_child(0))
	_rebuild_mana(player_mana if container == player_pillars else bot_mana, player.reserve)
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

func _apply_turn_start(player: Dictionary) -> void:
	for unit in player.board:
		if unit == null: continue
		var card := database.get_card(unit.id, profile.merged_cards)
		unit.attack += _card_ability_strength(card, "Growth")
		if _has_ability(card, "Regeneration"):
			player.hp = mini(100, int(player.hp) + 2)
			unit.hp = mini(int(unit.max_hp), int(unit.hp) + 1)

func _bot_merge_pillars(player: Dictionary) -> void:
	for i in player.pillars.size():
		for j in range(i + 1, player.pillars.size()):
			var hybrid := fusion_engine.fusion_element(player.pillars[i].element, player.pillars[j].element)
			if not hybrid.is_empty():
				player.pillars.remove_at(j)
				player.pillars.remove_at(i)
				player.pillars.append(_pillar_record("pillar_" + hybrid.to_lower()))
				return

func _resolve_spell(card: Dictionary, owner: Dictionary, opponent: Dictionary) -> void:
	var strength := _ability_strength(_ability_ref(card.abilities[0])) if not card.abilities.is_empty() else 0
	match card.id:
		"fireball": opponent.hp -= strength
		"healing_rain": owner.hp = mini(100, int(owner.hp) + strength)
		"regrowth":
			var target := _first_occupied_slot(owner.board)
			if target >= 0: owner.board[target].hp = mini(int(owner.board[target].max_hp), int(owner.board[target].hp) + strength)
	match_state.message = "%s resolved." % card.display_name

func _refresh_match() -> void:
	if match_header == null: return
	match_header.text = "TURN %d  |  YOUR ACTIONS" % match_state.turn
	end_turn_button.disabled = bool(match_state.busy)
	player_stats.text = "YOU  %d HP    Deck %d    Discard %d" % [match_state.player.hp, match_state.player.deck.size(), match_state.player.discard.size()]
	bot_stats.text = "BOT  %d HP    Hand %d    Deck %d" % [match_state.bot.hp, match_state.bot.hand.size(), match_state.bot.deck.size()]
	match_status.text = match_state.message
	_rebuild_mana(player_mana, match_state.player.mana)
	_rebuild_mana(bot_mana, match_state.bot.mana)
	_rebuild_hp_bar(player_hp_bar, match_state.player, _incoming_face_damage(match_state.bot, match_state.player))
	_rebuild_hp_bar(bot_hp_bar, match_state.bot, _incoming_face_damage(match_state.player, match_state.bot))
	for child in opponent_hand.get_children(): child.queue_free()
	for i in match_state.bot.hand.size():
		var opponent_card := database.get_card(match_state.bot.hand[i], profile.merged_cards)
		opponent_hand.add_child(_hand_card(opponent_card, i, false))
	_rebuild_start_zone(bot_start_zone, match_state.bot, false)
	_rebuild_pillars(bot_pillars, match_state.bot.pillars, false, match_state.bot.board)
	_rebuild_board(bot_board, match_state.bot.board, false)
	_rebuild_board(player_board, match_state.player.board, true)
	_rebuild_pillars(player_pillars, match_state.player.pillars, true, match_state.player.board)
	for child in match_hand.get_children(): child.queue_free()
	for i in match_state.player.hand.size():
		var card := database.get_card(match_state.player.hand[i], profile.merged_cards)
		match_hand.add_child(_hand_card(card, i, true))
	_rebuild_start_zone(player_start_zone, match_state.player, true)

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
		container.add_child(_battlefield_card(structure, board[slot], player_owned, slot))
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
	if not player_owned: portrait.pressed.connect(_enemy_slot_clicked.bind(slot))
	stack.add_child(portrait)
	for ability_index in card.abilities.size():
		var ability := _ability_ref(card.abilities[ability_index])
		if ability.kind == "activated":
			var ability_button := _ability_button(ability)
			ability_button.disabled = not player_owned
			ability_button.pressed.connect(_activate_ability.bind(slot, ability_index))
			stack.add_child(ability_button)
	return stack

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
	if bool(match_state.get("busy", false)) or bool(match_state.get("finished", false)): return false
	if bool(card.get("is_pillar", false)): return true
	if not _can_pay(match_state.player.mana, card.cost): return false
	return card.card_type == "Spell" or _first_empty_slot(match_state.player.board) >= 0

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
	art.texture = load(str(card.get("image", "res://assets/elemental_mark.svg")))
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var rounded_material := ShaderMaterial.new()
	rounded_material.shader = load("res://assets/ui/rounded_portrait.gdshader")
	art.material = rounded_material
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(art)
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
			ability_name.text = _ability_label(ability)
			ability_name.add_theme_color_override("font_color", GOLD)
			ability_row.add_child(ability_name)
			ability_list.add_child(ability_row)
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
	if is_instance_valid(hover_preview): hover_preview.queue_free()
	hover_preview = null

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
		var description: String = database.abilities.get(ability.id, {}).get("description", "")
		description = description.replace("{strength}", str(_ability_strength(ability)))
		descriptions.append("%s%s: %s" % [_symbol_cost(ability.cost, true) + " " if ability.kind == "activated" else "", _ability_label(ability), description])
	return "%s\n%s\n%s" % [card.display_name, _subtype_line(card), "\n".join(descriptions)]

func _ability_strength(ability: Dictionary) -> int:
	return int(ability.get("strength", 0))

func _card_ability_strength(card: Dictionary, id: String) -> int:
	for reference in card.abilities:
		var ability := _ability_ref(reference)
		if ability.id == id:
			return _ability_strength(ability)
	return 0

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
	label.text = "%d / %d%s" % [current, maximum, "  −%d" % incoming if incoming > 0 else ""]

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
		total += int(unit.attack) + _card_ability_strength(card, "Burn") + _card_ability_strength(card, "Scald")
	return total

func _first_occupied_slot(board: Array) -> int:
	for i in board.size():
		if board[i] != null: return i
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
		"Home": return GOLD
		"Deck": return NATURE
		"Match": return FIRE
	return MUTED

func _notify(message: String) -> void:
	toast.text = message
