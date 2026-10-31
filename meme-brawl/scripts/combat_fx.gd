extends Node2D
## Layered ribbons, additive light, anisotropic impact bursts and tracked skills.
const R = preload("res://scripts/roster.gd")
const PALETTE = [Color("37dfff"),Color("7ee9ff"),Color("ffc244"),Color("ccff38"),Color("ff983c"),Color("f2a4ff")]
var arena: Node2D
var events: Array = []
var ghosts: Array = []
var trail_clock := 0.0
var clock := 0.0
var flash := 0.0
var glow: Node2D
func _ready() -> void:
	glow = preload("res://scripts/combat_glow.gd").new()
	glow.fx = self
	glow.z_index = -1
	add_child(glow)
func palette(kind: int) -> Color:
	return PALETTE[kind]
func clear() -> void:
	events.clear()
	ghosts.clear()
	flash = 0
func emit(mode: String, at: Vector2, kind: int, duration := 0.4, facing := 1.0, strong := false) -> void:
	if events.size() >= 96: events.pop_front()
	events.append({"mode":mode,"at":at,"kind":kind,"life":duration,"duration":duration,"facing":facing,"strong":strong,"owner":-1})
	queue_redraw()
func skill(f: Node2D, move: int, ex: bool) -> void:
	var modes: Array = [["sonic","dash","spin"],["shield","uppercut","slash"],["shard","counter","dash"],["slime","dash","leap"],["dash","uppercut","quake"],["kick","uppercut","box"]]
	emit(modes[f.kind][move],f.position+Vector2(0,-70),f.kind,0.66 if not ex else 0.85,f.facing,ex)
	events[-1].owner = f.side
	events[-1]["serial"] = f.action_serial
	if ex:
		emit("charge",f.position+Vector2(0,-70),f.kind,0.22,f.facing,true)
		events[-1].owner = f.side
func follow_strike(f: Node2D) -> void:
	var mode: String = ["sonic","slash","shard","slime","quake","kick"][f.kind]
	emit(mode,f.position+Vector2(f.facing*35,-70),f.kind,0.2,f.facing,true)
func impact(at: Vector2, kind: int, guarded: bool, strength: int, data: Dictionary, facing: float) -> void:
	var mode := "guard" if guarded else "impact"
	if data.get("counter",false): mode = "counter_hit"
	emit(mode,at,kind,0.19 if guarded else 0.3,facing,strength == 2)
	if not guarded:
		for i in range(5 if strength < 2 else 10):
			emit("spark",at,kind,0.24+i*0.012,facing,strength == 2)
			events[-1]["seed"] = i
		if data.get("finisher",false): emit("finish",at,kind,0.6,facing,true)
		if strength == 2: flash = 0.045
func event_position(e: Dictionary) -> Vector2:
	if int(e.owner) >= 0 and arena.fighters.size() == 2:
		var f = arena.fighters[int(e.owner)]
		if not e.has("serial") or int(e.serial) == f.action_serial:
			return f.position+Vector2(0,-70)
	return e.at
func can_draw() -> bool:
	return arena != null and arena.screen == "fight" and not arena.show_help and not arena.paused and arena.cinematic <= 0 and arena.intro_time <= 0
func _process(dt: float) -> void:
	if arena == null or arena.paused or arena.show_help: return
	clock += dt
	flash = maxf(0,flash-dt)
	if arena.cinematic <= 0:
		for event in events: event.life -= dt
		events = events.filter(func(e): return e.life > 0)
	for ghost in ghosts: ghost.life -= dt
	ghosts = ghosts.filter(func(g): return g.life > 0)
	trail_clock -= dt
	if can_draw() and trail_clock <= 0 and arena.hit_pause <= 0:
		trail_clock = 0.032
		for f in arena.fighters:
			if f.active > 0 and (absf(f.velocity.x) > 240 or f.action_type == "super" or f.attack.get("air",false)):
				var snapshot: Dictionary = f.visual.snapshot()
				if not snapshot.is_empty():
					snapshot["life"] = 0.22
					snapshot["kind"] = f.kind
					ghosts.append(snapshot)
					if ghosts.size() > 28: ghosts.pop_front()
				if f.grounded: emit("dust",f.position,f.kind,0.27,-f.facing)
	queue_redraw()
	if glow != null: glow.queue_redraw()
func _draw() -> void:
	if not can_draw(): return
	for ghost in ghosts:
		draw_set_transform_matrix(ghost.transform)
		draw_texture_rect(ghost.texture,ghost.rect,false,Color(palette(int(ghost.kind)),float(ghost.life)/0.22*0.4))
	draw_set_transform(Vector2.ZERO)
	for p in arena.projectiles: draw_projectile(p)
	for e in events: draw_event(e)
	if flash > 0: draw_rect(Rect2(0,133,1152,410),Color(0.9,0.95,1,0.13))

# Filled tapered geometry carries volume; thin white cores make contact readable.
func crescent(center: Vector2, radius: Vector2, start: float, length: float, width: float, color: Color) -> void:
	if color.a < 0.005 or width < 0.01: return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var safe_width := minf(width,minf(radius.x,radius.y)*0.8)
	for i in range(25):
		var t := i/24.0
		var direction := Vector2.from_angle(start+length*t)
		var thickness := maxf(0.05,pow(maxf(0,sin(t*PI)),0.65)*safe_width)
		outer.append(center+direction*radius)
		inner.append(center+direction*(radius-Vector2.ONE*thickness))
	for i in range(24):
		draw_colored_polygon(PackedVector2Array([outer[i],outer[i+1],inner[i+1],inner[i]]),color)
	draw_polyline(outer,Color(1,1,0.95,color.a*0.85),1.5)
func streak(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var normal := (b-a).normalized().orthogonal()*width
	draw_colored_polygon(PackedVector2Array([a,b+normal,b-normal]),color)
func chip(at: Vector2, size: float, angle: float, color: Color) -> void:
	var a := at+Vector2(0,-size).rotated(angle)
	var b := at+Vector2(-size*0.7,size*0.5).rotated(angle)
	var c := at+Vector2(size*0.7,size*0.5).rotated(angle)
	draw_colored_polygon(PackedVector2Array([a,b,c]),color)
	draw_line(a,b,Color(1,0.95,0.7,color.a),2)
func impact_burst(t: float, color: Color, size: float, slash := false) -> void:
	var alpha := pow(1-t,1.2)
	for layer in range(2):
		for i in range(12):
			var direction := Vector2.from_angle(i*TAU/12+0.18+layer*0.1)
			var length := size*(0.6+0.4*sin(i*7.2+1))*(0.45+t*0.8)
			var a := direction*(7+t*18)
			var b := direction*length
			b.x *= 1.35
			streak(b,a,(5 if i%2 == 0 else 2)*(1-t),Color(color.darkened(0.35) if layer == 0 else Color("fff3cf"),alpha))
	crescent(Vector2.ZERO,Vector2(44,30)*(0.4+t*1.7),-0.4,TAU-0.2,7*(1-t),Color(color,alpha*0.8))
	streak(Vector2(-size*0.85,-size*0.2),Vector2(7,0),8*(1-t),Color(1,1,1,alpha))
	streak(Vector2(size*0.8,size*0.2),Vector2(-6,0),8*(1-t),Color(1,1,1,alpha))
	if slash:
		streak(Vector2(-size,size),Vector2(15,-18),11*(1-t),Color(color,alpha))
		streak(Vector2(size,-size),Vector2(-15,18),5*(1-t),Color(1,1,1,alpha))
	draw_circle(Vector2.ZERO,maxf(1,10*(1-t)),Color(1,1,1,alpha))

func draw_event(e: Dictionary) -> void:
	var t := clampf(1-float(e.life)/float(e.duration),0,1)
	var alpha := 1-t
	var color := Color(palette(int(e.kind)),alpha)
	var at := event_position(e)
	var mode: String = e.mode
	var power := 1.35 if e.strong else 1.0
	draw_set_transform(at,0,Vector2(float(e.facing),1))
	if mode in ["impact","counter_hit"]:
		impact_burst(t,color,90*power,int(e.kind) == 1)
		if mode == "counter_hit":
			crescent(Vector2.ZERO,Vector2.ONE*(35+t*95),t*2,4.8,9*alpha,Color("ffa2dc")*Color(1,1,1,alpha))
	elif mode == "spark":
		var seed: int = e.get("seed",0)
		var dir := Vector2.from_angle(-2.9+seed*0.64)
		var pos := dir*(t*145*power)+Vector2(0,t*t*70)
		streak(pos-dir*(13+seed%3*6)*alpha,pos,2.5*alpha,Color(1,0.85,0.5,alpha))
		if seed%2 == 0: draw_rect(Rect2(pos,Vector2(3,3)),Color(1,1,1,alpha))
	elif mode == "guard":
		crescent(Vector2(-12,0),Vector2(43+t*16,59),-1.45,2.9,10*alpha,Color(0.28,0.75,1,alpha))
		for i in range(5):
			var dir := Vector2.from_angle(-1.2+i*0.6)
			streak(dir*(35+t*65),dir*(29+t*40),2*alpha,Color(0.7,0.95,1,alpha))
	elif mode == "fist":
		for i in range(5):
			streak(Vector2(-55-t*20,-23+i*12),Vector2(40+t*28,-17+i*9),2+i%2,Color(color,alpha*0.65))
		crescent(Vector2(48,0),Vector2(23,35),-1.5,3,11*alpha,color)
	elif mode in ["slash","uppercut","kick","spin"]:
		var swing := clampf((t-0.08)*1.4,0,1)
		var center := Vector2(25,-10)
		var radius := Vector2(96,67)*power
		var start := -2.4+swing*3.2
		if mode == "uppercut":
			center = Vector2(28,-22-t*35)
			radius = Vector2(65,110)*power
			start = 0.6-swing*3.9
		if mode == "spin": radius = Vector2(103,62)*power
		for layer in range(3):
			crescent(center,radius+Vector2.ONE*layer*9,start-layer*0.18,2.65,22-layer*5,Color(color,alpha*(0.85-layer*0.2)))
		for i in range(8):
			var dir := Vector2.from_angle(start+i*0.33)
			streak(center+dir*(radius+Vector2.ONE*(10+t*35)),center+dir*radius,2*alpha,Color(1,1,0.9,alpha))
	elif mode in ["dash","shield"]:
		for i in range(13):
			var y := -59+i*10.0
			var x := -40-fmod(t*360+i*23,170)
			streak(Vector2(x-70,y),Vector2(x+65,y+sin(i*3.0)*7),2+i%3,Color(color,alpha*(0.3+float(i%3)*0.13)))
		crescent(Vector2(45,0),Vector2(45,77)*power,-1.4,2.8,13,Color(color,alpha))
		if mode == "shield":
			for i in range(3): crescent(Vector2(46,0),Vector2(40+i*10,66+i*10),-1.3,2.6,3,Color(0.85,0.98,1,alpha))
	elif mode in ["sonic","charge","counter","cancel"]:
		for i in range(3):
			var radius := (22+i*18+t*60)*power
			crescent(Vector2(15,0),Vector2(radius,radius*0.75),-2.5+t*3+i,4.2,8*alpha,Color(color,alpha))
		for i in range(10):
			var dir := Vector2.from_angle(i*TAU/10+t*2)
			var r := (110-t*80) if mode in ["charge","counter"] else (25+t*90)
			streak(dir*r,dir*(r-18),3*alpha,Color(1,1,0.85,alpha))
	elif mode == "shard":
		for i in range(9):
			var dir := Vector2.from_angle(-PI+i*PI/8)
			var pos := dir*(22+t*115)
			streak(pos-dir*30,pos,3*alpha,Color(color,alpha*0.5))
			chip(pos,12*alpha+3,t*4+i,Color(1,0.74,0.2,alpha))
	elif mode in ["quake","land"]:
		var ground := Vector2(0,70)
		for i in range(3): crescent(ground,Vector2(60+t*160+i*16,16+t*25+i*6),0,TAU-0.02,7*alpha,Color(color,alpha*0.7))
		for i in range(11):
			var pos := Vector2((i-5)*(12+t*23),70-sin(t*PI)*(20+i%4*15))
			chip(pos,5+i%3,t*4+i,Color(0.6,0.48,0.35,alpha))
			if mode == "quake": streak(Vector2((i-5)*18,70),pos-Vector2(0,35),4*alpha,Color(1,0.65,0.2,alpha))
	elif mode in ["dust","leap"]:
		for i in range(6):
			var pos := Vector2(-i*10-t*45,-sin(t*PI)*(8+i*3))
			draw_circle(pos,3+i*1.5,Color(0.67,0.62,0.5,alpha*0.35))
	elif mode == "slime":
		for i in range(9):
			var pos := Vector2(10+i*12*t,-25+sin(i*2.0)*t*65)
			draw_circle(pos,7-i*0.4,Color(0.6,0.72,0.08,alpha))
			draw_circle(pos-Vector2(2,2),2,Color(0.95,1,0.6,alpha))
	elif mode == "box":
		crescent(Vector2(40,-10),Vector2(70,40),-2.8,2.5,12,Color(1,0.8,0.28,alpha))
	elif mode == "ca":
		for i in range(18):
			var dir := Vector2.from_angle(i*TAU/18+0.1)
			streak(dir*(180+t*130),dir*(60+t*80),4*alpha,Color(color,alpha*0.5))
	elif mode == "finish":
		impact_burst(t,color,190,int(e.kind) == 1)
		if e.kind == 2:
			for i in range(16): chip(Vector2.from_angle(i*TAU/16)*(35+t*190),18*alpha+3,i+t*6,Color(1,0.73,0.2,alpha))
		elif e.kind in [4,5]:
			for i in range(4): crescent(Vector2(0,65),Vector2(100+t*220+i*20,25+i*12),0,TAU-0.02,14*alpha,Color(color,alpha))
		else:
			for i in range(4): crescent(Vector2.ZERO,Vector2(75+t*120+i*24,100+t*100),-2+t*3+i,4.5,16*alpha,Color(color,alpha))
	draw_set_transform(Vector2.ZERO)

func draw_projectile(p: Dictionary) -> void:
	if p.delay > 0: return
	var at: Vector2 = p.position
	var direction := 1.0 if p.velocity.x >= 0 else -1.0
	var color := palette(int(p.kind))
	var power := 1.25 if p.ex else 1.0
	draw_set_transform(at,0,Vector2(direction,1)*power)
	if p.kind == 0:
		for i in range(5):
			crescent(Vector2(-i*10,0),Vector2(24-i*2,38-i*3),-1.35,2.7,9-i,Color(color,1-i*0.16))
		for i in range(6): streak(Vector2(-63-i%2*18,-28+i*11),Vector2(-12,-24+i*10),1.5,Color(0.7,1,1,0.65))
	elif p.kind == 2:
		if p.trap:
			for i in range(5): chip(Vector2((i-2)*11.0,3),10+(i%2)*6,i*0.2,Color("f4bb40"))
			crescent(Vector2(0,8),Vector2(38,8),0,TAU-0.02,3,Color(1,0.84,0.3,0.8))
		else:
			for i in range(4):
				var pos := Vector2(-i*13,0)
				chip(pos,(21 if not p.flat else 10)-i*3,float(p.age)*8,Color(1,0.76,0.27,1-i*0.23))
			for i in range(5): streak(Vector2(-45-i*7,-23+i*10),Vector2(-15,-20+i*10),1,Color(1,0.9,0.5,0.7))
	elif p.kind == 3:
		for i in range(6):
			var pos := Vector2(-i*9,sin(clock*18+i)*5)
			draw_circle(pos,19-i*2.4,Color(0.65,0.74,0.08,1-i*0.14))
			draw_circle(pos-Vector2(4,5),4-i*0.4,Color(0.95,1,0.55,0.7))
	elif p.kind == 5:
		crescent(Vector2(-7,0),Vector2(40,32),float(p.age)*5,3.4,8,Color(1,0.8,0.2,0.7))
		draw_set_transform(at,float(p.age)*3,Vector2.ONE*power)
		draw_rect(Rect2(-22,-18,44,36),Color("d8a82b"))
		draw_rect(Rect2(-22,-18,44,36),Color("ffed9f"),false,3)
		draw_line(Vector2(-22,0),Vector2(22,0),Color("685329"),4)
		draw_line(Vector2(-4,-18),Vector2(-4,18),Color("ffdc68"),6)
	draw_set_transform(Vector2.ZERO)
