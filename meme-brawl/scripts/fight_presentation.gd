extends Node2D
## Original arcade presentation. Every displayed gauge reads real combat state.

const ArcadeArt = preload("res://scripts/arcade_skin.gd")
const Frames = preload("res://scripts/sprite_frames.gd")
const R = preload("res://scripts/roster.gd")
const CJK = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
const DISPLAY = preload("res://assets/fonts/ArcadeDisplay.ttf")
const INK = Color("0b1018")
const CYAN = Color("5acbff")
const PINK = Color("ff6548")
const GOLD = Color("ffd34c")
var arena: Node2D
var life_trail := [1.0,1.0]
var last_life := [1.0,1.0]
var trail_delay := [0.0,0.0]
var clock := 0.0
var selection_age := 1.0

func reset() -> void:
	life_trail = [1.0,1.0]
	last_life = [1.0,1.0]
	trail_delay = [0.0,0.0]

func update_gauges(dt: float) -> void:
	if arena.fighters.size() != 2: return
	for side in range(2):
		var f = arena.fighters[side]
		var ratio: float = clampf(f.hp/R.HP[f.kind],0,1)
		if ratio < last_life[side]: trail_delay[side] = 0.35
		elif ratio > last_life[side]: life_trail[side] = ratio
		last_life[side] = ratio
		trail_delay[side] = maxf(0,trail_delay[side]-dt)
		if trail_delay[side] <= 0:
			life_trail[side] = move_toward(life_trail[side],ratio,dt*0.65)

func _process(dt: float) -> void:
	if arena == null: return
	clock += dt
	selection_age = minf(1,selection_age+dt*4)
	if not arena.paused and not arena.show_help: update_gauges(dt)
	queue_redraw()

func label(at: Vector2, value: String, size := 18, color := Color.WHITE, display := false) -> void:
	if display and size >= 26: draw_string(DISPLAY,at+Vector2(3,4),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0,0,color.a*0.7))
	draw_string(DISPLAY if display else CJK,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func middle(y: float, value: String, size := 24, color := Color.WHITE, display := false) -> void:
	var font = DISPLAY if display else CJK
	var width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	label(Vector2((1152-width)/2,y),value,size,color,display)

func middle_fit(y: float, value: String, width: float, size: int, color: Color) -> void:
	while size > 10 and CJK.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width: size -= 1
	middle(y,value,size,color)

func right(at: Vector2, value: String, size := 18, color := Color.WHITE, display := false) -> void:
	var font = DISPLAY if display else CJK
	var width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	label(at-Vector2(width,0),value,size,color,display)

func cut_panel(rect: Rect2, color: Color, notch := 10.0) -> void:
	var p := rect.position
	var e := rect.end
	draw_colored_polygon(PackedVector2Array([p+Vector2(notch,0),Vector2(e.x,p.y),e-Vector2(notch,0),Vector2(p.x,e.y)]),color)

func actor(kind: int, rect: Rect2, special := false, mirrored := false) -> void:
	if mirrored: draw_set_transform(Vector2(rect.get_center().x*2,0),0,Vector2(-1,1))
	var duo: bool = kind in [0,2]
	var sheet := ("gugu_actions.png" if kind == 0 else "cat_actions.png") if duo else "meme_fighters_atlas.png"
	var index := (10 if special else 0) if duo else kind+(18 if special else 0)
	var pose: Dictionary = Frames.get_frame(sheet,index)
	draw_texture_rect(pose.texture,Frames.fit_rect(pose,rect),false)
	if kind == 2 and not special:
		for chip in Frames.attachments(pose,rect,true):
			draw_colored_polygon(chip,GOLD)

	if mirrored: draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if arena == null: return
	if arena.paused or arena.show_help: return
	if arena.screen == "select":
		draw_selection()
		return
	if arena.paused or arena.show_help: return
	if arena.fighters.size() != 2: return
	draw_hud()
	if arena.screen == "result": draw_result()
	elif arena.intro_time > 0: draw_intro()
	elif arena.cinematic > 0: draw_ca()
	elif arena.banner_time > 0:
		cut_panel(Rect2(376,154,400,36),Color(0.04,0.03,0.09,0.74))
		middle(180,arena.banner,19,arena.banner_color)
	if arena.demo_mode:
		cut_panel(Rect2(384,514,384,27),Color(0.04,0.03,0.09,0.88))
		middle(534,"SHOWCASE  %02d / 72s  ·  Enter 跳片段  ·  Esc 退出" % int(arena.demo_clock),13,GOLD)
		draw_rect(Rect2(0,645,1152*clampf(arena.demo_clock/72,0,1),3),PINK)

func draw_selection() -> void:
	var rival_kind: int = arena.preview_rival()
	ArcadeArt.backdrop(self,clock)
	label(Vector2(32,40),"MEME / BRAWL",23,ArcadeArt.PAPER,true)
	draw_rect(Rect2(12,21,7,24),ArcadeArt.EMBER)
	label(Vector2(32,104),"CHARACTER SELECT",43,ArcadeArt.PAPER,true)
	for i in range(3):
		var rect: Rect2 = arena.menu_rect("mode"+str(i))
		var active: bool = arena.mode_index == i
		var hovered: bool = arena.hovered_menu == "mode"+str(i)
		if hovered and not active: draw_line(rect.position+Vector2(10,50),rect.end-Vector2(10,3),ArcadeArt.EMBER,1)
		if active:
			cut_panel(rect,Color("29303a"),8)
			draw_rect(Rect2(rect.position+Vector2(5,48),Vector2(136,4)),ArcadeArt.EMBER)
		label(rect.position+Vector2(10,25),["VERSUS","ARCADE","TRAINING"][i],18,ArcadeArt.PAPER if active or hovered else ArcadeArt.MUTED,true)
		label(rect.position+Vector2(10,43),["自由对战","食物链巡回","练习与演练"][i],11,ArcadeArt.EMBER if active else ArcadeArt.MUTED)
	var slide := pow(1-selection_age,3)*25
	label(Vector2(-12,360),"01",190,Color(0.2,0.65,1,0.045),true)
	right(Vector2(1164,360),"02",190,Color(1,0.45,0.15,0.045),true)
	draw_colored_polygon(PackedVector2Array([Vector2(0,450),Vector2(300,137),Vector2(324,137),Vector2(24,450)]),Color(0.1,0.65,1,0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(852,137),Vector2(876,137),Vector2(1152,450),Vector2(1128,450)]),Color(1,0.3,0.1,0.12))
	label(Vector2(32,144),"PLAYER 01",13,CYAN,true)
	right(Vector2(1120,144),"CPU CHALLENGER",13,PINK,true)
	actor(arena.selected,Rect2(20-slide,153,365,274))
	actor(rival_kind,Rect2(767+slide,153,365,274),false,true)
	label(Vector2(32,458),R.NAMES[arena.selected],35,ArcadeArt.PAPER)
	right(Vector2(1120,458),R.NAMES[rival_kind],35,ArcadeArt.PAPER)
	label(Vector2(34,480),R.ROLES[arena.selected],13,CYAN)
	right(Vector2(1118,480),R.ROLES[rival_kind],13,PINK)
	middle(194,"THE FOOD CHAIN NEVER ENDS",11,ArcadeArt.MUTED,true)
	cut_panel(Rect2(517,211,119,114),Color("71331c"),37)
	middle(306,"VS",91,ArcadeArt.EMBER,true)
	middle(354,["自由交锋 / 先胜两回合","五人巡回 / 食物链挑战","无限资源 / 角色特色演练"][arena.mode_index],15,ArcadeArt.PAPER)
	middle(382,"P1  /  CPU",12,ArcadeArt.MUTED,true)
	draw_line(Vector2(0,490),Vector2(1152,490),Color("35404c"),1)
	draw_rect(Rect2(0,491,1152,157),Color(0.015,0.025,0.04,0.82))
	label(Vector2(32,509),"ROSTER / 选择角色",12,ArcadeArt.MUTED)
	for side in range(2):
		var rect: Rect2 = arena.menu_rect("p1" if side == 0 else "cpu")
		var accent := CYAN if side == 0 else PINK
		if arena.select_target == side: draw_rect(Rect2(rect.position,Vector2(rect.size.x,2)),accent)
		label(rect.position+Vector2(7,17),"1P 选择" if side == 0 else ("CPU 自动" if arena.mode_index == 1 else "CPU 选择"),12,accent if arena.select_target == side else ArcadeArt.MUTED)
	for kind in range(6):
		var rect: Rect2 = arena.grid_rect(kind)
		var is_player: bool = kind == arena.selected
		var is_rival: bool = kind == rival_kind
		cut_panel(rect,Color("263341") if is_player or is_rival else Color("131e29"),5)
		actor(kind,Rect2(rect.position+Vector2(11,-1),Vector2(80,74)))
		label(rect.position+Vector2(5,88),R.NAMES[kind],13,ArcadeArt.PAPER)
		if is_player:
			draw_rect(Rect2(rect.position,Vector2(3,94)),CYAN)
			label(rect.position+Vector2(5,13),"1P",11,CYAN,true)
		if is_rival:
			draw_rect(Rect2(rect.position+Vector2(99,0),Vector2(3,94)),PINK)
			label(rect.position+Vector2(70,13),"CPU",10,PINK,true)
		if kind == arena.hovered_character: draw_rect(rect.grow(2),Color(1,0.8,0.45,0.7),false,1)
	var stage_rect: Rect2 = arena.menu_rect("stage")
	label(stage_rect.position+Vector2(0,13),"STAGE",10,ArcadeArt.MUTED,true)
	label(stage_rect.position+Vector2(0,37),R.STAGES[arena.stage],16,ArcadeArt.PAPER)
	label(stage_rect.position+Vector2(221,36),"›",21,ArcadeArt.EMBER)
	draw_line(stage_rect.position+Vector2(0,46),stage_rect.end-Vector2(0,3),Color("43505b"),1)
	var level_rect: Rect2 = arena.menu_rect("difficulty")
	label(level_rect.position+Vector2(0,13),"CPU LEVEL",10,ArcadeArt.MUTED,true)
	label(level_rect.position+Vector2(0,37),"标准  ›" if arena.difficulty == 1 else "激烈  ›",16,ArcadeArt.PAPER)
	draw_line(level_rect.position+Vector2(0,46),level_rect.end-Vector2(0,3),Color("43505b"),1)
	var confirm: Rect2 = arena.menu_rect("confirm")
	cut_panel(Rect2(confirm.position+Vector2(4,4),confirm.size),Color("71331c"),13)
	cut_panel(confirm,ArcadeArt.EMBER.lightened(0.1) if arena.hovered_menu == "confirm" else ArcadeArt.EMBER,13)
	label(confirm.position+Vector2(19,37),"确认出战",24,INK)
	label(confirm.position+Vector2(178,36),"ENTER",13,INK,true)
	label(confirm.position+Vector2(320+sin(clock*5)*3,40),"»",35,INK,true)
	for item in [["showcase","F3  演出"],["settings","F2  设置"],["help","F1  招式"]]:
		var rect: Rect2 = arena.menu_rect(item[0])
		label(rect.position+Vector2(4,22),item[1],13,ArcadeArt.PAPER if arena.hovered_menu == item[0] else ArcadeArt.MUTED)
	label(Vector2(32,639),"← → 角色    TAB 双方    Q/E 模式    1–6 快选",12,ArcadeArt.MUTED)
	right(Vector2(1120,639),"M 声音 "+("关闭" if arena.muted else "开启")+"    /    F2 自定义按键",11,ArcadeArt.MUTED)

func selection_wedge() -> PackedVector2Array:
	return PackedVector2Array([Vector2(790,0),Vector2(1152,0),Vector2(1152,648),Vector2(440,648)])

func v_ratio(f: Node2D) -> float:
	return clampf(f.v_meter/100 if f.kind >= 3 else 1-f.v_cooldown/7,0,1)

func meter_count(f: Node2D) -> int:
	return clampi(int(floor(f.meter)),0,3)

func draw_hud() -> void:
	draw_rect(Rect2(0,0,1152,133),Color(0.025,0.04,0.06,0.94))
	draw_line(Vector2(0,132),Vector2(1152,132),Color("4a4f56"),2)
	for side in range(2):
		var f = arena.fighters[side]
		var accent: Color = CYAN if side == 0 else PINK
		var x := 104.0 if side == 0 else 647.0
		var portrait_x := 19.0 if side == 0 else 1063.0
		cut_panel(Rect2(portrait_x,15,70,88),accent.darkened(0.75),7)
		actor(f.kind,Rect2(portrait_x-5,12,82,82))
		label(Vector2(portrait_x+12,117),"P1" if side == 0 else ("DUM" if arena.training else "CPU"),15,accent,true)
		if side == 0: label(Vector2(x,32),R.NAMES[f.kind],23,Color.WHITE)
		else: right(Vector2(x+401,32),R.NAMES[f.kind],23,Color.WHITE)
		var health := Rect2(x,43,401,28)
		cut_panel(health.grow(3),Color("6d6a60"),9)
		draw_rect(health,Color("3b2022"))
		var fraction: float = clampf(f.hp/R.HP[f.kind],0,1)
		var life_color := Color("f9da65") if fraction > 0.5 else (Color("ffb54d") if fraction > 0.25 else Color("ff5e3c"))
		var ghost: float = clampf(life_trail[side],fraction,1)
		var ghost_x := x if side == 0 else x+401*(1-ghost)
		draw_rect(Rect2(ghost_x,43,401*ghost,28),Color("ca4940"))
		var filled_x := x if side == 0 else x+401*(1-fraction)
		draw_rect(Rect2(filled_x,43,401*fraction,28),life_color)
		draw_rect(Rect2(filled_x,43,401*fraction,6),life_color.lightened(0.35))
		draw_rect(Rect2(filled_x,65,401*fraction,6),life_color.darkened(0.3))
		if fraction <= 0.25 and fraction > 0:
			draw_rect(health,Color(1,0.05,0.2,0.12+0.12*sin(clock*12)))
		for segment in range(6):
			var amount := clampf(v_ratio(f)*6-segment,0,1)
			var gx := x+segment*44 if side == 0 else x+401-(segment+1)*44
			draw_rect(Rect2(gx,79,39,9),Color("2c2341"))
			draw_rect(Rect2(gx+(39*(1-amount) if side == 1 else 0),79,39*amount,9),CYAN if f.kind < 3 else PINK)
		var v_text := "V READY" if f.v_cooldown <= 0 else "V %.1fs" % f.v_cooldown
		if f.kind >= 3: v_text = "V %03d / 100" % int(f.v_meter)
		if side == 0:
			label(Vector2(x,105),v_text,13,Color("bbb0d0"),true)
			right(Vector2(x+401,102),"%d / %d" % [ceili(f.hp),R.HP[f.kind]],15,Color("ded5e8"),true)
		else:
			right(Vector2(x+401,105),v_text,13,Color("bbb0d0"),true)
			label(Vector2(x,102),"%d / %d" % [ceili(f.hp),R.HP[f.kind]],15,Color("ded5e8"),true)
		var status: String = R.V[f.kind]
		if f.kind == 0 and f.v_time > 0: status = "迁徙 %.1fs  ·  %d/2 跳" % [f.v_time,f.jumps]
		if f.kind == 2: status = ("再生 %.1fs" % f.horns if f.horns > 0 else "脆角就绪")+" · 陷阱 %d/3" % arena.cat_trap_count(side)
		if f.kind == 4 and f.charging: status = "喊妈蓄力 %.1f / 2.5s" % f.charge
		if f.trigger_time > 0: status = R.TRIGGERS[f.kind]+" %.1fs" % f.trigger_time
		if side == 0: label(Vector2(x,124),status,12,accent)
		else: right(Vector2(x+401,124),status,12,accent)
		for pip in range(2):
			var at := Vector2(478+pip*18 if side == 0 else 674-pip*18,119)
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-5),at+Vector2(5,0),at+Vector2(0,5),at+Vector2(-5,0)]),GOLD if arena.round_wins[side] > pip else Color("473954"))
		if arena.screen == "fight": draw_super(side,f,accent)
		if arena.combo[side] > 1:
			var cx := 42.0 if side == 0 else 900.0
			label(Vector2(cx,230),"%02d" % arena.combo[side],62+int(arena.combo_pulse[side]*40),accent,true)
			label(Vector2(cx+88,224),"HITS",22,Color.WHITE,true)
			label(Vector2(cx+3,254),"DAMAGE  %d" % arena.combo_damage[side],14,GOLD,true)
		if arena.cancel_notice_time[side] > 0:
			label(Vector2(42 if side == 0 else 865,327),arena.cancel_notice[side],18,GOLD,true)
		if arena.feedback_time[side] > 0:
			var fx := 42.0 if side == 0 else 865.0
			label(Vector2(fx,295),arena.feedback[side],19,accent,true)
	cut_panel(Rect2(526,12,100,86),Color("222e3a"),15)
	middle(76,"∞" if arena.training else "%02d" % ceili(arena.time_left),53,Color("ff927c") if arena.time_left <= 10 else Color.WHITE,not arena.training)
	middle(115,"FINAL ROUND" if arena.round_wins == [1,1] else "ROUND %d" % arena.round_number,12,GOLD,true)
	if arena.training: middle(151,arena.hint("TRAINING / {skill1} {skill2} {skill3} 技能 · {super} 大招 · F4 提示 · F5 演练"),13,Color("b8acd2"))
	else: middle(151,R.STAGES[arena.stage],12,Color("aba2bc"))
	if arena.training and arena.screen == "fight" and arena.combo_help and arena.intro_time <= 0 and arena.cinematic <= 0:
		cut_panel(Rect2(336,194,480,82),Color(0.025,0.04,0.06,0.85),12)
		middle(217,R.ROLES[arena.selected],15,GOLD)
		middle_fit(242,arena.hint(arena.combo_coach.ROUTES[arena.selected]),452,15,Color("dcefff"))
		middle(264,arena.combo_coach.status if arena.combo_coach.status != "" else arena.hint(R.TACTICS[arena.selected]),12,Color("a8a1b9"))
	if arena.screen == "result":
		middle(640,"Enter 继续  ·  Esc 返回角色选择",12,Color("a99abc"))
	else:
		middle(640,arena.hint("{left}/{right} 移动 · {jump} 跳 · {light}/{medium}/{heavy} 攻击 · {skill1}/{skill2}/{skill3} 技能 · {super} 大招 · F2 设置"),12,Color("8e859f"))

func draw_super(side: int, f: Node2D, accent: Color) -> void:
	var x := 24.0 if side == 0 else 662.0
	cut_panel(Rect2(x,552,466,72),Color(0.025,0.04,0.06,0.93),12)
	var count := meter_count(f)
	var ready := "CA READY" if count == 3 else ("EX AVAILABLE" if count >= 1 else "BUILD METER")
	if side == 0:
		label(Vector2(x+8,612),str(count),58,accent,true)
		label(Vector2(x+78,571),ready,14,GOLD if count == 3 else accent,true)
	else:
		right(Vector2(x+452,612),str(count),58,accent,true)
		right(Vector2(x+388,571),ready,14,GOLD if count == 3 else accent,true)
	var bx := x+78 if side == 0 else x+6
	for segment in range(3):
		var fill := clampf(f.meter-segment,0,1)
		var xx := bx+segment*126 if side == 0 else bx+(2-segment)*126
		cut_panel(Rect2(xx,581,119,23),Color("28303a"),5)
		var width := 115*fill
		var px := xx+2 if side == 0 else xx+117-width
		draw_rect(Rect2(px,584,width,17),accent if count < 3 else GOLD)
		if count == 3:
			draw_rect(Rect2(xx+2,584,115,3),Color(1,1,1,0.35+0.3*sin(clock*8)))
	var value := "SUPER  %.2f / 3" % f.meter
	if side == 0: label(Vector2(x+80,619),value,11,Color("8e859f"),true)
	else: right(Vector2(x+386,619),value,11,Color("8e859f"),true)

func draw_intro() -> void:
	var progress: float = 1-clampf(arena.intro_time/arena.intro_duration,0,1)
	if arena.intro_time <= 0.75:
		var zoom := 1+maxf(0,arena.intro_time-0.4)*0.8
		draw_set_transform(Vector2(576,320),-0.035,Vector2.ONE*zoom)
		var word := "FIGHT"
		var width := DISPLAY.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,108).x
		label(Vector2(-width/2+5,7),word,108,PINK,true)
		label(Vector2(-width/2,0),word,108,Color.WHITE,true)
		draw_set_transform(Vector2.ZERO)
		return
	draw_rect(Rect2(0,135,1152,405),Color(0.025,0.04,0.06,0.96))
	var slide := (1-pow(1-minf(1,progress*4),3))*55
	cut_panel(Rect2(-70+slide,147,545,345),CYAN.darkened(0.8),65)
	cut_panel(Rect2(678-slide,147,545,345),PINK.darkened(0.8),65)
	actor(arena.selected,Rect2(72+slide,162,275,275),progress > 0.35)
	actor(arena.rival,Rect2(805-slide,162,275,275),progress > 0.35)
	middle(325,"VS",91,GOLD,true)
	label(Vector2(64,459),R.NAMES[arena.selected],30,CYAN)
	right(Vector2(1088,459),R.NAMES[arena.rival],30,PINK)
	label(Vector2(64,496),R.intro(arena.selected,arena.rival),17,Color("d5cde1"))
	right(Vector2(1088,496),R.intro(arena.rival,arena.selected),17,Color("d5cde1"))
	middle(524,"FIRST TO 2  ·  Enter / Space 跳过",13,Color("82778e"))

func draw_ca() -> void:
	var progress: float = 1-clampf(arena.cinematic/arena.ca_duration,0,1)
	var color: Color = R.COLORS[arena.ca_kind]
	draw_rect(Rect2(0,0,1152,648),Color("0b1018"))
	for n in range(14):
		var y := float(n*54)-fmod(progress*360,54)
		draw_line(Vector2(0,y+90),Vector2(1152,y-90),Color(color,0.12),18)
	cut_panel(Rect2(-50,124,1250,376),color.darkened(0.76),120)
	actor(arena.ca_kind,Rect2(90+progress*55,110,390,390),true)
	label(Vector2(510,247),"CRITICAL",48,Color.WHITE,true)
	label(Vector2(510,303),"ART",54,color,true)
	label(Vector2(510,367),R.CA[arena.ca_kind],37,GOLD)
	label(Vector2(513,407),R.NAMES[arena.ca_kind],20,Color("cbbce0"))
	draw_rect(Rect2(0,501,1152*progress,4),color)
	middle(554,"Enter / Space 跳过特写 · 攻击与能量消耗照常结算",13,Color("93859f"))

func draw_result() -> void:
	var t: float = arena.result_time
	if t < 0.85:
		draw_rect(Rect2(0,155,1152,340),Color(0.025,0.04,0.06,0.82))
		var scale_value := 1+maxf(0,0.4-t)*1.6
		draw_set_transform(Vector2(576,345),-0.05,Vector2.ONE*scale_value)
		label(Vector2(-153,10),"K.O.",130,PINK,true)
		label(Vector2(-158,0),"K.O.",130,GOLD,true)
		draw_set_transform(Vector2.ZERO)
		return
	cut_panel(Rect2(240,168,672,353),Color(0.035,0.055,0.075,0.96),35)
	var f = arena.fighters[arena.winner]
	middle(210,"MATCH WINNER" if arena.match_complete else "ROUND WINNER",24,CYAN if arena.winner == 0 else PINK,true)
	middle(270,R.NAMES[f.kind],44,Color.WHITE)
	middle(316,"%d  —  %d" % [arena.round_wins[0],arena.round_wins[1]],28,GOLD,true)
	middle(356,R.WIN[f.kind],22,R.COLORS[f.kind])
	if arena.match_complete:
		middle(406,R.ending(f.kind,arena.fighters[1-arena.winner].kind),17,Color("bbc5ce"))
		middle(471,"食物链永恒循环。下一次，谁是猎物？",16,Color("8895a1"))
	else:
		middle(406,"下一回合 · 生命恢复 · 超必杀能量保留",18,Color("bbc5ce"))
		middle(471,"FIRST TO 2",20,GOLD,true)
