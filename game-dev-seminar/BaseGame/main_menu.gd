extends Control
## Start menu: pick the number of rounds (3-7) and the bot style, then play.

const TABLE_SCENE := "res://BaseGame/game_table.tscn"

var _rounds_option: OptionButton
var _style_option: OptionButton
var _speed_option: OptionButton
var _schedule_label: Label
var _rules_panel: Control
var _specials_panel: Control
var _specials_summary: Label
var _special_rows: Dictionary = {}   # special -> {spin, rarity}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.22, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(460, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "BLANd"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Old Maid, with a twist"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(1, 1, 1, 0.75)
	box.add_child(sub)

	box.add_child(HSeparator.new())

	_rounds_option = OptionButton.new()
	for r in range(GameSettings.MIN_ROUNDS, GameSettings.MAX_ROUNDS + 1):
		_rounds_option.add_item("%d rounds" % r, r)
	_rounds_option.select(GameSettings.num_rounds - GameSettings.MIN_ROUNDS)
	_rounds_option.item_selected.connect(_on_rounds_changed)
	box.add_child(_labeled("Rounds", _rounds_option))

	_schedule_label = Label.new()
	_schedule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_schedule_label.modulate = Color(1, 0.9, 0.6)
	box.add_child(_schedule_label)

	_style_option = OptionButton.new()
	_style_option.add_item("Random (coin-flip decisions)", GameSettings.BotStyle.RANDOM)
	_style_option.add_item("Basic strategy", GameSettings.BotStyle.BASIC)
	_style_option.select(GameSettings.bot_style)
	box.add_child(_labeled("Bots", _style_option))

	_speed_option = OptionButton.new()
	var names := GameSettings.BOT_SPEEDS.keys()
	for i in names.size():
		_speed_option.add_item(names[i], i)
		if is_equal_approx(GameSettings.BOT_SPEEDS[names[i]], GameSettings.bot_delay):
			_speed_option.select(i)
	box.add_child(_labeled("Bot speed", _speed_option))

	var specials_row := HBoxContainer.new()
	var sl := Label.new()
	sl.text = "Specials"
	sl.custom_minimum_size = Vector2(90, 0)
	specials_row.add_child(sl)
	var specials_btn := Button.new()
	specials_btn.text = "Special Cards Setup..."
	specials_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	specials_btn.pressed.connect(func() -> void: _specials_panel.visible = true)
	specials_row.add_child(specials_btn)
	box.add_child(specials_row)
	_specials_summary = Label.new()
	_specials_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_specials_summary.modulate = Color(1, 1, 1, 0.7)
	_specials_summary.add_theme_font_size_override("font_size", 13)
	box.add_child(_specials_summary)

	box.add_child(HSeparator.new())

	var start := Button.new()
	start.text = "Start Game"
	start.custom_minimum_size = Vector2(0, 48)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_on_start)
	box.add_child(start)

	var rules := Button.new()
	rules.text = "How to Play"
	rules.pressed.connect(func() -> void: _rules_panel.visible = true)
	box.add_child(rules)

	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	_rules_panel = _build_rules_panel()
	add_child(_rules_panel)
	_rules_panel.visible = false

	_specials_panel = _build_specials_panel()
	add_child(_specials_panel)
	_specials_panel.visible = false
	_update_specials_ui()

	_on_rounds_changed(_rounds_option.selected)
	start.grab_focus()


func _labeled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _on_rounds_changed(i: int) -> void:
	var rounds := _rounds_option.get_item_id(i)
	_schedule_label.text = GameSettings.schedule_text(rounds)


func _on_start() -> void:
	GameSettings.num_rounds = _rounds_option.get_item_id(_rounds_option.selected)
	GameSettings.bot_style = _style_option.get_item_id(_style_option.selected)
	GameSettings.bot_delay = GameSettings.BOT_SPEEDS[_speed_option.get_item_text(_speed_option.selected)]
	get_tree().change_scene_to_file(TABLE_SCENE)


# ---------------------------------------------------------------- special cards setup

func _build_specials_panel() -> Control:
	var layer := ColorRect.new()
	layer.color = Color(0, 0, 0, 0.75)
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_box())
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Special Cards Setup"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	v.add_child(title)
	var hint := Label.new()
	hint.text = "How many copies of each special card go in the deck (Jokers are separate).\nRarity follows the count: 1 = Rare (purple), 2 = Uncommon (green), 3+ = Common (light blue)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.75)
	v.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for h in ["Card", "What it does", "Copies", "Rarity"]:
		var hl := Label.new()
		hl.text = h
		hl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		grid.add_child(hl)
	for sp in GameSettings.DEFAULT_SPECIAL_COUNTS:
		var name_l := Label.new()
		name_l.text = BlandCard.SPECIAL_NAMES[sp]
		grid.add_child(name_l)
		var help := Label.new()
		help.text = BlandCard.SPECIAL_HELP[sp]
		help.modulate = Color(1, 1, 1, 0.8)
		grid.add_child(help)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = GameSettings.MAX_COPIES_PER_SPECIAL
		spin.step = 1
		spin.value = GameSettings.count_of(sp)
		spin.value_changed.connect(func(val: float) -> void:
			GameSettings.special_counts[sp] = int(val)
			_update_specials_ui())
		grid.add_child(spin)
		var rarity := Label.new()
		rarity.custom_minimum_size = Vector2(110, 0)
		grid.add_child(rarity)
		_special_rows[sp] = {"spin": spin, "rarity": rarity}

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(func() -> void:
		GameSettings.special_counts = GameSettings.DEFAULT_SPECIAL_COUNTS.duplicate()
		for sp in _special_rows:
			_special_rows[sp]["spin"].set_value_no_signal(GameSettings.count_of(sp))
		_update_specials_ui())
	buttons.add_child(reset)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(120, 0)
	done.pressed.connect(func() -> void: layer.visible = false)
	buttons.add_child(done)
	return layer


func _panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.14)
	sb.border_color = Color(1, 0.85, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	return sb


func _update_specials_ui() -> void:
	for sp in _special_rows:
		var r: Label = _special_rows[sp]["rarity"]
		r.text = GameSettings.rarity_name(sp)
		r.add_theme_color_override("font_color", GameSettings.rarity_color(sp))
	var total := GameSettings.total_specials()
	var deck_min := 40 + total + 1
	_specials_summary.text = "%d special cards in the deck (%d–%d cards total with Jokers)" % [total, deck_min, deck_min + 2]


func _build_rules_panel() -> Control:
	var layer := ColorRect.new()
	layer.color = Color(0, 0, 0, 0.7)
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_box())
	panel.custom_minimum_size = Vector2(760, 520)
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = GameSettings.RULES_TEXT
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(text)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: layer.visible = false)
	v.add_child(close)
	return layer
