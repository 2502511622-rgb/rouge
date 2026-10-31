extends SceneTree
## 72 seconds: six distinct role lessons, then each fighter’s EX signature.
const Arena = preload("res://scripts/arena.gd")
class Director:
	extends Node
	var arena: Node2D
	var clock := 0.0
	var segment := -1
	var started := false
	var ex_started := false
	func _physics_process(dt: float) -> void:
		clock += dt
		if clock >= 72:
			get_tree().quit()
			return
		var scene := int(clock/12)
		if scene != segment:
			segment = scene
			arena.selected = scene
			arena.rival = (scene+1)%6
			arena.stage = scene%4
			arena.start_match(true,false)
			arena.intro_time = 1.4
			started = false
			ex_started = false
		var phase := fmod(clock,12)
		if phase >= 1.5 and not started:
			started = true
			arena.combo_coach.start()
		if phase >= 8 and not ex_started:
			ex_started = true
			arena.new_round()
			arena.intro_time = 0
			arena.combo_coach.status = "EX SIGNATURE / 角色强化必杀"
			var a = arena.fighters[0]
			a.position = Vector2(475,532)
			arena.fighters[1].position = Vector2(650,532)
			a.visual.play("idle")
			arena.fighters[1].visual.play("idle")
			a.special([2,0,0,0,2,0][scene],true)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var director := Director.new()
	director.arena = arena
	root.add_child(director)
