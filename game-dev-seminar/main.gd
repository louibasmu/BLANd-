extends Control

const SUITS := ["Clubs", "Diamonds", "Hearts", "Spades"]
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const PLAYER_COUNT := 3

var players: Array[Dictionary] = []
var current_player := 0
var round_over := false
var status_label: Label
var turn_label: Label
var opponents_row: HBoxContainer
var draw_cards: HFlowContainer
var draw_title: Label
var hand_cards: HFlowContainer
var hand_title: Label
var new_round_button: Button
var player_anchors: Array[Control] = []


func _ready() -> void:
	_build_ui()
	_start_round()


func _build_ui() -> void:
	var table_scene := load("res://Sprites/table_sprite.tscn") as PackedScene
	var table := table_scene.instantiate() as Node2D
	table.position = get_viewport_rect().size / 2.0
	table.scale = Vector2.ONE * 0.22
	add_child(table)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.04, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)

	var heading := Label.new()
	heading.text = "JOKER"
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color(1.0, 0.87, 0.58))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)

	new_round_button = Button.new()
	new_round_button.text = "New Round"
	new_round_button.custom_minimum_size = Vector2(130, 42)
	new_round_button.pressed.connect(_start_round)
	header.add_child(new_round_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	layout.add_child(status_label)

	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.86))
	layout.add_child(turn_label)

	opponents_row = HBoxContainer.new()
	opponents_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opponents_row.add_theme_constant_override("separation", 40)
	layout.add_child(opponents_row)

	var draw_panel := _make_panel()
	draw_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(draw_panel)

	var draw_layout := VBoxContainer.new()
	draw_layout.add_theme_constant_override("separation", 8)
	draw_panel.add_child(draw_layout)

	draw_title = Label.new()
	draw_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_title.add_theme_font_size_override("font_size", 17)
	draw_layout.add_child(draw_title)

	var draw_scroll := ScrollContainer.new()
	draw_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draw_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	draw_layout.add_child(draw_scroll)

	draw_cards = HFlowContainer.new()
	draw_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_cards.alignment = FlowContainer.ALIGNMENT_CENTER
	draw_cards.add_theme_constant_override("h_separation", 7)
	draw_cards.add_theme_constant_override("v_separation", 7)
	draw_scroll.add_child(draw_cards)

	var hand_panel := _make_panel()
	hand_panel.custom_minimum_size = Vector2(0, 190)
	layout.add_child(hand_panel)

	var hand_layout := VBoxContainer.new()
	hand_layout.add_theme_constant_override("separation", 8)
	hand_panel.add_child(hand_layout)

	hand_title = Label.new()
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_title.add_theme_font_size_override("font_size", 17)
	hand_layout.add_child(hand_title)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_layout.add_child(hand_scroll)

	hand_cards = HFlowContainer.new()
	hand_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_cards.alignment = FlowContainer.ALIGNMENT_CENTER
	hand_cards.add_theme_constant_override("h_separation", 7)
	hand_cards.add_theme_constant_override("v_separation", 7)
	hand_scroll.add_child(hand_cards)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.08, 0.05, 0.74)
	style.border_color = Color(0.72, 0.52, 0.25, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _start_round() -> void:
	var deck: Array[Dictionary] = []
	for suit in SUITS:
		for rank in RANKS:
			if rank == "2" and (suit == "Clubs" or suit == "Spades"):
				continue
			deck.append({"rank": rank, "suit": suit})
	deck.append({"rank": "JOKER", "suit": ""})
	deck.shuffle()

	players = [
		{"name": "You", "hand": [], "human": true},
		{"name": "Computer 1", "hand": [], "human": false},
		{"name": "Computer 2", "hand": [], "human": false},
	]
	for card_index in range(deck.size()):
		players[card_index % PLAYER_COUNT]["hand"].append(deck[card_index])
	for player_index in range(PLAYER_COUNT):
		_discard_pairs(player_index)

	current_player = 0
	round_over = false
	new_round_button.disabled = false
	status_label.text = "CARDS DEALT  •  PAIRS OUT"
	_play_computer_turns()
	_refresh_ui()


func _discard_pairs(player_index: int) -> Array[String]:
	var hand: Array = players[player_index]["hand"]
	var counts: Dictionary = {}
	for card in hand:
		if card["rank"] != "JOKER":
			counts[card["rank"]] = int(counts.get(card["rank"], 0)) + 1

	var discard_counts: Dictionary = {}
	var pair_names: Array[String] = []
	for rank in counts:
		var pair_count: int = int(counts[rank]) - int(counts[rank]) % 2
		if pair_count > 0:
			discard_counts[rank] = pair_count
			pair_names.append(str(rank))

	var remaining: Array[Dictionary] = []
	for card in hand:
		var rank: String = card["rank"]
		if rank != "JOKER" and int(discard_counts.get(rank, 0)) > 0:
			discard_counts[rank] = int(discard_counts[rank]) - 1
		else:
			remaining.append(card)
	players[player_index]["hand"] = remaining
	return pair_names


func _on_human_picked(card_index: int) -> void:
	if round_over or current_player != 0:
		return
	var target_index := _next_player_with_cards(current_player)
	if target_index == -1:
		_finish_round()
		return

	var source_button := draw_cards.get_child(card_index) as Button
	source_button.disabled = true
	current_player = -1
	var card: Dictionary = players[target_index]["hand"].pop_at(card_index)
	players[0]["hand"].append(card)
	new_round_button.disabled = true
	await _animate_draw_card(card, target_index, 0, source_button)
	var pairs := _discard_pairs(0)
	if pairs.is_empty():
		status_label.text = "JOKER!" if card["rank"] == "JOKER" else "NO PAIR"
		await get_tree().create_timer(0.35).timeout
	else:
		status_label.text = "PAIR!"
		await _animate_pair_discard(pairs, 0)
	current_player = 0
	await _finish_turn()


func _play_computer_turns() -> void:
	while not round_over and current_player != 0:
		var target_index := _next_player_with_cards(current_player)
		if target_index == -1:
			_finish_round()
			return
		var target_hand: Array = players[target_index]["hand"]
		var picked_index := randi_range(0, target_hand.size() - 1)
		var card: Dictionary = target_hand.pop_at(picked_index)
		players[current_player]["hand"].append(card)
		status_label.text = "%s draws…" % players[current_player]["name"]
		turn_label.text = "%s is drawing" % players[current_player]["name"]
		_refresh_ui()
		await get_tree().process_frame
		await _animate_draw_card(card, target_index, current_player)
		var pairs := _discard_pairs(current_player)
		if not pairs.is_empty():
			status_label.text = "PAIR!"
			await _animate_pair_discard(pairs, current_player)
		else:
			status_label.text = "NO PAIR"
			await get_tree().create_timer(0.3).timeout
		if _is_round_over():
			_finish_round()
			return
		current_player = _next_player_with_cards(current_player)
		if current_player == -1:
			_finish_round()
			return


func _finish_turn() -> void:
	if _is_round_over():
		_finish_round()
		_refresh_ui()
		new_round_button.disabled = false
		return
	current_player = _next_player_with_cards(0)
	if current_player == -1:
		_finish_round()
	elif current_player != 0:
		await _play_computer_turns()
	_refresh_ui()
	new_round_button.disabled = false


func _animate_draw_card(card: Dictionary, from_player: int, to_player: int, source_button: Button = null) -> void:
	var viewport_size := get_viewport_rect().size
	var origin := viewport_size * 0.5
	if source_button != null:
		origin = source_button.global_position + source_button.size * 0.5
		source_button.hide()
	elif from_player < player_anchors.size() and is_instance_valid(player_anchors[from_player]):
		var source := player_anchors[from_player]
		origin = source.global_position + source.size * 0.5

	var destination := viewport_size * 0.5
	if to_player < player_anchors.size() and is_instance_valid(player_anchors[to_player]):
		var target := player_anchors[to_player]
		destination = target.global_position + target.size * 0.5

	var animation_layer := Control.new()
	animation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_layer.z_index = 20
	add_child(animation_layer)

	var flying_card := _make_card_button("◆", false)
	flying_card.custom_minimum_size = Vector2(100, 136)
	flying_card.size = Vector2(100, 136)
	flying_card.position = origin - flying_card.size * 0.5
	flying_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_layer.add_child(flying_card)

	var action := Label.new()
	action.text = "DRAW"
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", 28)
	action.add_theme_color_override("font_color", Color(1.0, 0.87, 0.58))
	action.position = Vector2(0, viewport_size.y * 0.3)
	action.size = Vector2(viewport_size.x, 48)
	animation_layer.add_child(action)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		flying_card,
		"position",
		viewport_size * 0.5 - flying_card.size * 0.5,
		0.38
	)
	tween.tween_property(flying_card, "scale:x", 0.04, 0.12)
	tween.tween_callback(func() -> void:
		flying_card.text = _card_text(card)
		flying_card.add_theme_color_override(
			"font_color",
			Color(0.72, 0.12, 0.16) if card["suit"] == "Hearts" or card["suit"] == "Diamonds" else Color(0.08, 0.12, 0.16)
		)
		flying_card.add_theme_stylebox_override("normal", _card_face_style())
		action.text = _card_text(card)
	)
	tween.tween_property(flying_card, "scale:x", 1.0, 0.12)
	tween.tween_interval(0.3)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(flying_card, "position", destination - flying_card.size * 0.5, 0.38)
	tween.tween_property(flying_card, "scale", Vector2(0.55, 0.55), 0.2)
	tween.parallel().tween_property(action, "modulate:a", 0.0, 0.2)
	await tween.finished
	animation_layer.queue_free()


func _animate_pair_discard(pair_names: Array[String], player_index: int) -> void:
	var viewport_size := get_viewport_rect().size
	var animation_layer := Control.new()
	animation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_layer.z_index = 21
	add_child(animation_layer)

	var title := Label.new()
	title.text = "PAIR!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.87, 0.58))
	title.position = Vector2(0, viewport_size.y * 0.3)
	title.size = Vector2(viewport_size.x, 48)
	animation_layer.add_child(title)

	var actor_label := Label.new()
	actor_label.text = str(players[player_index]["name"]).to_upper() + " DISCARD"
	actor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actor_label.add_theme_font_size_override("font_size", 18)
	actor_label.add_theme_color_override("font_color", Color.WHITE)
	actor_label.position = Vector2(0, viewport_size.y * 0.3 + 48)
	actor_label.size = Vector2(viewport_size.x, 34)
	animation_layer.add_child(actor_label)

	var cards_to_show := mini(pair_names.size() * 2, 8)
	var cards: Array[Button] = []
	var start_x := viewport_size.x * 0.5 - cards_to_show * 42.0
	for card_index in range(cards_to_show):
		var rank: String = pair_names[int(card_index / 2)]
		var button := _make_card_button(rank + "\nPAIR", false)
		button.custom_minimum_size = Vector2(78, 104)
		button.position = Vector2(start_x + card_index * 84, viewport_size.y * 0.42)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.scale = Vector2(0.2, 0.2)
		animation_layer.add_child(button)
		cards.append(button)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.01)
	for button in cards:
		tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.22)
	tween.tween_interval(0.35)
	for button in cards:
		tween.parallel().tween_property(button, "position:y", button.position.y + 100, 0.35)
		tween.parallel().tween_property(button, "modulate:a", 0.0, 0.35)
	await tween.finished
	animation_layer.queue_free()


func _card_face_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.94, 0.86)
	style.border_color = Color(0.75, 0.62, 0.39)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style


func _next_player_with_cards(from_index: int) -> int:
	for step in range(1, PLAYER_COUNT + 1):
		var candidate := (from_index + step) % PLAYER_COUNT
		if not players[candidate]["hand"].is_empty():
			return candidate
	return -1


func _is_round_over() -> bool:
	var players_with_cards := 0
	for player in players:
		if not player["hand"].is_empty():
			players_with_cards += 1
	return players_with_cards <= 1


func _finish_round() -> void:
	round_over = true
	for player in players:
		if not player["hand"].is_empty():
			status_label.text = "%s is left holding the Joker. %s" % [
				player["name"],
				"You lose!" if player["human"] else "You win!",
			]
			return
	status_label.text = "The round ended without a Joker. Start a new round to play again."


func _refresh_ui() -> void:
	if round_over:
		turn_label.text = "Round over"
		draw_title.text = "Start a new round when you're ready."
	else:
		turn_label.text = "Your turn" if current_player == 0 else "%s is playing…" % players[current_player]["name"]
		var target_index := _next_player_with_cards(0)
		if current_player == 0 and target_index != -1:
			draw_title.text = "Choose one face-down card from %s" % players[target_index]["name"]
		else:
			draw_title.text = "The computers are taking their turns."

	player_anchors.clear()
	player_anchors.append(hand_cards)
	player_anchors.append(null)
	player_anchors.append(null)
	_clear_children(opponents_row)
	for player_index in range(1, PLAYER_COUNT):
		var opponent := VBoxContainer.new()
		opponent.alignment = BoxContainer.ALIGNMENT_CENTER
		opponent.add_theme_constant_override("separation", 4)
		opponents_row.add_child(opponent)

		var name_label := Label.new()
		name_label.text = "%s  •  %d cards" % [
			players[player_index]["name"],
			players[player_index]["hand"].size(),
		]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color.WHITE)
		opponent.add_child(name_label)

		var backs := HBoxContainer.new()
		backs.alignment = BoxContainer.ALIGNMENT_CENTER
		backs.add_theme_constant_override("separation", -22)
		opponent.add_child(backs)
		for card_index in range(mini(5, players[player_index]["hand"].size())):
			var back := _make_card_button("◆", false)
			back.custom_minimum_size = Vector2(48, 64)
			back.disabled = true
			backs.add_child(back)
		player_anchors[player_index] = backs

	_clear_children(draw_cards)
	if not round_over and current_player == 0:
		var target_index := _next_player_with_cards(0)
		if target_index != -1:
			for card_index in range(players[target_index]["hand"].size()):
				var button := _make_card_button("?", false)
				button.custom_minimum_size = Vector2(56, 76)
				button.tooltip_text = "Pick this face-down card"
				button.pressed.connect(_on_human_picked.bind(card_index))
				draw_cards.add_child(button)

	_clear_children(hand_cards)
	var human_hand: Array = players[0]["hand"]
	hand_title.text = "Your hand  •  %d cards" % human_hand.size()
	for card in human_hand:
		var button := _make_card_button(_card_text(card), card["suit"] == "Hearts" or card["suit"] == "Diamonds")
		button.custom_minimum_size = Vector2(70, 92)
		button.disabled = true
		hand_cards.add_child(button)


func _make_card_button(card_text: String, is_red: bool) -> Button:
	var button := Button.new()
	button.text = card_text
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override(
		"font_color",
		Color(0.72, 0.12, 0.16) if is_red else Color(0.08, 0.12, 0.16)
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.94, 0.86) if card_text != "?" and card_text != "◆" else Color(0.12, 0.23, 0.47)
	style.border_color = Color(0.75, 0.62, 0.39)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(1.0, 0.88, 0.59) if card_text == "?" else style.bg_color
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	return button


func _card_text(card: Dictionary) -> String:
	if card["rank"] == "JOKER":
		return "JOKER\n★"
	var suit_symbols := {
		"Clubs": "♣",
		"Diamonds": "♦",
		"Hearts": "♥",
		"Spades": "♠",
	}
	return "%s\n%s" % [card["rank"], suit_symbols[card["suit"]]]


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
