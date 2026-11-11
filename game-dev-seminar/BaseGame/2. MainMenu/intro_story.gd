extends Control
## Intro story: types each line letter by letter with a blinking cursor,
## waits, clears the screen, then types the next line.
## Click / Space / Enter = finish the line (or skip a pause).
## The Skip button is connected to _leave() in the editor (Node tab -> Signals).


@export_file("*.tscn") var menu_scene: String = "res://BaseGame/2. MainMenu/main_menu.tscn"
@export_group("Story")
@export_multiline var lines: Array[String] = [
	"You wake in the dark.",
	"Rope on your wrists.",
	"Three strangers. One table.\nEvery one of them guilty.",
	"A masked man deals the cards.",
	"Only one of you leaves.",
	"The cards are already dealt.",
]
@export var text_color := Color(0.88, 0.82, 0.68)
@export var blood_color := Color(0.75, 0.12, 0.12)  # the LAST line uses this
@export var cursor := "|"

@export_group("Typing Speed")
@export var type_delay := 0.09        # base time between letters
@export var type_jitter := 0.04       # random +/- per letter
@export var pause_comma := 0.35
@export var pause_period := 0.8       # after . ! ?
@export var pause_newline := 0.6
@export var pause_after_line := 1.6   # wait once a line is finished
@export var pause_between := 0.7      # dark pause between lines
@export var first_delay := 1.2        # wait before the first line

@export_group("Fades")
@export var screen_fade_in := 1.0
@export var screen_fade_out := 0.8
@export var music_fade_in := 2.0
@export var music_fade_out := 0.8


@onready var _label: Label = $CenterContainer/StoryLabel
@onready var _key_player: AudioStreamPlayer = $KeyClickPlayer
@onready var _music_player: AudioStreamPlayer = $MusicPlayer


var _typed := ""                 # text currently on screen
var _typing := false             # true while letters are being typed
var _skip_requested := false     # set by click / Space / Enter
var _leaving := false            # true once heading to the menu


func _ready() -> void:
	#preload("res://BaseGame/2. MainMenu/main_menu.tscn")
	# Music
	if _music_player.stream != null:
		var target_volume := _music_player.volume_db
		_music_player.volume_db = -40.0
		_music_player.play()
		create_tween().tween_property(_music_player, "volume_db", target_volume, music_fade_in)

	# Fade the screen in, then start the story.
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, screen_fade_in)
	t.tween_callback(_play_story)


# Every frame: draw typed text + cursor.
# Cursor is solid while typing, blinks twice a second while waiting.
func _process(_delta: float) -> void:
	var blink_on: bool = int(Time.get_ticks_msec() / 500.0) % 2 == 0
	_label.text = _typed + (cursor if (_typing or blink_on) else " ")


# Left-click or Space/Enter = "skip ahead".
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var clicked: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		_skip_requested = true
		


# For each line: set colour -> type it -> wait -> clear -> dark pause.
# After the last line, go to the menu.
func _play_story() -> void:
	await _wait(first_delay)
	for i in lines.size():
		if _leaving or not is_inside_tree():
			return
		var is_last: bool = i == lines.size() - 1
		_label.add_theme_color_override("font_color", blood_color if is_last else text_color)
		await _type_line(lines[i])
		await _wait(pause_after_line)
		_typed = ""
		await _wait(pause_between)
	_leave()


# Types one line a letter at a time. A click mid-line prints the rest at once.
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
		if ch != " " and ch != "\n" and _key_player.stream != null:
			_key_player.pitch_scale = randf_range(0.9, 1.1)
			_key_player.play()
		await get_tree().create_timer(_delay_after(ch)).timeout
	_typing = false


# Pause length after a character: longer after punctuation, slightly random otherwise.
func _delay_after(ch: String) -> float:
	match ch:
		",":
			return pause_comma
		".", "!", "?":
			return pause_period
		"\n":
			return pause_newline
		_:
			return maxf(0.02, type_delay + randf_range(-type_jitter, type_jitter))


# Waits `seconds`, but a click ends the wait early.
func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		if _leaving or not is_inside_tree():
			return
		if _skip_requested:
			#_skip_requested = false
			return
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05


# Fade music + screen out, then load the menu.
# Also called by the Skip button (connected in the editor). Safe to call twice.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	create_tween().tween_property(_music_player, "volume_db", -40.0, music_fade_out)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, screen_fade_out)
	t.tween_callback(_go_to_menu)


func _go_to_menu() -> void:
	var err := get_tree().change_scene_to_file(menu_scene)
	_leaving = true
	if err != OK:
		push_error("Intro: could not load menu scene '%s' (error %d). Check Menu Scene in the Inspector." % [menu_scene, err])
		modulate.a = 1.0
		_leaving = false
	
func _on_skip_button_pressed() -> void:
	pass
