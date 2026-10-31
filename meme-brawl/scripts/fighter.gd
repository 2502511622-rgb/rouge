extends Node2D

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
var cancel_window := 0.0
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

func opponent() -> Node2D:
	return arena.fighters[1 - side]

func tick(dt: float, controlled: bool) -> void:
	clock += dt
	animation += dt
	for key in ["stun", "cooldown", "active", "v_time", "v_cooldown", "horns", "invulnerable", "flash", "label_time", "trigger_time", "armor", "cancel_window", "low_profile"]:
		set(key, maxf(0.0, float(get(key)) - dt))
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
	if grounded and active <= 0 and stun <= 0:
		facing = 1 if opponent().position.x > position.x else -1
	blocking = false
	crouching = false
	if controlled:
		player_input(dt)
	elif not arena.training:
		ai_input(dt)
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
		grounded = true
		jumps = 0
		if slam_pending:
			slam_pending = false
			begin_attack({"damage": 150 if slam_ex else 105, "range": 210, "height": 90, "low": true, "push": 300, "knockdown": slam_ex}, 0.2, 0.6)
	if not attack.is_empty() and not connected:
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
	if stun > 0 or active > 0: return
	crouching = down and grounded
	blocking = x * facing < 0 and grounded
	if not crouching:
		velocity.x = x * R.SPEED[kind] * (1.45 if (kind == 0 and v_time > 0) or (kind == 3 and trigger_time > 0) else 1.0)

func press(key: int) -> void:
	if hp <= 0 or stun > 0: return
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
		cooldown = 0.65
		arena.sound(kind, "taunt")
		return
	if key == KEY_G:
		throw_move()
		return
	var keys := [KEY_J, KEY_K, KEY_L, KEY_U, KEY_I, KEY_O]
	var index := keys.find(key)
	if index < 0: return
	var kick := index >= 3
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

func normal(strength: int, kick: bool) -> void:
	if cooldown > 0 or active > 0: return
	var low := crouching and kick and not (kind == 5 and trigger_time > 0)
	var damage: float = [38, 65, 95][strength] * (0.85 if kind == 2 else (1.25 if kind == 4 else 1.0))
	begin_attack({"damage": damage, "range": [88, 112, 145][strength] + (20 if kick else 0), "low": low, "air": not grounded or (kind == 5 and trigger_time > 0 and kick), "push": 145 + strength * 65, "cancelable": true}, 0.16 + strength * 0.06, 0.23 + strength * 0.13)
	meter = minf(3, meter + 0.025)

func begin_attack(data: Dictionary, duration: float, recovery: float) -> void:
	attack = data.duplicate()
	if trigger_time > 0 and kind == 5: attack.damage = float(attack.get("damage", 0)) * 1.2
	if trigger_time > 0 and kind == 4: attack.range = float(attack.get("range", 95)) + 110
	if kind == 4 and data.get("special", false):
		attack.damage = float(attack.get("damage", 0)) * charge_bonus
		charge_bonus = 1.0
	active = duration
	cooldown = recovery * (0.65 if kind == 3 and trigger_time > 0 else 1.0)
	connected = false
	remaining_hits = 0
	arena.sound(kind, "swing")

func special(move: int, use_ex: bool) -> void:
	# Double-heavy may upgrade the immediately preceding normal into an EX.
	if cooldown > 0 and not use_ex: return
	if use_ex and meter < 1:
		say("能量不足 · EX 需要 1 格")
		return
	if use_ex: meter -= 1
	last_special_at = clock if not use_ex else -10.0
	last_special_move = move
	var empowered := use_ex or (kind == 0 and v_time > 0 and move != 0)
	say(R.EX[kind][move] if use_ex else R.SPECIALS[kind][move])
	motion.clear()
	if kind >= 3:
		dlc_special(move, use_ex)
		arena.sound(kind, "special")
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
		begin_attack({"damage": 155 if empowered else 105, "range": reach, "height": 180 if move == 1 else 100, "push": 360, "knockdown": empowered, "ex": empowered}, 0.38, 0.7)
		if move == 0 or (kind == 0 and move == 1):
			velocity.x = facing * (650 if empowered else 440)
		if move == 1 and kind == 1:
			grounded = false
			velocity.y = -430
		if empowered: invulnerable = 0.22
	arena.sound(kind, "special")

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
	begin_attack({"damage": 62.0 if multi else damage * (1.45 if empowered else 1.0), "range":reach, "height":190 if move == 1 else 100, "low": kind == 4 and move == 2, "push":25 if multi else 340, "special":true, "cancelable":true, "knockdown":empowered and not multi},0.65 if multi else 0.35,1.0 if empowered else 0.65)
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
	arena.sound(kind, "v")

func trigger() -> void:
	if kind < 3 or trigger_time > 0 or v_meter < 100 or active > 0: return
	v_meter = 0
	trigger_time = 8.0
	say(R.TRIGGERS[kind])
	arena.sound(kind, "trigger")

func super_move() -> void:
	if meter < 3:
		say("CA 需要 3 格能量")
		return
	if active > 0: return
	meter = 0
	motion.clear()
	say(R.CA[kind])
	invulnerable = 0.9
	arena.cinematic = 0.65
	arena.ca_kind = kind
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
	arena.sound(kind, "ca")

func throw_move() -> void:
	if cooldown > 0 or not grounded: return
	say("投技")
	begin_attack({"damage": 125, "range": 85, "height": 70, "throw": true, "push": 430, "knockdown": true}, 0.15, 0.7)

func receive(data: Dictionary, source: Node2D) -> void:
	if hp <= 0 or invulnerable > 0: return
	if low_profile > 0 and data.get("projectile", false): return
	var is_throw: bool = data.get("throw", false)
	if is_throw and not grounded: return
	if v_time > 0 and kind in [1,2,5] and not is_throw and not data.get("counter", false) and not (kind == 1 and data.get("low", false)):
		v_time = 0
		if kind == 2: horns = 3.0
		say("盾反斩！" if kind == 1 else ("肥嘟嘟格挡 · 反击！" if kind == 5 else "磨平棱角 · 弹射反击！"))
		meter = minf(3, meter + 0.45)
		source.receive({"damage": 170, "counter": true, "push": 420, "knockdown": true}, self)
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
	if guarded: damage *= 0.08
	hp = maxf(0, hp - damage)
	meter = minf(3, meter + (0.24 if kind == 2 else 0.12))
	if not guarded:
		v_meter = minf(100, v_meter + 12)
		source.v_meter = minf(100, source.v_meter + 8)
		if data.get("cancelable", false): source.cancel_window = 0.3
	source.meter = minf(3, source.meter + (0.08 if guarded else 0.16))
	stun = 0.12 if guarded else (0.6 if data.get("knockdown", false) else 0.27)
	if armor > 0 and not is_throw:
		stun = 0
		flash = 0.12
		arena.hit_effect(position + Vector2(0,-70), false, damage)
		if hp <= 0: arena.finish(source.side)
		return
	active = 0
	attack = {}
	slam_pending = false
	velocity.x = source.facing * float(data.get("push", 180)) * (0.35 if guarded else 1.0)
	if data.get("knockdown", false) and not guarded:
		velocity.y = -260
		grounded = false
	flash = 0.12
	arena.hit_effect(position + Vector2(0, -70), guarded, damage)
	arena.sound(kind, "block" if guarded else "hit")
	if hp <= 0:
		arena.finish(source.side)

func ai_input(dt: float) -> void:
	if kind == 3 and cancel_window > 0 and v_meter >= 35 and randf() < 0.08: v_skill()
	if stun > 0 or active > 0: return
	if kind >= 3 and v_meter >= 100: trigger()
	if kind == 4 and not charging and charge <= 0 and randf() < 0.01: v_skill()
	var dist := absf(opponent().position.x - position.x)
	blocking = opponent().active > 0 and randf() < 0.78
	crouching = blocking and opponent().crouching
	if dist > 155 and not blocking: velocity.x = facing * R.SPEED[kind] * 0.7
	ai_time -= dt
	if ai_time > 0: return
	ai_time = randf_range(0.32, 0.75) / arena.difficulty
	if blocking:
		if randf() < 0.4: v_skill()
	elif meter >= 3 and dist < 400:
		super_move()
	elif dist < 90 and randf() < 0.18:
		throw_move()
	elif randf() < 0.35:
		special(randi_range(0, 2), meter >= 1 and randf() < 0.4)
	elif dist < 165:
		normal(randi_range(0, 2), randf() < 0.5)
	elif grounded and randf() < 0.3:
		grounded = false
		velocity.y = -520
		velocity.x = facing * 230

func _draw() -> void:
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
