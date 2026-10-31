extends SceneTree
const Arena = preload("res://scripts/arena.gd")
const Profile = preload("res://scripts/input_profile.gd")
var arena: Node2D
var path := "/tmp/meme-controls-test-%d.cfg" % Time.get_ticks_usec()
func _initialize() -> void:
	run.call_deferred()
func event(code: int, held := true, ctrl := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = held
	e.ctrl_pressed = ctrl
	return e
func run() -> void:
	var p := Profile.new()
	p.path = path
	assert([p.key("skill1"),p.key("skill2"),p.key("skill3"),p.key("super")] == [KEY_U,KEY_I,KEY_O,KEY_P])
	assert(p.bind("skill1",KEY_J) != "" and p.key("skill1") == KEY_U)
	assert(p.bind("skill1",KEY_F2) != "")
	assert(p.bind("skill1",KEY_SHIFT) != "")
	assert(p.bind("skill1",KEY_Q) == "")
	assert(p.bind("ex",KEY_CTRL) == "")
	assert(p.hint("{skill1}+{ex}") == "Q+Ctrl")
	assert(p.save_bindings() == OK)
	assert(p.bind("skill1",KEY_E) == "" and p.save_bindings() == OK,"Existing settings file can be replaced")
	var loaded := Profile.new()
	loaded.path = path
	assert(loaded.load_bindings() == OK and loaded.key("skill1") == KEY_E and loaded.key("ex") == KEY_CTRL)
	var corrupt := ConfigFile.new()
	assert(corrupt.load(path) == OK)
	corrupt.set_value("keys","skill1",KEY_J)
	assert(corrupt.save(path) == OK)
	var clean := Profile.new()
	clean.path = path
	assert(clean.load_bindings() == ERR_INVALID_DATA and clean.key("skill1") == KEY_U)
	arena = Arena.new()
	root.add_child(arena)
	arena.smoke = true
	arena.set_physics_process(false)
	arena.controls.reset_defaults()
	arena.controls.path = path
	arena.open_settings()
	arena.capture_binding("skill1")
	arena._input(event(KEY_F2))
	assert(arena.capturing_action == "skill1" and arena.controls.key("skill1") == KEY_U)
	arena._input(event(KEY_Q))
	assert(arena.capturing_action == "" and arena.controls.key("skill1") == KEY_Q)
	arena.capture_binding("skill2")
	arena._input(event(KEY_ESCAPE))
	assert(arena.capturing_action == "" and arena.controls.key("skill2") == KEY_I)
	arena.close_settings(false)
	assert(arena.screen == "select" and arena.controls.key("skill1") == KEY_U,"Cancel must restore every previous binding")
	arena.open_settings()
	arena.capture_binding("skill1")
	arena._input(event(KEY_Q))
	arena.close_settings(true)
	assert(arena.screen == "select")
	assert(loaded.load_bindings() == OK and loaded.key("skill1") == KEY_Q)
	arena.set_select_target(1)
	var player: int = arena.selected
	arena.choose_grid(5)
	assert(arena.rival == 5 and arena.selected == player)
	arena._unhandled_key_input(event(KEY_RIGHT))
	assert(arena.rival == 0 and arena.selected == player,"Grid navigation must edit the chosen side")
	arena.set_select_target(0)
	arena.set_mode(1)
	arena._unhandled_key_input(event(KEY_E))
	assert(arena.mode_index == 2)
	arena._unhandled_key_input(event(KEY_ENTER))
	assert(arena.training and not arena.arcade,"Enter confirms the chosen mode")
	arena.back_to_menu()
	arena.set_mode(1)
	var shown_rival: int = arena.preview_rival()
	arena.set_select_target(1)
	assert(arena.select_target == 0,"Arcade opponent is automatically scheduled")
	arena.start_chosen_mode()
	assert(arena.rival == shown_rival,"Arcade preview must match the actual first challenger")
	assert(arena.arcade and not arena.training,"Arcade mode must route to tour")
	arena.back_to_menu()
	arena.set_mode(0)
	arena.start_chosen_mode()
	assert(not arena.arcade and not arena.training)
	arena.start_match(true,false)
	arena.intro_time = 0
	var f = arena.fighters[0]
	arena.open_settings()
	var before: Vector2 = f.position
	var timer: float = arena.time_left
	arena._physics_process(0.2)
	assert(f.position == before and arena.time_left == timer and arena.paused)
	arena.close_settings(false)
	assert(arena.screen == "fight" and not arena.paused)
	f.meter = 3
	f.press(KEY_U)
	assert(f.action_type == "idle","Old skill key must stop triggering after remap")
	f.press(KEY_Q)
	assert(f.action_type == "special" and f.last_special_move == 0)
	f.cooldown = 0
	f.active = 0
	assert(arena.controls.bind("ex",KEY_CTRL) == "")
	arena._unhandled_key_input(event(KEY_Q,true,true))
	assert(f.meter == 2,"Custom EX modifier must work through actual input dispatch")
	f.cooldown = 0
	f.active = 0
	f.meter = 3
	f.press(KEY_P)
	assert(f.action_type == "super" and f.meter == 0)
	arena.cinematic = 0
	f.active = 0
	f.cooldown = 0
	f.stun = 0
	assert(arena.controls.bind("left",KEY_LEFT) == "")
	assert(arena.controls.bind("right",KEY_RIGHT) == "")
	arena._input(event(KEY_RIGHT))
	f.player_input(0.016)
	assert(f.velocity.x > 0,"Held movement must use remapped physical keys")
	arena._input(event(KEY_RIGHT,false))
	arena._input(event(KEY_LEFT))
	f.player_input(0.016)
	assert(f.velocity.x < 0)
	arena._input(event(KEY_LEFT,false))
	assert(arena.controls.bind("jump",KEY_UP) == "")
	f.press(KEY_UP)
	assert(not f.grounded and f.jumps == 1)
	arena._input(event(KEY_LEFT))
	arena._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(not arena.controls.pressed("left"),"Focus loss releases held controls")
	assert(arena.hint(arena.combo_coach.ROUTES[0]).contains("Q"))
	DirAccess.remove_absolute(path)
	print("CONTROLS PASS: UIOP defaults / remap and conflicts / persistent atomic save / corrupt recovery / settings capture and cancel / round freeze / custom EX / movement / live hints / P1 CPU grid navigation / three modes and accurate arcade preview")
	quit()
