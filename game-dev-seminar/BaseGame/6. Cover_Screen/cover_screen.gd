extends Control

#new Accessibility Panel
@onready var world_env: WorldEnvironment =$WorldEnvironment
@onready var _accessibility_panel: Control = %Accessibility_Panel 
@onready var _brightness_contrast: Button = %Brightness_Contrast

@onready var _brightness_slider: Control = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Brightness_Slider
@onready var b_num: Label = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Brightness_Slider/B_Num

@onready var _contrast_slider: Control = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Contrast_Slider
@onready var c_num: Label = $Accessibility_Panel/Access_Center/Access_Body/Access_Column/Contrast_Slider/C_Num

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
