extends Node2D

const PixelAnimator = preload("res://scripts/pixel_animator.gd")
var visual: Node2D

const Rules = preload("res://scripts/combat_rules.gd")
const R = preload("res://scripts/roster.gd")
var arena: Node2D
var kind := 0
var side := 0
var v_meter := 100.0
var trigger_time := 0.0
var charging := false
var charge := 0.0
var charge_bonus := 1.0
var armor := 0.0
var shield_guard := 0.0
var cancel_window := 0.0
var action_type := "idle"
var action_rank := -1
var action_serial := 0
var confirmed_serial := -1
var buffered: Dictionary = {}
var buffer_time := 0.0
var juggle_count := 0
var low_profile := 0.0
var slam_pending := false
var slam_ex := false
var hp := 900.0
var meter := 0.0
var facing := 1.0
var velocity := Vector2.ZERO
var grounded := true
var crouching := false
var blocking := false
var stun := 0.0
var cooldown := 0.0
var active := 0.0
var v_time := 0.0
var v_cooldown := 0.0
var horns := 0.0
var guard_time := 0.0
var counter_startup := 0.0
var attack_startup := 0.0
var invulnerable := 0.0
var flash := 0.0
var attack: Dictionary = {}
var frame_data: Dictionary = {}
var stun_kind := ""
var controlled_now := false
var contact_window := 0.0
var pending_spawn: Dictionary = {}
var last_contact: Dictionary = {}
var grabbed: Dictionary = {}
var grab_lock := 0.0
var last_throw_pressed := -100.0
var throw_protection := 0.0
var knockdown_air := false
var down_time := 0.0
var rising_time := 0.0
var wake_choice := "normal"
var dash_time := 0.0
var dash_direction := 0.0
var last_tap: Dictionary = {}
var prejump := 0.0
var jump_queued := false
var connected := false
var hit_interval := 0.0
var remaining_hits := 0
var jumps := 0
var animation := 0.0
var motion: Array = []
var last_dir := 5
var clock := 0.0
var last_heavy := -10.0
var last_heavy_kick := -10.0
var last_special_at := -10.0
var last_special_move := 0
var ai_time := 0.4
var label := ""
var label_time := 0.0

func configure(owner_arena: Node2D, character: int, team: int) -> void:
	arena = owner_arena
	kind = character
	side = team
	controlled_now = team == 0
	hp = R.HP[kind]
	position = Vector2(320 if side == 0 else 832, 532)
	facing = 1 if side == 0 else -1
	z_index = 3
	visual = PixelAnimator.new()
	visual.fighter = self
	add_child(visual)

func can_act() -> bool:
	return hp > 0 and stun <= Rules.EPS and active <= Rules.EPS and cooldown <= Rules.EPS and down_time <= Rules.EPS and rising_time <= Rules.EPS and not knockdown_air and grabbed.is_empty() and grab_lock <= Rules.EPS and dash_time <= Rules.EPS and prejump <= Rules.EPS

func guard_available() -> bool:
	if hp <= 0 or not grounded or knockdown_air or down_time > 0 or rising_time > 0 or grab_lock > 0 or not grabbed.is_empty() or dash_time > 0 or prejump > 0: return false
	if stun > Rules.EPS: return stun_kind == "block"
	return (active <= Rules.EPS and cooldown <= Rules.EPS) or guard_time > 0

func refresh_defense(incoming_facing := 0.0) -> void:
	if not guard_available():
		blocking = false
		return
	crouching = arena.controls.pressed("crouch")
	var x := float(arena.controls.pressed("right"))-float(arena.controls.pressed("left"))
	blocking = x*(facing if incoming_facing == 0 else incoming_facing) < 0 or guard_time > 0

func strike_live() -> bool:
	return not attack.is_empty() and active > Rules.EPS and attack_startup <= Rules.EPS and contact_window > Rules.EPS and stun <= Rules.EPS and down_time <= 0 and rising_time <= 0 and not knockdown_air

func hurt_box() -> Rect2:
	if hp <= 0 or down_time > 0 or rising_time > 0 or not grabbed.is_empty(): return Rect2(position,Vector2.ZERO)
	var width: float = Rules.HURT_WIDTH[kind]
	var height: float = 90.0 if crouching or low_profile > 0 else Rules.HURT_HEIGHT[kind]
	return Rect2(position+Vector2(-width*.5,-height),Vector2(width,height))

func push_box() -> Rect2:
	return Rect2(position-Vector2(Rules.PUSH_WIDTH[kind]*.5,100),Vector2(Rules.PUSH_WIDTH[kind],100))

func hit_box() -> Rect2:
	if attack.is_empty(): return Rect2(position,Vector2.ZERO)
	var reach := float(attack.get("range",95))
	var top := -130.0
	var bottom := -44.0
	if attack.get("low",false):
		top = -36
		bottom = 4
	elif attack.get("throw",false):
		top = -110
		bottom = -15
	elif attack.get("special",false) or attack.get("ca",false) or attack.has("height"):
		top = -float(attack.get("height",120))
		bottom = 18
	elif attack.get("kick",false):
		top = -105
		bottom = -20
	var x := 18.0 if facing > 0 else -reach
	return Rect2(position+Vector2(x,top),Vector2(maxf(0,reach-18),bottom-top))

func throw_immune(super_grab := false) -> bool:
	return not grounded or (stun > Rules.EPS and not super_grab) or down_time > 0 or rising_time > 0 or knockdown_air or throw_protection > Rules.EPS or not grabbed.is_empty()

func tech_throw(source: Node2D) -> void:
	for fighter in [self,source]:
		fighter.grabbed.clear()
		fighter.grab_lock = 0
		fighter.active = 0
		fighter.attack.clear()
		fighter.pending_spawn.clear()
		fighter.buffered.clear()
		fighter.stun = 0
		fighter.cooldown = 12*Rules.FRAME
		fighter.throw_protection = 6*Rules.FRAME
		fighter.velocity.x = -fighter.facing*180
		fighter.last_contact = {"result":"THROW TECH","advantage":0,"projectile":false}
	arena.announce("拆投 · THROW TECH",Color("93e6e9"))
	arena.combat_audio.play_clip("block",0)

func try_dash(action: String) -> void:
	if not grounded or not can_act(): return
	var previous := float(last_tap.get(action,-100.0))
	last_tap[action] = clock
	if clock-previous > 12*Rules.FRAME: return
	last_tap.clear()
	var direction := -1.0 if action == "left" else 1.0
	var forward := direction*facing > 0
	dash_time = (18 if forward else 22)*Rules.FRAME
	dash_direction = direction*(R.SPEED[kind]*1.6 if forward else 340)
	blocking = false
	if not forward: throw_protection = 6*Rules.FRAME

func begin_setplay(count: int, empowered: bool, recovery: float, trap := false) -> void:
	begin_attack({"projectile_only":true,"startup_frames":12,"active_frames":1,"recovery_frames":maxi(12,Rules.frames(recovery)-12),"range":0,"damage":0,"hitstun_frames":24 if trap else 22,"blockstun_frames":14},Rules.FRAME,recovery)
	pending_spawn = {"time":attack_startup,"count":count,"ex":empowered,"trap":trap,"flat":kind == 2 and horns > 0}

func phase_name() -> String:
	if hp <= 0: return "KO"
	if not grabbed.is_empty() or grab_lock > 0: return "GRAB / 拆投窗口"
	if knockdown_air: return "KNOCKDOWN / 击倒"
	if down_time > 0: return "DOWN / 倒地"
	if rising_time > 0: return "RISE / 起身"
	if stun > Rules.EPS: return "BLOCKSTUN" if stun_kind == "block" else "HITSTUN"
	if prejump > 0: return "PREJUMP"
	if dash_time > 0: return "DASH"
	if attack_startup > Rules.EPS and active > Rules.EPS: return "STARTUP"
	if active > Rules.EPS: return "ACTIVE" if strike_live() else ("ACTIVE GAP" if attack.get("multi",false) else "ACTION")
	if cooldown > Rules.EPS: return "RECOVERY"
	return "NEUTRAL"

func opponent() -> Node2D:
	return arena.fighters[1 - side]

func tick(dt: float, controlled: bool) -> void:
	# Large test/preview advances still visit each combat frame, never skip contact.
	var remaining := dt
	while remaining > Rules.EPS:
		var step := minf(remaining,Rules.FRAME)
		tick_step(step,controlled)
		remaining -= step

func tick_step(dt: float, controlled: bool) -> void:
	controlled_now = controlled
	var held_guard := blocking
	var was_startup := attack_startup > Rules.EPS
	var was_rising := rising_time > Rules.EPS
	clock += dt
	animation += dt
	for key in ["stun", "cooldown", "active", "v_time", "v_cooldown", "horns", "invulnerable", "flash", "label_time", "trigger_time", "armor", "cancel_window", "low_profile", "guard_time", "counter_startup", "attack_startup", "buffer_time", "shield_guard", "grab_lock", "throw_protection", "dash_time", "prejump"]:
		set(key, maxf(0.0, float(get(key)) - dt))
		if key != "buffer_time" and float(get(key)) < Rules.EPS: set(key,0.0)
	if not grabbed.is_empty():
		grabbed.time -= dt
		if grabbed.time <= Rules.EPS:
			var caught := grabbed.duplicate()
			grabbed.clear()
			var resolved: Dictionary = caught.data.duplicate()
			resolved["techable"] = false
			receive(resolved,caught.source)
		queue_redraw()
		return
	if down_time > 0:
		down_time = maxf(0,down_time-dt)
		if down_time <= Rules.EPS:
			rising_time = 6*Rules.FRAME
			if wake_choice == "back": position.x = clampf(position.x-facing*68,72,1080)
	elif rising_time > 0:
		rising_time = maxf(0,rising_time-dt)
	if down_time < Rules.EPS: down_time = 0
	if rising_time < Rules.EPS: rising_time = 0
	if was_rising and rising_time <= Rules.EPS:
		throw_protection = Rules.WAKE_THROW_PROTECTION*Rules.FRAME
		stun = 0
		cooldown = 0
		wake_choice = "normal"
	if prejump <= Rules.EPS and grounded and jump_queued:
		jump_queued = false
		grounded = false
		jumps = 1
		velocity.y = -660 if kind == 5 and trigger_time > 0 else -540
	consume_buffer()
	if not was_startup and attack_startup <= Rules.EPS: contact_window = maxf(0,contact_window-dt)
	if not pending_spawn.is_empty():
		pending_spawn.time -= dt
		if pending_spawn.time <= Rules.EPS:
			var emission := pending_spawn.duplicate()
			pending_spawn.clear()
			for n in range(emission.count):
				if emission.trap: arena.place_cat_trap(self,n*43,emission.ex)
				else: arena.spawn_projectile(self,n*55,emission.ex)
				if kind == 2:
					var shot: Dictionary = arena.projectiles[-1]
					shot.flat = emission.flat
					shot.damage = (12 if emission.flat else (28 if emission.ex else 20)) if emission.trap else (32 if emission.flat else (80 if emission.ex else 65))
	if charging and kind == 4:
		charge = minf(2.5, charge + dt)
	v_meter = minf(100, v_meter + dt * 3.0)
	if active <= 0:
		attack = {}
	if attack_startup <= Rules.EPS: hit_interval -= dt
	if remaining_hits > 0 and hit_interval <= Rules.EPS and attack_startup <= Rules.EPS and not attack.is_empty():
		connected = false
		contact_window = 3*Rules.FRAME
		remaining_hits -= 1
		hit_interval = 0.12
		attack.push = 600 if remaining_hits == 0 else 25
		attack.knockdown = remaining_hits == 0
		attack["finisher"] = remaining_hits == 0
		if remaining_hits == 0 and attack.get("ca",false): attack.damage = float(attack.damage)*1.5
		if attack.get("special",false) and kind in [3,5]:
			velocity.x = facing*(540 if kind == 3 else 420)
			if kind == 5 or (kind == 3 and last_special_move == 1):
				grounded = false
				velocity.y = -160
		arena.fx.follow_strike(self)
	if grounded and can_act():
		facing = 1 if opponent().position.x > position.x else -1
	if stun <= Rules.EPS and active <= Rules.EPS: crouching = false
	blocking = false
	if controlled:
		player_input(dt)
	elif not arena.training:
		if stun > 0 and stun_kind == "block": blocking = held_guard
		ai_input(dt)
	elif stun > 0 and stun_kind == "block":
		blocking = held_guard
	if guard_time > 0 and stun <= 0 and down_time <= 0 and rising_time <= 0:
		blocking = true
	if dash_time > Rules.EPS:
		velocity.x = dash_direction
	elif down_time > Rules.EPS or rising_time > Rules.EPS or grab_lock > Rules.EPS or prejump > Rules.EPS:
		velocity.x = 0
	elif stun > 0:
		velocity.x = move_toward(velocity.x, 0, 650 * dt)
	elif active <= 0:
		velocity.x = move_toward(velocity.x, 0, 1200 * dt)
	if not grounded:
		velocity.y += 1200 * dt
	position += velocity * dt
	position.x = clampf(position.x, 72, 1080)
	if position.y >= 532:
		position.y = 532
		velocity.y = 0
		if not grounded:
			arena.fx.emit("land",position-Vector2(0,50),kind,0.32,facing,slam_pending)
			arena.combat_audio.play_clip("quake" if slam_pending else "land",1,true)
			if kind == 4: arena.home_stages.heavy(kind,position)
		if knockdown_air:
			knockdown_air = false
			down_time = (14 if wake_choice == "quick" else (24 if wake_choice == "back" else 30))*Rules.FRAME
			stun = 0
			active = 0
			cooldown = 0
			buffered.clear()
		grounded = true
		juggle_count = 0
		jumps = 0
		if slam_pending:
			slam_pending = false
			begin_attack({"damage": 150 if slam_ex else 105, "range": 210, "height": 90, "low": true, "push": 300, "knockdown": slam_ex}, 0.2, 0.6)
	if strike_live() and not connected and not attack.get("projectile_only",false):
		var enemy = opponent()
		if hit_box().intersects(enemy.hurt_box()):
			if not enemy.invulnerable > Rules.EPS and not (attack.get("throw",false) and enemy.throw_immune(attack.get("ca",false)) and not attack.get("grab_confirmed",false)):
				connected = true
				enemy.receive(attack,self)
	queue_redraw()

func player_input(_dt: float) -> void:
	var x := float(arena.controls.pressed("right")) - float(arena.controls.pressed("left"))
	var down: bool = arena.controls.pressed("crouch")
	var dir := 5
	if x * facing > 0: dir = 6
	if x * facing < 0: dir = 4
	if down: dir = 2 if x == 0 else (3 if x * facing > 0 else 1)
	if dir != last_dir:
		motion.append([dir, clock])
		last_dir = dir
	while not motion.is_empty() and clock - float(motion[0][1]) > 0.85:
		motion.pop_front()
	if down_time > 0 or rising_time > 0 or knockdown_air or not grabbed.is_empty(): return
	if stun > 0:
		if stun_kind == "block":
			crouching = down and grounded
			blocking = x*facing < 0 and grounded
		return
	if not can_act():
		if kind == 0 and not grounded and active > 0 and attack.get("air",false):
			velocity.x = move_toward(velocity.x,x*R.SPEED[0],1800*_dt)
		return
	crouching = down and grounded
	blocking = x*facing < 0 and grounded
	velocity.x = 0 if crouching else x*R.SPEED[kind]*(1.45 if (kind == 0 and v_time > 0) or (kind == 3 and trigger_time > 0) else 1.0)

func press(key: int, ex_modifier := false) -> void:
	if hp <= 0: return
	var action: String = arena.controls.action_for(key)
	if action == "throw":
		last_throw_pressed = clock
		if not grabbed.is_empty():
			tech_throw(grabbed.source)
			return
	if knockdown_air or down_time > 0:
		if action == "jump":
			wake_choice = "quick"
			if down_time > 0: down_time = minf(down_time,14*Rules.FRAME)
		elif action == ("left" if facing > 0 else "right"):
			wake_choice = "back"
			if down_time > 0: down_time = minf(down_time,24*Rules.FRAME)
		return
	if stun > 0 or rising_time > 0 or grab_lock > 0 or dash_time > 0 or prejump > 0:
		if action in ["light","medium","heavy","kick_light","kick_medium","kick_heavy","skill1","skill2","skill3","super","throw","v","jump"]:
			queue_action("press",key,ex_modifier)
		return
	var late_recovery := maxf(active,cooldown) > Rules.EPS and maxf(active,cooldown) <= Rules.INPUT_BUFFER+Rules.EPS
	var frog_cancel := kind == 3 and action == "v" and cancel_window > 0 and v_meter >= 35
	if late_recovery and not frog_cancel and action in ["skill1","skill2","skill3","jump","throw","v","trigger"]:
		var target := "special" if action.begins_with("skill") else action
		if not can_cancel(target):
			queue_action("press",key,ex_modifier)
			return
	if action in ["left","right"]:
		try_dash(action)
		return
	if action in ["skill1","skill2","skill3"]:
		special(["skill1","skill2","skill3"].find(action),ex_modifier or arena.controls.pressed("ex"))
		return
	if action == "super":
		super_move()
		return
	if action == "jump":
		if can_act() and (grounded or (kind == 0 and v_time > 0 and jumps < 2)):
			if grounded:
				prejump = 4*Rules.FRAME
				jump_queued = true
				velocity.x = 0
			else:
				jumps += 1
				velocity.y = -540
		return
	if action == "trigger":
		trigger()
		return
	if action == "v":
		v_skill()
		return
	if action == "taunt" and cooldown <= 0:
		say(R.TAUNT[kind])
		visual.play("taunt",0.8)
		cooldown = 0.65
		arena.sound(kind, "taunt")
		return
	if action == "throw":
		throw_move()
		return
	var attacks := ["light","medium","heavy","kick_light","kick_medium","kick_heavy"]
	var index := attacks.find(action)
	if index < 0: return
	var kick := index >= 3 or kind == 5
	var strength := index % 3
	var ex: bool = ex_modifier or arena.controls.pressed("ex")
	if strength == 2:
		var previous := last_heavy_kick if kick else last_heavy
		ex = ex or clock - previous < 0.28
		if kick: last_heavy_kick = clock
		else: last_heavy = clock
	if ex and strength == 2 and clock - last_special_at < 0.28:
		special(last_special_move, true)
	elif matches([2, 1, 4, 2, 1, 4] if kind == 4 else [2, 3, 6, 2, 3, 6]) and kick == (kind == 5):
		super_move()
	elif matches([6, 2, 3]) and kick == (kind == 0):
		special(1, ex)
	elif matches([2, 1, 4]) and (kick == (kind in [0,2,3]) or (ex and kind == 2)):
		special(2, ex)
	elif matches([2, 3, 6]) and kick == (kind == 5):
		special(0, ex)
	else:
		normal(strength, kick)

func matches(sequence: Array) -> bool:
	var filtered: Array = []
	for item in motion:
		if item[0] != 5:
			filtered.append(item[0])
	if filtered.size() < sequence.size(): return false
	if motion.is_empty() or clock-float(motion[-1][1]) > .18: return false
	if motion.size() >= sequence.size() and clock-float(motion[-sequence.size()][1]) > (.65 if sequence.size() > 3 else .38): return false
	return filtered.slice(filtered.size() - sequence.size()) == sequence

func say(text: String) -> void:
	label = text
	label_time = 1.5
	arena.announce(text, R.COLORS[kind])

func can_cancel(target: String, strength := -1) -> bool:
	if hp <= 0 or stun > 0 or cancel_window <= 0 or confirmed_serial != action_serial: return false
	if opponent().stun <= 0: return false
	if target == "normal": return action_type == "normal" and strength > action_rank
	if target == "special": return action_type == "normal"
	if target == "super": return action_type in ["normal","special"]
	return false

func queue_action(type: String, value := 0, option := false) -> void:
	# A short leniency window, never a stored sequence or an automatic combo.
	buffered = {"type":type,"value":value,"option":option}
	buffer_time = Rules.INPUT_BUFFER+Rules.EPS

func consume_buffer() -> void:
	if buffer_time <= 0:
		buffered.clear()
		return
	if buffered.is_empty() or stun > 0 or knockdown_air or down_time > 0 or rising_time > 0 or grab_lock > 0 or dash_time > 0 or prejump > 0: return
	var type: String = buffered.type
	if (cooldown > 0 or active > 0) and not can_cancel(type,int(buffered.value)): return
	var command := buffered.duplicate()
	buffered.clear()
	if type == "press": press(command.value,command.option)
	elif type == "normal": normal(command.value,command.option)
	elif type == "special": special(command.value,command.option)
	elif type == "super": super_move()

func cancel_into(type: String) -> void:
	var title := "CHAIN" if type == "normal" else ("SUPER CANCEL" if type == "super" else "SPECIAL CANCEL")
	arena.cancel_notice[side] = title
	arena.cancel_notice_time[side] = 1.1
	arena.fx.emit("cancel",position+Vector2(0,-70),kind,0.32,facing,type == "super")
	arena.combat_audio.play_clip("counter",0,true)
	active = 0
	cooldown = 0
	remaining_hits = 0
	pending_spawn.clear()
	attack = {}
	velocity.x *= 0.25

func start_action(type: String, rank := -1) -> void:
	action_type = type
	action_rank = rank
	action_serial += 1
	cancel_window = 0
	confirmed_serial = -1
	buffered.clear()
	pending_spawn.clear()

func normal(strength: int, kick: bool) -> void:
	if hp <= 0 or stun > 0 or knockdown_air or down_time > 0 or rising_time > 0 or grab_lock > 0: return
	if cooldown > 0 or active > 0:
		if can_cancel("normal",strength): cancel_into("normal")
		else:
			queue_action("normal",strength,kick)
			return
	start_action("normal",strength)
	var low := crouching and kick and not (kind == 5 and trigger_time > 0)
	var damage: float = [38,65,95][strength] * ([0.85,1.05,0.85,0.8,1.25,0.95][kind])
	var reach: float = [88,112,145][strength]+(20 if kick else 0)
	if kind == 3: reach = [88,110,135][strength]
	if kind == 5 and kick: reach = [160,200,235][strength]
	begin_attack({"strength": strength, "kick": kick, "damage": damage, "range": reach, "low": low, "air": not grounded or (kind == 5 and trigger_time > 0 and kick), "push": 195 if kind == 5 and kick else 45 + strength * 25, "guard_chip":0.25 if kind == 4 and strength == 2 else 0.08, "hitstun": [0.27,0.34,0.42][strength], "cancelable": true, "startup_frames": Rules.normal_startup(kind,strength), "active_frames":[3,4,5][strength], "recovery_frames":roundi([10,15,21][strength]*(.82 if kind == 3 else (1.18 if kind == 4 else 1))), "hitstun_frames":[17,22,28][strength], "blockstun_frames":[11,14,18][strength]}, 0.16 + strength * 0.06, 0.23 + strength * 0.13)
	if kind == 4:
		if strength == 2: armor = 0.12
	visual.play(("kick_" if kick else "punch_")+str(strength),cooldown)
	arena.combat_audio.play_clip("kick" if kick else "swing",strength)
	arena.fx.emit("kick" if kick else ("slash" if kind == 1 else "fist"),position+Vector2(facing*(85 if kind == 5 and kick else 35),-75),kind,0.22,facing,strength == 2)
	meter = minf(3, meter + 0.025)

func begin_attack(data: Dictionary, duration: float, recovery: float) -> void:
	attack = data.duplicate()
	attack["serial"] = action_serial
	attack["cancelable"] = action_type in ["normal","special"] or data.get("cancelable",false)
	if action_type == "special": attack["special"] = true
	if trigger_time > 0 and kind == 5: attack.damage = float(attack.get("damage", 0)) * 1.2
	if trigger_time > 0 and kind == 4: attack.range = float(attack.get("range", 95)) + 110
	if kind == 4 and data.get("special", false):
		attack.damage = float(attack.get("damage", 0)) * charge_bonus
		charge_bonus = 1.0
	frame_data = Rules.profile(action_type,data,duration,recovery)
	if kind == 3 and trigger_time > 0: frame_data.recovery = maxi(1,roundi(frame_data.recovery*.65))
	attack["hitstun"] = Rules.seconds(frame_data.hitstun)
	attack["blockstun"] = Rules.seconds(frame_data.blockstun)
	attack_startup = Rules.seconds(frame_data.startup)
	active = Rules.seconds(frame_data.startup+frame_data.active)
	cooldown = Rules.seconds(frame_data.startup+frame_data.active+frame_data.recovery)
	contact_window = Rules.seconds(mini(3,frame_data.active) if data.get("multi",false) else frame_data.active)
	blocking = false
	if visual.locked: visual.duration = cooldown
	connected = false
	remaining_hits = 0

func special(move: int, use_ex: bool) -> void:
	if hp <= 0 or stun > 0 or knockdown_air or down_time > 0 or rising_time > 0 or grab_lock > 0: return
	var upgrade := use_ex and attack_startup > Rules.EPS and not connected and clock-last_special_at < 0.28 and action_type == "special" and move == last_special_move
	if cooldown > 0 or active > 0:
		if can_cancel("special"): pass
		elif not upgrade:
			if action_type == "normal": queue_action("special",move,use_ex)
			return
	if use_ex and meter < 1:
		say("能量不足 · EX 需要 1 格")
		return
	if can_cancel("special"): cancel_into("special")
	start_action("special")
	if use_ex: meter -= 1
	last_special_at = clock if not use_ex else -10.0
	last_special_move = move
	arena.skill_fx(self,move,use_ex)
	var empowered := use_ex or (kind == 0 and v_time > 0 and move != 0)
	say(R.EX[kind][move] if use_ex else R.SPECIALS[kind][move])
	visual.play(("ex_" if use_ex else "special_")+str(move),0.85 if use_ex else 0.65)
	motion.clear()
	if kind == 0:
		penguin_special(move, empowered)
		return
	if kind == 2:
		cat_special(move, use_ex)
		return
	if kind >= 3:
		dlc_special(move, use_ex)
		return
	if move == 0 and kind != 1:
		var count := 3 if empowered else 1
		for n in range(count):
			arena.spawn_projectile(self, n * 55, empowered)
		if kind == 2: horns = 2.6
		active = 0.22
		cooldown = 0.65
	elif kind == 2 and move > 0:
		v_time = 1.5 if empowered else 0.7
		blocking = true
		cooldown = 0.6
		if move == 2:
			velocity.x = -facing * 240
			invulnerable = 0.18
	elif kind == 1 and move == 2 and empowered:
		begin_attack({"projectile_only":true,"startup_frames":4,"active_frames":40,"recovery_frames":16,"range":0,"damage":0},40*Rules.FRAME,60*Rules.FRAME)
		counter_startup = 4*Rules.FRAME
		v_time = 44*Rules.FRAME
	else:
		var reach := 155.0 if move == 2 else 115.0
		begin_attack({"multi":empowered and move == 0,"damage": 155 if empowered else 105, "range": reach, "height": 220 if move == 1 else 100, "launch": move == 1, "push": 180, "knockdown": empowered, "ex": empowered}, 0.38, 0.7)
		if kind == 1 and move == 0: shield_guard = 0.5 if empowered else 0.35
		if move == 0 or (kind == 0 and move == 1):
			velocity.x = facing * (650 if empowered else 440)
		if move == 1 and kind == 1:
			grounded = false
			velocity.y = -430
		if empowered: invulnerable = 0.22
		if empowered and move == 0:
			attack.damage = 55
			attack.push = 25
			attack.knockdown = false
			remaining_hits = 2
			hit_interval = 0.16
			frame_data.active = 37
			frame_data.recovery = 20
			active = attack_startup+Rules.seconds(37)
			cooldown = active+Rules.seconds(20)

func penguin_special(move: int, empowered: bool) -> void:
	if move == 0:
		begin_setplay(3 if empowered else 1,empowered,.44 if empowered else .42)
	elif move == 1:
		begin_attack({"damage":145 if empowered else 85,"range":125,"height":145,"push":400,"knockdown":empowered},0.45,0.72)
		low_profile = 0.38 if empowered else 0.22
		velocity.x = facing*(710 if empowered else 450)
		if empowered and not grounded: velocity.y = 330
	else:
		begin_attack({"multi":true,"damage":48,"range":145,"height":160,"air":true,"push":25},0.4,0.64)
		remaining_hits = 2 if empowered else 1
		hit_interval = 0.12
		if grounded:
			grounded = false
			jumps = 1
			velocity.y = -320
		velocity.x = facing*(290 if empowered else 210)

func cat_special(move: int, empowered: bool) -> void:
	if move == 0:
		var blunt := horns > 0
		begin_setplay(3 if empowered else 1,empowered,.8)
		horns = maxf(horns,2.6)
		if blunt: say("磨平 · 钝角气团" if not empowered else "EX · 钝角碎片")
	elif move == 1:
		begin_attack({"projectile_only":true,"startup_frames":5 if empowered else 11,"active_frames":34 if empowered else 28,"recovery_frames":12,"range":0,"damage":0},28*Rules.FRAME,51*Rules.FRAME)
		counter_startup = attack_startup
		v_time = active
	else:
		begin_setplay(3 if empowered else 1,empowered,.7,true)
		horns = maxf(horns,2.6)
		guard_time = 0.5
		velocity.x = -facing*235
		v_time = 0.45 if empowered else 0.0
		counter_startup = 0.08 if empowered else 0.0

func dlc_special(move: int, empowered: bool) -> void:
	if kind == 4:
		charge_bonus = 1.0 + charge * 0.35
		charging = false
		charge = 0
	if (kind == 3 and move == 0 and not empowered) or (kind == 5 and move == 2):
		begin_setplay(1,empowered,.7)
		return
	if kind == 3 and move == 2:
		grounded = false
		velocity = Vector2(facing * 250,-550)
		slam_pending = true
		slam_ex = empowered
		active = 8*Rules.FRAME
		cooldown = 18*Rules.FRAME
		frame_data = {"startup":8,"active":0,"recovery":10,"hitstun":18,"blockstun":12}
		return
	var damage := 125.0 if kind == 4 else 95.0
	var reach := 230.0 if kind == 5 else (280.0 if kind == 4 and move == 2 else 120.0)
	var multi := empowered and ((kind == 3 and move < 2) or (kind == 4 and move == 2) or (kind == 5 and move == 0))
	begin_attack({"multi":multi,"damage": 62.0 if multi else damage * (1.45 if empowered else 1.0), "range":reach, "height":220 if move == 1 else 100, "launch": move == 1 and kind in [4,5], "low": kind == 4 and move == 2, "push":25 if multi else 340, "special":true, "ex":empowered, "cancelable":true, "knockdown":empowered and not multi},0.65 if multi else 0.35,1.0 if empowered else 0.65)
	if multi:
		remaining_hits = 2
		hit_interval = 0.18
	if (kind == 4 and move == 0) or (kind == 3 and move < 2) or (kind == 5 and (move == 0 or empowered)):
		velocity.x = facing * (590 if empowered else 430)
	if kind == 3 and (move == 1 or empowered): low_profile = 0.55
	if empowered and ((kind == 4 and move == 0) or (kind == 5 and move == 1)): armor = 0.55
	if move == 1 and kind in [4,5] and not empowered:
		grounded = false
		velocity.y = -410

func v_skill() -> void:
	if kind == 3:
		if cancel_window > 0 and v_meter >= 35:
			v_meter -= 35
			active = 0
			cooldown = 0
			attack = {}
			remaining_hits = 0
			velocity.x = 0
			cancel_window = 0
			say("狂笑取消 · 哈哈哈哈！")
			visual.play("v",0.2)
			arena.sound(kind, "v")
		return
	if kind == 4:
		if not can_act(): return
		charging = not charging
		say("妈 ——（移动蓄力中）" if charging else "蓄力保留 · %.1f" % charge)
		return
	if v_cooldown > 0 or not can_act(): return
	v_time = 3.5 if kind == 0 else 1.0
	v_cooldown = 7.0
	say(R.V[kind])
	visual.play("v",0.7)
	arena.sound(kind, "v")

func trigger() -> void:
	if kind < 3 or trigger_time > 0 or v_meter < 100 or not can_act(): return
	v_meter = 0
	trigger_time = 8.0
	say(R.TRIGGERS[kind])
	visual.play("trigger",0.8)
	arena.sound(kind, "trigger")

func super_move() -> void:
	if meter < 3:
		say("CA 需要 3 格能量")
		return
	if hp <= 0 or stun > 0: return
	if active > 0 or cooldown > 0:
		if can_cancel("super"): cancel_into("super")
		else:
			queue_action("super")
			return
	elif can_cancel("super"): cancel_into("super")
	start_action("super")
	meter = 0
	motion.clear()
	say(R.CA[kind])
	invulnerable = 0.9
	arena.begin_ca(kind,side)
	begin_attack({"multi":true,"startup_frames":12,"recovery_frames":30,"damage": 55, "range": 1200 if kind != 1 else 450, "height": 600, "push": 25, "knockdown": false, "ca": true}, 0.85, 1.25)
	remaining_hits = 5
	hit_interval = 0.12
	if kind in [1,3]: velocity.x = facing * 680
	if kind == 4:
		attack.range = 170
		attack["throw"] = true
		attack.damage = 70
	if kind == 5:
		grounded = false
		velocity.y = -300
	visual.play("ca",arena.ca_duration+cooldown)
	arena.fx.emit("ca",position+Vector2(0,-75),kind,arena.ca_duration+0.8,facing,true)
	arena.sound(kind, "ca")

func throw_move() -> void:
	if not can_act() or not grounded: return
	start_action("throw")
	say("投技")
	begin_attack({"startup_frames":Rules.THROW_STARTUP,"active_frames":Rules.THROW_ACTIVE,"recovery_frames":Rules.THROW_RECOVERY,"techable":true,"damage": 150 if kind == 4 else 110, "range": 68 if kind == 4 else 52, "height": 70, "throw": true, "push": 430, "knockdown": true}, 0.15, 0.7)
	visual.play("throw",cooldown)

func receive(data: Dictionary, source: Node2D) -> void:
	var linked := stun > 0 and stun_kind == "hit"
	var hit_note := "COUNTER HIT" if active > 0 else ("PUNISH" if cooldown > 0 else "")
	if data.get("throw",false): hit_note = "THROW"
	if hp <= 0 or invulnerable > 0 or down_time > 0 or rising_time > 0 or not grabbed.is_empty(): return
	if controlled_now: refresh_defense(1.0 if source.position.x > position.x else -1.0)
	if data.get("throw",false) and throw_immune(data.get("ca",false)) and not data.get("grab_confirmed",false): return
	if data.get("throw",false) and data.get("techable",false):
		if clock-last_throw_pressed <= 3*Rules.FRAME or (action_type == "throw" and active > 0):
			tech_throw(source)
			return
		grabbed = {"source":source,"data":data.duplicate(),"time":Rules.THROW_TECH*Rules.FRAME}
		visual.play("hit",Rules.THROW_TECH*Rules.FRAME)
		active = 0
		attack.clear()
		pending_spawn.clear()
		velocity = Vector2.ZERO
		source.grab_lock = Rules.THROW_TECH*Rules.FRAME
		source.active = 0
		source.attack.clear()
		return
	if shield_guard > 0 and data.get("projectile",false) and not data.get("low",false):
		meter = minf(3,meter+0.08)
		arena.hit_effect(position+Vector2(facing*30,-70),true,0,source.side,false,"SHIELD",data)
		return
	if low_profile > 0 and data.get("projectile", false) and not data.get("low",false): return
	if data.get("throw",false) and data.get("ca",false): source.attack["grab_confirmed"] = true
	var is_throw: bool = data.get("throw", false)
	if is_throw and not grounded: return
	if not grounded and stun > 0 and juggle_count >= 4 and not data.get("ca",false): return
	if v_time > 0 and counter_startup <= 0 and kind in [1,2,5] and not is_throw and not data.get("counter", false) and not (kind == 1 and data.get("low", false)):
		var blunt_counter := kind == 2 and horns > 0
		v_time = 0
		counter_startup = 0
		if kind == 2: horns = 3.0
		say("盾反斩！" if kind == 1 else ("肥嘟嘟格挡 · 反击！" if kind == 5 else "磨平棱角 · 弹射反击！"))
		visual.play("v",0.65)
		start_action("special")
		begin_attack({"startup_frames":4,"active_frames":3,"recovery_frames":18,"range":170,"height":140,"damage":120 if blunt_counter else 170,"counter":true,"push":420,"knockdown":true},3*Rules.FRAME,25*Rules.FRAME)
		meter = minf(3, meter + (0.65 if blunt_counter else 0.45))
		return
	var guarded := blocking and guard_available() and grounded and not is_throw
	if data.get("low", false) and not crouching: guarded = false
	if data.get("air", false) and crouching: guarded = false
	var damage := float(data.get("damage", 50))
	# Cyclic advantage: penguin > dog > cat > penguin. Readable, modest 8%.
	if source.kind < 3 and kind < 3 and (source.kind + 1) % 3 == kind: damage *= 1.08
	if kind == 2 and horns > 0: damage *= 0.9
	if (kind == 3 and trigger_time > 0) or charging: damage *= 1.25
	if kind == 4 and charging:
		charging = false
		charge = 0
	if linked and not guarded:
		damage *= maxf(0.5 if data.get("ca",false) else 0.35,1.0-int(arena.combo[source.side])*0.085)
	if guarded: damage *= float(data.get("guard_chip",0.08))
	hp = maxf(0, hp - damage)
	meter = minf(3, meter + (0.24 if kind == 2 else 0.12))
	if not guarded:
		v_meter = minf(100, v_meter + 12)
		source.v_meter = minf(100,source.v_meter + (0 if source.kind == 3 and data.get("ca",false) else (4 if source.kind == 3 else 8)))
		if data.get("cancelable", false) and int(data.get("serial",-1)) == source.action_serial:
			source.cancel_window = 0.3
			source.confirmed_serial = source.action_serial
	source.meter = minf(3, source.meter + (0.08 if guarded else 0.16))
	stun = float(data.get("blockstun",12*Rules.FRAME)) if guarded else float(data.get("hitstun",18*Rules.FRAME))
	stun_kind = "block" if guarded else "hit"
	source.last_contact = {"result":"BLOCK" if guarded else "HIT","advantage":Rules.frames(stun)-Rules.frames(source.cooldown),"projectile":data.get("projectile",false)}
	if armor > 0 and not is_throw:
		stun = 0
		flash = 0.12
		arena.hit_effect(position + Vector2(0,-70), false, damage,source.side,linked,hit_note,data)
		if hp <= 0: arena.finish(source.side)
		return
	active = 0
	cooldown = 0
	attack = {}
	pending_spawn.clear()
	buffered.clear()
	dash_time = 0
	prejump = 0
	jump_queued = false
	if not guarded:
		guard_time = 0
		shield_guard = 0
	if kind in [1,2,5] and not guarded:
		v_time = 0
		counter_startup = 0
	slam_pending = false
	velocity.x = source.facing * float(data.get("push", 180)) * (0.35 if guarded else 1.0)
	if not guarded and data.get("knockdown",false):
		knockdown_air = true
		wake_choice = "normal"
	if not guarded and (data.get("launch",false) or data.get("knockdown",false)):
		velocity.y = -370 if data.get("launch",false) else -260
		grounded = false
	elif not guarded and not grounded and stun > 0:
		velocity.y = minf(velocity.y,-155)
	if not grounded and not guarded: juggle_count += 1
	flash = 0.12
	arena.hit_effect(position + Vector2(0, -70), guarded, damage,source.side,linked,hit_note,data)
	visual.play("ko" if hp <= 0 else ("block" if guarded else "hit"),0.8 if hp <= 0 else 0.28)
	if hp <= 0:
		arena.finish(source.side)

func preferred_special(distance: float) -> int:
	var airborne: bool = not opponent().grounded
	match kind:
		0: return 2 if distance < 150 or (airborne and distance < 210) else 0
		1: return 1 if airborne else (0 if distance > 145 else 2)
		2: return 1 if distance < 155 and opponent().active > 0 else (2 if distance < 190 or arena.cat_trap_count(side) == 0 else 0)
		3: return 2 if airborne and distance < 170 else 1
		4: return 1 if airborne else (0 if distance > 190 else 2)
		5: return 1 if airborne and distance < 220 else (2 if distance > 320 else 0)
	return 0

func ai_input(dt: float) -> void:
	var dist := absf(opponent().position.x-position.x)
	if kind == 3 and action_type == "special" and cancel_window > 0 and v_meter >= 35 and randf() < 0.14:
		v_skill()
		normal(0,false)
	if stun <= 0 and cancel_window > 0 and randf() < (0.3 if kind == 3 else 0.07):
		if can_cancel("normal",action_rank+1) and action_rank < 2: normal(action_rank+1,kind == 5)
		elif can_cancel("special"): special(preferred_special(dist),false)
		elif can_cancel("super") and meter >= 3 and not arena.demo_mode: super_move()
	if not can_act(): return
	if kind >= 3 and v_meter >= 100: trigger()
	if kind == 4 and not charging and charge <= 0 and randf() < 0.03: v_skill()
	blocking = opponent().active > 0 and dist < 220 and randf() < (0.9 if kind == 1 else 0.55)
	crouching = blocking and opponent().crouching
	if dist > R.SPACING_MAX[kind]: velocity.x = facing*R.SPEED[kind]*0.8
	elif dist < R.SPACING_MIN[kind]: velocity.x = -facing*R.SPEED[kind]*0.8
	else: velocity.x = move_toward(velocity.x,0,1400*dt)
	ai_time -= dt
	if ai_time > 0: return
	ai_time = randf_range(0.2 if kind == 3 else 0.3,0.4 if kind == 3 else 0.65)/arena.difficulty
	if blocking and kind in [1,2,5] and v_cooldown <= 0:
		v_skill()
	elif meter >= 3 and dist < (160 if kind == 4 else 400) and not arena.demo_mode:
		super_move()
	elif kind == 4 and dist < 95 and randf() < 0.3:
		throw_move()
	elif kind == 3 and dist < 110 and randf() < 0.8:
		normal(1 if dist > 82 else 0,false)
	elif kind == 5 and dist >= 150 and dist <= 235 and randf() < 0.65:
		normal(1 if dist < 195 else 2,true)
	elif kind == 1 and dist < 140 and randf() < 0.55:
		normal(2 if dist > 110 else 1,false)
	elif kind == 4 and dist < 145 and randf() < 0.5:
		normal(2,false)
	else:
		special(preferred_special(dist),meter >= 1 and randf() < 0.25)

func _draw() -> void:
	if visual != null and visual.texture != null:
		draw_ellipse_shadow()
		if v_time > 0 or trigger_time > 0:
			draw_arc(Vector2(0,-70),82,0,TAU,16,R.COLORS[kind],3)
		if blocking:
			draw_arc(Vector2(facing*45,-72),60,-1.5 if facing > 0 else 1.6,1.5 if facing > 0 else 4.7,10,Color("73b8ff"),4)
		return
	var bob := roundf(sin(animation * 8) * 2) if grounded and active <= 0 else 0.0
	var color: Color = R.COLORS[kind]
	if flash > 0: color = Color.WHITE
	draw_set_transform(Vector2(0, bob), 0, Vector2(facing, 1))
	draw_ellipse_shadow()
	if hp <= 0:
		draw_set_transform(Vector2(0, -12), -facing * 1.35, Vector2(facing, 1))
	var squish := 16.0 if crouching else 0.0
	var roll := animation * 18 if kind == 3 and low_profile > 0 and active > 0 else 0.0
	var pivot := Vector2(0, squish + bob - 70) + Vector2(0,70).rotated(roll)
	draw_set_transform(pivot, roll, Vector2(facing, 1 - squish / 160))
	if v_time > 0:
		draw_arc(Vector2(0, -66), 76, 0, TAU, 14, Color(color, 0.65), 4)
	if kind == 0:
		poly([Vector2(-37,-22),Vector2(-48,-69),Vector2(-33,-119),Vector2(11,-131),Vector2(40,-105),Vector2(48,-47),Vector2(26,-13)], Color("151c29"))
		poly([Vector2(-19,-23),Vector2(-29,-70),Vector2(-16,-103),Vector2(17,-100),Vector2(30,-57),Vector2(19,-20)], color.lightened(0.6))
		poly([Vector2(17,-101),Vector2(52,-92),Vector2(19,-79)], Color("edb843"))
		draw_rect(Rect2(10,-113,8,9), Color.BLACK)
		draw_rect(Rect2(-33,-15,27,13),Color("d99c35"))
		draw_rect(Rect2(10,-15,30,13),Color("d99c35"))
		poly([Vector2(-32,-84),Vector2(-57,-41),Vector2(-24,-57)], Color("293442"))
	elif kind == 1:
		poly([Vector2(-39,-12),Vector2(-44,-88),Vector2(-20,-107),Vector2(27,-100),Vector2(44,-16)], Color("6c6551"))
		poly([Vector2(-31,-99),Vector2(-39,-146),Vector2(-17,-137),Vector2(14,-145),Vector2(43,-121),Vector2(55,-103),Vector2(13,-94)], color)
		poly([Vector2(-34,-142),Vector2(-54,-125),Vector2(-32,-111)], Color("4a3a32"))
		draw_line(Vector2(12,-125),Vector2(30,-120),Color.BLACK,5)
		draw_rect(Rect2(43,-111,10,7),Color.BLACK)
		draw_rect(Rect2(-35,-18,24,17),Color("403c38"))
		draw_rect(Rect2(16,-18,25,17),Color("403c38"))
		draw_circle(Vector2(-26,-65),33,Color("363e46"))
		draw_arc(Vector2(-26,-65),33,0,TAU,8,Color("a8aba1"),6)
		draw_line(Vector2(-46,-65),Vector2(-7,-65),Color("828375"),4)
		var extension := 52.0 if active > 0 else 0.0
		poly([Vector2(31,-72),Vector2(64+extension,-118),Vector2(73+extension,-115),Vector2(46,-55)],Color("d6e0da"))
		draw_line(Vector2(26,-75),Vector2(53,-54),Color("c89955"),7)
	elif kind == 2:
		poly([Vector2(-45,-12),Vector2(-53,-61),Vector2(-35,-105),Vector2(-22,-123),Vector2(29,-119),Vector2(49,-87),Vector2(53,-22),Vector2(27,-7)], color.lightened(0.15))
		poly([Vector2(-39,-75),Vector2(-15,-91),Vector2(35,-80),Vector2(40,-30),Vector2(14,-18),Vector2(-31,-25)],Color("d6d4d5"))
		if horns <= 0:
			poly([Vector2(-38,-105),Vector2(-47,-154),Vector2(-4,-120)],Color("e8a92d"))
			poly([Vector2(5,-120),Vector2(44,-151),Vector2(38,-99)],Color("f0b438"))
		else:
			draw_line(Vector2(-38,-119),Vector2(-9,-119),Color("a6a2ac"),5)
			draw_line(Vector2(12,-120),Vector2(38,-120),Color("a6a2ac"),5)
		draw_line(Vector2(-23,-98),Vector2(-7,-97),Color("3a3542"),5)
		draw_line(Vector2(14,-97),Vector2(30,-99),Color("3a3542"),5)
		draw_line(Vector2(1,-84),Vector2(11,-84),Color("766773"),3)
		draw_rect(Rect2(-43,-12,30,12),Color("adaab5"))
		draw_rect(Rect2(19,-12,30,12),Color("adaab5"))
	else:
		var body_width := 65.0 if kind == 4 else 56.0
		poly([Vector2(-body_width,-15),Vector2(-body_width-5,-75),Vector2(-35,-122),Vector2(28,-128),Vector2(body_width,-80),Vector2(body_width,-18)],color)
		draw_circle(Vector2(4,-57),42,Color("f2df87"))
		for direction in [-1,1]:
			draw_rect(Rect2(direction*42-12,-15,34,15),color.darkened(0.25))
			draw_line(Vector2(direction*40,-80),Vector2(direction*64,-57),color.darkened(0.12),17)
		if kind == 3:
			for direction in [-1,1]:
				draw_circle(Vector2(direction*27,-115),20,color)
				draw_line(Vector2(direction*27-8,-115),Vector2(direction*27+8,-115),Color("484326"),4)
			draw_arc(Vector2(0,-105),32,0.1,3.0,7,Color("463c22"),8)
			for n in range(6): draw_rect(Rect2(-24+n*9,-92,5,7),Color("eee3ac"))
		elif kind == 4:
			for direction in [-1,1]:
				poly([Vector2(direction*26,-120),Vector2(direction*61,-161),Vector2(direction*47,-111)],Color("b6a889"))
				draw_circle(Vector2(direction*23,-108),5,Color("514631"))
			draw_rect(Rect2(-31,-100,65,28),Color("b58b43"))
			draw_circle(Vector2(-17,-88),5,Color("584b34"))
			draw_circle(Vector2(19,-88),5,Color("584b34"))
		else:
			for direction in [-1,1]:
				poly([Vector2(direction*17,-121),Vector2(direction*32,-164),Vector2(direction*44,-117)],color.darkened(0.12))
				draw_line(Vector2(direction*10,-108),Vector2(direction*30,-114),Color("574324"),5)
			draw_arc(Vector2(0,-104),22,0,2.5,5,Color("574324"),4)
			poly([Vector2(-38,-29),Vector2(-91,-5),Vector2(-70,-39),Vector2(-48,-65)],color.darkened(0.18))
			draw_rect(Rect2(-24,-58,49,30),Color("cf981f"))
		if trigger_time > 0:
			draw_arc(Vector2(0,-70),87,0,TAU,12,Color("ff7051"),5)
		if charging:
			draw_rect(Rect2(-40,-185,80*charge/2.5,6),Color("ffed82"))
	# Deliberate coarse facets and misplaced pixels evoke broken AI geometry.
	for n in range(8):
		draw_rect(Rect2(-28 + (n*19)%56,-30-(n*31)%65,7+(n%3)*3,4),Color(0.1,0.12,0.16,0.18))
	if active > 0:
		var reach := float(attack.get("range", 100))
		reach = minf(reach, 210)
		draw_line(Vector2(22,-68),Vector2(reach,-68),color.lightened(0.4),10)
		draw_arc(Vector2(reach-15,-70),33,-1.5,1.4,7,Color("fff1cb"),5)
	if blocking:
		draw_arc(Vector2(39,-72),56,-1.5,1.5,9,Color("73b8ff"),5)
	draw_set_transform(Vector2.ZERO)

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func draw_ellipse_shadow() -> void:
	draw_rect(Rect2(-47,-5,94,10),Color(0,0,0,0.3))
