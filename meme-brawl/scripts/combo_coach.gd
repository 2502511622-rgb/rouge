extends RefCounted
## Rehearsal presses the same actions as the player; it never invents a hit.
const MOVES = [0,1,0,1,2,0]
const ROUTES = ["J → K → L → ↓↘→ J → ↓↘→↓↘→ J","J → K → L → →↓↘ J → ↓↘→↓↘→ J","J → K → L → ↓↘→ J → ↓↘→↓↘→ J","J → K → L → →↓↘ J → ↓↘→↓↘→ J","J → K → L → ↓↙← J → ↓↙←↓↙← J","J → K → L → ↓↘→ U → ↓↘→↓↘→ U"]
var arena: Node2D
var running := false
var step := 0
var wait := 0.0
var timeout := 0.0
var status := ""
func start() -> void:
	arena.new_round()
	arena.intro_time = 0
	for f in arena.fighters:
		f.visual.play("idle")
	arena.fighters[0].position = Vector2(475,532)
	arena.fighters[1].position = Vector2(560,532)
	arena.fighters[0].meter = 3
	running = true
	step = 0
	wait = 0
	timeout = 0
	status = "LIVE COMBO / 真实输入与判定"
func tick(dt: float) -> void:
	if not running: return
	timeout += dt
	wait = maxf(0,wait-dt)
	if timeout > 5 or arena.screen != "fight":
		running = false
		status = "演练结束 · F5 重播"
		return
	var f = arena.fighters[0]
	if step == 5:
		if f.active <= 0:
			running = false
			status = "连段完成 · F5 重播"
		return
	if wait > 0: return
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
