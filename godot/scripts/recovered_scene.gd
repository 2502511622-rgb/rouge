extends Node2D
func _ready() -> void:
	if "--smoke-test" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	if "--recovered-smoke" in OS.get_cmdline_user_args():
		var screen := get_node("Viewport/Screen")
		var tiles := 0
		var objects := 0
		for child in screen.get_children():
			if child is TileMapLayer:
				tiles += child.get_used_cells().size()
			if child is Sprite2D:
				objects += 1
		assert(tiles > 0)
		assert(objects > 0)
		print("RECOVERED SCENE PASS: native tile cells=", tiles, " separate OBJ sprites=", objects)
		get_tree().quit(0)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1:
			get_tree().change_scene_to_file("res://scenes/recovered_village.tscn")
		KEY_2:
			get_tree().change_scene_to_file("res://scenes/recovered_title.tscn")
		KEY_3:
			get_tree().change_scene_to_file("res://scenes/recovered_dialogue.tscn")
		KEY_P:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
