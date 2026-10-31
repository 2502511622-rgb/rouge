extends SceneTree
const Arena = preload("res://scripts/arena.gd")
var arena: Node2D
func _initialize() -> void:
	run.call_deferred()
func fixture(kind := 0) -> void:
	arena.selected = kind
	arena.rival = (kind+1)%6
	arena.start_match(true,false)
	arena.intro_time = 0
	arena.fighters[0].position = Vector2(475,532)
	arena.fighters[1].position = Vector2(550,532)
func step(seconds: float) -> void:
	for i in range(ceili(seconds*120)):
		arena._physics_process(1.0/120)
func run() -> void:
	arena = Arena.new()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.smoke = true
	for kind in range(6):
		fixture(kind)
		arena.combo_coach.start()
		var peak := 0
		for i in range(1400):
			arena._physics_process(1.0/120)
			peak = maxi(peak,arena.combo[0])
			if not arena.combo_coach.running: break
		print("ROUTE ",kind," step=",arena.combo_coach.step," hits=",peak," hp=",arena.fighters[1].hp)
		assert(arena.combo_coach.step == 5,"Every character must confirm normals → special → CA")
		assert(peak >= 9,"Six-hit CA must be part of one uninterrupted combo")
		assert(arena.fighters[1].hp > 0,"Full route must leave room for another exchange")
	# Test with real knockback instead of the training dummy's zero velocity.
	for kind in range(6):
		fixture(kind)
		arena.combo_coach.start()
		arena.training = false
		var peak := 0
		for i in range(1600):
			var dt := 1.0/120
			if arena.cinematic > 0: arena.cinematic = maxf(0,arena.cinematic-dt)
			elif arena.hit_pause > 0: arena.hit_pause = maxf(0,arena.hit_pause-dt)
			else:
				# Controlled neutral fighters keep AI decisions out of the fixture.
				arena.fighters[0].tick(dt,true)
				arena.fighters[1].tick(dt,true)
				arena.resolve_overlap()
				arena.tick_projectiles(dt)
				arena.combo_coach.tick(dt)
			peak = maxi(peak,arena.combo[0])
			if not arena.combo_coach.running: break
		assert(peak == 10 and arena.combo_coach.step == 5,"Route must survive real knockback outside training")
		print("KNOCKBACK ROUTE ",kind," hits=",peak)
	fixture()
	var a = arena.fighters[0]
	var b = arena.fighters[1]
	a.normal(0,false)
	var serial: int = a.action_serial
	a.normal(1,false)
	assert(a.action_serial == serial and not a.buffered.is_empty(),"Early press buffers without whiff cancel")
	step(0.15)
	assert(a.action_serial == serial+1 and a.action_rank == 1,"Buffered medium fires only after light confirms")
	a.normal(0,false)
	assert(a.action_rank == 1,"Cannot reverse chain medium back to light")
	fixture()
	a = arena.fighters[0]
	b = arena.fighters[1]
	b.position.x = 900
	a.normal(0,false)
	a.special(0,false)
	step(0.12)
	assert(a.action_type == "normal","Whiff cannot special-cancel")
	a.special(0,true)
	assert(a.action_type == "normal","EX cannot bypass a whiffed normal's recovery")
	fixture()
	a = arena.fighters[0]
	b = arena.fighters[1]
	b.position.x = 900
	a.normal(2,false)
	a.tick(0.4,false)
	assert(a.active <= 0 and a.cooldown > 0)
	a.super_move()
	assert(a.action_type == "normal" and arena.cinematic == 0,"Whiff recovery cannot be super-canceled")
	fixture()
	a = arena.fighters[0]
	b = arena.fighters[1]
	b.blocking = true
	a.normal(0,false)
	a.tick(0.05,false)
	assert(a.cancel_window == 0 and not a.can_cancel("special"),"Blocked contact cannot grant hit-only chain cancels")
	fixture()
	a = arena.fighters[0]
	b = arena.fighters[1]
	a.normal(0,false)
	a.tick(0.05,false)
	a.special(0,false)
	assert(a.action_type == "special" and a.meter > 0,"Confirmed normal cancels into special")
	var old_serial: int = a.action_serial
	a.cooldown = 0
	a.active = 0
	a.normal(0,false)
	b.receive({"damage":10,"cancelable":true,"serial":old_serial},a)
	assert(not a.can_cancel("special"),"An older projectile cannot confirm a new action")
	fixture()
	a = arena.fighters[0]
	b = arena.fighters[1]
	var before: float = b.hp
	b.receive({"damage":100},a)
	var first: float = before-b.hp
	before = b.hp
	b.receive({"damage":100},a)
	assert(before-b.hp < first,"Linked hits must scale damage")
	fixture()
	a = arena.fighters[0]
	b = arena.fighters[1]
	b.grounded = false
	b.position.y = 450
	b.stun = 0.5
	b.juggle_count = 4
	before = b.hp
	b.receive({"damage":100},a)
	assert(b.hp == before,"Juggle limit prevents infinite air loops")
	b.receive({"damage":55,"ca":true},a)
	assert(b.hp < before,"CA can complete a bounded air combo")
	fixture(1)
	a = arena.fighters[0]
	a.special(0,true)
	step(0.9)
	assert(arena.combo[0] == 3,"Dog EX shield rush must connect three actual attacks")
	fixture(2)
	a = arena.fighters[0]
	b = arena.fighters[1]
	a.v_skill()
	a.receive({"damage":50},b)
	assert(a.can_cancel("super"),"Successful counter can be super-canceled")
	a.super_move()
	assert(a.meter == 0 and a.action_type == "super")
	print("COMBO PASS: six uninterrupted routes / buffered confirm / whiff denial / rank ordering / stale projectile / damage scaling / juggle limit")
	quit()
