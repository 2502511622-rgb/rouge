extends SceneTree
const Arena = preload("res://scripts/arena.gd")
var arena: Node2D
func _initialize() -> void:
	run.call_deferred()
func fixture(kind: int, practice := true) -> void:
	arena.selected = kind
	arena.rival = (kind+1)%6
	arena.start_match(practice,false)
	arena.intro_time = 0
func run() -> void:
	arena = Arena.new()
	root.add_child(arena)
	arena.smoke = true
	arena.set_physics_process(false)
	for kind in range(6):
		fixture(kind,false)
		var f = arena.fighters[0]
		f.meter = 3
		var event := InputEventKey.new()
		event.pressed = true
		event.physical_keycode = arena.controls.key("skill1")
		arena._unhandled_key_input(event)
		assert(f.action_type == "special" and f.last_special_move == 0,"Bound skills must work in a real match")
		f.cooldown = 0
		f.active = 0
		event.physical_keycode = arena.controls.key("skill2")
		event.shift_pressed = true
		arena._unhandled_key_input(event)
		assert(f.last_special_move == 1 and f.meter == 2,"Shift skill binding spends one bar")
		f.cooldown = 0
		f.active = 0
		f.meter = 3
		event.physical_keycode = arena.controls.key("super")
		event.shift_pressed = false
		arena._unhandled_key_input(event)
		assert(f.action_type == "super" and f.meter == 0)
		fixture(kind)
		arena.combo_coach.start()
		var peak := 0
		for i in range(2200):
			arena._physics_process(1.0/120)
			peak = maxi(peak,arena.combo[0])
			if not arena.combo_coach.running: break
		print("ROLE ",kind," hits=",peak," step=",arena.combo_coach.step," ",arena.combo_coach.status)
		assert(arena.combo_coach.status.begins_with("演练完成"),"Every role rehearsal must finish via actual hits")
		assert(peak == [7,7,7,14,7,8][kind],"Role lessons must have distinct real outcomes")
		if kind == 3: assert(arena.fighters[0].v_meter < 90,"Frog extended combo must spend V resource")
	fixture(0)
	var a = arena.fighters[0]
	a.press(arena.controls.key("skill1"))
	a.tick(12.0/60,false)
	var sonic_speed: float = arena.projectiles[0].velocity.x
	var sonic_recovery: float = a.cooldown
	a.ai_time = 999
	arena.fighters[1].position.x = a.position.x+120
	a.active = 0
	a.cooldown = 0
	a.ai_input(0.016)
	assert(a.velocity.x < 0,"Ranged AI retreats from close pressure")
	fixture(2)
	a = arena.fighters[0]
	a.press(arena.controls.key("skill1"))
	a.tick(12.0/60,false)
	assert(sonic_speed > arena.projectiles[0].velocity.x and sonic_recovery < a.cooldown)
	fixture(1)
	a = arena.fighters[0]
	var b = arena.fighters[1]
	a.press(arena.controls.key("skill1"))
	var before: float = a.hp
	a.receive({"damage":100,"projectile":true},b)
	assert(a.hp == before and a.shield_guard > 0,"Shield rush blocks a high projectile")
	a.receive({"damage":100,"projectile":true,"low":true},b)
	assert(a.hp < before and a.shield_guard == 0,"Low hit interrupts shield rush")
	fixture(2)
	a = arena.fighters[0]
	b = arena.fighters[1]
	for i in range(5):
		a.active = 0
		a.cooldown = 0
		a.press(arena.controls.key("skill3"))
		a.tick(12.0/60,false)
	assert(arena.cat_trap_count(0) == 3 and a.guard_time > 0 and a.v_time == 0)
	arena.spawn_projectile(a,0,true)
	arena.settle_trap(arena.projectiles[-1])
	a.active = 0
	a.cooldown = 0
	a.press(arena.controls.key("skill3"))
	a.tick(12.0/60,false)
	assert(arena.cat_trap_count(0) == 3,"Expired EX fragments must not bypass the placed-trap cap")
	before = b.hp
	var trap: Dictionary = arena.projectiles.filter(func(p): return p.trap and p.life > 0)[0]
	b.position = Vector2(trap.position.x,532)
	arena.tick_projectiles(0.016)
	assert(b.hp < before,"Placed normal trap must damage a grounded opponent")
	fixture(4)
	a = arena.fighters[0]
	a.press(KEY_L)
	assert(a.armor > 0 and a.attack.guard_chip == 0.25,"Bull heavy has brief armor and stronger guard pressure")
	fixture(5)
	a = arena.fighters[0]
	b = arena.fighters[1]
	a.position.x = 475
	b.position.x = 665
	before = b.hp
	a.press(KEY_K)
	assert(a.attack.kick and a.attack.range == 200,"Kangaroo's primary keys must use long kicks")
	a.tick(6.0/60,false)
	assert(b.hp < before,"Midrange kick must connect where an ordinary punch cannot")
	assert(a.preferred_special(210) == 0)
	print("ROLES PASS: global simple controls / six distinct lessons / ranged spacing / shield vulnerability / trap cap / heavy armor / midrange kick")
	quit()
