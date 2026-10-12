extends Control
## The table: draws the game state and turns clicks into BlandGame calls.
## The whole UI is built in code so it's easy to restyle later (Ash's art can
## replace the placeholder colours / card_empty specials without touching rules).
##
## Division of labour: BlandGame decides what is legal and what happens; this script only
##   (1) draws the current state (_refresh), (2) turns the human's clicks into BlandGame calls,
##   (3) paces the bots with a timer so the human can follow, and (4) shows pop-ups.
## It reacts to the signals BlandGame emits (connected in _ready) rather than being told directly.

# Scene to load when the player quits to the main menu.
const MENU_SCENE := "res://BaseGame/main_menu.tscn"
# Folder holding the card pictures; _tex() loads them from here by file name.
const CARD_DIR := "res://Sprites/Card Assets/"
# Card sizes in pixels: big for the human's own hand, small for the opponents' face-down cards.
const BIG_CARD := Vector2(78, 111)
const SMALL_CARD := Vector2(40, 57)
# Seat number of the human player (always 0).
const HUMAN := 0

# What the human is in the middle of choosing. Many actions need several clicks, and this
# remembers which step we are on:
#   NONE                - nothing selected
#   CHOOSE_TARGET       - picked a special, now pick which opponent it affects
#   CHOOSE_GIVE_CARD    - playing Give, now pick which card from your hand to give away
#   CHOOSE_VISION_INDEX - playing Vision, now pick which card of the target to peek at
#   CHOOSE_DRAW_INDEX   - chose a player to draw from, now pick the card
enum UiMode { NONE, CHOOSE_TARGET, CHOOSE_GIVE_CARD, CHOOSE_VISION_INDEX, CHOOSE_DRAW_INDEX }

# The rules object. All game state lives in here; this script only displays it.
var game: BlandGame
var ui_mode: UiMode = UiMode.NONE
# Half-finished choices while ui_mode != NONE: the special being played, the card to give,
# and the player being aimed at. _clear_selection() resets them.
var pending_special: BlandCard = null
var pending_gift: BlandCard = null
var pending_target: int = -1
# Cache of loaded card pictures so each file is only loaded once.
var _tex_cache: Dictionary = {}

# Bots act on a timer. _bot_player is the bot we are waiting on, and _bot_pick is the card it has
# highlighted and will take on the next tick.
var _bot_timer: Timer
var _bot_player: int = -1
var _bot_pick: Dictionary = {}     # {src, index} the bot is about to take (highlighted)
# True while the pause menu is open; the bot timer ignores ticks during a pause.
var _paused: bool = false

# UI nodes that are updated later; they are created in _build_ui() and kept in variables.
# UI nodes
var _status_label: Label
var _compass: TurnCompass
# Last direction shown, so the compass only "pulses" when the direction actually flips.
var _last_direction: int = 1
var _log: RichTextLabel
var _prompt: Label
var _cancel_btn: Button
var _shuffle_btn: Button
var _start_btn: Button
var _keep_btn: Button
# Index of the card the player has picked up while arranging their hand (-1 = none).
var _arrange_sel: int = -1        # card picked up while arranging (click-to-move)
# Per-seat UI parts, filled in by _make_seat(): the panel, labels, card row and buttons.
var _seats: Dictionary = {}      # player index -> {panel, name, info, cards, target}
# The pop-up dialog currently open (null = none). Only one is shown at a time.
var _modal: Control = null
var _toast_box: VBoxContainer      # pop-up alerts when a bot's move hits you
var _pause_modal: Control = null


# Godot calls this when the scene loads: build the interface, create the bot timer, create the game,
# connect the game's signals to the handlers below, and deal the first round.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	_bot_timer = Timer.new()
	_bot_timer.one_shot = true
	_bot_timer.timeout.connect(_on_bot_timer)
	add_child(_bot_timer)

	game = BlandGame.new(GameSettings.num_rounds)
	# `changed` can fire several times for one action, so it goes through _queue_refresh to redraw only once.
	game.changed.connect(_queue_refresh)   # many changes in one action -> one redraw
	game.log_message.connect(_add_log)
	game.private_info.connect(func(t: String) -> void: _add_log("[color=#ffe27a]" + t + "[/color]"))
	game.turn_started.connect(_on_turn_started)
	game.turn_continued.connect(_on_turn_continued)
	game.special_drawn.connect(_on_special_drawn)
	game.affected.connect(_on_affected)
	game.player_finished.connect(_on_player_finished)
	game.round_over.connect(_on_round_over)
	game.game_over.connect(_on_game_over)
	game.start_round()


# Keyboard shortcuts: T opens the card tracker. Esc (ui_cancel) cancels a half-finished selection if there
# is one, and otherwise opens / closes the pause menu.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		if _modal == null:
			_show_tracker()
		return
	if event.is_action_pressed("ui_cancel"):
		if ui_mode != UiMode.NONE:
			_cancel_selection()
		else:
			_toggle_pause()


# ================================================================ layout
# The screen is made of Godot container nodes created in code, laid out as:
#   top bar (status + buttons) / top bot / [left bot | turn compass + log | right bot] /
#   prompt row (instructions + buttons) / the human's seat at the bottom.

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.3, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# --- top bar
	var bar := HBoxContainer.new()
	root.add_child(bar)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_status_label)
	var tracker_btn := Button.new()
	tracker_btn.text = "Card Tracker (T)"
	tracker_btn.pressed.connect(_show_tracker)
	bar.add_child(tracker_btn)
	var rules_btn := Button.new()
	rules_btn.text = "Rules"
	rules_btn.pressed.connect(_show_rules)
	bar.add_child(rules_btn)
	var pause_btn := Button.new()
	pause_btn.text = "Pause (Esc)"
	pause_btn.pressed.connect(_toggle_pause)
	bar.add_child(pause_btn)

	# --- top bot (seat 2)
	var top_row := CenterContainer.new()
	root.add_child(top_row)
	top_row.add_child(_make_seat(2, 620))

	# --- middle: left bot, log, right bot
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	root.add_child(mid)
	mid.add_child(_make_seat(1, 300))
	var log_panel := PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0)))
	mid.add_child(log_panel)
	var log_row := HBoxContainer.new()
	log_row.add_theme_constant_override("separation", 6)
	log_panel.add_child(log_row)
	_compass = TurnCompass.new()   # which way play is going + who's up next
	log_row.add_child(_compass)
	_log = RichTextLabel.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_font_size_override("bold_font_size", 13)
	log_row.add_child(_log)
	mid.add_child(_make_seat(3, 300))

	# --- prompt
	var prompt_row := HBoxContainer.new()
	root.add_child(prompt_row)
	_prompt = Label.new()
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	# Wraps long prompts so they never push the buttons off-screen.
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # long prompts wrap instead of pushing buttons off-screen
	_prompt.custom_minimum_size = Vector2(200, 0)
	prompt_row.add_child(_prompt)
	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.pressed.connect(_cancel_selection)
	prompt_row.add_child(_cancel_btn)
	_shuffle_btn = Button.new()
	_shuffle_btn.text = "Shuffle my hand"
	# The "Shuffle my hand" and "Lock hand & start round" buttons only appear in the ARRANGE phase,
	# "Keep it & end turn" only right after drawing a special; _refresh() decides which are visible.
	_shuffle_btn.pressed.connect(func() -> void:
		_arrange_sel = -1
		game.shuffle_hand(HUMAN))
	prompt_row.add_child(_shuffle_btn)
	_start_btn = Button.new()
	_start_btn.text = "Lock hand & start round"
	_start_btn.pressed.connect(func() -> void:
		_arrange_sel = -1
		game.finish_arranging())
	prompt_row.add_child(_start_btn)
	_keep_btn = Button.new()
	_keep_btn.text = "Keep it & end turn"
	_keep_btn.pressed.connect(func() -> void:
		_clear_selection()
		game.pass_turn(HUMAN))
	prompt_row.add_child(_keep_btn)

	# --- you (seat 0)
	root.add_child(_make_seat(0, 0))

	# --- alert pop-ups (own layer so they show above everything)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.grow_vertical = Control.GROW_DIRECTION_BOTH
	top.add_theme_constant_override("margin_bottom", 60)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	_toast_box = VBoxContainer.new()
	_toast_box.add_theme_constant_override("separation", 6)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_toast_box)


# Builds the panel for one seat: name, "PLAYING"/"NEXT" badge, score line, the pairs they have made,
# a "Choose" button for targeting them, and a container for their cards (a row for the
# human's big overlapping cards, a wrapping flow for opponents' small ones).
# `i` is the seat number; `min_width` stops the opponents' panels from collapsing.
# Everything needed to update the seat later is stored in _seats[i].
func _make_seat(i: int, min_width: float) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var name_l := Label.new()
	name_l.add_theme_font_size_override("font_size", 16)
	head.add_child(name_l)
	var badge := Label.new()   # "PLAYING" / "NEXT"
	badge.add_theme_font_size_override("font_size", 12)
	head.add_child(badge)
	var info_l := Label.new()
	info_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_l.clip_text = true
	info_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_l.modulate = Color(1, 1, 1, 0.8)
	head.add_child(info_l)

	# Second row: the pairs this player has made + the action button.
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	var pairs_l := Label.new()
	pairs_l.text = "Pairs made:"
	pairs_l.add_theme_font_size_override("font_size", 12)
	pairs_l.modulate = Color(1, 1, 1, 0.7)
	row2.add_child(pairs_l)
	var pairs_box := HFlowContainer.new()
	pairs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pairs_box.add_theme_constant_override("h_separation", 3)
	pairs_box.add_theme_constant_override("v_separation", 3)
	row2.add_child(pairs_box)
	var target_btn := Button.new()
	target_btn.text = "Choose"
	target_btn.visible = false
	# `.bind(i)` makes the button call _on_target_chosen(i) so it knows which seat was clicked.
	target_btn.pressed.connect(_on_target_chosen.bind(i))
	row2.add_child(target_btn)

	var cards: Container
	if i == HUMAN:
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(0, BIG_CARD.y + 4)
		v.add_child(c)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", -14)   # overlap a little
		c.add_child(row)
		cards = row
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 2)
		flow.add_theme_constant_override("v_separation", 2)
		v.add_child(flow)
		cards = flow

	_seats[i] = {"panel": panel, "name": name_l, "badge": badge, "info": info_l, "cards": cards, "target": target_btn,
		"pairs": pairs_box}
	return panel


# Helper that makes a rounded coloured panel style (used for seats, the log and pop-ups).
func _box(fill: Color, border: Color, width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


# ================================================================ cards

# Loads a card picture the first time it is asked for and remembers it. Returns null if the file
# doesn't exist yet (e.g. art that hasn't been added), instead of crashing.
func _tex(file: String) -> Texture2D:
	if not _tex_cache.has(file):
		var path := CARD_DIR + file
		_tex_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[file]


## One card. `card == null` or face_down draws the back.
## Builds the little widget for one card: the picture (face up or the card back), the "special" overlay if needed,
## the number underneath (the position opponents pick from), and highlight / hover effects.
## `on_click` is a Callable to run when it is clicked; an invalid (empty) Callable means the card is not clickable.
## `highlight` raises and tints the card (used when a bot is about to take it, or for a card you just drew).
func _card_view(card: BlandCard, face_up: bool, size: Vector2, index: int, on_click: Callable, highlight: bool = false) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 0)

	var btn := TextureButton.new()
	btn.texture_normal = _tex(card.texture_file() if face_up else "card_back.png")
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = size
	holder.add_child(btn)

	# Specials have no finished art yet, so a coloured band with the card's name is drawn on top of a blank card.
	if face_up and card.is_special():
		_add_special_overlay(btn, card, size)

	# Clickable cards get a pointer cursor and light up / lift when the mouse is over them.
	if on_click.is_valid():
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(on_click)
		btn.self_modulate = Color(1, 1, 0.8)
		btn.mouse_entered.connect(func() -> void:
			btn.self_modulate = Color(1.35, 1.35, 0.6)
			btn.position.y = -6)
		btn.mouse_exited.connect(func() -> void:
			btn.self_modulate = Color(1, 1, 0.8)
			btn.position.y = 0)
		btn.tooltip_text = _card_tooltip(card) if face_up else "Card #%d" % (index + 1)
	# Not clickable: ignore the mouse entirely for face-down cards, but let face-up ones show their tooltip.
	else:
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if not face_up else Control.MOUSE_FILTER_PASS
		if face_up:
			btn.tooltip_text = _card_tooltip(card)

	if highlight:
		# A bot is about to take / is looking at this card.
		btn.self_modulate = Color(1.5, 1.25, 0.35)
		btn.position.y = -8

	if index >= 0:
		# Index numbers under opponents' cards (needed for Vision and drawing).
		var l := Label.new()
		l.text = ("> %d <" % (index + 1)) if highlight else str(index + 1)
		if highlight:
			l.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 10)
		l.modulate = Color(1, 1, 1, 0.7)
		holder.add_child(l)
	return holder


# Draws the placeholder look of a special card: a coloured band, the name in capitals, and a border whose colour shows its rarity.
# Font and border sizes scale with the card size so it looks right on both big and small cards.
func _add_special_overlay(btn: Control, card: BlandCard, size: Vector2) -> void:
	var col: Color = BlandCard.SPECIAL_COLORS[card.special]
	var band := ColorRect.new()
	band.color = col
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = Vector2(size.x * 0.1, size.y * 0.32)
	band.size = Vector2(size.x * 0.8, size.y * 0.36)
	btn.add_child(band)
	var l := Label.new()
	l.text = card.special_name().to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(8, int(size.x / 6.5)))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = band.position
	l.size = band.size
	btn.add_child(l)
	# Rarity border: light blue = common, green = uncommon, purple = rare
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = GameSettings.rarity_color(card.special)
	sb.set_border_width_all(maxi(2, int(size.x / 22.0)))
	sb.set_corner_radius_all(maxi(3, int(size.x / 14.0)))
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2.ZERO
	frame.size = size
	btn.add_child(frame)


# Text shown when hovering a card: name, rarity and description for specials, plain name otherwise.
func _card_tooltip(card: BlandCard) -> String:
	if card.is_special():
		return "%s  (%s)\n%s" % [card.special_name(), GameSettings.rarity_name(card.special),
			BlandCard.SPECIAL_HELP[card.special]]
	return card.display_name()


## A tiny "7 7" chip showing one discarded pair.
## Each half of the chip is coloured like its card: red for hearts/diamonds, black for clubs/spades.
func _pair_chip(a: BlandCard, b: BlandCard) -> Control:
	var chip := PanelContainer.new()
	var sb := _box(Color(0.95, 0.93, 0.85), Color(0.3, 0.3, 0.3), 1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	chip.add_child(row)
	for c in [a, b]:
		var l := Label.new()
		l.text = c.rank_name()
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.8, 0.05, 0.05) if c.is_red() else Color(0.08, 0.08, 0.08))
		row.add_child(l)
	chip.tooltip_text = "%s + %s" % [a.display_name(), b.display_name()]
	return chip


# A small faint label (used for "none yet").
func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.5)
	return l


# ================================================================ refresh
# The table never edits the display piece by piece. Whenever anything changes it simply
# redraws everything from the BlandGame state in _refresh().

var _refresh_queued: bool = false


## The game emits `changed` several times during one action; redraw once per frame instead.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_flush_refresh.call_deferred()


func _flush_refresh() -> void:
	_refresh_queued = false
	_refresh()


# Redraws the whole screen from the current game state: the status line, the turn compass, every seat,
# which buttons are visible, and the instruction text.
func _refresh() -> void:
	if game == null:
		return
	var dir := "clockwise" if game.direction == 1 else "counter-clockwise"
	var upcoming := game.upcoming_player()
	var playing := game.phase in [BlandGame.Phase.PLAY_OR_DRAW, BlandGame.Phase.SPECIAL_DRAWN, BlandGame.Phase.VISION_DECIDE]
	var next_text := ""
	if playing and upcoming >= 0:
		next_text = "   •   Next up: %s" % game.players[upcoming].display_name
	_status_label.text = "Round %d / %d   •   Jokers: %d   •   Pairs left: %d   •   Play: %s%s" % [
		game.round_number, game.total_rounds, game.jokers_this_round, game.pairs_left(), dir, next_text]

	# Flags for the compass: who is safe (out of cards) and who is frozen.
	var safe_flags := []
	var frozen_flags := []
	for pl in game.players:
		safe_flags.append(pl.finished)
		frozen_flags.append(pl.frozen_turns > 0)
	_compass.set_state(game.direction, game.current if playing else -1,
		upcoming if playing else -1, safe_flags, frozen_flags)
	if game.direction != _last_direction:
		_last_direction = game.direction
		_compass.pulse()

	# True when it is the human's turn and they are free to act.
	var human_turn := game.current == HUMAN and game.is_turn_of(HUMAN)

	for i in game.players.size():
		_refresh_seat(i, human_turn)

	_cancel_btn.visible = ui_mode != UiMode.NONE
	var arranging := game.phase == BlandGame.Phase.ARRANGE
	_shuffle_btn.visible = arranging
	_start_btn.visible = arranging
	_keep_btn.visible = game.current == HUMAN and game.phase == BlandGame.Phase.SPECIAL_DRAWN
	_prompt.text = _prompt_text(human_turn)


# Redraws one seat panel: name, PLAYING / NEXT badge, score and cards-left text, the border colour
# (gold = their turn, blue = frozen, orange = someone is drawing from them), the pairs they have made,
# the "Choose" button when they can be targeted, and finally their cards.
func _refresh_seat(i: int, human_turn: bool) -> void:
	var p := game.players[i]
	var seat: Dictionary = _seats[i]
	seat["name"].text = p.display_name
	var badge: Label = seat["badge"]
	var in_play := game.phase in [BlandGame.Phase.PLAY_OR_DRAW, BlandGame.Phase.SPECIAL_DRAWN, BlandGame.Phase.VISION_DECIDE]
	badge.text = ""
	if in_play and game.current == i:
		badge.text = "  PLAYING"
		badge.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	elif in_play and game.upcoming_player() == i:
		badge.text = "  NEXT"
		badge.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	var info := "   Score %d  •  %d card%s" % [p.total_score, p.hand.size(), "" if p.hand.size() == 1 else "s"]
	if p.frozen_turns > 0:
		info += "   •   FROZEN (%d)" % p.frozen_turns
	if p.finished:
		info += "   •   SAFE (out of cards)"
	seat["info"].text = info

	# Border colour priority: current player, then frozen, then "being drawn from".
	var is_current := game.current == i and game.phase != BlandGame.Phase.ROUND_OVER \
		and game.phase != BlandGame.Phase.GAME_OVER
	var border := Color(1, 0.85, 0.2) if is_current else Color(0, 0, 0, 0)
	if p.frozen_turns > 0 and not is_current:
		border = Color(0.4, 0.8, 1)
	var being_drawn_from: bool = (not _bot_pick.is_empty() and _bot_pick["src"] == i) \
		or (ui_mode == UiMode.CHOOSE_DRAW_INDEX and pending_target == i)
	if being_drawn_from and not is_current:
		border = Color(1, 0.55, 0.15)
	seat["panel"].add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.3), border, 3))

	# Target button (Freeze / Angel / Give / Vision)
	# Shown on an opponent's panel in two cases: (a) a special is waiting for a target, or (b) it is
	# the human's turn to draw and this opponent can be drawn from.
	var tb: Button = seat["target"]
	tb.visible = false
	if ui_mode == UiMode.CHOOSE_TARGET and pending_special != null and i != HUMAN:
		tb.visible = game.valid_targets(HUMAN, pending_special).has(i)
		tb.text = "%s this player" % pending_special.special_name()
	elif game.can_draw(HUMAN) and i != HUMAN and game.can_draw_from(HUMAN, i) \
			and (ui_mode == UiMode.NONE or ui_mode == UiMode.CHOOSE_DRAW_INDEX):
		# Step 1 of drawing: pick who to take from.
		tb.visible = not (ui_mode == UiMode.CHOOSE_DRAW_INDEX and pending_target == i)
		tb.text = "Draw from %s" % p.display_name

	# Pairs are rebuilt from scratch each refresh (old chips are freed), sorted by rank so they read in order.
	var pbox: Container = seat["pairs"]
	for c in pbox.get_children():
		c.queue_free()
	var pairs := p.paired_cards.duplicate()
	pairs.sort_custom(func(x: Array, y: Array) -> bool: return x[0].rank < y[0].rank)
	for pr in pairs:
		pbox.add_child(_pair_chip(pr[0], pr[1]))
	if pairs.is_empty():
		pbox.add_child(_small_label("none yet"))

	# Likewise the cards in the hand are rebuilt each time.
	var box: Container = seat["cards"]
	for c in box.get_children():
		c.queue_free()

	# The human's own cards are face up. What clicking a card does depends on the situation:
	#   arranging -> pick up / drop it; your turn -> play it if it is a special you can play;
	#   choosing a card for Give -> give it away.
	if i == HUMAN:
		var arranging := game.phase == BlandGame.Phase.ARRANGE
		for idx in p.hand.size():
			var card := p.hand[idx]
			var cb := Callable()
			if arranging:
				cb = _on_arrange_click.bind(idx)
			elif human_turn and ui_mode == UiMode.NONE and game.can_play(HUMAN, card):
				cb = _on_my_special.bind(card)
			elif ui_mode == UiMode.CHOOSE_GIVE_CARD and card != pending_special:
				cb = _on_gift_chosen.bind(card)
			# Your own cards show their position too: that's what opponents pick from.
			var just_drawn := game.phase == BlandGame.Phase.SPECIAL_DRAWN and card == game.drawn_special
			var view := _card_view(card, true, BIG_CARD, idx, cb, (arranging and idx == _arrange_sel) or just_drawn)
			if arranging:
				_enable_drag(view.get_child(0), idx)
			box.add_child(view)
	# Opponents' cards are face down, and only clickable when we are choosing a card to draw or to peek at.
	# The card a bot is about to take is highlighted (hl), as is the one a bot peeked at with Vision.
	else:
		for idx in p.hand.size():
			var cb := Callable()
			if game.can_draw(HUMAN) and ui_mode == UiMode.CHOOSE_DRAW_INDEX and i == pending_target:
				cb = _on_draw.bind(idx)          # step 2 of drawing: pick the card
			elif ui_mode == UiMode.CHOOSE_VISION_INDEX and i == pending_target:
				cb = _on_vision_index.bind(idx)
			var hl: bool = not _bot_pick.is_empty() and _bot_pick["src"] == i and _bot_pick["index"] == idx
			if game.phase == BlandGame.Phase.VISION_DECIDE and game.current != HUMAN \
					and not game.last_peek.is_empty() and game.last_peek["target"] == i \
					and game.last_peek["index"] == idx:
				hl = true
			box.add_child(_card_view(p.hand[idx], false, SMALL_CARD, idx, cb, hl))


# Works out the instruction line shown above the buttons, based on the phase, what the human is
# choosing, and what the bots are doing. It is plain text only; it never changes game state.
func _prompt_text(human_turn: bool) -> String:
	match game.phase:
		BlandGame.Phase.ARRANGE:
			if _arrange_sel >= 0:
				return "Now click the spot where card #%d should go." % (_arrange_sel + 1)
			return "Arrange your hand: drag cards, or click a card then click where it goes. Order locks when the round starts."
		BlandGame.Phase.ROUND_OVER:
			return "Round over."
		BlandGame.Phase.GAME_OVER:
			return "Game over."
	match ui_mode:
		UiMode.CHOOSE_TARGET:
			return "%s: click \"%s this player\" on an opponent." % [pending_special.special_name(), pending_special.special_name()]
		UiMode.CHOOSE_GIVE_CARD:
			return "Give: click the card from your hand you want to give away."
		UiMode.CHOOSE_VISION_INDEX:
			return "Vision: click the card in %s's hand you want to peek at." % game.players[pending_target].display_name
		UiMode.CHOOSE_DRAW_INDEX:
			return "Click the card you want from %s's hand (or pick a different player)." % game.players[pending_target].display_name
	if not human_turn:
		var who := game.players[game.current].display_name
		if game.phase == BlandGame.Phase.VISION_DECIDE and game.current != HUMAN:
			return "%s peeked at card #%d in %s's hand and is deciding whether to take it..." % [
				who, game.last_peek["index"] + 1, game.players[game.last_peek["target"]].display_name]
		if not _bot_pick.is_empty():
			var from := "your" if _bot_pick["src"] == HUMAN else game.players[_bot_pick["src"]].display_name + "'s"
			return "%s is taking card #%d from %s hand..." % [who, _bot_pick["index"] + 1, from]
		if game.players[HUMAN].finished:
			return "You're safe! Fast-forwarding: %s's turn..." % who
		return "%s's turn..." % who
	if game.phase == BlandGame.Phase.SPECIAL_DRAWN and game.drawn_special != null:
		return "You drew %s: click it to play it now, or press \"Keep it & end turn\"." % game.drawn_special.special_name()
	if game.draw_only:
		return "Now take a card: choose a player to draw from."
	var lead := "Pair! Go again" if game.actions_this_turn > 0 else "Your turn"
	if game.can_play_specials(HUMAN) and not game.players[HUMAN].specials().is_empty():
		return "%s: choose a player to draw from, or play a special card (ends your turn unless it makes a pair)." % lead
	return "%s: choose a player to draw from." % lead


# Adds a line to the on-screen game log (RichTextLabel understands [b], [color] etc. BBCode tags).
func _add_log(text: String) -> void:
	_log.append_text(text + "\n")


# ================================================================ human input
# Everything below runs when the human clicks something and then calls the matching BlandGame function.

## Arranging, click version: first click picks a card up, second click puts it there.
## Clicking the same card again cancels the pick-up.
func _on_arrange_click(idx: int) -> void:
	if game.phase != BlandGame.Phase.ARRANGE:
		return
	if _arrange_sel == -1:
		_arrange_sel = idx
		_refresh()
	elif _arrange_sel == idx:
		_arrange_sel = -1
		_refresh()
	else:
		var from := _arrange_sel
		_arrange_sel = -1
		game.move_card(HUMAN, from, idx)


## Arranging, drag version: drop a card onto another card to move it to that spot.
## set_drag_forwarding lets us attach drag-and-drop behaviour to the button using three small functions:
## one that starts a drag (and makes the floating preview image), one that says whether a drop is
## allowed, and one that does the move when the card is dropped.
func _enable_drag(btn: Control, idx: int) -> void:
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			var preview := TextureRect.new()
			preview.texture = (btn as TextureButton).texture_normal
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.size = BIG_CARD
			preview.modulate = Color(1, 1, 1, 0.8)
			btn.set_drag_preview(preview)
			return {"arrange_from": idx},
		func(_pos: Vector2, data: Variant) -> bool:
			return data is Dictionary and data.has("arrange_from") and game.phase == BlandGame.Phase.ARRANGE,
		func(_pos: Vector2, data: Variant) -> void:
			_arrange_sel = -1
			game.move_card(HUMAN, data["arrange_from"], idx))


# The human clicked one of their special cards. Skip and Reverse need no target, so they play
# immediately. Give first needs a card to give away, and everything else needs a target player.
func _on_my_special(card: BlandCard) -> void:
	match card.special:
		BlandCard.Special.SKIP:
			game.play_skip(HUMAN, card)
		BlandCard.Special.REVERSE:
			game.play_reverse(HUMAN, card)
		BlandCard.Special.GIVE:
			pending_special = card
			ui_mode = UiMode.CHOOSE_GIVE_CARD
			_refresh()
		_:
			pending_special = card
			ui_mode = UiMode.CHOOSE_TARGET
			_refresh()


# The human picked which card to give; next they must pick who gets it.
func _on_gift_chosen(card: BlandCard) -> void:
	pending_gift = card
	ui_mode = UiMode.CHOOSE_TARGET
	_refresh()


# Called when the human clicks a "Choose" button on an opponent. With nothing selected (or while
# choosing a card) this is step 1 of an ordinary draw: remember the player and ask for a card.
# Otherwise it finishes the special that is waiting for a target.
func _on_target_chosen(target: int) -> void:
	if ui_mode == UiMode.NONE or ui_mode == UiMode.CHOOSE_DRAW_INDEX:
		pending_target = target           # step 1 of drawing done
		ui_mode = UiMode.CHOOSE_DRAW_INDEX
		_refresh()
		return
	var special := pending_special
	var gift := pending_gift
	if special == null:
		return
	# What happens depends on which special is pending. Vision still needs a card position, so it moves
	# on to that step; the other three can now be played. Angel's answer is shown in a pop-up.
	match special.special:
		BlandCard.Special.VISION:
			pending_target = target
			ui_mode = UiMode.CHOOSE_VISION_INDEX
			_refresh()
		BlandCard.Special.FREEZE:
			_clear_selection()
			game.play_freeze(HUMAN, special, target)
		BlandCard.Special.ANGEL:
			_clear_selection()
			var has := game.play_angel(HUMAN, special, target)
			var who := game.players[target].display_name
			_show_modal("Angel", "%s %s a Joker." % [who, "HAS" if has else "does NOT have"], null,
				[["OK", Callable()]])
		BlandCard.Special.GIVE:
			_clear_selection()
			game.play_give(HUMAN, special, gift, target)


# The human chose which card to peek at. The card is revealed in a pop-up with Take / Leave buttons.
func _on_vision_index(index: int) -> void:
	var special := pending_special
	var target := pending_target
	_clear_selection()
	var seen := game.play_vision(HUMAN, special, target, index)
	if seen == null:
		_refresh()
		return
	var who := game.players[target].display_name
	var note := "\nTake it: if it makes a pair you go again, otherwise your turn ends.\nLeave it: your turn ends."
	_show_modal("Vision", "Card #%d in %s's hand is the %s.%s" % [index + 1, who, seen.display_name(), note], seen, [
		["Take it", func() -> void: game.resolve_vision(true)],
		["Leave it", func() -> void: game.resolve_vision(false)],
	])


# Step 2 of an ordinary draw: take the chosen card from the chosen player.
func _on_draw(index: int) -> void:
	var src := pending_target
	_clear_selection()
	game.draw_card(HUMAN, src, index)


# Abandons whatever the human was in the middle of choosing (Cancel button or Esc).
func _cancel_selection() -> void:
	_clear_selection()
	_refresh()


# Forgets any half-finished choice and returns to the normal state.
func _clear_selection() -> void:
	ui_mode = UiMode.NONE
	pending_special = null
	pending_gift = null
	pending_target = -1


# ================================================================ bots
# Bots are not instant. A one-shot Timer fires _on_bot_timer after a delay, the bot does ONE step,
# and the timer is restarted while that bot is still acting. This gives the human time to read the log.

# A new turn began. For a human, just redraw. For a bot, remember who it is and start the timer.
func _on_turn_started(p: int) -> void:
	_clear_selection()
	_bot_pick = {}
	if game.players[p].is_human:
		_refresh()
		return
	_bot_player = p
	_bot_timer.start(_bot_delay())


## A bot made a pair and goes again: keep its timer running.
func _on_turn_continued(p: int) -> void:
	if game.players[p].is_human:
		_clear_selection()
		_refresh()
		return
	_bot_player = p


## You drew a special card: offer to play it right away.
func _on_special_drawn(p: int, card: BlandCard) -> void:
	if not game.players[p].is_human:
		return
	_show_modal("You drew %s! (%s)" % [card.special_name(), GameSettings.rarity_name(card.special)],
		"%s\n\nPlay it now, or keep it for later (keeping it ends your turn).\nIf you play it and don't make a pair, your turn ends."
			% BlandCard.SPECIAL_HELP[card.special], card, [
		["Play it now", func() -> void: _on_my_special(card)],
		["Keep it (end turn)", func() -> void: game.pass_turn(HUMAN)],
	])


# One bot step per timer tick. Ignored if paused or if it's no longer that bot's turn.
# If the bot already highlighted a card on the previous tick, take it now. Otherwise decide what to
# do for the current phase (see BotBrain.step): decide on a Vision peek, play or keep a drawn special,
# or play a special / aim at a card to draw.
func _on_bot_timer() -> void:
	if _paused or _bot_player < 0 or _bot_player != game.current or game.players[_bot_player].is_human:
		return
	var p := _bot_player
	var style := GameSettings.bot_style
	if not _bot_pick.is_empty():
		# Take the card that was highlighted on the previous tick.
		var pick := _bot_pick
		_bot_pick = {}
		if game.can_draw(p):
			if game.can_draw_from(p, pick["src"]) and pick["index"] < game.players[pick["src"]].hand.size():
				game.draw_card(p, pick["src"], pick["index"])
			else:
				BotBrain.draw(game, p, style)
	else:
		match game.phase:
			BlandGame.Phase.VISION_DECIDE:
				BotBrain.decide_vision(game, p, style)
			BlandGame.Phase.SPECIAL_DRAWN:
				if BotBrain.try_play_special(game, p, style) == "none":
					game.pass_turn(p)
			BlandGame.Phase.PLAY_OR_DRAW:
				if BotBrain.try_play_special(game, p, style) == "none":
					_bot_aim(p, style)
					return
			_:
				return
	# Same bot still acting (made a pair, drew a special, or is deciding on Vision)? Pause, then continue.
	if _bot_player == p and BotBrain.is_acting(game, p):
		_refresh()
		_bot_timer.start(_bot_delay())


## Highlight the card the bot is about to take, then take it after a pause.
## Showing the target first (next tick takes it) lets the human see which of their cards is about to be taken.
func _bot_aim(p: int, style: int) -> void:
	var pick := BotBrain.choose_draw(game, p, style)
	if pick.is_empty():
		game.draw_card(p, -1, -1)
		return
	_bot_pick = pick
	_refresh()
	_bot_timer.start(_bot_delay())


# ================================================================ alerts

## Once you're out of cards the rest of the round plays out quickly.
## Returns the pause between bot actions: the speed chosen on the menu, or the fast-forward delay.
func _bot_delay() -> float:
	if game != null and game.players[HUMAN].finished:
		return GameSettings.FAST_FORWARD_DELAY
	return GameSettings.bot_delay


# Shows a banner when someone finishes. The human sees their own news always, and others' news
# only while they are still in the round.
func _on_player_finished(p: int) -> void:
	if p == HUMAN and game.phase != BlandGame.Phase.ROUND_OVER:
		_toast("You're out of cards: safe from the Joker! Fast-forwarding the rest of the round.")
	elif p != HUMAN and game.phase != BlandGame.Phase.ROUND_OVER and not game.players[HUMAN].finished:
		_toast("%s is out of cards and safe." % game.players[p].display_name)


# Only show an alert when another player's move hit the human.
func _on_affected(target: int, actor: int, text: String) -> void:
	if target == HUMAN and actor != HUMAN and actor >= 0:
		_toast(text)


## A pop-up banner at the top of the screen that fades out after a few seconds.
## At most 4 are shown at once (the oldest is removed). Each stays for a time based on the bot speed, then
## fades out via a Tween (an animation helper) and deletes itself.
func _toast(text: String) -> void:
	while _toast_box.get_child_count() >= 4:
		var oldest := _toast_box.get_child(0)
		_toast_box.remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _box(Color(0.35, 0.08, 0.05, 0.95), Color(1, 0.6, 0.2), 2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = "!  " + text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	panel.add_child(l)
	_toast_box.add_child(panel)
	var hold: float = clampf(GameSettings.bot_delay * 2.5, 3.0, 6.0)
	var tw := panel.create_tween()
	tw.tween_interval(hold)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


# ================================================================ rounds / game over

# The round ended: stop the bots, clear alerts and selections, then show a results table in a pop-up.
# Its button starts the next round (or shows the final results after the last one).
func _on_round_over(summary: Array) -> void:
	_bot_timer.stop()
	_bot_pick = {}
	for t in _toast_box.get_children():
		t.queue_free()
	_clear_selection()
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 24)
	for h in ["Player", "Pairs", "Jokers held", "Round points", "Total"]:
		grid.add_child(_cell(h, true))
	for row in summary:
		grid.add_child(_cell(row["name"]))
		grid.add_child(_cell(str(row["pairs"])))
		grid.add_child(_cell("%d  (-%d)" % [row["jokers"], row["penalty"]] if row["jokers"] > 0 else "0"))
		grid.add_child(_cell("%+d" % row["round_points"]))
		grid.add_child(_cell(str(row["total"]), true))
	var last := game.round_number >= game.total_rounds
	_show_modal("Round %d complete" % game.round_number, grid, null,
		[["See final results" if last else "Next round", func() -> void: game.next_round()]])


# The whole game ended: show the final standings (sorted by BlandGame) and offer Play again / Main menu.
func _on_game_over(standings: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	var place := 1
	for p in standings:
		grid.add_child(_cell("#%d" % place, true))
		grid.add_child(_cell(p.display_name, place == 1))
		grid.add_child(_cell("%d pts" % p.total_score, place == 1))
		place += 1
	var winner: BlandPlayer = standings[0]
	var title := "You win!" if winner.is_human else "%s wins!" % winner.display_name
	_show_modal(title, grid, null, [
		["Play again", func() -> void: get_tree().reload_current_scene()],
		["Main menu", func() -> void: get_tree().change_scene_to_file(MENU_SCENE)],
	])


# A table cell (a Label), optionally highlighted in gold.
func _cell(text: String, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if bold:
		l.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	return l


# ================================================================ modals / pause

## buttons: Array of [label, Callable]. Any button closes the modal first.
## A "modal" is a pop-up that dims the screen and blocks the table underneath. `body` can be plain text or a
## ready-made Control (like a table). `card` optionally shows a large picture of a card above the text.
func _show_modal(title: String, body, card: BlandCard, buttons: Array) -> void:
	_close_modal()
	_modal = _make_overlay()
	var v: VBoxContainer = _modal.get_meta("content")
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 24)
	v.add_child(t)
	if card != null:
		var c := CenterContainer.new()
		c.add_child(_card_view(card, true, BIG_CARD * 1.4, -1, Callable()))
		v.add_child(c)
	if body is String:
		var l := Label.new()
		l.text = body
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		v.add_child(l)
	elif body is Control:
		var cc := CenterContainer.new()
		cc.add_child(body)
		v.add_child(cc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(130, 36)
		var cb: Callable = b[1]
		btn.pressed.connect(func() -> void:
			_close_modal()
			if cb.is_valid():
				cb.call())
		row.add_child(btn)
	add_child(_modal)


# Builds the dimmed full-screen backdrop with a bordered panel in the middle. The empty box inside
# is stored as metadata ("content") so the caller can fill it with whatever it needs.
func _make_overlay() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.12, 0.12, 0.16), Color(1, 0.85, 0.3), 2))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	dim.set_meta("content", v)
	return dim


# Closes the current pop-up and redraws, so the table shows any change made by the button.
func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
	_refresh()


# Opens or closes the pause menu (Esc / Pause button). While paused the bot timer is stopped; on resume
# it is restarted if it was a bot's turn, so the game carries on from where it left off.
func _toggle_pause() -> void:
	if _pause_modal != null:
		_pause_modal.queue_free()
		_pause_modal = null
		_paused = false
		if _bot_timer.is_stopped() and _bot_player == game.current and not game.players[game.current].is_human:
			_bot_timer.start(_bot_delay())
		return
	_paused = true
	_bot_timer.stop()
	_pause_modal = _make_overlay()
	var v: VBoxContainer = _pause_modal.get_meta("content")
	var t := Label.new()
	t.text = "Paused"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	v.add_child(t)
	for entry in [["Resume", _toggle_pause],
			["Restart game", func() -> void: get_tree().reload_current_scene()],
			["Main menu", func() -> void: get_tree().change_scene_to_file(MENU_SCENE)]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(220, 38)
		b.pressed.connect(entry[1])
		v.add_child(b)
	add_child(_pause_modal)


## Which cards are gone and which are still out there, rank by rank.
## There are 4 of each rank, so cards still hidden in opponents' hands = 4 - already paired - in your hand.
## A green number means you hold a card of that rank and a match for it is still out there.
func _show_tracker() -> void:
	var paired := game.paired_count_by_rank()
	var mine := {}
	for c in game.players[HUMAN].hand:
		if c.is_pair_card():
			mine[c.rank] = mine.get(c.rank, 0) + 1
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	for h in ["Card", "Already paired", "In your hand", "Still in opponents' hands"]:
		grid.add_child(_cell(h, true))
	for r in GameSettings.PAIR_RANKS:
		var gone: int = paired[r]
		var have: int = mine.get(r, 0)
		var out := 4 - gone - have
		grid.add_child(_cell("Ace" if r == 1 else str(r), true))
		grid.add_child(_cell("%d / 4" % gone))
		grid.add_child(_cell(str(have) if have > 0 else "-"))
		var out_l := _cell(str(out) if out > 0 else "-")
		if have > 0 and out > 0:
			out_l.add_theme_color_override("font_color", Color(0.5, 1, 0.5))   # you can still pair this
		grid.add_child(out_l)
	var specials_out := 0
	var specials_used := 0
	for c in game.discard_pile:
		if c.is_special():
			specials_used += 1
	for p in game.players:
		if p.index != HUMAN:
			specials_out += p.specials().size()
	var footer := "Jokers this round: %d   •   Special cards played: %d / %d   •   Specials in opponents' hands: %d\nGreen = a match for a card you hold is still out there." % [
		game.jokers_this_round, specials_used, GameSettings.total_specials(), specials_out]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(grid)
	var f := Label.new()
	f.text = footer
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.modulate = Color(1, 1, 1, 0.8)
	v.add_child(f)
	_show_modal("Card Tracker — Round %d" % game.round_number, v, null, [["Close", Callable()]])


# The rules pop-up (same text as the main menu's How to Play).
func _show_rules() -> void:
	_close_modal()
	_modal = _make_overlay()
	var v: VBoxContainer = _modal.get_meta("content")
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = GameSettings.RULES_TEXT
	text.custom_minimum_size = Vector2(720, 460)
	v.add_child(text)
	var b := Button.new()
	b.text = "Close"
	b.pressed.connect(_close_modal)
	v.add_child(b)
	add_child(_modal)
