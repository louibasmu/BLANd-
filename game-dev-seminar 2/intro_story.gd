extends Control
## Intro backstory, typed out letter by letter like someone typing in a document,
## with a blinking cursor. Each line types itself, waits, then the next one starts.
## Click / Space / Enter: finish the current line instantly (or skip the pause after it).
## The Skip button jumps straight to the main menu.

# Scene to load when the intro ends. CHANGE THIS to your real main menu path
# (FileSystem dock -> right-click your menu scene -> Copy Path).
const MENU_SCENE := "res://BaseGame/2. MainMenu/main_menu.tscn"


# ---- Typing feel (all in seconds). Bigger numbers = slower. ----
const TYPE_DELAY := 0.09          # base time between letters
const TYPE_JITTER := 0.04         # random +/- on each letter so it feels human
const PAUSE_COMMA := 0.35
const PAUSE_PERIOD := 0.8         # after . ! ?  (each dot of "..." counts, so ellipses drag)
const PAUSE_NEWLINE := 0.6
const PAUSE_AFTER_LINE := 1.6     # wait once a line is finished
const PAUSE_BETWEEN := 0.7        # empty dark screen between lines
const FIRST_DELAY := 1.2
const CURSOR := "|"

const COL_TEXT := Color(0.88, 0.82, 0.68)
const COL_BLOOD := Color(0.75, 0.12, 0.12)   # the last line is typed in this colour

const LINES := [
	"You wake in the dark.",
	"Rope on your wrists.",
	"Three strangers. One table.\nEvery one of them guilty.",
	"A masked man deals the cards.",
	"Only one of you leaves.",
	"The cards are already dealt.",
]

# ---- Settings: select this scene's root node and edit these in the Inspector ----
@export_group("Background")
@export var background_color: Color = Color(0.02, 0.01, 0.02)
@export var background_texture: Texture2D
@export_range(0.0, 1.0, 0.05) var background_dim: float = 0.5
@export_group("Sound")
## Optional: a short key-click sound. It plays on every letter, with a slightly random pitch.
@export var type_sound: AudioStream
## Optional: background music / ambience that plays during the whole intro (mp3, ogg or wav).
@export var intro_music: AudioStream = load("res://sound_assets/story background/ScaryMusic2018-10-12_-_It_Is_Coming_-_David_Fesliyan.mp3")
## Music volume in decibels. 0 = full volume, -10 = quieter, -20 = much quieter.
@export_range(-40.0, 6.0, 1.0) var music_volume_db: float = -8.0
## Loop the music if the intro lasts longer than the track.
@export var loop_music: bool = true

var _label: Label
var _hint: Label
var _player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _typed := ""
var _typing := false
var _skip_requested := false
var _leaving := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = background_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	if background_texture != null:
		var pic := TextureRect.new()
		pic.texture = background_texture
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)

		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, background_dim)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Left-aligned with a fixed size, so the text grows rightwards like real typing
	# instead of jumping around while it is centred.
	_label = Label.new()
	_label.custom_minimum_size = Vector2(700, 200)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", COL_TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_label)

	_hint = Label.new()
	_hint.text = "Click to skip ahead"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.modulate = Color(1, 1, 1, 0.3)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -50
	_hint.offset_bottom = -20
	_hint.offset_left = -200
	_hint.offset_right = 200
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	var skip := Button.new()
	skip.text = "Skip"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -90
	skip.offset_top = 16
	skip.offset_right = -16
	skip.offset_bottom = 48
	skip.pressed.connect(_leave)
	add_child(skip)

	if type_sound != null:
		_player = AudioStreamPlayer.new()
		_player.stream = type_sound
		add_child(_player)

	# Background music: starts quietly and fades in together with the screen.
	if intro_music != null:
		if loop_music:
			if intro_music is AudioStreamMP3:
				intro_music.loop = true
			elif intro_music is AudioStreamOggVorbis:
				intro_music.loop = true
		_music_player = AudioStreamPlayer.new()
		_music_player.stream = intro_music
		_music_player.volume_db = -40.0
		add_child(_music_player)
		_music_player.play()
		create_tween().tween_property(_music_player, "volume_db", music_volume_db, 2.0)

	# Fade in, then start the story.
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 1.0)
	t.tween_callback(_play_story)


# The blinking cursor: redraws the label every frame as typed text + cursor.
# The cursor stays solid while letters are being typed, and blinks while waiting.
func _process(_delta: float) -> void:
	var blink_on: bool = int(Time.get_ticks_msec() / 500.0) % 2 == 0
	var show_cursor: bool = _typing or blink_on
	_label.text = _typed + (CURSOR if show_cursor else " ")


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var clicked: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		_skip_requested = true


# The whole intro: type a line, wait, clear the screen, repeat. Then go to the menu.
func _play_story() -> void:
	await _wait(FIRST_DELAY)
	for i in LINES.size():
		if _leaving or not is_inside_tree():
			return
		var is_last: bool = i == LINES.size() - 1
		_label.add_theme_color_override("font_color", COL_BLOOD if is_last else COL_TEXT)
		await _type_line(LINES[i])
		await _wait(PAUSE_AFTER_LINE)
		_typed = ""
		await _wait(PAUSE_BETWEEN)
	_leave()


# Types one line letter by letter. A click while typing prints the rest instantly.
func _type_line(text: String) -> void:
	_typed = ""
	_typing = true
	for i in text.length():
		if _leaving or not is_inside_tree():
			return
		if _skip_requested:
			_skip_requested = false
			_typed = text
			break
		var ch := text[i]
		_typed += ch
		if ch != " " and ch != "\n":
			_play_key()
		await get_tree().create_timer(_delay_after(ch)).timeout
	_typing = false


# How long to pause after each character: slower after punctuation, a little random otherwise.
func _delay_after(ch: String) -> float:
	match ch:
		",":
			return PAUSE_COMMA
		".", "!", "?":
			return PAUSE_PERIOD
		"\n":
			return PAUSE_NEWLINE
		_:
			return maxf(0.02, TYPE_DELAY + randf_range(-TYPE_JITTER, TYPE_JITTER))


# Waits for `seconds`, but a click ends the wait early.
func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		if _leaving or not is_inside_tree():
			return
		if _skip_requested:
			_skip_requested = false
			return
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05


func _play_key() -> void:
	if _player == null:
		return
	_player.pitch_scale = randf_range(0.9, 1.1)
	_player.play()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	if _music_player != null:
		create_tween().tween_property(_music_player, "volume_db", -40.0, 0.8)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.8)
	t.tween_callback(_go_to_menu)


func _go_to_menu() -> void:
	print("Intro: loading menu at ", MENU_SCENE)
	if not ResourceLoader.exists(MENU_SCENE):
		push_error("Intro: this scene does not exist: " + MENU_SCENE + "  -> fix MENU_SCENE at the top of intro_story.gd")
		modulate.a = 1.0
		_leaving = false
		return
	var err := get_tree().change_scene_to_file(MENU_SCENE)
	if err != OK:
		push_error("Intro: change_scene_to_file failed, error code %d" % err)
