extends SceneTree
const Arena = preload("res://scripts/arena.gd")
const Rules = preload("res://scripts/combat_rules.gd")
var arena: Node2D
var a: Node2D
var b: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func fresh(kind := 0, other := 1) -> void:
	arena.controls.release_all()
	arena.selected = kind
	arena.rival = other
	arena.start_match(true,false)
	arena.intro_time = 0
	arena.cinematic = 0
	arena.hit_pause = 0
	a = arena.fighters[0]
	b = arena.fighters[1]
	a.position = Vector2(500,532)
	b.position = Vector2(500+(Rules.PUSH_WIDTH[kind]+Rules.PUSH_WIDTH[other])*.5,532)
	a.facing = 1
	b.facing = -1
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		push_error("RULES FAIL: "+message)
		return
	checks += 1
func run() -> void:
	arena = Arena.new()
	root.add_child(arena)
	arena.smoke = true
	arena.set_physics_process(false)
	fresh()
	arena.controls.held[arena.controls.key("right")] = true
	b.player_input(Rules.FRAME)
	a.meter = 3
	a.super_move()
	arena.cinematic = 0
	var hp: float = b.hp
	var guarded_hits := 0
	for frame in range(70):
		a.tick(Rules.FRAME,false)
		if b.hp < hp:
			check(b.stun_kind == "block" and hp-b.hp < 10,"Every CA hit must remain blocked while holding back")
			guarded_hits += 1
			hp = b.hp
		b.tick(Rules.FRAME,true)
	check(guarded_hits == 6,"Actual six-hit CA must execute")
	fresh()
	b.position.x = 900
	a.normal(2,false)
	while a.active > Rules.EPS: a.tick(Rules.FRAME,false)
	check(a.cooldown > 0,"Heavy must retain a separate recovery phase")
	arena.controls.held[arena.controls.key("left")] = true
	a.tick(Rules.FRAME,true)
	check(not a.blocking and absf(a.velocity.x) < .01,"Recovery cannot walk or guard")
	var before: float = a.hp
	b.position.x = 570
	b.normal(0,false)
	b.tick(6*Rules.FRAME,false)
	check(a.hp < before and a.stun_kind == "hit","A recovery punish must connect despite holding back")
	fresh()
	a.stun = 3*Rules.FRAME
	a.stun_kind = "hit"
	a.press(arena.controls.key("skill2"))
	check(not a.buffered.is_empty(),"Last three stun frames accept a reversal input")
	a.tick(3*Rules.FRAME,true)
	check(a.action_type == "special" and a.attack_startup > 0,"Buffered reversal executes when stun ends")
	fresh()
	a.stun = 20*Rules.FRAME
	a.stun_kind = "hit"
	a.press(arena.controls.key("skill2"))
	a.tick(21*Rules.FRAME,true)
	check(a.action_type == "idle","Old buffered input must expire rather than auto-fire")
	a.motion = [[2,a.clock-.8],[3,a.clock-.7],[6,a.clock-.6]]
	check(not a.matches([2,3,6]),"Old motion must not replace a normal")
	fresh()
	a.normal(0,false)
	check(a.frame_data == {"startup":4,"active":3,"recovery":10,"hitstun":17,"blockstun":11},"Authoritative light timing must match displayed timing")
	before = b.hp
	for i in range(3): a.tick(Rules.FRAME,false)
	check(b.hp == before and not a.strike_live(),"Startup has no live hitbox")
	a.tick(Rules.FRAME,false)
	check(b.hp < before and a.strike_live(),"First active frame uses the actual hitbox")
	a.tick(3*Rules.FRAME,false)
	check(not a.strike_live() and a.cooldown > 0,"Hitbox disappears during recovery")
	fresh()
	a.throw_move()
	before = b.hp
	a.tick(4*Rules.FRAME,false)
	check(b.grabbed.is_empty() and b.hp == before,"Normal throw has five-frame startup")
	a.tick(Rules.FRAME,false)
	check(not b.grabbed.is_empty() and b.hp == before,"Throw opens a tech window before damage")
	b.press(arena.controls.key("throw"))
	check(b.grabbed.is_empty() and b.hp == before and a.hp == arena.R.HP[a.kind],"Throw tech prevents all damage")
	fresh()
	a.throw_move()
	a.tick(5*Rules.FRAME,false)
	b.tick(8*Rules.FRAME,false)
	check(b.hp < arena.R.HP[b.kind] and b.knockdown_air,"Unteched throw damages and knocks down")
	b.press(arena.controls.key("jump"))
	var frames := 0
	while not b.can_act() and frames < 150:
		b.tick(Rules.FRAME,false)
		frames += 1
	check(frames < 150 and b.throw_protection > 0,"Quick rise ends in an actionable state with throw protection")
	before = b.hp
	b.receive({"damage":50,"throw":true},a)
	check(b.hp == before,"Wake-up throw protection rejects immediate throw")
	b.receive({"damage":50},a)
	check(b.hp < before,"Wake-up is strike-vulnerable: meaty attacks remain possible")
	fresh()
	b.receive({"damage":50,"knockdown":true},a)
	b.press(arena.controls.key("right"))
	var x: float = b.position.x
	for i in range(110): b.tick(Rules.FRAME,false)
	check(b.position.x > x+50 and b.can_act(),"Backward recovery changes position and completes")
	fresh()
	b.position.x = 950
	a.throw_move()
	a.tick(8*Rules.FRAME,false)
	check(b.grabbed.is_empty() and a.phase_name() == "RECOVERY","Whiffed throw leaves punishable recovery")
	fresh()
	a.press(arena.controls.key("right"))
	a.tick(6*Rules.FRAME,true)
	a.press(arena.controls.key("right"))
	a.tick(Rules.FRAME,true)
	check(a.dash_time > 0 and a.velocity.x > arena.R.SPEED[a.kind] and not a.blocking,"Double forward starts a committed dash")
	fresh()
	a.press(arena.controls.key("left"))
	a.tick(6*Rules.FRAME,true)
	a.press(arena.controls.key("left"))
	check(a.dash_time > 0 and a.throw_protection > 0 and a.invulnerable == 0,"Backdash evades throws briefly but not strikes")
	fresh()
	a.press(arena.controls.key("jump"))
	check(a.grounded and a.prejump > 0,"Jump has a real prejump phase")
	a.tick(4*Rules.FRAME,true)
	check(not a.grounded and a.velocity.y < 0,"Jump launches after prejump")
	fresh()
	a.special(0,false)
	check(arena.projectiles.is_empty(),"Projectile cannot spawn before startup")
	a.tick(12*Rules.FRAME,false)
	check(arena.projectiles.size() == 1,"Projectile appears at the authored startup frame")
	fresh()
	a.special(0,false)
	a.receive({"damage":40},b)
	a.tick(20*Rules.FRAME,false)
	check(arena.projectiles.is_empty(),"Interrupting startup cancels deferred projectile")
	fresh()
	b.crouching = true
	check(b.hurt_box().size.y == 90,"Crouching changes the real hurtbox")
	arena.combat_debug.show_boxes = true
	check(arena.combat_debug.show_frames,"Training frame display is enabled")
	fresh()
	b.blocking = true
	b.receive({"damage":40},a)
	b.tick(Rules.FRAME,false)
	before = b.hp
	b.receive({"damage":40},a)
	check(b.stun_kind == "block" and before-b.hp < 5,"CPU and dummy retain guard through blockstun")
	fresh()
	b.controlled_now = true
	arena.controls.held[arena.controls.key("right")] = true
	arena.controls.held[arena.controls.key("crouch")] = true
	before = b.hp
	b.receive({"damage":50,"low":true},a)
	check(before-b.hp < 5,"Crouch-back blocks a low")
	b.receive({"damage":50,"air":true},a)
	check(b.stun_kind == "hit","An overhead defeats crouch-block during pressure")
	fresh()
	a.press(arena.controls.key("throw"))
	b.press(arena.controls.key("throw"))
	for i in range(5):
		a.tick(Rules.FRAME,false)
		b.tick(Rules.FRAME,false)
	check(a.hp == arena.R.HP[a.kind] and b.hp == arena.R.HP[b.kind] and b.last_contact.get("result","") == "THROW TECH","Simultaneous ordinary throws tech")
	fresh()
	a.throw_move()
	a.tick(5*Rules.FRAME,false)
	b.tick(6*Rules.FRAME,false)
	b.press(arena.controls.key("throw"))
	check(b.grabbed.is_empty() and b.hp == arena.R.HP[b.kind],"Last legal throw-tech frame succeeds")
	fresh()
	a.throw_move()
	a.tick(5*Rules.FRAME,false)
	b.tick(7*Rules.FRAME,false)
	before = b.hp
	b.press(arena.controls.key("throw"))
	check(before < arena.R.HP[b.kind] and b.knockdown_air,"Late throw-tech cannot erase committed damage")
	fresh(4,0)
	a.meter = 3
	a.super_move()
	arena.cinematic = 0
	a.tick(12*Rules.FRAME,false)
	check(b.grabbed.is_empty() and b.hp < arena.R.HP[b.kind],"Command CA grab is not an ordinary techable throw")
	fresh()
	a.press(arena.controls.key("left"))
	a.tick(6*Rules.FRAME,true)
	a.press(arena.controls.key("left"))
	before = a.hp
	a.receive({"damage":40},b)
	check(a.hp < before and a.dash_time == 0,"A strike can punish a backdash")
	fresh()
	b.position.x = 490
	arena.controls.held[arena.controls.key("left")] = true
	before = a.hp
	a.receive({"damage":50},b)
	check(a.hp < before,"Holding old back must not auto-block a cross-up")
	fresh()
	b.receive({"damage":40},a)
	before = b.hp
	b.receive({"damage":50,"throw":true},a)
	check(b.hp == before,"Normal throws cannot grab through hitstun")
	fresh()
	a.position.x = 1040
	b.position.x = 1080
	arena.resolve_overlap()
	check(b.position.x == 1080 and absf(b.position.x-a.position.x) >= 105-.001,"Corner pushboxes cannot overlap or escape the wall")
	check(is_equal_approx(a.push_box().end.x,b.push_box().position.x),"Displayed pushboxes match corner separation")
	fresh()
	b.position.x = 950
	a.special(1,false)
	while a.active > Rules.EPS: a.tick(Rules.FRAME,false)
	var serial: int = a.action_serial
	a.meter = 3
	a.special(1,true)
	check(a.action_serial == serial and a.meter == 3,"EX correction cannot bypass a whiffed special's recovery")
	fresh()
	a.cooldown = 3*Rules.FRAME
	a.press(arena.controls.key("jump"))
	a.tick(3*Rules.FRAME,true)
	check(a.prejump > 0,"Jump input survives the last recovery frames")
	fresh()
	a.action_type = "special"
	a.cooldown = 3*Rules.FRAME
	a.press(arena.controls.key("skill2"))
	a.tick(3*Rules.FRAME,true)
	check(a.action_serial == 1 and a.attack_startup > 0,"Special-to-special input buffers without canceling recovery")
	if failures > 0:
		print("COMBAT RULES FAILED: %d failures" % failures)
		quit(1)
		return
	print("COMBAT RULES PASS: %d checks / guard continuity / recovery punish / reversal buffer / phases and real boxes / throw tech / wakeup / dash / jump / projectile startup" % checks)
	if "--capture-combat" in OS.get_cmdline_user_args():
		fresh()
		arena.combo_help = false
		a.normal(1,false)
		a.tick(6*Rules.FRAME,false)
		arena.banner_time = 0
		arena.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/stages/combat_rules.png")
	arena.queue_free()
	await process_frame
	await create_timer(.1).timeout
	quit()
