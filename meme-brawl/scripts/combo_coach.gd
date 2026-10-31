extends RefCounted
## Role lessons call the same actions, counters and collisions as the player.
const MOVES = [0,1,0,1,2,0]
const ROUTES = ["{v} 加速 · {skill1} 远程压制 → 命中后 {super}","{v} 盾反接住攻击 → {super}；{skill1} 举盾逼近","{skill3} 布角后撤 → 对手踩中陷阱 → {super}","{light} → {medium} → {heavy} → {skill2} → {v} → {light} → {medium} → {heavy} → {skill2} → {super}","{v} 蓄力 → {skill3} 重击 → {super}；贴身 {throw} 重投","{medium} 中距踢 → {skill1} 重踢 → {super}"]
var arena: Node2D
var running := false
var step := 0
var wait := 0.0
var timeout := 0.0
var status := ""
var classic := false
func start(use_classic := false) -> void:
	arena.new_round()
	classic = use_classic
	arena.intro_time = 0
	for f in arena.fighters: f.visual.play("idle")
	arena.fighters[0].position = Vector2(475,532)
	arena.fighters[1].position = Vector2(560,532)
	if not classic:
		match arena.selected:
			0:
				arena.fighters[0].position.x = 250
				arena.fighters[1].position.x = 850
			1: arena.fighters[1].position.x = 570
			2: arena.fighters[1].position.x = 750
			4: arena.fighters[1].position.x = 580
			5: arena.fighters[1].position.x = 665
	arena.fighters[0].meter = 3
	running = true
	step = 0
	wait = 0
	timeout = 0
	status = "实际判定演练 · "+arena.R.ROLES[arena.selected]
func finish() -> void:
	running = false
	status = "演练完成 · F5 重播"
func tick(dt: float) -> void:
	if not running: return
	timeout += dt
	wait = maxf(0,wait-dt)
	if timeout > 8.5 or arena.screen != "fight":
		running = false
		status = "演练结束 · F5 重播"
		return
	if wait > 0: return
	var f = arena.fighters[0]
	if classic:
		tick_classic(f)
	elif f.kind == 3:
		tick_frog(f)
	else:
		tick_role(f)
func tick_classic(f: Node2D) -> void:
	if step == 5:
		if f.active <= 0: finish()
		return
	var serial: int = f.action_serial
	if step == 0: f.normal(0,false)
	elif step < 3:
		if f.can_cancel("normal",step): f.normal(step,false)
	elif step == 3:
		if f.can_cancel("special"): f.special(MOVES[f.kind],false)
	elif step == 4:
		if f.can_cancel("super"): f.super_move()
	if f.action_serial != serial:
		step += 1
		wait = 0.055
func tick_frog(f: Node2D) -> void:
	if step == 10:
		if f.active <= 0: finish()
		return
	var serial: int = f.action_serial
	if step in [0,5]: f.normal(0,false)
	elif step in [1,2,6,7]:
		var rank := step if step < 3 else step-5
		if f.can_cancel("normal",rank): f.normal(rank,false)
	elif step in [3,8]:
		if f.can_cancel("special"): f.special(1,false)
	elif step == 4:
		if f.cancel_window > 0 and f.v_meter >= 35:
			f.v_skill()
			step += 1
			wait = 0.035
		return
	elif step == 9:
		if f.can_cancel("super"): f.super_move()
	if f.action_serial != serial:
		step += 1
		wait = 0.055
func tick_role(f: Node2D) -> void:
	var final_step := 3 if f.kind in [4,5] else 2
	if step == final_step:
		if f.active <= 0: finish()
		return
	var serial: int = f.action_serial
	if step == 0:
		match f.kind:
			0:
				f.v_skill()
				f.special(0,false)
			1:
				f.v_skill()
				arena.fighters[1].normal(1,false)
				step = 1
				return
			2: f.special(2,false)
			4:
				f.v_skill()
				step = 1
				wait = 1.5
				return
			5: f.normal(1,true)
	elif step == 1:
		if f.kind == 2 and not f.can_cancel("super"):
			arena.fighters[1].velocity.x = -150
		if f.kind == 4: f.special(2,false)
		elif f.kind == 5:
			if f.can_cancel("special"): f.special(0,false)
		elif f.can_cancel("super"): f.super_move()
	elif step == 2 and f.can_cancel("super"): f.super_move()
	if f.action_serial != serial:
		step += 1
		wait = 0.055
