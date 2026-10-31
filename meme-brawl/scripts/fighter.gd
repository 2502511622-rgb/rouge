extends Node2D

const PixelAnimator = preload("res://scripts/pixel_animator.gd")
var visual: Node2D

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
	hp = R.HP[kind]
	position = Vector2(320 if side == 0 else 832, 532)
	facing = 1 if side == 0 else -1
	z_index = 3
	visual = PixelAnimator.new()
	visual.fighter = self
	add_child(visual)

func opponent() -> Node2D:
	return arena.fighters[1 - side]

func tick(dt: float, controlled: bool) -> void:
	clock += dt
	animation += dt
	for key in ["stun", "cooldown", "active", "v_time", "v_cooldown", "horns", "invulnerable", "flash", "label_time", "trigger_time", "armor", "cancel_window", "low_profile", "guard_time", "counter_startup", "attack_startup", "buffer_time", "shield_guard"]:
		set(key, maxf(0.0, float(get(key)) - dt))
	consume_buffer()
	if charging and kind == 4:
		charge = minf(2.5, charge + dt)
	v_meter = minf(100, v_meter + dt * 3.0)
	if active <= 0:
		attack = {}
	hit_interval -= dt
	if remaining_hits > 0 and hit_interval <= 0 and not attack.is_empty():
		connected = false
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
	if grounded and active <= 0 and stun <= 0:
		facing = 1 if opponent().position.x > position.x else -1
	blocking = false
	crouching = false
	if controlled:
		player_input(dt)
	elif not arena.training:
		ai_input(dt)
	if guard_time > 0 and stun <= 0:
		blocking = true
	if stun > 0:
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
		grounded = true
		juggle_count = 0
		jumps = 0
		if slam_pending:
			slam_pending = false
			begin_attack({"damage": 150 if slam_ex else 105, "range": 210, "height": 90, "low": true, "push": 300, "knockdown": slam_ex}, 0.2, 0.6)
	if not attack.is_empty() and not connected and attack_startup <= 0:
		var enemy = opponent()
		var delta: Vector2 = enemy.position - position
		if delta.x * facing > -24 and absf(delta.x) < float(attack.get("range", 95)) and absf(delta.y) < float(attack.get("height", 100)):
			connected = true
			enemy.receive(attack, self)
	queue_redraw()

func player_input(_dt: float) -> void:
	var x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var down := Input.is_physical_key_pressed(KEY_S)
	var dir := 5
	if x * facing > 0: dir = 6
	if x * facing < 0: dir = 4
	if down: dir = 2 if x == 0 else (3 if x * facing > 0 else 1)
	if dir != last_dir:
		motion.append([dir, clock])
		last_dir = dir
	while not motion.is_empty() and clock - float(motion[0][1]) > 0.85:
		motion.pop_front()
	if stun > 0: return
	if active > 0:
		if kind == 0 and not grounded and attack.get("air",false):
			velocity.x = move_toward(velocity.x,x*R.SPEED[0],1800*_dt)
		return
	crouching = down and grounded
	blocking = x * facing < 0 and grounded
	if not crouching:
		velocity.x = x * R.SPEED[kind] * (1.45 if (kind == 0 and v_time > 0) or (kind == 3 and trigger_time > 0) else 1.0)

func press(key: int, ex_modifier := false) -> void:
	if hp <= 0 or stun > 0: return
	if key >= KEY_1 and key <= KEY_3:
		special(key-KEY_1,ex_modifier or Input.is_physical_key_pressed(KEY_SHIFT))
		return
	if key == KEY_4:
		super_move()
		return
	if key == KEY_W and (grounded or (kind == 0 and v_time > 0 and jumps < 2)) and active <= 0:
		grounded = false
		jumps += 1
		velocity.y = -660 if kind == 5 and trigger_time > 0 else -540
		return
	if key == KEY_B:
		trigger()
		return
	if key == KEY_V:
		v_skill()
		return
	if key == KEY_T and cooldown <= 0:
		say(R.TAUNT[kind])
		visual.play("taunt",0.8)
		cooldown = 0.65
		arena.sound(kind, "taunt")
		return
	if key == KEY_G:
		throw_move()
		return
	var keys := [KEY_J, KEY_K, KEY_L, KEY_U, KEY_I, KEY_O]
	var index := keys.find(key)
	if index < 0: return
	var kick := index >= 3 or kind == 5
	var strength := index % 3
	var ex := Input.is_physical_key_pressed(KEY_SHIFT)
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
	buffer_time = 0.14

func consume_buffer() -> void:
	if buffer_time <= 0:
		buffered.clear()
		return
	if buffered.is_empty() or stun > 0: return
	var type: String = buffered.type
	if (cooldown > 0 or active > 0) and not can_cancel(type,int(buffered.value)): return
	var command := buffered.duplicate()
	buffered.clear()
	if type == "normal": normal(command.value,command.option)
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
	attack = {}
	velocity.x *= 0.25

func start_action(type: String, rank := -1) -> void:
	action_type = type
	action_rank = rank
	action_serial += 1
	cancel_window = 0
	confirmed_serial = -1
	buffered.clear()

func normal(strength: int, kick: bool) -> void:
	if hp <= 0 or stun > 0: return
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
	begin_attack({"strength": strength, "kick": kick, "damage": damage, "range": reach, "low": low, "air": not grounded or (kind == 5 and trigger_time > 0 and kick), "push": 195 if kind == 5 and kick else 45 + strength * 25, "guard_chip":0.25 if kind == 4 and strength == 2 else 0.08, "hitstun": [0.27,0.34,0.42][strength], "cancelable": true, "startup": 0.09 + strength*0.035 if kind == 2 else [0.045,0.065,0.085][strength]}, 0.16 + strength * 0.06, 0.23 + strength * 0.13)
	if kind == 3: cooldown *= 0.82
	if kind == 4:
		cooldown *= 1.18
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
	attack_startup = float(data.get("startup",0))
	active = duration + attack_startup
	cooldown = (recovery + attack_startup) * (0.65 if kind == 3 and trigger_time > 0 else 1.0)
	connected = false
	remaining_hits = 0

func special(move: int, use_ex: bool) -> void:
	if hp <= 0 or stun > 0: return
	var upgrade := use_ex and clock-last_special_at < 0.28 and action_type == "special" and move == last_special_move
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
		v_time = 1.8
		cooldown = 0.45
	else:
		var reach := 155.0 if move == 2 else 115.0
		begin_attack({"damage": 155 if empowered else 105, "range": reach, "height": 220 if move == 1 else 100, "launch": move == 1, "push": 180, "knockdown": empowered, "ex": empowered}, 0.38, 0.7)
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
			active = 0.62
			cooldown = 0.92

func penguin_special(move: int, empowered: bool) -> void:
	if move == 0:
		for n in range(3 if empowered else 1):
			arena.spawn_projectile(self,n*55,empowered)
		active = 0.22
		cooldown = 0.44 if empowered else 0.42
	elif move == 1:
		begin_attack({"damage":145 if empowered else 85,"range":125,"height":145,"push":400,"knockdown":empowered},0.45,0.72)
		low_profile = 0.38 if empowered else 0.22
		velocity.x = facing*(710 if empowered else 450)
		if empowered and not grounded: velocity.y = 330
	else:
		begin_attack({"damage":48,"range":145,"height":160,"air":true,"push":25},0.4,0.64)
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
		for n in range(3 if empowered else 1):
			arena.spawn_projectile(self,n*55,empowered)
		horns = maxf(horns,2.6)
		active = 0.34
		cooldown = 0.8
		if blunt: say("磨平 · 钝角气团" if not empowered else "EX · 钝角碎片")
	elif move == 1:
		v_time = 1.55 if empowered else 0.8
		counter_startup = 0.08 if empowered else 0.18
		active = counter_startup
		cooldown = 0.75 if empowered else 0.65
	else:
		for i in range(3 if empowered else 1): arena.place_cat_trap(self,i*43,empowered)
		horns = maxf(horns,2.6)
		guard_time = 0.5
		active = 0.3
		cooldown = 0.7
		velocity.x = -facing*235
		v_time = 0.45 if empowered else 0.0
		counter_startup = 0.08 if empowered else 0.0

func dlc_special(move: int, empowered: bool) -> void:
	if kind == 4:
		charge_bonus = 1.0 + charge * 0.35
		charging = false
		charge = 0
	if (kind == 3 and move == 0 and not empowered) or (kind == 5 and move == 2):
		arena.spawn_projectile(self, 0, empowered)
		active = 0.25
		cooldown = 0.7
		return
	if kind == 3 and move == 2:
		grounded = false
		velocity = Vector2(facing * 250,-550)
		slam_pending = true
		slam_ex = empowered
		cooldown = 0.65
		return
	var damage := 125.0 if kind == 4 else 95.0
	var reach := 230.0 if kind == 5 else (280.0 if kind == 4 and move == 2 else 120.0)
	var multi := empowered and ((kind == 3 and move < 2) or (kind == 4 and move == 2) or (kind == 5 and move == 0))
	begin_attack({"damage": 62.0 if multi else damage * (1.45 if empowered else 1.0), "range":reach, "height":220 if move == 1 else 100, "launch": move == 1 and kind in [4,5], "low": kind == 4 and move == 2, "push":25 if multi else 340, "special":true, "ex":empowered, "cancelable":true, "knockdown":empowered and not multi},0.65 if multi else 0.35,1.0 if empowered else 0.65)
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
		if active > 0: return
		charging = not charging
		say("妈 ——（移动蓄力中）" if charging else "蓄力保留 · %.1f" % charge)
		return
	if v_cooldown > 0 or active > 0: return
	v_time = 3.5 if kind == 0 else 1.0
	v_cooldown = 7.0
	say(R.V[kind])
	visual.play("v",0.7)
	arena.sound(kind, "v")

func trigger() -> void:
	if kind < 3 or trigger_time > 0 or v_meter < 100 or active > 0: return
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
	begin_attack({"damage": 55, "range": 1200 if kind != 1 else 450, "height": 600, "push": 25, "knockdown": false, "ca": true}, 0.85, 1.25)
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
	visual.play("ca",arena.ca_duration+1.25)
	arena.fx.emit("ca",position+Vector2(0,-75),kind,arena.ca_duration+0.8,facing,true)
	arena.sound(kind, "ca")

func throw_move() -> void:
	if cooldown > 0 or not grounded: return
	start_action("throw")
	say("投技")
	visual.play("throw",0.7)
	begin_attack({"damage": 180 if kind == 4 else 125, "range": 95 if kind == 4 else 85, "height": 70, "throw": true, "push": 430, "knockdown": true}, 0.15, 0.7)

func receive(data: Dictionary, source: Node2D) -> void:
	var linked := stun > 0
	var hit_note := "COUNTER HIT" if active > 0 else ("PUNISH" if cooldown > 0 else "")
	if data.get("throw",false): hit_note = "THROW"
	if hp <= 0 or invulnerable > 0: return
	if shield_guard > 0 and data.get("projectile",false) and not data.get("low",false):
		meter = minf(3,meter+0.08)
		arena.hit_effect(position+Vector2(facing*30,-70),true,0,source.side,false,"SHIELD",data)
		return
	if low_profile > 0 and data.get("projectile", false) and not data.get("low",false): return
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
		active = 0.2
		cooldown = 0.4
		attack = {}
		meter = minf(3, meter + (0.65 if blunt_counter else 0.45))
		source.receive({"damage": 120 if blunt_counter else 170, "cancelable":true, "serial":action_serial, "counter": true, "push": 420, "knockdown": true}, self)
		return
	var guarded := blocking and grounded and not is_throw
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
	stun = 0.12 if guarded else float(data.get("hitstun",0.6 if data.get("knockdown", false) else 0.27))
	if armor > 0 and not is_throw:
		stun = 0
		flash = 0.12
		arena.hit_effect(position + Vector2(0,-70), false, damage,source.side,linked,hit_note,data)
		if hp <= 0: arena.finish(source.side)
		return
	active = 0
	attack = {}
	if not guarded:
		guard_time = 0
		shield_guard = 0
	if kind == 2:
		v_time = 0
		counter_startup = 0
	slam_pending = false
	velocity.x = source.facing * float(data.get("push", 180)) * (0.35 if guarded else 1.0)
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
	if stun > 0 or active > 0: return
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
