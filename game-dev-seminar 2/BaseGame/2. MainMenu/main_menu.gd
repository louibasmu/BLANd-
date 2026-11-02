extends Control
## Death's Doorstep main menu.
##
## Layout: title + four buttons (Play, How to Play, Sound, Quit) and a disclaimer at the bottom.
## "Play" opens a Game Setup pop-up (rounds, bots, bot speed, special cards) with a Begin button.
## All choices are saved into the static variables on GameSettings, same as before.
## Everything is built in code, so main_menu.tscn only needs this script on a Control root.

const TABLE_SCENE := "res://BaseGame/5. CardTable/game_table.tscn"

# Palette: dark, desaturated, with a muted gold for accents.
const COL_PANEL := Color(0.09, 0.08, 0.09)
const COL_GOLD := Color(0.78, 0.65, 0.32)
const COL_BONE := Color(0.88, 0.82, 0.68)
const COL_BLOOD := Color(0.45, 0.1, 0.1)

# ---- Background settings: select the menu's root node and edit these in the Inspector ----
@export_group("Background")
## Solid colour behind everything. Also shows through if no picture is set.
@export var background_color: Color = Color(0.05, 0.04, 0.05)
## Optional picture. Drag any image (png/jpg) here. It is scaled to cover the whole window.
@export var background_texture: Texture2D
## How much to darken the picture so the menu text stays readable (0 = none, 1 = black).
@export_range(0.0, 1.0, 0.05) var background_dim: float = 0.35
@export var show_embers: bool = false
@export var embers_color: Color = Color(0.9, 0.65, 0.25, 0.45)

var _bg_color_rect: ColorRect
var _bg_texture_rect: TextureRect
var _bg_dim_rect: ColorRect

var _rounds_option: OptionButton
var _style_option: OptionButton
var _speed_option: OptionButton
var _schedule_label: Label
var _rules_panel: Control
var _specials_panel: Control
var _setup_panel: Control
var _specials_summary: Label
var _sound_btn: Button
var _special_rows: Dictionary = {}   # special -> {spin, rarity}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()

	_build_background()
	if show_embers:
		add_child(_make_embers())
	_build_main_column()
	_build_corner_widgets()

	# Pop-ups are built now and hidden until a button shows them.
	_setup_panel = _build_setup_panel()
	_rules_panel = _build_rules_panel()
	_specials_panel = _build_specials_panel()
	for p in [_setup_panel, _rules_panel, _specials_panel]:
		p.visible = false
		add_child(p)
	_update_specials_ui()
	_on_rounds_changed(_rounds_option.selected)

	# Fade the menu in.
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)


# ---------------------------------------------------------------- look & feel

# One Theme for the whole menu so every Button / OptionButton / Label shares the same style.
func _make_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", COL_BONE)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, _btn_box(Color(0.1, 0.09, 0.1), Color(0.35, 0.3, 0.2)))
		t.set_stylebox("hover", cls, _btn_box(Color(0.16, 0.12, 0.1), COL_GOLD))
		t.set_stylebox("pressed", cls, _btn_box(COL_BLOOD, COL_GOLD))
		t.set_stylebox("focus", cls, _btn_box(Color(0.16, 0.12, 0.1), COL_GOLD))
		t.set_color("font_color", cls, COL_BONE)
		t.set_color("font_hover_color", cls, Color(1, 0.95, 0.8))
	return t


func _btn_box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# Three stacked layers: solid colour, optional picture, optional dark overlay on top of the picture.
func _build_background() -> void:
	_bg_color_rect = ColorRect.new()
	_bg_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_color_rect)

	_bg_texture_rect = TextureRect.new()
	_bg_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_bg_texture_rect)

	_bg_dim_rect = ColorRect.new()
	_bg_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_dim_rect)

	set_background(background_texture, background_color)


# Change the background at any time (from code, a button, a settings menu, etc.).
# Example: set_background(load("res://art/temple.png"), Color.BLACK)
# Pass null as the texture to go back to a plain colour.
func set_background(texture: Texture2D, color: Color = background_color) -> void:
	background_texture = texture
	background_color = color
	_bg_color_rect.color = color
	_bg_texture_rect.texture = texture
	_bg_texture_rect.visible = texture != null
	_bg_dim_rect.color = Color(0, 0, 0, background_dim)
	_bg_dim_rect.visible = texture != null


# Slow gold embers rising from the bottom of the screen for atmosphere.
func _make_embers() -> CPUParticles2D:
	var size := get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x / 2.0, size.y + 10)
	p.amount = 45
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x / 2.0, 4)
	p.direction = Vector2(0, -1)
	p.spread = 20.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = embers_color
	return p


# ---------------------------------------------------------------- main screen

func _build_main_column() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(380, 0)
	center.add_child(box)

	var studio := Label.new()
	studio.text = "BLANd's"
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio.add_theme_font_size_override("font_size", 18)
	studio.modulate = Color(1, 1, 1, 0.5)
	box.add_child(studio)

	var title := Label.new()
	title.text = "DEATH'S\nDOORSTEP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", COL_GOLD)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Seven sins. One survivor."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(1, 1, 1, 0.65)
	box.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	box.add_child(gap)

	var play := _menu_button("Play", 24)
	play.pressed.connect(func() -> void: _setup_panel.visible = true)
	box.add_child(play)

	var rules := _menu_button("How to Play", 18)
	rules.pressed.connect(func() -> void: _rules_panel.visible = true)
	box.add_child(rules)

	var quit := _menu_button("Quit", 18)
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	play.grab_focus()


func _menu_button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", font_size)
	return b


# Sound toggle (top right) and the content disclaimer (bottom).
func _build_corner_widgets() -> void:
	_sound_btn = Button.new()
	_sound_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_sound_btn.offset_left = -150
	_sound_btn.offset_top = 16
	_sound_btn.offset_right = -16
	_sound_btn.offset_bottom = 52
	_sound_btn.pressed.connect(_on_sound_toggled)
	add_child(_sound_btn)
	_refresh_sound_text()

	var disc := Label.new()
	disc.text = "If you dislike the idea of the Devil, Hades, or death, we recommend you not play this game."
	disc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disc.add_theme_font_size_override("font_size", 13)
	disc.modulate = Color(1, 1, 1, 0.4)
	disc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	disc.offset_top = -48
	disc.offset_bottom = -12
	disc.offset_left = 40
	disc.offset_right = -40
	add_child(disc)


func _on_sound_toggled() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_refresh_sound_text()


func _refresh_sound_text() -> void:
	var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	_sound_btn.text = "Sound: Off" if muted else "Sound: On"


# ---------------------------------------------------------------- game setup pop-up

# Rounds, bot style, bot speed, special cards. "Begin" saves everything and loads the table.
func _build_setup_panel() -> Control:
	var layer := _overlay(0.8)
	var v := _overlay_panel(layer, Vector2(520, 0))

	v.add_child(_heading("Game Setup"))

	_rounds_option = OptionButton.new()
	for r in range(GameSettings.MIN_ROUNDS, GameSettings.MAX_ROUNDS + 1):
		_rounds_option.add_item("%d rounds" % r, r)
	_rounds_option.select(GameSettings.num_rounds - GameSettings.MIN_ROUNDS)
	_rounds_option.item_selected.connect(_on_rounds_changed)
	v.add_child(_labeled("Rounds", _rounds_option))

	_schedule_label = Label.new()
	_schedule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_schedule_label.modulate = Color(1, 0.85, 0.5)
	v.add_child(_schedule_label)

	_style_option = OptionButton.new()
	_style_option.add_item("Random (coin-flip decisions)", GameSettings.BotStyle.RANDOM)
	_style_option.add_item("Basic strategy", GameSettings.BotStyle.BASIC)
	_style_option.select(GameSettings.bot_style)
	v.add_child(_labeled("Bots", _style_option))

	_speed_option = OptionButton.new()
	var names := GameSettings.BOT_SPEEDS.keys()
	for i in names.size():
		_speed_option.add_item(names[i], i)
		if is_equal_approx(GameSettings.BOT_SPEEDS[names[i]], GameSettings.bot_delay):
			_speed_option.select(i)
	v.add_child(_labeled("Bot speed", _speed_option))

	var specials_btn := Button.new()
	specials_btn.text = "Special Cards Setup..."
	specials_btn.pressed.connect(func() -> void: _specials_panel.visible = true)
	v.add_child(_labeled("Specials", specials_btn))

	_specials_summary = Label.new()
	_specials_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_specials_summary.modulate = Color(1, 1, 1, 0.6)
	_specials_summary.add_theme_font_size_override("font_size", 13)
	v.add_child(_specials_summary)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 44)
	back.pressed.connect(func() -> void: layer.visible = false)
	row.add_child(back)
	var begin := Button.new()
	begin.text = "Begin"
	begin.custom_minimum_size = Vector2(180, 44)
	begin.add_theme_font_size_override("font_size", 20)
	begin.pressed.connect(_on_start)
	row.add_child(begin)
	return layer


func _on_rounds_changed(i: int) -> void:
	_schedule_label.text = GameSettings.schedule_text(_rounds_option.get_item_id(i))


# Saves every choice into GameSettings (static, so it survives the scene change), then starts the game.
func _on_start() -> void:
	GameSettings.num_rounds = _rounds_option.get_item_id(_rounds_option.selected)
	GameSettings.bot_style = _style_option.get_item_id(_style_option.selected)
	GameSettings.bot_delay = GameSettings.BOT_SPEEDS[_speed_option.get_item_text(_speed_option.selected)]
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(TABLE_SCENE))


# ---------------------------------------------------------------- special cards setup

func _build_specials_panel() -> Control:
	var layer := _overlay(0.85)
	var v := _overlay_panel(layer, Vector2.ZERO)

	v.add_child(_heading("Special Cards Setup"))
	var hint := Label.new()
	hint.text = "How many copies of each special card go in the deck (Jokers are separate).\nRarity follows the count: 1 = Rare (purple), 2 = Uncommon (green), 3+ = Common (light blue)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	v.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for h in ["Card", "What it does", "Copies", "Rarity"]:
		var hl := Label.new()
		hl.text = h
		hl.add_theme_color_override("font_color", COL_GOLD)
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


func _update_specials_ui() -> void:
	for sp in _special_rows:
		var r: Label = _special_rows[sp]["rarity"]
		r.text = GameSettings.rarity_name(sp)
		r.add_theme_color_override("font_color", GameSettings.rarity_color(sp))
	var total := GameSettings.total_specials()
	var deck_min := 40 + total + 1
	_specials_summary.text = "%d special cards in the deck (%d–%d cards total with Jokers)" % [total, deck_min, deck_min + 2]


# ---------------------------------------------------------------- how to play

func _build_rules_panel() -> Control:
	var layer := _overlay(0.8)
	var v := _overlay_panel(layer, Vector2(760, 520))
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


# ---------------------------------------------------------------- shared helpers

# Full-screen dark layer that sits behind a pop-up panel.
func _overlay(alpha: float) -> ColorRect:
	var layer := ColorRect.new()
	layer.color = Color(0, 0, 0, alpha)
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	return layer


# Adds a centred bordered panel to the overlay and returns the VBoxContainer inside it.
func _overlay_panel(layer: Control, min_size: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_box())
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	return v


func _panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(22)
	return sb


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", COL_GOLD)
	return l


func _labeled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row
