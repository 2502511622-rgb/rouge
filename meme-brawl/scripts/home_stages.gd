extends RefCounted
## Decorative only: no collision bodies, damage, or projectile registration.
const NAMES = ["破碎迁徙冰原", "乱石伏击谷", "零食荒原", "腐臭沼泽洼地", "枯寂黄土坡", "扭曲外卖街巷"]
const Frames = preload("res://scripts/sprite_frames.gd")
const IDS = ["gugu","dog","cat","naiwa","niulai","kangaroo"]
var backgrounds: Array[Texture2D] = []
var props: Array[AtlasTexture] = []
var backdrop: Sprite2D
var backdrop_material: ShaderMaterial
var clock := 0.0
var pulse := 0.0
var burst := 0.0
var crack := 0.0
var stage := -1
var drops: Array = []
var sparks: Array = []
var shocks: Array = []
var next_drop := 1.0
var next_echo := 9.0
var rng := RandomNumberGenerator.new()
var canvas: CanvasItem
var arena: Node2D

func _init() -> void:
	rng.seed = 631176

func prepare_art() -> void:
	for id in IDS: backgrounds.append(load("res://assets/art/stages/%s.png" % id))
	var sheet: Texture2D = load("res://assets/art/stages/props.png")
	var regions = [[20,38,520,474],[540,48,494,445],[1060,50,460,475],[24,560,512,406],[540,530,490,440],[1050,540,470,440]]
	for bounds in regions:
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
		texture.filter_clip = true
		props.append(texture)
	backdrop = Sprite2D.new()
	backdrop.name = "PaintedStageBackdrop"
	backdrop.centered = false
	backdrop.z_index = -10
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop_material = ShaderMaterial.new()
	backdrop_material.shader = preload("res://scripts/stage_backdrop.gdshader")
	backdrop.material = backdrop_material
	arena.add_child(backdrop)

func update_backdrop() -> void:
	if backdrop == null: return
	backdrop.visible = arena.screen in ["fight","result"]
	backdrop.texture = backgrounds[stage]
	backdrop.scale = Vector2(1152.0/backgrounds[stage].get_width(),648.0/backgrounds[stage].get_height())
	backdrop_material.set_shader_parameter("stage_kind",stage)
	backdrop_material.set_shader_parameter("stage_clock",clock)
	backdrop_material.set_shader_parameter("surge",minf(1,burst))

func reset(value: int) -> void:
	stage = value
	clock = 0
	pulse = 0
	burst = 0
	crack = 0
	drops.clear()
	sparks.clear()
	shocks.clear()
	next_drop = rng.randf_range(1.0,3.0)
	next_echo = rng.randf_range(8,14)
	update_backdrop()

func skill(kind: int) -> void:
	if stage == 1 and kind == 1: pulse = 1.3

func ca(kind: int) -> void:
	if stage == kind and kind in [2,3,5]:
		burst = 2.4
		if kind == 5:
			for i in range(32):
				spawn_spark(Vector2(80+(i%8)*142,420+(i%3)*28),Vector2(rng.randf_range(-150,150),rng.randf_range(-220,-65)),"f5c632",2.2)

func heavy(kind: int, at: Vector2) -> void:
	if stage != 4 or kind != 4: return
	crack = 1.5
	for i in range(14): spawn_spark(Vector2(at.x,534),Vector2(rng.randf_range(-110,110),rng.randf_range(-90,-30)),"d8b674",.8)

func spawn_spark(at: Vector2, velocity: Vector2, color: String, life: float) -> void:
	if sparks.size() >= 80: sparks.pop_front()
	sparks.append({"at":at,"v":velocity,"color":Color(color),"life":life,"max":life})

func tick(dt: float) -> void:
	if stage != arena.stage: reset(arena.stage)
	update_backdrop()
	if arena.paused or arena.show_help or not arena.screen in ["fight","result"]: return
	clock += dt
	pulse = maxf(0,pulse-dt)
	burst = maxf(0,burst-dt)
	crack = maxf(0,crack-dt)
	next_drop -= dt
	next_echo -= dt
	if next_echo <= 0:
		next_echo = rng.randf_range(10,18)
		if stage in [0,3]: arena.character_audio.ambient(stage)
	if next_drop <= 0:
		next_drop = rng.randf_range(1.7,4.9)
		if stage in [0,1,2]:
			drops.append({"x":rng.randf_range(70,1080),"y":80.0,"speed":rng.randf_range(35,60) if stage == 2 else rng.randf_range(100,190),"size":rng.randf_range(12,23)})
		elif stage == 3:
			for i in range(5): spawn_spark(Vector2(rng.randf_range(100,1050),480),Vector2(rng.randf_range(-35,35),rng.randf_range(-110,-50)),"a7b840",1.0)
	for drop in drops:
		drop.y += drop.speed*dt
		if stage != 2: drop.speed += dt*150
		if drop.y >= 520:
			if stage == 0: shocks.append({"at":Vector2(drop.x,526),"life":.7})
			drop.y = 1000
			for i in range(8): spawn_spark(Vector2(drop.x,526),Vector2((i-3.5)*18,-rng.randf_range(18,42)),"c5e6e8" if stage == 0 else ("c9a15e" if stage == 2 else "a59078"),.65)
	drops = drops.filter(func(d): return d.y < 700)
	for shock in shocks: shock.life -= dt
	shocks = shocks.filter(func(p): return p.life > 0)
	for part in sparks:
		part.life -= dt
		part.at += part.v*dt
		part.v.y += dt*140
	sparks = sparks.filter(func(p): return p.life > 0)

func box(x: float,y: float,w: float,h: float,color: Color) -> void:
	canvas.draw_rect(Rect2(roundf(x/2)*2,roundf(y/2)*2,w,h),color)

func poly(points: Array,color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points),color)

func line(a: Vector2,b: Vector2,color: Color,width := 2.0) -> void:
	canvas.draw_line(a.snapped(Vector2(2,2)),b.snapped(Vector2(2,2)),color,width,false)

func ellipse(at: Vector2, size: Vector2, color: Color) -> void:
	# Stepped silhouette matches the isolated pixel fighter sprites.
	box(at.x-size.x*.4,at.y-size.y*.5,size.x*.8,size.y,color)
	box(at.x-size.x*.5,at.y-size.y*.3,size.x,size.y*.6,color)

func prop(index: int, at: Vector2, width: float, angle := 0.0, tint := Color.WHITE, stretch := 1.0) -> void:
	var texture := props[index]
	var height := width*texture.get_height()/texture.get_width()
	canvas.draw_set_transform(at.snapped(Vector2(1,1)),angle,Vector2(1,stretch))
	canvas.draw_texture_rect(texture,Rect2(-width*.5,-height,width,height),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)

func paint(target: CanvasItem) -> void:
	canvas = target
	if stage < 0: reset(arena.stage)
	match stage:
		0: ice_details()
		1: canyon_details()
		2: snack_details()
		3: swamp_details()
		4: loess_details()
		5: street_details()
	for drop in drops:
		prop(0 if stage == 2 else (2 if stage == 0 else 5),Vector2(drop.x+sin(clock)*6,drop.y),drop.size*1.65,clock*.2 if stage == 2 else clock*.5)
	for shock in shocks:
		var age: float = .7-shock.life
		for i in range(24):
			var a: Vector2 = shock.at+Vector2(cos(i*TAU/24)*age*75,sin(i*TAU/24)*age*16)
			var b: Vector2 = shock.at+Vector2(cos((i+1)*TAU/24)*age*75,sin((i+1)*TAU/24)*age*16)
			line(a,b,Color(.8,.95,.96,shock.life),2)
	for part in sparks:
		var tint: Color = part.color
		tint.a *= part.life/part.max
		box(part.at.x,part.at.y,6,4,tint)
	# Keep foreground contrast stable for the fighters and HUD.
	box(0,540,1152,108,Color(0.02,0.025,0.035,.24))

func ice_details() -> void:
	for i in range(35):
		box(fposmod(i*83+clock*(7+i%4),1152),fposmod(i*37+clock*(12+i%6),515),2+(i%2),2,Color(.9,.96,.98,.35))
	for i in range(3):
		prop(2,Vector2(190+i*380,310+sin(clock*.6+i)*9),25+i*3,0,Color(.8,.91,1,.65))
	var pose: Dictionary = Frames.get_frame("gugu_actions.png",0)
	for i in range(7):
		var rect := Rect2(140+i*127+sin(clock*.6+i)*7,278+(i%3)*8,22,26)
		canvas.draw_texture_rect(pose.texture,Frames.fit_rect(pose,rect),false,Color(.64,.75,.85,.22))
	for i in range(4):
		var at := Vector2(80+i*297,513+(i%2)*17)
		var size := 13+sin(clock*.13+i)*6
		ellipse(at,Vector2(size*2.5,4),Color(.1,.24,.3,.28))
		line(at-Vector2(size,2),at+Vector2(size,2),Color(.65,.85,.9,.3),1)

func canyon_details() -> void:
	if pulse > 0:
		for i in range(3):
			for side in [0,1]:
				var x: float = 18+side*965+i*16
				var y := 268+i*18
				line(Vector2(x,y),Vector2(x+105,y-59),Color(1,.6,.25,pulse*.12),9)
				line(Vector2(x,y),Vector2(x+105,y-59),Color(1,.85,.55,pulse*.7),2)
	var phase := fposmod(clock,13)
	if phase > 10 and phase < 10.7:
		var x := 1050-(phase-10)*1100
		ellipse(Vector2(x,396),Vector2(24,9),Color(.1,.13,.15,.65))
		line(Vector2(x-10,395),Vector2(x-21,386),Color(.1,.13,.15,.65),3)

func snack_details() -> void:
	var lift := smoothstep(0,1,minf(2.4-burst,burst)*3) if burst > 0 else 0.0
	prop(0,Vector2(68,482),148,lerpf(-.35,0,lift),Color(.94,.86,.73,1),lerpf(.72,1,lift))
	prop(0,Vector2(1090,480),155,lerpf(.29,0,lift),Color(.94,.86,.73,1),lerpf(.68,1,lift))
	for i in range(13):
		var x := float(35+(i*191)%1100)
		var y := float(435+(i*29)%138)
		var width := float(24+(i%4)*18)
		var angle := sin(i*2.1)*1.1
		var rise := smoothstep(0,1,minf(2.4-burst,burst)*3) if burst > 0 else 0.0
		prop(0,Vector2(x,y),width,lerpf(angle,0,rise),Color(.95,.87,.72,1),lerpf(.4,1,rise))
	for i in range(24):
		box(fposmod(i*91+clock*(8+i%5),1152),490+(i*27)%85+sin(clock*2+i)*2,3,2,Color(.88,.72,.43,.45))

func swamp_details() -> void:
	for i in range(5):
		prop(3,Vector2(70+i*254,429+(i%2)*21),40+(i%3)*10,0,Color(.78,.85,.58,.65),1+sin(clock+i)*.035)
	for i in range(30 if burst > 0 else 10):
		var phase := fposmod(clock*(2 if burst > 0 else .35)+i*.37,1.0)
		var at := Vector2(60+(i*113)%1040,300+(i*31)%140)
		canvas.draw_arc(at,2+phase*7,0,TAU,12,Color(.77,.83,.39,(1-phase)*.6),1,false)
		box(at.x-2,at.y-3,2,2,Color(.9,.91,.57,(1-phase)*.65))
		if burst > 0: box(at.x,at.y-phase*65,3,5,Color(.77,.83,.39,1-phase))

func loess_details() -> void:
	if crack > 0:
		for i in range(12):
			var at := Vector2(90+(i*193)%1000,504+(i*37)%100)
			line(at,at+Vector2(26+crack*12,-8),Color(.27,.19,.1,crack*.3),2)
			line(at+Vector2(25,-8),at+Vector2(44,-21-crack*5),Color(.27,.19,.1,crack*.25),2)
	for fighter in arena.fighters:
		if fighter.kind == 4 and fighter.charging:
			var color := Color(1,.89,.47,.07+fighter.charge*.035)
			ellipse(Vector2(745,290),Vector2(65,80),color)
			poly([Vector2(712,318),Vector2(775,311),Vector2(808,424),Vector2(676,424)],color)
			line(Vector2(713,334),Vector2(675,358),color,17)
			line(Vector2(777,328),Vector2(810,355),color,17)
	for i in range(15): box(fposmod(i*117+clock*13,1152),470+(i*31)%140,4,2,Color(.9,.75,.44,.23))

func street_details() -> void:
	var stack = [Vector3(40,447,90),Vector3(115,447,84),Vector3(183,441,73),Vector3(69,383,79),Vector3(139,384,70),Vector3(103,330,65),Vector3(1110,447,92),Vector3(1035,448,85),Vector3(964,442,72),Vector3(1080,382,80),Vector3(1007,385,71),Vector3(1045,330,66)]
	for i in range(stack.size()):
		var item: Vector3 = stack[i]
		var direction := -1.0 if i < 6 else 1.0
		var age := 2.4-burst if burst > 0 else 0.0
		var travel := age*(70+(i%3)*13) if burst > 0 else 0.0
		prop(1,Vector2(item.x+direction*travel,item.y-travel*1.6+age*age*24),item.z,direction*age*.8,Color(1,1,1,maxf(0,1-age*.4)))
	for i in range(3):
		prop(4,Vector2(272+i*304,205+sin(clock*.9+i)*8),28,0,Color(.9,.91,.95,.9))
	# Flicker at existing painted lamps, instead of drawing duplicate streetlights.
	for light in [Vector2(142,100),Vector2(550,205),Vector2(714,217),Vector2(1071,160)]:
		var flicker := .04 if sin(clock*13+light.x)+sin(clock*29) > -.4 else .0
		ellipse(light,Vector2(52,35),Color(1,.78,.24,flicker))
	var phase := fposmod(clock,11)
	if phase > 8 and phase < 9:
		var x := (phase-8)*850+130
		ellipse(Vector2(x,368),Vector2(15,24),Color(.74,.66,.33,.22))
		for offset in [-10,19]: canvas.draw_arc(Vector2(x+offset,390),10,0,TAU,12,Color(.65,.7,.76,.25),2)
