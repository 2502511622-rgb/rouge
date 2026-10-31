extends SceneTree
const Arena = preload("res://scripts/arena.gd")
var arena: Node2D
func _initialize() -> void:
	run.call_deferred()
func capture(name: String) -> void:
	arena.queue_redraw()
	arena.presentation.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/tmp/meme-menu-visual/"+name) == OK)
func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event
func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/meme-menu-visual")
	arena = Arena.new()
	root.add_child(arena)
	arena.muted = true
	arena.controls.reset_defaults()
	arena.set_physics_process(false)
	await capture("selection.png")
	await click(arena.grid_rect(1).get_center())
	assert(arena.selected == 1,"Mouse must select through the entire portrait tile")
	await click(arena.menu_rect("cpu").get_center())
	assert(arena.select_target == 1)
	await click(arena.grid_rect(5).get_center())
	assert(arena.rival == 5 and arena.selected == 1)
	await capture("versus.png")
	await click(arena.menu_rect("settings").get_center())
	assert(arena.screen == "settings","Settings menu button must respond to actual mouse events")
	await capture("settings.png")
	await click(Vector2(420,420))
	assert(arena.capturing_action == "skill1")
	Input.parse_input_event(key(KEY_Q))
	await process_frame
	assert(arena.controls.key("skill1") == KEY_Q)
	await capture("remapped.png")
	arena.close_settings(false)
	assert(arena.controls.key("skill1") == KEY_U)
	await click(arena.menu_rect("mode2").get_center())
	assert(arena.mode_index == 2)
	await capture("training-mode.png")
	await click(arena.menu_rect("confirm").get_center())
	assert(arena.screen == "fight" and arena.training and not arena.arcade)
	arena.back_to_menu()
	arena.set_mode(0)
	arena.selected = 3
	arena.start_match(true,false)
	arena.intro_time = 0
	arena.toggle_help()
	await capture("moves-uiop.png")
	arena.toggle_help()
	arena.open_settings()
	assert(arena.controls.bind("skill1",KEY_Q) == "")
	arena.close_settings(false)
	arena.combo_coach.start()
	for f in arena.fighters: f.visual.set_process(false)
	arena.fx.set_process(false)
	for i in range(1800):
		arena._physics_process(1.0/120)
		for f in arena.fighters: f.visual._process(1.0/120)
		arena.fx._process(1.0/120)
		if arena.combo[0] == 14:
			await capture("uiop-combo.png")
			break
	assert(arena.combo[0] == 14)
	print("MENU VISUAL PASS: full-tile mouse selection / independent CPU / settings click / capture / mode tabs and single confirm / UIOP help / actual 14-hit route")
	quit()
