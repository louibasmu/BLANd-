extends Control
## Start menu: pick the number of rounds (1-3) and the bot style, then play.
##
## The whole menu was built in code in _ready() 
##Asmus manually created them by node structure instead during week 7 and 8

# Scene file to load when the player presses Start Game.
#game should start with the story rather than the main menu. 
const TABLE_SCENE := "res://BaseGame/5. CardTable/game_table.tscn"

# Controls that later functions need to read or update, so they are kept as member variables.
# Nodes built in the editor (looked up by their path in the scene tree).
@onready var _rounds_option: OptionButton = %RoundsOption
@onready var _style_option: OptionButton = %StyleOption
@onready var _speed_option: OptionButton = %SpeedOption
@onready var _schedule_label: Label = %ScheduleLabel
@onready var _specials_summary: Label = %SpecialsSummary
@onready var _start_btn: Button = %StartButton
@onready var _rules_panel: Control = %RulesPanel     
@onready var _rules_text: RichTextLabel = %RulesText
@onready var _accessibility_panel: Control = %Accessibility_Panel #new_lean
@onready var _specials_panel: Control = %SpecialsPanel
@onready var _specials_grid: GridContainer = %SpecialsGrid
var _special_rows: Dictionary = {}   # special -> {spin, rarity}


# builds the main menu and assigns functionality to buttons and proper
# round numbers along with special card customization
func _ready() -> void:
	
	#User can choose how many rounds to play number of jokers is based on the number of rounds
	for r in range(GameSettings.MIN_ROUNDS, GameSettings.MAX_ROUNDS + 1):
		_rounds_option.add_item("%d rounds" % r, r)
	_rounds_option.select(GameSettings.num_rounds - GameSettings.MIN_ROUNDS)
	_rounds_option.item_selected.connect(_on_rounds_changed)
	
	#Choosing the bot's strategy, random or strategized. 
	#uses for loop for the various bot speeds and ensures the option selected is proper
	#before entering the game to eliminate risk of crash
	#Utilized in _on_start()
	##Could implement difficulty here...
	_style_option.select(GameSettings.bot_style)
	var names := GameSettings.BOT_SPEEDS.keys()
	for i in names.size():
		_speed_option.add_item(names[i], i)
		_speed_option.set_item_metadata(i, GameSettings.BOT_SPEEDS[names[i]])
		if is_equal_approx(GameSettings.BOT_SPEEDS[names[i]], GameSettings.bot_delay):
			_speed_option.select(i)

	#setting the _rules_text variable to the official rules text string set in game_settings.gd ~line 138
	_rules_text.text = GameSettings.RULES_TEXT

	_fill_specials_grid()
	_update_specials_ui()

	# Fill in the Jokers-per-round text for the starting selection, 
	# and focus Start Game so Enter works immediately.
	_on_rounds_changed(_rounds_option.selected)
	_start_btn.grab_focus()

# Runs when the rounds dropdown changes: refresh the "Jokers per round" text.
func _on_rounds_changed(i: int) -> void:
	var rounds := _rounds_option.get_item_id(i)
	_schedule_label.text = GameSettings.schedule_text(rounds)

# Saves every choice into GameSettings (these are static, so they survive the scene change)
# and then loads the table scene, which starts the game.
func _on_start() -> void:
	GameSettings.num_rounds = _rounds_option.get_item_id(_rounds_option.selected)
	GameSettings.bot_style = _style_option.get_item_id(_style_option.selected)
	GameSettings.bot_delay = _speed_option.get_selected_metadata()
	get_tree().change_scene_to_file(TABLE_SCENE)


# ---------------------------------------------------------------- special cards setup

#Builds the items within specials grid with done and reset button
func _fill_specials_grid() -> void:
	# Header row. The data rows are added below, one per special card type.
	for h in ["Card", "What it does", "Copies", "Rarity"]:
		var hl := Label.new()
		hl.text = h
		hl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		_specials_grid.add_child(hl)
	for sp in GameSettings.DEFAULT_SPECIAL_COUNTS:
		var name_l := Label.new()
		name_l.text = BlandCard.SPECIAL_NAMES[sp]
		_specials_grid.add_child(name_l)
		var help := Label.new()
		help.text = BlandCard.SPECIAL_HELP[sp]
		help.modulate = Color(1, 1, 1, 0.8)
		_specials_grid.add_child(help)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = GameSettings.MAX_COPIES_PER_SPECIAL
		spin.step = 1
		spin.value = GameSettings.count_of(sp)
		spin.value_changed.connect(func(val: float) -> void:
			GameSettings.special_counts[sp] = int(val)
			_update_specials_ui())
		_specials_grid.add_child(spin)
		var rarity := Label.new()
		rarity.custom_minimum_size = Vector2(110, 0)
		_specials_grid.add_child(rarity)
		_special_rows[sp] = {"spin": spin, "rarity": rarity}

func _on_specials_reset() -> void:
	GameSettings.special_counts = GameSettings.DEFAULT_SPECIAL_COUNTS.duplicate()
	for sp in _special_rows:
		_special_rows[sp]["spin"].set_value_no_signal(GameSettings.count_of(sp))
	_update_specials_ui()

# Refreshes the setup screen: each row's rarity name and colour, plus the summary line.
# The deck is 40 pair cards + the special cards + 1 to 3 Jokers, so we show the smallest and largest possible total
# (deck_min assumes one Joker, deck_min + 2 assumes three).
func _update_specials_ui() -> void:
	for sp in _special_rows:
		var r: Label = _special_rows[sp]["rarity"]
		r.text = GameSettings.rarity_name(sp)
		r.add_theme_color_override("font_color", GameSettings.rarity_color(sp))
	var total_special := GameSettings.total_specials()
	var pair_card_count = GameSettings.pair_card_count
	var deck_min := GameSettings.pair_card_count + total_special + 1
	_specials_summary.text = "%d special cards in the deck (%d–%d cards total with Jokers)" % [total_special, deck_min, deck_min + 2]

#when how to play button pressed it shows the rules
func _on_rules_pressed() -> void:
	_rules_panel.visible = true

#connecting the function of the specials panel to visible since it starts as invisible
func _on_specials_pressed() -> void:
	_specials_panel.visible = true

#Quits the tree(the game) when quit button is pressed
func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_close_button_pressed() -> void:
	_rules_panel.visible = false

func _on_done_button_pressed() -> void:
	_specials_panel.visible = false

func _on_accessibility_pressed() -> void:
	_accessibility_panel.visible = true

func _on_access_close_pressed() -> void:
	_accessibility_panel.visible = false
