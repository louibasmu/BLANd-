extends Control
#new Accessibility Panel
@onready var world_env: WorldEnvironment =$WorldEnvironment

@onready var _accessibility_panel: Control = %Accessibility_Panel
@onready var _brightness_contrast: Button = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Brightness_Contrast
@onready var _brightness_slider: Control = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Brightness_Slider
@onready var b_num: Label = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Brightness_Slider/B_Num

@onready var _contrast_slider: Control = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Contrast_Slider
@onready var c_num: Label = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Contrast_Slider/C_Num


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	world_env.environment.adjustment_enabled = true

# -------------------------------Accessibility Menu-------------------------------
func _on_accessibility_pressed() -> void:
	_accessibility_panel.visible = true

func _on_access_close_pressed() -> void:
	_accessibility_panel.visible = false

# Brightness fns
func _on_brightness_contrast_pressed() -> void:
	_brightness_slider.visible = true
	_contrast_slider.visible = true

func _on_b_slider_value_changed(value: float) -> void:
	b_num.text = str(value)
	world_env.environment.adjustment_brightness = value

# Contrast fns
func _on_c_slider_value_changed(value: float) -> void:
	c_num.text = str(value)
	world_env.environment.adjustment_contrast = value
# Called every frame. 'delta' is the elapsed time since the previous frame.
