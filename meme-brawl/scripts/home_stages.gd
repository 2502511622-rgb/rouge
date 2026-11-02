extends RefCounted
## Decorative only: no collision bodies, damage, or projectile registration.
const NAMES = ["破碎迁徙冰原", "乱石伏击谷", "零食荒原", "腐臭沼泽洼地", "枯寂黄土坡", "扭曲外卖街巷"]
const SKY = ["8b9ea5","403b38","afa99a","444a2d","b59b66","394857"]
const GROUND = ["92b8be","655347","c4ad7b","4d5332","aa7e42","565965"]
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

func rock(x: float,y: float,w: float,h: float,color: Color) -> void:
	poly([Vector2(x-w*.5,y),Vector2(x-w*.38,y-h*.7),Vector2(x+w*.12,y-h),Vector2(x+w*.44,y-h*.62),Vector2(x+w*.5,y)],color)
	poly([Vector2(x-w*.38,y-h*.7),Vector2(x+w*.12,y-h),Vector2(x+w*.06,y-h*.2)],color.lightened(.12))
	line(Vector2(x-w*.3,y-h*.68),Vector2(x+w*.08,y-h*.9),color.lightened(.25),3)
	for i in range(14):
		var px := x-w*.22+fposmod(i*13.7,w*.45)
		var py := y-h*.16-fposmod(i*17.3,h*.45)
		box(px,py,3+(i%3)*2,2,color.lightened(.05) if i%2 else color.darkened(.06))

func hill(x: float,y: float,w: float,h: float,color: Color) -> void:
	for i in range(20):
		var height := pow(sin((i+.5)*PI/20),.8)*h
		box(x-w*.5+i*w/20,y-height,w/20+2,height,color)

func chip(x: float,y: float,size: float,angle: float, color: Color) -> void:
	var a := Vector2(-size*.6,size*.3).rotated(angle)+Vector2(x,y)
	var b := Vector2(size*.1,-size*.8).rotated(angle)+Vector2(x,y)
	var c := Vector2(size*.65,size*.35).rotated(angle)+Vector2(x,y)
	poly([a,b,c],color)
	line(a,b,color.lightened(.3),4)
	line(b,c,color.darkened(.25),5)
	line(a.lerp(b,.4),a.lerp(c,.65),color.darkened(.15),2)

func penguin(x: float,y: float,scale: float,alpha: float) -> void:
	var gray := Color(.65,.72,.74,alpha)
	ellipse(Vector2(x,y-20*scale),Vector2(24,35)*scale,gray)
	ellipse(Vector2(x,y-35*scale),Vector2(22,17)*scale,gray.lightened(.08))
	poly([Vector2(x-14*scale,y-28*scale),Vector2(x-22*scale,y),Vector2(x+13*scale,y-2*scale)],Color(.24,.32,.36,alpha*.7))
	box(x+9*scale,y-35*scale,7*scale,4*scale,Color(.83,.8,.65,alpha))
	box(x-9*scale,y,8*scale,3*scale,gray)
	box(x+4*scale,y,8*scale,3*scale,gray)

func paint(target: CanvasItem) -> void:
	canvas = target
	if stage < 0: reset(arena.stage)
	box(0,0,1152,648,Color(SKY[stage]))
	match stage:
		0: ice()
		1: canyon()
		2: snacks()
		3: swamp()
		4: loess()
		5: street()
	for drop in drops:
		if stage == 2: chip(drop.x+sin(clock)*13,drop.y,drop.size,clock*.25,Color("e7bb71"))
		else: rock(drop.x,drop.y,drop.size,drop.size*1.2,Color("cee4e6") if stage == 0 else Color("7c6b5b"))
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

func floor_base(color: Color) -> void:
	box(0,454,1152,194,color)
	for i in range(170):
		var x := float((i*173)%1152)
		var y := float(464+(i*47)%181)
		box(x,y,4+(i%4)*4,2,color.lightened(.08) if i%2 == 0 else color.darkened(.09))

func ice() -> void:
	for layer in range(3):
		for i in range(8):
			var x := float(i*190-70+layer*38)
			hill(x,450-layer*28,320,80+(i*37)%70,Color("a7b8bb").darkened(layer*.045))
	# Multiple fog bands soften the mountain edges.
	for i in range(12): box(0,300+i*12,1152,14,Color(.66,.74,.76,.10))
	for i in range(14): penguin(48+i*80+sin(clock*.6+i)*9,434+(i%3)*4,.75,.22)
	floor_base(Color("88aeb7"))
	# Black melt pools open slowly between separate slabs, not under collision.
	for i in range(8):
		var x := float(40+i*157)
		var y := float(468+(i*31)%145)
		ellipse(Vector2(x,y),Vector2(65+sin(clock*.13+i)*22,15+sin(clock*.13+i)*6),Color("253f4a"))
	for i in range(15):
		var x := float(i*91-20)
		var y := float(473+(i*37)%132)
		poly([Vector2(x,y),Vector2(x+12,y-24),Vector2(x+66,y-19),Vector2(x+85,y+8),Vector2(x+43,y+19)],Color("bbd3d5").darkened((i%3)*.045))
		line(Vector2(x+12,y-24),Vector2(x+66,y-19),Color("e2e9e2"),3)
		line(Vector2(x+43,y+19),Vector2(x+85,y+8),Color("627f91"),4)
	for i in range(30):
		var x := float(66+(i*97)%1020)
		var y := float(466+(i*13)%165)
		box(x,y,5,3,Color("68858e"))
		box(x+8,y+5,5,3,Color("68858e"))
	for i in range(6):
		var x := float(130+i*175)
		var y := 345+sin(clock*.6+i)*9
		poly([Vector2(x,y),Vector2(x+12,y-26),Vector2(x+28,y+4),Vector2(x+15,y+30)],Color("bfd6dc"))
	for i in range(45):
		var x := fposmod(i*83+clock*(7+i%4),1152)
		var y := fposmod(i*37+clock*(12+i%6),510)
		box(x,y,4+(i%2)*2,4,Color(.89,.95,.94,.42))

func canyon() -> void:
	for i in range(9):
		var x := float(i*155-25)
		rock(x,458,220,190+(i*97)%170,Color("514743").darkened((i%3)*.1))
		rock(x+40,440,100,115+(i*37)%130,Color("68554b"))
	poly([Vector2(890,80),Vector2(960,80),Vector2(690,510),Vector2(480,510)],Color(.91,.73,.37,.09))
	floor_base(Color("695246"))
	for i in range(15):
		var x := float(30+i*82)
		var y := float(472+(i*43)%157)
		if i%3 == 0: rock(x,y-38-sin(clock*.45+i)*8,48,37,Color("786354"))
		else: rock(x,y,40+(i%4)*16,24+(i%3)*18,Color("7c6758"))
	for i in range(33):
		var x := float(24+(i*139)%1100)
		var y := float(285+(i*59)%340)
		var color := Color("eaba65") if pulse > 0 else Color("463a36")
		line(Vector2(x,y),Vector2(x+24,y-14),color,3)
		line(Vector2(x+7,y+5),Vector2(x+31,y-10),color,2)
	for i in range(34):
		var x := float(20+(i*37)%130) if i%2 == 0 else float(1000+(i*47)%145)
		line(Vector2(x,512),Vector2(x-11+(i%4)*6,486-(i%3)*7),Color("9a8655"),3)
	var phase := fposmod(clock,13.0)
	if phase > 10 and phase < 10.7:
		var x := 1150-(phase-10)*1100
		ellipse(Vector2(x,412),Vector2(28,10),Color("252c2b"))
		line(Vector2(x-10,411),Vector2(x-25,398),Color("252c2b"),4)

func snacks() -> void:
	for i in range(10): rock(i*160-80,452,250,65+(i*37)%50,Color("b8b29f"))
	for i in range(5):
		var x := float(90+i*235)
		line(Vector2(x,461),Vector2(x+17,351),Color("8e8060"),13)
		line(Vector2(x+14,393),Vector2(x-21,365),Color("8e8060"),9)
		for j in range(3):
			rock(x-28+j*30,361-j*9,64,38,Color("c6b17e"))
			for k in range(3): box(x-35+j*30+k*12,340-j*9,4,4,Color("9b885e"))
	floor_base(Color("c4b38a"))
	for i in range(16):
		var x := float(24+(i*157)%1140)
		var y := float(473+(i*43)%157)
		var size := float(35+(i%4)*14)
		var angle := sin(i*1.9)*.9
		if burst > 0: angle = lerpf(angle,-PI*.5,minf(1,burst*2))
		chip(x,y,size,angle,Color("dcaf69").darkened((i%3)*.06))
		# Angular bite marks carve the outer silhouette.
		box(x+size*.25,y-size*.2,9,8,Color("c4b38a"))
	for i in range(40):
		var x := fposmod(i*67+clock*(9+i%5),1152)
		box(x,475+(i*37)%160+sin(clock*2+i)*3,5,3,Color("e4c58b"))

func swamp() -> void:
	for i in range(8):
		var x := float(20+i*163)
		var y := float(440-(i%3)*12)
		line(Vector2(x,y),Vector2(x-21,292+(i%3)*25),Color("30392b"),18)
		line(Vector2(x-15,y-72),Vector2(x+35,y-125),Color("30392b"),9)
		line(Vector2(x-20,y-102),Vector2(x-55,y-139),Color("30392b"),7)
	floor_base(Color("303d2c"))
	for i in range(22):
		var x := float((i*113)%1152)
		var y := float(465+(i*37)%171)
		var surge := sin(clock*(8 if burst > 0 else 1.1)+i)*(9 if burst > 0 else 2)
		ellipse(Vector2(x,y+surge),Vector2(90+(i%3)*20,18),Color("70783b").darkened((i%3)*.08))
		line(Vector2(x-28,y+surge),Vector2(x+20,y+surge-3),Color("93924a"),2)
		if i%3 == 0:
			ellipse(Vector2(x,y-7+surge),Vector2(44,26+sin(clock+i)*4),Color("655b3a"))
		elif i%3 == 1:
			poly([Vector2(x-22,y),Vector2(x-15,y-14),Vector2(x+20,y-9),Vector2(x+6,y+4),Vector2(x,y-4)],Color("727343"))
	for i in range(32 if burst > 0 else 12):
		var phase := fposmod(clock*(2 if burst > 0 else .4)+i*.37,1.0)
		var at := Vector2(30+(i*101)%1100,470+(i*31)%155)
		var r := 3+phase*9
		canvas.draw_arc(at,r,0,TAU,12,Color(.67,.71,.28,(1-phase)*.65),2,false)
		if burst > 0:
			box(at.x,at.y-phase*95,5,8,Color(.7,.73,.32,1-phase))
	for i in range(25):
		var x := float((i*139)%1152)
		var y := float(475+(i*17)%170)
		line(Vector2(x,y),Vector2(x+sin(clock+i)*7-12,y-35),Color("727d43"),4)
		line(Vector2(x-10,y-28),Vector2(x+10,y-42),Color("727d43"),3)

func loess() -> void:
	for layer in range(3):
		for i in range(7): hill(i*220-40+layer*55,457-layer*22,340,52+(i*31+layer*17)%32,Color("b59a67").darkened(layer*.055))
	floor_base(Color("b38a4e"))
	rock(590,476,160,172,Color("8b734f"))
	for i in range(35):
		var x := float((i*193)%1152)
		var y := float(464+(i*37)%180)
		var size := 14+crack*10
		line(Vector2(x,y),Vector2(x+size,y-8),Color("745b38"),2)
		line(Vector2(x+size,y-8),Vector2(x+size*1.4,y-3),Color("745b38"),2)
		line(Vector2(x+size,y-8),Vector2(x+size*1.3,y-21-crack*5),Color("745b38"),2)
	for i in range(12):
		var at := Vector2(60+(i*193)%1080,476+(i*31)%155)
		ellipse(at-Vector2(9,0),Vector2(13,20),Color("927040"))
		ellipse(at+Vector2(9,0),Vector2(13,20),Color("927040"))
	for fighter in arena.fighters:
		if fighter.kind == 4 and fighter.charging:
			var alpha: float = .10+fighter.charge*.045
			var color := Color(1,.87,.32,alpha)
			ellipse(Vector2(740,316),Vector2(92,115),color)
			poly([Vector2(692,357),Vector2(785,340),Vector2(843,472),Vector2(636,472)],color)
			line(Vector2(688,375),Vector2(635,405),color,24)
			line(Vector2(788,368),Vector2(825,401),color,24)
	for i in range(18):
		box(fposmod(i*117+clock*13,1152),480+(i*31)%155,8,3,Color(.85,.68,.39,.28))

func delivery_box(x: float,y: float,w: float,h: float) -> void:
	box(x-w*.5,y-h,w,h,Color("bc922c"))
	poly([Vector2(x-w*.5,y-h),Vector2(x-w*.35,y-h-12),Vector2(x+w*.6,y-h-9),Vector2(x+w*.5,y-h)],Color("f5d354"))
	box(x-w*.5+5,y-h+6,w-10,6,Color("e9be37"))
	box(x-5,y-h+8,10,h-15,Color("d8ad32"))
	line(Vector2(x-w*.25,y-h*.5),Vector2(x+w*.22,y-h*.6),Color("665b38"),4)

func street() -> void:
	for i in range(10):
		var x := float(i*128-30)
		var height := float(195+(i*67)%165)
		poly([Vector2(x,465),Vector2(x+12,465-height),Vector2(x+112,455-height),Vector2(x+124,465)],Color("4a5862").darkened((i%3)*.07))
		for j in range(4):
			for k in range(3): box(x+24+k*25,495-height+j*39,12,20,Color("79807b").darkened((i+j)%3*.14))
		var sign_y := 420-height*.45
		box(x+14,sign_y,95,33,Color("9d5145") if i%2 else Color("d4ad35"))
		# Deliberately unreadable block glyphs, rather than misleading pseudo text.
		for j in range(5):
			line(Vector2(x+23+j*15,sign_y+6),Vector2(x+29+j*15,sign_y+25),Color("e8d598"),3)
			line(Vector2(x+20+j*15,sign_y+16),Vector2(x+30+j*15,sign_y+12),Color("e8d598"),3)
	floor_base(Color("59616a"))
	for i in range(10): box(i*140+22,578,72,5,Color("bba855"))
	for i in range(8):
		var x := float(65+i*145)
		if burst <= 0:
			delivery_box(x,474+(i%3)*16,70+(i%2)*20,48+(i%3)*15)
			if i%3 == 0: delivery_box(x-8,420,60,45)
		else:
			# Lids and panels scatter outward, then reset when the visual ends.
			var age := 2.4-burst
			for j in range(3):
				var at := Vector2(x+(j-1)*age*40,460-age*95+age*age*35)
				poly([at,at+Vector2(28,-12),at+Vector2(35,7),at+Vector2(4,17)],Color("e6ba39"))
	for i in range(4):
		var x := float(110+i*290)
		line(Vector2(x,477),Vector2(x+17,289),Color("2b343e"),9)
		line(Vector2(x+17,289),Vector2(x-26,278),Color("2b343e"),7)
		var lit := sin(clock*9+i*7)+sin(clock*23+i) > -.65
		box(x-42,278,27,9,Color("f9de5a") if lit else Color("665e3e"))
		if lit: poly([Vector2(x-42,287),Vector2(x-15,287),Vector2(x+25,470),Vector2(x-110,470)],Color(1,.84,.25,.055))
	for i in range(5):
		var x := float(85+i*230)
		var y := 253+sin(clock*.9+i)*12
		ellipse(Vector2(x,y),Vector2(36,22),Color("eac632"))
		box(x-21,y+4,43,6,Color("a58d32"))
	var phase := fposmod(clock,11)
	if phase > 8 and phase < 9:
		var x := (phase-8)*1350-100
		ellipse(Vector2(x,425),Vector2(20,32),Color(.8,.72,.29,.3))
		line(Vector2(x,433),Vector2(x+20,451),Color(.8,.72,.29,.3),5)
		canvas.draw_arc(Vector2(x-13,458),13,0,TAU,12,Color(.7,.72,.65,.25),3)
		canvas.draw_arc(Vector2(x+27,458),13,0,TAU,12,Color(.7,.72,.65,.25),3)
