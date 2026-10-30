extends Node2D

const R = preload("res://scripts/roster.gd")
const Fighter = preload("res://scripts/fighter.gd")
const FONT = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var fighters: Array = []
var projectiles: Array = []
var effects: Array = []
var screen := "select"
var selected := 0
var rival := 1
var stage := 0
var difficulty := 1.0
var training := false
var arcade := false
var arcade_wins := 0
var time_left := 99.0
var intro_time := 0.0
var cinematic := 0.0
var ca_kind := 0
var winner := 0
var banner := ""
var banner_color := Color.WHITE
var banner_time := 0.0
var elapsed := 0.0
var shake := 0.0
var paused := false
var show_help := false
var muted := false
var combo := [0, 0]
var combo_timer := [0.0, 0.0]
var ui: CanvasLayer
var panel: Control
var music_phase := 0.0
var sound_players: Array = []
var smoke := false

func _ready() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	panel = Control.new()
	ui.add_child(panel)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sound_players.append(player)
	build_menu()
	if "--smoke-test" in OS.get_cmdline_user_args():
		smoke = true
		run_smoke.call_deferred()

func clear_ui() -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

func button(text: String, rect: Rect2, action: Callable, color := Color("303b4c")) -> void:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("a4afba")
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.22)
	b.add_theme_stylebox_override("hover", hover)
	b.pressed.connect(action)
	panel.add_child(b)

func build_menu() -> void:
	clear_ui()
	for i in range(3):
		button("%s\n%s" % [R.NAMES[i],R.ROLES[i]], Rect2(105+i*320,320,300,74), choose.bind(i), R.COLORS[i].darkened(0.7) if selected != i else R.COLORS[i].darkened(0.4))
	button("对手  ·  " + R.NAMES[rival],Rect2(105,415,300,45),cycle_rival)
	button("舞台  ·  " + R.STAGES[stage],Rect2(425,415,300,45),cycle_stage)
	button("AI  ·  " + ("标准" if difficulty == 1 else "激烈"),Rect2(745,415,300,45),cycle_difficulty)
	button("开始对战  →",Rect2(105,485,300,56),start_match.bind(false,false),Color("805035"))
	button("街机 · 食物链巡回",Rect2(425,485,300,56),start_match.bind(false,true),Color("435e59"))
	button("练习 · 无限时间与能量",Rect2(745,485,300,56),start_match.bind(true,false),Color("5a466b"))
	button("F1 招式与操作",Rect2(425,565,300,40),toggle_help)

func choose(i: int) -> void:
	selected = i
	build_menu()

func cycle_rival() -> void:
	rival = (rival + 1) % 3
	build_menu()

func cycle_stage() -> void:
	stage = (stage + 1) % 4
	build_menu()

func cycle_difficulty() -> void:
	difficulty = 1.45 if difficulty == 1 else 1.0
	build_menu()

func toggle_help() -> void:
	show_help = not show_help
	panel.visible = not show_help
	queue_redraw()

func start_match(practice := false, tour := false) -> void:
	training = practice
	arcade = tour
	arcade_wins = 0
	if arcade: rival = (selected + 1) % 3
	new_round()

func new_round() -> void:
	clear_ui()
	for f in fighters:
		remove_child(f)
		f.queue_free()
	fighters.clear()
	projectiles.clear()
	effects.clear()
	combo = [0,0]
	combo_timer = [0.0,0.0]
	for side in range(2):
		var f = Fighter.new()
		f.configure(self,selected if side == 0 else rival,side)
		add_child(f)
		fighters.append(f)
		if training: f.meter = 3
	time_left = 99
	intro_time = 3.6
	screen = "fight"
	paused = false
	show_help = false
	panel.visible = true
	announce("食物链永恒循环",Color("e7c381"))
	sound(selected,"intro")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode
	if key == KEY_F1:
		toggle_help()
		return
	if key == KEY_M:
		muted = not muted
		return
	if key == KEY_ESCAPE:
		if show_help:
			toggle_help()
		elif screen == "fight":
			paused = not paused
			if paused:
				button("继续对战",Rect2(426,285,300,50),resume)
				button("返回角色选择",Rect2(426,350,300,50),back_to_menu)
			else: clear_ui()
		return
	if screen == "select":
		if key == KEY_ENTER: start_match()
		if key == KEY_1: choose(0)
		if key == KEY_2: choose(1)
		if key == KEY_3: choose(2)
	elif screen == "fight" and not paused and not show_help and intro_time <= 0 and cinematic <= 0:
		if training and key == KEY_R: new_round()
		else: fighters[0].press(key)

func resume() -> void:
	paused = false
	clear_ui()

func back_to_menu() -> void:
	screen = "select"
	paused = false
	build_menu()

func _physics_process(dt: float) -> void:
	elapsed += dt
	for f in fighters:
		f.visible = screen == "fight" and not show_help and not paused and cinematic <= 0 and intro_time <= 0
	banner_time = maxf(0,banner_time-dt)
	shake = maxf(0,shake-dt)
	if screen == "fight" and not paused and not show_help:
		if intro_time > 0:
			intro_time -= dt
		elif cinematic > 0:
			cinematic -= dt
		else:
			if not training: time_left = maxf(0,time_left-dt)
			fighters[0].tick(dt,true)
			if screen == "fight": fighters[1].tick(dt,false)
			# Practice dummy stays neutral while receiving attacks.
			if training:
				fighters[1].velocity.x = 0
				fighters[0].meter = 3
			if screen == "fight":
				resolve_overlap()
				tick_projectiles(dt)
				if time_left <= 0: finish(0 if fighters[0].hp/R.HP[selected] >= fighters[1].hp/R.HP[rival] else 1)
	for i in range(2):
		combo_timer[i] = maxf(0,float(combo_timer[i])-dt)
		if combo_timer[i] <= 0: combo[i] = 0
	for e in effects: e.life -= dt
	effects = effects.filter(func(e): return e.life > 0)
	queue_redraw()

func resolve_overlap() -> void:
	var a = fighters[0]
	var b = fighters[1]
	var diff: Vector2 = b.position-a.position
	if absf(diff.x) < 70 and absf(diff.y) < 100:
		var push := (70-absf(diff.x))*0.5
		var sign_x := 1 if diff.x >= 0 else -1
		a.position.x = clampf(a.position.x-push*sign_x,72,1080)
		b.position.x = clampf(b.position.x+push*sign_x,72,1080)

func spawn_projectile(source: Node2D, offset: float, empowered: bool) -> void:
	projectiles.append({"position":source.position+Vector2(source.facing*(52-offset),-75),"velocity":Vector2(source.facing*(310 if source.kind == 0 else 380),0),"owner":source.side,"kind":source.kind,"life":3.5,"ex":empowered,"trap":false})

func tick_projectiles(dt: float) -> void:
	for p in projectiles:
		p.life -= dt
		p.position += p.velocity*dt
		var target = fighters[1-int(p.owner)]
		if p.position.distance_to(target.position+Vector2(0,-65)) < (64 if not p.trap else 82):
			target.receive({"damage":65 if not p.ex else 80,"push":150,"low":p.trap,"projectile":true},fighters[int(p.owner)])
			if p.kind == 2 and p.ex and not p.trap:
				p.trap = true
				p.position.y = 520
				p.velocity = Vector2.ZERO
				p.life = 2.0
			else: p.life = 0
	projectiles = projectiles.filter(func(p): return p.life > 0 and p.position.x > -70 and p.position.x < 1220)

func hit_effect(at: Vector2, guarded: bool, damage: float) -> void:
	effects.append({"at":at,"life":0.32,"guard":guarded,"damage":roundi(damage)})
	shake = 0.08 if guarded else 0.16
	if not guarded:
		var attacker := 0 if at.x > fighters[0].position.x else 1
		combo[attacker] += 1
		combo_timer[attacker] = 1.25

func announce(text: String, color: Color) -> void:
	banner = text
	banner_color = color
	banner_time = 1.5

func finish(side: int) -> void:
	if screen != "fight": return
	winner = side
	screen = "result"
	announce("K.O.",Color("f0c883"))
	button("再来一局",Rect2(265,530,290,52),new_round,Color("805035"))
	if arcade and side == 0 and arcade_wins < 1:
		button("下一场 · 食物链继续",Rect2(580,530,310,52),next_arcade,Color("435e59"))
	else:
		button("返回角色选择",Rect2(580,530,310,52),back_to_menu)
	sound(fighters[side].kind,"win")

func next_arcade() -> void:
	arcade_wins += 1
	rival = (selected + 2) % 3
	stage = (stage + 1) % 4
	new_round()

func sound(kind: int, action: String) -> void:
	if muted or smoke: return
	var player: AudioStreamPlayer = sound_players[0]
	for candidate in sound_players:
		if not candidate.playing:
			player = candidate
			break
	var path := "res://assets/audio/%s_%s.ogg" % [["gugu","dog","cat"][kind],action]
	if ResourceLoader.exists(path):
		player.stream = load(path)
		player.volume_db = -6
	else:
		# Original synthesis only; no borrowed meme recordings bundled.
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var duration := 0.12 if action in ["swing","hit","block"] else 0.35
		var samples := int(duration*22050)
		var bytes := PackedByteArray()
		bytes.resize(samples*2)
		var base: float = [330.0,110.0,220.0][kind]
		for i in range(samples):
			var t := float(i)/22050
			var env := (1.0-float(i)/samples)*minf(1,t*120)
			var freq: float = base*(1.0+0.3*sin(t*45))
			if action == "hit": freq = 70+400*exp(-t*45)
			if action == "block": freq = 700
			var value := sin(TAU*freq*t)*env*0.25
			if action == "ca": value += sin(TAU*base*0.5*t)*env*0.15
			bytes.encode_s16(i*2,int(value*32767))
		wav.data = bytes
		player.stream = wav
		player.volume_db = -9
	player.play()

func text(at: Vector2, value: String, size := 20, color := Color.WHITE) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center(y: float, value: String, size := 24, color := Color.WHITE) -> void:
	var width := FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text(Vector2((1152-width)*0.5,y),value,size,color)

func _draw() -> void:
	draw_stage()
	if screen == "select":
		draw_rect(Rect2(0,0,1152,648),Color(0.02,0.03,0.06,0.65))
		text(Vector2(106,56),"ABSTRACT FOOD CHAIN  /  INSERT COIN ∞",15,Color("91aaa7"))
		text(Vector2(100,120),"模因乱斗：抽象食物链",48,Color("f2d7a0"))
		text(Vector2(104,157),"MEME BRAWL     ·     荒野里，没有永远的猎手",20,Color("b9bbc0"))
		for i in range(3):
			draw_portrait(Vector2(255+i*320,267),i)
		text(Vector2(105,633),"咕咕嘎嘎 → 刀盾狗 → 妙脆角猫 → 咕咕嘎嘎     /     克制伤害 +8%      ·      M 静音",16,Color("aeb8c0"))
	else:
		draw_hud()
		for p in projectiles:
			var pos: Vector2 = p.position
			var color: Color = R.COLORS[int(p.kind)]
			if p.kind == 0:
				draw_arc(pos,25,-1.4,1.4,8,color,7)
				draw_arc(pos-Vector2(12,0),17,-1.4,1.4,6,color.lightened(0.4),4)
			else:
				draw_colored_polygon(PackedVector2Array([pos+Vector2(-18,15),pos+Vector2(0,-22),pos+Vector2(20,15)]),Color("f2b337"))
		for e in effects:
			var pos: Vector2 = e.at
			var color := Color("73bbff") if e.guard else Color("ffe2a2")
			for j in range(8):
				var ray := Vector2.from_angle(j*TAU/8)
				draw_line(pos+ray*12,pos+ray*(30+(0.32-e.life)*90),color,4)
			text(pos+Vector2(-15,-50),"防御" if e.guard else str(e.damage),23,color)
		if intro_time > 0:
			draw_rect(Rect2(0,218,1152,145),Color(0.03,0.04,0.07,0.85))
			if intro_time > 0.8:
				center(260,R.NAMES[selected]+"："+R.intro(selected,rival),25,R.COLORS[selected])
				center(310,R.NAMES[rival]+"："+R.intro(rival,selected),25,R.COLORS[rival])
			else: center(310,"食物链 · 开战！",48,Color("f2d7a0"))
		elif cinematic > 0:
			draw_rect(Rect2(0,180,1152,210),Color(0.05,0.02,0.1,0.88))
			center(260,"CRITICAL ART",22,R.COLORS[ca_kind])
			center(335,R.CA[ca_kind],64,Color("fff0ce"))
		elif banner_time > 0 and screen == "fight":
			center(193,banner,24,banner_color)
		if screen == "result": draw_result()
	if paused:
		draw_rect(Rect2(0,0,1152,648),Color(0,0,0,0.65))
		center(225,"食物链暂停",42,Color("f2d7a0"))
	if show_help: draw_help()
	# Thin CRT scanlines over the procedural low-resolution shapes.
	for y in range(0,648,4):
		draw_line(Vector2(0,y),Vector2(1152,y),Color(0,0,0,0.065))

func draw_portrait(at: Vector2, kind: int) -> void:
	var c: Color = R.COLORS[kind]
	draw_rect(Rect2(at-Vector2(122,80),Vector2(244,110)),Color(c,0.08))
	if kind == 0:
		draw_circle(at,51,Color("1b2633"))
		draw_circle(at+Vector2(7,10),33,Color("e5e6da"))
		draw_colored_polygon(PackedVector2Array([at+Vector2(22,-4),at+Vector2(63,8),at+Vector2(22,17)]),Color("e7b338"))
		draw_rect(Rect2(at+Vector2(13,-24),Vector2(9,10)),Color.BLACK)
	elif kind == 1:
		draw_rect(Rect2(at-Vector2(45,43),Vector2(90,85)),c.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([at+Vector2(-35,-28),at+Vector2(-50,-65),at+Vector2(-12,-49),at+Vector2(29,-49),at+Vector2(67,-10),at+Vector2(17,5)]),c)
		draw_circle(at+Vector2(-37,23),31,Color("657278"))
		draw_line(at+Vector2(28,35),at+Vector2(63,-32),Color("dce1d7"),9)
	else:
		draw_circle(at,49,c.lightened(0.2))
		for direction in [-1,1]:
			draw_colored_polygon(PackedVector2Array([at+Vector2(direction*10,-36),at+Vector2(direction*49,-78),at+Vector2(direction*40,-18)]),Color("e8b035"))
			draw_line(at+Vector2(direction*9,-8),at+Vector2(direction*30,-10),Color("53495a"),5)
		draw_line(at+Vector2(-5,12),at+Vector2(6,12),Color("53495a"),3)
	text(at+Vector2(-110,62),R.ENGLISH[kind],17,c)

func draw_stage() -> void:
	var skies := [Color("555c61"),Color("627c90"),Color("665149"),Color("75616d")]
	var grounds := [Color("525543"),Color("a5c0c4"),Color("66594e"),Color("8d7358")]
	draw_rect(Rect2(0,0,1152,648),skies[stage].darkened(0.4))
	draw_circle(Vector2(904,204),79,Color("c0b7a1").darkened(stage*0.04))
	for i in range(15):
		var x := float(i*91-45)
		var y := float(325+(i*31)%90)
		draw_colored_polygon(PackedVector2Array([Vector2(x,480),Vector2(x+36,y),Vector2(x+110,470)]),skies[stage].darkened(0.23+(i%3)*0.08))
	draw_rect(Rect2(0,454,1152,194),grounds[stage])
	for i in range(65):
		var x := float((i*173)%1152)
		var y := float(461+(i*47)%185)
		var tint: Color = grounds[stage].darkened(0.12+(i%4)*0.04)
		draw_rect(Rect2(x,y,15+(i%5)*11,3+(i%3)*3),tint)
		if stage == 0:
			draw_line(Vector2(x,y),Vector2(x-8,y-18),tint,3)
		elif stage == 1:
			draw_line(Vector2(x,y),Vector2(x+44,y+15),Color("6e929f"),2)
		elif stage == 3 and i%5 == 0:
			draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+20,y-30),Vector2(x+35,y+4)]),Color("b88943"))
	for i in range(4):
		var x := float(72+i*310)
		draw_line(Vector2(x,458),Vector2(x+13,300-i*12),Color("353a35"),13)
		draw_line(Vector2(x+10,350),Vector2(x-27,312),Color("353a35"),9)
		draw_line(Vector2(x+10,335),Vector2(x+52,294+i*9),Color("353a35"),7)
	draw_rect(Rect2(0,540,1152,108),Color(0.02,0.025,0.035,0.36))

func draw_hud() -> void:
	draw_rect(Rect2(0,0,1152,122),Color("111923"))
	for side in range(2):
		var f = fighters[side]
		var x := 40.0 if side == 0 else 657.0
		text(Vector2(x,34),("P1  " if side == 0 else ("DUMMY  " if training else "CPU  "))+R.NAMES[f.kind],22,R.COLORS[f.kind])
		draw_rect(Rect2(x,46,455,25),Color("3e252d"))
		var ratio: float = f.hp/R.HP[f.kind]
		draw_rect(Rect2(x if side == 0 else x+455*(1-ratio),46,455*ratio,25),R.COLORS[f.kind])
		text(Vector2(x,96),"%d / %d" % [ceili(f.hp),R.HP[f.kind]],14,Color("bfc7c9"))
		text(Vector2(x+165,96),"V  就绪" if f.v_cooldown <= 0 else "V  %.1fs" % f.v_cooldown,14,Color("a3b6bb"))
		for m in range(3):
			draw_rect(Rect2(x+m*155,587,145,17),Color("26323e"))
			draw_rect(Rect2(x+m*155,587,145*clampf(f.meter-m,0,1),17),Color("e5b85d") if f.meter >= 3 else R.COLORS[f.kind])
		text(Vector2(x,577),"CRITICAL ART READY" if f.meter >= 3 else "EX  /  %.2f" % f.meter,16,Color("edd49e"))
		if combo[side] > 1:
			text(Vector2(x,245),"%d HITS" % combo[side],32,Color("ffe0a2"))
	center(68,"∞" if training else "%02d" % ceili(time_left),38,Color("ead4b1"))
	center(112,R.STAGES[stage],14,Color("a4a8a9"))
	center(635,"WASD 移动 / 蹲防   J K L 拳   U I O 腿   G 投   V 技能   T 挑衅   F1 招式   Esc 暂停",15,Color("c2c6cb"))
	if training: center(150,"练习模式 · P1 无限能量 · R 重置 · 对手静止",17,Color("d0b8e8"))

func draw_result() -> void:
	draw_rect(Rect2(0,140,1152,450),Color(0.025,0.035,0.055,0.93))
	var win_kind: int = fighters[winner].kind
	var lose_kind: int = fighters[1-winner].kind
	center(213,"K.O.  /  " + R.NAMES[win_kind] + " 胜利",42,R.COLORS[win_kind])
	center(275,R.WIN[win_kind],27,Color("f0d8a6"))
	center(319,R.NAMES[lose_kind]+"："+R.LOSE[lose_kind],20,Color("aeb9c1"))
	center(391,R.ENDINGS[win_kind][lose_kind],21,Color("d6d1c7"))
	if arcade and winner == 0 and arcade_wins >= 1:
		center(449,"食物链巡回完成 · 黄色三幻神【奶蛙】尚未实装",20,Color("e4be79"))
	else: center(449,"食物链永恒循环。下一次，谁是猎物？",20,Color("929f9e"))

func draw_help() -> void:
	draw_rect(Rect2(35,22,1082,605),Color("111b29"))
	text(Vector2(67,65),"荒野格斗手册  /  F1 或 Esc 关闭",28,Color("efcf95"))
	text(Vector2(67,104),"W 跳跃 · A/D 左右 · S 蹲下 · 远离对手=格挡 · 远离+S=蹲防",20)
	text(Vector2(67,140),"J/K/L 轻/中/重拳 · U/I/O 轻/中/重腿 · G 投技（不可防）· V 专属技能 · T 挑衅",19)
	text(Vector2(67,176),"方向相对角色朝向。0.85 秒内搓招；按住 Shift+攻击发动 EX，或快速连按重攻击两次。",18,Color("bbced6"))
	for i in range(3):
		var x := 67+i*353
		text(Vector2(x,224),R.NAMES[i],25,R.COLORS[i])
		text(Vector2(x,263),"↓↘→ + 拳  " + R.SPECIALS[i][0],17)
		text(Vector2(x,299),"→↓↘ + " + ("脚" if i == 0 else "拳") + "  " + R.SPECIALS[i][1],17)
		text(Vector2(x,335),"↓↙← + " + ("拳" if i == 1 else "脚") + "  " + R.SPECIALS[i][2],17)
		text(Vector2(x,378),"V · " + R.V[i],19,R.COLORS[i])
		text(Vector2(x,414),["加速 3.5 秒 / 二段跳 / 突进强化", "举盾 1 秒 / 中上段及飞行道具反击", "当身 1 秒 / 反击后棱角磨平 3 秒"][i],15)
		text(Vector2(x,458),"CA · " + R.CA[i],20,Color("f2cc81"))
	text(Vector2(67,504),"EX 消耗 1 格 · CA 消耗 3 格：↓↘→↓↘→ + 拳 · 空中攻击需站防，低段需蹲防。",19)
	text(Vector2(67,542),"咕咕嘎嘎克狗 → 狗克猫 → 猫克企鹅（+8%）；猫受击额外积攒能量。",18,Color("bbced6"))
	text(Vector2(67,582),"当前为程序像素美术 / 原创合成音效原型；原版梗音频可按 README 说明替换。",17,Color("9cabb8"))

func run_smoke() -> void:
	# Exercise real combat rules, not only parsing or scene existence.
	for kind in range(3):
		selected = kind
		rival = (kind+1)%3
		start_match(true,false)
		intro_time = 0
		var a = fighters[0]
		var b = fighters[1]
		a.position = Vector2(500,532)
		b.position = Vector2(590,532)
		a.facing = 1
		var before: float = b.hp
		a.normal(1,false)
		a.tick(0.016,false)
		assert(b.hp < before,"Normal attack must deal damage")
		a.cooldown = 0
		a.active = 0
		a.special(0,true)
		assert(a.meter < 3,"EX spends meter")
		assert(a.label.begins_with("EX"))
		a.active = 0
		a.meter = 3
		a.super_move()
		assert(a.meter == 0 and cinematic > 0,"CA spends 3 and starts cinematic")
		cinematic = 0
		if kind != 0:
			a.active = 0
			a.invulnerable = 0
			a.v_cooldown = 0
			a.v_skill()
			var old_hp: float = a.hp
			a.receive({"damage":50},b)
			assert(a.hp == old_hp and a.v_time == 0,"V counters incoming attack")
		print("COMBAT PASS: ",R.NAMES[kind]," normal / EX / CA / V")
	selected = 0
	rival = 1
	start_match(true,false)
	var a = fighters[0]
	var b = fighters[1]
	a.motion = [[2,0.0],[3,0.1],[6,0.2],[2,0.3],[3,0.4],[6,0.5]]
	assert(a.matches([2,3,6,2,3,6]))
	b.blocking = true
	var hp_before: float = b.hp
	b.receive({"damage":100},a)
	assert(hp_before-b.hp < 10,"Guard reduces damage")
	b.invulnerable = 0
	b.receive({"damage":100,"throw":true},a)
	assert(hp_before-b.hp > 100,"Throw bypasses guard")
	a.v_skill()
	a.press(KEY_W)
	a.press(KEY_W)
	assert(a.jumps == 2,"Penguin V enables double jump")
	b.hp = 1
	b.blocking = false
	b.receive({"damage":100},a)
	assert(screen == "result" and winner == 0,"KO resolves winner")
	print("SYSTEM PASS: motion buffer / guard / throw / double jump / KO / result UI")
	for kind in range(3):
		selected = kind
		rival = (kind+1)%3
		start_match(false,false)
		intro_time = 0
		for frame in range(3600):
			if screen != "fight": break
			fighters[0].tick(1.0/60,false)
			if screen == "fight": fighters[1].tick(1.0/60,false)
			resolve_overlap()
			tick_projectiles(1.0/60)
		assert(fighters[0].hp < R.HP[selected] or fighters[1].hp < R.HP[rival],"AI must engage")
		print("SIMULATION PASS: ",R.NAMES[kind]," vs ",R.NAMES[rival])
	back_to_menu()
	assert(panel.get_child_count() == 10,"Selection menu buttons")
	print("MEME BRAWL SMOKE PASS")
	get_tree().quit(0)
