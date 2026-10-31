extends SceneTree
## 12 seconds of selection / editable bindings, followed by six role lessons.
const Arena = preload("res://scripts/arena.gd")
class Director:
	extends Node
	var arena: Node2D
	var clock := 0.0
	var phase_done := -1
	var segment := -1
	var started := false
	var ex_started := false
	func _physics_process(dt: float) -> void:
		clock += dt
		if clock >= 72:
			get_tree().quit()
			return
		if clock < 12:
			var phase := 0 if clock < 2 else (1 if clock < 4 else (2 if clock < 5.5 else (3 if clock < 6.5 else (4 if clock < 7.5 else (5 if clock < 9 else 6)))))
			if phase == phase_done: return
			phase_done = phase
			match phase:
				1:
					arena.selected = 1
					arena.rival = 5
					arena.build_menu()
				2: arena.open_settings()
				3: arena.capture_binding("skill1")
				4:
					var event := InputEventKey.new()
					event.physical_keycode = KEY_Q
					event.pressed = true
					arena._input(event)
				5: arena.reset_bindings()
				6:
					arena.close_settings(false)
					arena.selected = 3
					arena.rival = 4
					arena.build_menu()
			return
		var scene := int((clock-12)/10)
		if scene != segment:
			segment = scene
			arena.selected = scene
			arena.rival = (scene+1)%6
			arena.stage = scene%4
			arena.start_match(true,false)
			arena.intro_time = 0.7
			started = false
			ex_started = false
		var phase := fmod(clock-12,10)
		if phase >= 0.8 and not started:
			started = true
			arena.combo_coach.start()
		if phase >= 7.4 and not ex_started:
			ex_started = true
			arena.new_round()
			arena.intro_time = 0
			arena.combo_coach.status = "EX SIGNATURE / 角色强化技能"
			var a = arena.fighters[0]
			a.position = Vector2(475,532)
			arena.fighters[1].position = Vector2(650,532)
			for f in arena.fighters: f.visual.play("idle")
			a.special([2,0,0,0,2,0][scene],true)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	arena.controls.reset_defaults()
	var director := Director.new()
	director.arena = arena
	root.add_child(director)
