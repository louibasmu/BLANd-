extends TextureButton

func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://BaseGame/2. MainMenu/intro_story.tscn")
