extends Node2D
## Bounded procedural arcade VFX. Ghosts reuse isolated actor textures.

const R = preload("res://scripts/roster.gd")
const Bank = preload("res://scripts/sprite_frames.gd")
var arena: Node2D
var events: Array = []
var ghosts: Array = []
var trail_clock := 0.0
var clock := 0.0
var flash := 0.0

func clear() -> void:
	events.clear()
	ghosts.clear()
	flash = 0

func emit(mode: String, at: Vector2, kind: int, duration := 0.4, facing := 1.0, strong := false) -> void:
	if events.size() >= 96: events.pop_front()
	events.append({"mode":mode,"at":at,"kind":kind,"life":duration,"duration":duration,"facing":facing,"strong":strong})
	queue_redraw()

func skill(f: Node2D, move: int, ex: bool) -> void:
	var modes: Array = [["sonic","dash","spin"],["shield","uppercut","slash"],["shard","counter","dash"],["slime","dash","leap"],["dash","uppercut","quake"],["kick","uppercut","box"]]
	emit(modes[f.kind][move],f.position+Vector2(0,-65),f.kind,0.65,f.facing,ex)
	if ex: emit("charge",f.position+Vector2(0,-70),f.kind,0.3,f.facing,true)

func impact(at: Vector2, kind: int, guarded: bool, strength: int, data: Dictionary, facing: float) -> void:
	var mode := "guard" if guarded else ("slash_hit" if kind == 1 else "impact")
	if data.get("counter",false): mode = "counter_hit"
	emit(mode,at,kind,0.2 if guarded else 0.25,facing,strength == 2)
	if not guarded:
		for i in range(3 if strength < 2 else 7):
			emit("spark_"+str(i),at,kind,0.22+i*0.018,facing,strength == 2)
		if strength == 2: flash = 0.035

func _process(dt: float) -> void:
	if arena == null or arena.paused or arena.show_help: return
	clock += dt
	flash = maxf(0,flash-dt)
	for event in events: event.life -= dt
	events = events.filter(func(e): return e.life > 0)
	for ghost in ghosts: ghost.life -= dt
	ghosts = ghosts.filter(func(g): return g.life > 0)
	trail_clock -= dt
	if arena.screen == "fight" and arena.cinematic <= 0 and arena.intro_time <= 0 and trail_clock <= 0:
		trail_clock = 0.045
		for f in arena.fighters:
			if f.active > 0 and (absf(f.velocity.x) > 280 or (f.kind == 0 and f.attack.get("air",false))):
				var snapshot: Dictionary = f.visual.snapshot()
				if not snapshot.is_empty():
					snapshot["life"] = 0.19
					snapshot["kind"] = f.kind
					ghosts.append(snapshot)
					if ghosts.size() > 28: ghosts.pop_front()
				if f.grounded: emit("dust",f.position,f.kind,0.25,-f.facing)
	queue_redraw()

func _draw() -> void:
	if arena == null or arena.screen != "fight" or arena.show_help or arena.paused: return
	if arena.cinematic > 0 or arena.intro_time > 0: return
	for ghost in ghosts:
		draw_set_transform_matrix(ghost.transform)
		draw_texture_rect(ghost.texture,ghost.rect,false,Color(R.COLORS[int(ghost.kind)],float(ghost.life)/0.19*0.25))
	draw_set_transform(Vector2.ZERO)
	for p in arena.projectiles: draw_projectile(p)
	for e in events: draw_event(e)
	if flash > 0: draw_rect(Rect2(0,133,1152,410),Color(1,0.91,0.75,0.1))

func arc_band(center: Vector2, radius: float, start: float, end: float, color: Color, width := 5.0) -> void:
	draw_arc(center,radius,start,end,18,Color(color,0.15),width*3)
	draw_arc(center,radius,start,end,18,color,width)
	draw_arc(center,radius-3,start+0.1,end-0.1,18,Color(1,1,0.9,color.a),maxf(1,width*0.3))

func draw_event(e: Dictionary) -> void:
	var t := 1-float(e.life)/float(e.duration)
	var alpha := 1-t
	var at: Vector2 = e.at
	var color := Color(R.COLORS[int(e.kind)],alpha)
	var strong: bool = e.strong
	var scale_size := 1.4 if strong else 1.0
	draw_set_transform(at,0,Vector2(float(e.facing),1))
	var mode: String = e.mode
	if mode in ["impact","slash_hit","counter_hit"]:
		var rays := 12 if strong else 8
		for i in range(rays):
			var direction := Vector2.from_angle(i*TAU/rays+0.3)
			var tip := direction*(22+42*(1-t))*scale_size
			draw_colored_polygon(PackedVector2Array([direction*4,tip+direction.orthogonal()*4*(1-t),tip-direction.orthogonal()*4*(1-t)]),Color(1,0.83,0.38,alpha))
		draw_circle(Vector2.ZERO,12*(1-t),Color(1,1,0.92,alpha))
		if mode == "slash_hit":
			draw_line(Vector2(-35,40)*scale_size,Vector2(40,-45)*scale_size,Color(0.8,1,1,alpha),7*(1-t)+1)
		if mode == "counter_hit": arc_band(Vector2.ZERO,25+t*55,0,TAU,Color(1,0.4,0.75,alpha),4)
	elif mode.begins_with("spark_"):
		var index := int(mode.trim_prefix("spark_"))
		var direction := Vector2.from_angle(-2.7+index*0.73)
		var position := direction*t*95*scale_size+Vector2(0,t*t*45)
		draw_line(position,position-direction*13*(1-t),Color(1,0.86,0.48,alpha),3)
	elif mode == "guard":
		arc_band(Vector2.ZERO,25+t*22,-1.6,1.6,Color(0.4,0.8,1,alpha),4)
		for i in range(3): draw_line(Vector2(0,-18+i*18),Vector2(16+14*t,-11+i*18),Color(0.7,0.95,1,alpha),2)
	elif mode in ["slash","uppercut","kick","spin"]:
		var start := -2.0+t*2 if mode != "uppercut" else -0.2-t*1.8
		arc_band(Vector2(15,-5),48+t*25,start,start+2.1,color,7*scale_size)
	elif mode in ["dash","shield"]:
		for i in range(6):
			var y := -42+i*15
			draw_line(Vector2(-80-t*100,y),Vector2(25-t*10,y-5),Color(color,alpha*0.65),3+(i%2))
		if mode == "shield": arc_band(Vector2(42,0),45,-1.5,1.5,Color(0.7,0.9,1,alpha),5)
	elif mode in ["sonic","charge","counter"]:
		for i in range(3):
			var radius := 18+i*17+t*38
			arc_band(Vector2.ZERO,radius,0,TAU,color,3)
	elif mode == "shard":
		for i in range(5):
			var position := Vector2.from_angle(-PI+i*PI/4)*(20+t*65)
			draw_colored_polygon(PackedVector2Array([position+Vector2(0,-12),position+Vector2(-7,5),position+Vector2(8,5)]),Color(1,0.75,0.24,alpha))
	elif mode in ["quake","land"]:
		for i in range(3):
			var radius := 25+i*18+t*95
			draw_arc(Vector2(0,50),radius,PI,TAU,14,Color(1,0.75,0.3,alpha),4)
		for i in range(7):
			var x := (i-3)*(10+t*23)
			var y := 52-sin(t*PI)*(18+(i%3)*13)
			draw_rect(Rect2(x,y,8,7),Color(0.65,0.52,0.35,alpha))
	elif mode in ["dust","leap"]:
		for i in range(4):
			draw_circle(Vector2(-i*12-t*40,-sin(t*PI)*12),4+i*2,Color(0.7,0.66,0.52,alpha*0.45))
	elif mode == "slime":
		for i in range(5): draw_circle(Vector2(10+i*14*t,-20+sin(i*2.0)*t*30),8-i,Color(0.8,0.8,0.18,alpha))
	elif mode == "box":
		draw_line(Vector2(-15,15),Vector2(45+t*50,-25),color,5)
	elif mode == "ca":
		arc_band(Vector2.ZERO,45+t*180,0,TAU,Color(color,alpha*0.75),8)
		for i in range(12):
			var direction := Vector2.from_angle(i*TAU/12)
			draw_line(direction*(25+t*80),direction*(80+t*190),Color(1,1,0.8,alpha),3)
	draw_set_transform(Vector2.ZERO)

func draw_projectile(p: Dictionary) -> void:
	if p.delay > 0: return
	var at: Vector2 = p.position
	var direction := 1.0 if p.velocity.x >= 0 else -1.0
	var color: Color = R.COLORS[int(p.kind)]
	draw_set_transform(at,0,Vector2(direction,1))
	if p.kind == 0:
		for i in range(4):
			arc_band(Vector2(-i*13,0),16+i*4,-1.3,1.3,Color(color,1-i*0.18),4)
		draw_circle(Vector2(6,0),5,Color("e8ffff"))
	elif p.kind == 2:
		if p.trap:
			for i in range(3):
				var x := (i-1)*12.0
				draw_colored_polygon(PackedVector2Array([Vector2(x-7,8),Vector2(x,-12+(i%2)*6),Vector2(x+8,8)]),Color("eeb448"))
			draw_line(Vector2(-27,9),Vector2(27,9),Color("ffe9a3"),2)
		else:
			draw_set_transform(at,float(p.age)*8,Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(-18,13),Vector2(0,-23 if not p.flat else -4),Vector2(20,13)]),Color("d1a670") if p.flat else Color("ffd06b"))
			draw_line(Vector2(-14,9),Vector2(0,-18 if not p.flat else -1),Color("fff3bd"),2)
	elif p.kind == 3:
		for i in range(4): draw_circle(Vector2(-i*11,sin(clock*18+i)*5),18-i*3,Color(0.85,0.85,0.2,1-i*0.18))
	elif p.kind == 5:
		draw_set_transform(at,float(p.age)*3,Vector2.ONE)
		draw_rect(Rect2(-22,-18,44,36),Color("d8a82b"))
		draw_rect(Rect2(-22,-18,44,36),Color("ffdc6a"),false,3)
		draw_line(Vector2(-22,0),Vector2(22,0),Color("685329"),4)
	draw_set_transform(Vector2.ZERO)
