extends Node2D

const R = preload("res://scripts/roster.gd")
const Frames = preload("res://scripts/sprite_frames.gd")
const Presentation = preload("res://scripts/fight_presentation.gd")
const Fighter = preload("res://scripts/fighter.gd")
const FONT = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var fighters: Array = []
var projectiles: Array = []
var effects: Array = []
var screen := "select"
var selected := 0
var rival := 2
var stage := 0
var difficulty := 1.0
var training := false
var arcade := false
var arcade_wins := 0
var time_left := 99.0
var intro_time := 0.0
var cinematic := 0.0
var ca_kind := 0
var ca_side := 0
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
var round_wins := [0,0]
var round_number := 1
var match_complete := false
var intro_duration := 4.2
var ca_duration := 1.25
var result_time := 0.0
var combo_damage := [0,0]
var feedback := ["",""]
var feedback_time := [0.0,0.0]
var presentation: Node2D
var demo_mode := false
var demo_clock := 0.0
var demo_segment := -1
var demo_ca_started := false
var demo_ko_started := false
var auto_quit_demo := false
var voice_characters := 0
var portrait_atlas: Texture2D
var duo_atlases: Dictionary = {}

func _ready() -> void:
	Frames.prewarm()
	if ResourceLoader.exists("res://assets/art/meme_fighters_atlas.png"):
		portrait_atlas = load("res://assets/art/meme_fighters_atlas.png")
	for kind in [0,2]:
		var path: String = Fighter.PixelAnimator.DUO_PATHS[kind]
		if ResourceLoader.exists(path): duo_atlases[kind] = load(path)
	var audio_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/sources.json"))
	if audio_manifest is Dictionary:
		for character in R.AUDIO:
			for recording in audio_manifest.get("recordings",{}):
				if str(recording).begins_with(character+"_") and ResourceLoader.exists("res://assets/audio/"+recording):
					voice_characters += 1
					break
	var presentation_layer := CanvasLayer.new()
	presentation_layer.layer = 5
	add_child(presentation_layer)
	presentation = Presentation.new()
	presentation.arena = self
	presentation_layer.add_child(presentation)
	ui = CanvasLayer.new()
	ui.layer = 20
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
	elif "--demo" in OS.get_cmdline_user_args():
		auto_quit_demo = "--auto-quit" in OS.get_cmdline_user_args()
		start_demo.call_deferred()

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
	style.bg_color = color.lerp(Color("141224"),0.35)
	style.border_color = color.lightened(0.4)
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.22)
	b.add_theme_stylebox_override("hover", hover)
	var focus := style.duplicate()
	focus.border_color = Color.WHITE
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("focus",focus)
	b.pressed.connect(action)
	panel.add_child(b)

func build_menu() -> void:
	clear_ui()
	for i in range(R.NAMES.size()):
		button("%s\n%s" % [R.NAMES[i],R.ROLES[i]], Rect2(105+(i%3)*320,247+(i/3)*147,300,58), choose.bind(i), R.COLORS[i].darkened(0.7) if selected != i else R.COLORS[i].darkened(0.4))
	button("对手  ·  " + R.NAMES[rival],Rect2(105,466,300,40),cycle_rival)
	button("舞台  ·  " + R.STAGES[stage],Rect2(425,466,300,40),cycle_stage)
	button("AI  ·  " + ("标准" if difficulty == 1 else "激烈"),Rect2(745,466,300,40),cycle_difficulty)
	button("开始对战  →",Rect2(105,519,300,48),start_match.bind(false,false),Color("805035"))
	button("街机 · 食物链巡回",Rect2(425,519,300,48),start_match.bind(false,true),Color("435e59"))
	button("练习 · 无限时间与能量",Rect2(745,519,300,48),start_match.bind(true,false),Color("5a466b"))
	button("F3 演出鉴赏 · 72 秒",Rect2(105,579,300,36),start_demo,Color("5a3473"))
	button("F1 招式与操作",Rect2(425,579,300,36),toggle_help)
	button("声音 · "+("关闭" if muted else "开启")+" / M",Rect2(745,579,300,36),toggle_mute,Color("345367"))

func choose(i: int) -> void:
	selected = i
	build_menu()

func cycle_rival() -> void:
	rival = (rival + 1) % R.NAMES.size()
	build_menu()

func cycle_stage() -> void:
	stage = (stage + 1) % 4
	build_menu()

func cycle_difficulty() -> void:
	difficulty = 1.45 if difficulty == 1 else 1.0
	build_menu()

func _unhandled_input(event: InputEvent) -> void:
	if screen != "select" or show_help: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for kind in range(R.NAMES.size()):
			var card := Rect2(105+(kind%3)*320,157+(kind/3)*147,300,149)
			if card.has_point(event.position):
				choose(kind)
				get_viewport().set_input_as_handled()
				return

func toggle_help() -> void:
	show_help = not show_help
	panel.visible = not show_help
	queue_redraw()

func start_match(practice := false, tour := false) -> void:
	demo_mode = false
	round_wins = [0,0]
	round_number = 1
	match_complete = false
	training = practice
	arcade = tour
	arcade_wins = 0
	if arcade: rival = (selected + 1) % R.NAMES.size()
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
	combo_damage = [0,0]
	feedback_time = [0.0,0.0]
	result_time = 0
	match_complete = false
	presentation.reset()
	for side in range(2):
		var f = Fighter.new()
		f.configure(self,selected if side == 0 else rival,side)
		add_child(f)
		fighters.append(f)
		f.visual.play("intro",intro_duration)
		if training: f.meter = 3
	time_left = 99
	intro_time = intro_duration
	screen = "fight"
	paused = false
	show_help = false
	panel.visible = true
	announce("食物链永恒循环",Color("e7c381"))
	sound(selected,"intro")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode
	if key == KEY_F3:
		if demo_mode: stop_demo()
		else: start_demo()
		return
	if demo_mode and key == KEY_ESCAPE:
		stop_demo()
		return
	if key in [KEY_ENTER,KEY_SPACE] and screen != "select":
		if intro_time > 0:
			intro_time = 0
			for f in fighters: f.visual.play("idle",0.5)
		elif cinematic > 0:
			cinematic = 0
			if fighters.size() == 2:
				var visual = fighters[ca_side].visual
				visual.clock = maxf(visual.clock,visual.duration-1.25)
		elif demo_mode:
			demo_clock = (demo_segment+1)*12.0
		elif screen == "result":
			if result_time < 1: result_time = 1
			else: primary_result()
		return
	if key == KEY_F1:
		toggle_help()
		return
	if key == KEY_M:
		toggle_mute()
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
		elif screen == "result":
			back_to_menu()
		return
	if screen == "select":
		if key == KEY_ENTER: start_match()
		if key == KEY_1: choose(0)
		if key == KEY_2: choose(1)
		if key == KEY_3: choose(2)
		if key == KEY_4: choose(3)
		if key == KEY_5: choose(4)
		if key == KEY_6: choose(5)
	elif screen == "fight" and not paused and not show_help and intro_time <= 0 and cinematic <= 0:
		if training and key == KEY_R: new_round()
		else: fighters[0].press(key)

func resume() -> void:
	paused = false
	clear_ui()

func back_to_menu() -> void:
	demo_mode = false
	panel.visible = true
	screen = "select"
	paused = false
	build_menu()

func _physics_process(dt: float) -> void:
	elapsed += dt
	if demo_mode and not paused and not show_help: update_demo(dt)
	if screen == "result" and not paused and not show_help:
		result_time += dt
		panel.visible = result_time >= 1 and not demo_mode
	for f in fighters:
		f.visible = screen in ["fight","result"] and not show_help and not paused and cinematic <= 0
	banner_time = maxf(0,banner_time-dt)
	shake = maxf(0,shake-dt)
	if screen == "fight" and not paused and not show_help:
		if intro_time > 0:
			intro_time -= dt
		elif cinematic > 0:
			cinematic -= dt
		else:
			if not training: time_left = maxf(0,time_left-dt)
			fighters[0].tick(dt,not demo_mode)
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
		feedback_time[i] = maxf(0,float(feedback_time[i])-dt)
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
	var flat: bool = source.kind == 2 and source.horns > 0
	projectiles.append({"position":source.position+Vector2(source.facing*52,-75),"velocity":Vector2(source.facing*(270 if source.kind == 0 else 340),0),"owner":source.side,"kind":source.kind,"life":3.5,"ex":empowered,"trap":false,"bounced":false,"delay":offset/55.0*0.12,"age":0.0,"flat":flat,"damage":32 if flat else (80 if empowered else 65)})

func settle_trap(p: Dictionary) -> void:
	p.trap = true
	p.position.y = 516
	p.velocity = Vector2.ZERO
	p.life = 2.6
	p.damage = 12 if p.flat else 24

func tick_projectiles(dt: float) -> void:
	for p in projectiles:
		if p.delay > 0:
			p.delay = maxf(0,p.delay-dt)
			continue
		p.life -= dt
		p.age += dt
		if p.kind == 5:
			p.velocity.y += 500*dt
		elif p.kind == 2 and p.ex and not p.trap:
			p.velocity.y += 360*dt
		p.position += p.velocity*dt
		if p.kind == 2 and p.ex and not p.trap and p.position.y >= 510:
			settle_trap(p)
		if p.kind == 5 and p.position.y >= 515 and not p.bounced:
			p.position.y = 515
			p.velocity.y = -250
			p.bounced = true
		var target = fighters[1-int(p.owner)]
		var touches: bool = p.position.distance_to(target.position+Vector2(0,-65)) < 64
		if p.trap:
			touches = target.grounded and absf(target.position.x-p.position.x) < 38 and target.position.y > 490
		if touches:
			target.receive({"damage":p.damage,"push":65 if p.trap else 150,"low":p.trap,"projectile":true,"hitstun":0.42 if p.trap else (0.34 if p.kind == 2 else 0.27)},fighters[int(p.owner)])
			if p.kind == 5 and not p.bounced:
				p.position.y = 515
				p.velocity.y = -250
				p.bounced = true
			elif p.kind == 2 and p.ex and not p.trap:
				settle_trap(p)
			else: p.life = 0
	projectiles = projectiles.filter(func(p): return p.life > 0 and p.position.x > -70 and p.position.x < 1220)

func hit_effect(at: Vector2, guarded: bool, damage: float, attacker := -1, linked := false, note := "") -> void:
	effects.append({"at":at,"life":0.32,"guard":guarded,"damage":roundi(damage)})
	shake = 0.08 if guarded else 0.16
	if attacker < 0: return
	if not guarded:
		if not linked:
			combo[attacker] = 0
			combo_damage[attacker] = 0
		combo[attacker] += 1
		combo_damage[attacker] += roundi(damage)
		combo_timer[attacker] = 1.25
	feedback[attacker] = "BLOCK" if guarded else note
	feedback_time[attacker] = 1.1 if not note.is_empty() or guarded else 0

func announce(text: String, color: Color) -> void:
	banner = text
	banner_color = color
	banner_time = 1.5

func finish(side: int) -> void:
	if screen != "fight": return
	winner = side
	round_wins[side] += 1
	match_complete = training or round_wins[side] >= 2
	result_time = 0
	screen = "result"
	panel.visible = false
	for team in range(2):
		fighters[team].position = Vector2(145 if team == 0 else 1007,510)
		fighters[team].visual.play("win" if team == side else "ko",1.8)
	announce("K.O.",Color("f0c883"))
	button("再战" if match_complete else "下一回合",Rect2(265,530,290,52),primary_result,Color("805035"))
	button("返回角色选择",Rect2(580,530,310,52),back_to_menu)
	if arcade and side == 0 and match_complete and arcade_wins < R.NAMES.size()-2:
		panel.get_child(0).text = "下一场 · 食物链继续"
	sound(fighters[side].kind,"win")

func primary_result() -> void:
	if not match_complete:
		var resource := [fighters[0].meter,fighters[1].meter]
		round_number += 1
		new_round()
		for side in range(2): fighters[side].meter = resource[side]
	elif arcade and winner == 0 and arcade_wins < R.NAMES.size()-2:
		next_arcade()
	else:
		restart_match()

func restart_match() -> void:
	round_wins = [0,0]
	round_number = 1
	new_round()

func next_arcade() -> void:
	arcade_wins += 1
	rival = (selected + arcade_wins + 1) % R.NAMES.size()
	stage = (stage + 1) % 4
	round_wins = [0,0]
	round_number = 1
	new_round()

func toggle_mute() -> void:
	muted = not muted
	if muted:
		for player in sound_players: player.stop()
	if screen == "select": build_menu()

func begin_ca(kind: int, side := 0) -> void:
	ca_kind = kind
	ca_side = side
	ca_duration = 2.2 if demo_mode else 1.25
	cinematic = ca_duration

func start_demo() -> void:
	demo_mode = true
	demo_clock = 0
	demo_segment = -1
	training = false
	arcade = false
	show_help = false
	paused = false
	update_demo(0)

func stop_demo() -> void:
	demo_mode = false
	if auto_quit_demo:
		get_tree().quit(0)
	else:
		back_to_menu()

func update_demo(dt: float) -> void:
	demo_clock += dt
	if demo_clock >= 72:
		stop_demo()
		return
	var segment := int(demo_clock/12)
	if segment != demo_segment:
		demo_segment = segment
		selected = segment
		rival = [2,0,0,4,5,3][segment]
		stage = segment%4
		round_wins = [0,0]
		round_number = 1
		new_round()
		for f in fighters: f.meter = 3
		demo_ca_started = false
		demo_ko_started = false
	var phase := fmod(demo_clock,12)
	if phase >= 6 and not demo_ca_started:
		demo_ca_started = true
		intro_time = 0
		var a = fighters[0]
		var b = fighters[1]
		a.position = Vector2(480,532)
		b.position = Vector2(635,532)
		a.facing = 1
		b.facing = -1
		a.stun = 0
		a.active = 0
		a.cooldown = 0
		a.meter = 3
		b.v_time = 0
		b.counter_startup = 0
		b.invulnerable = 0
		a.super_move()
	if phase >= 10 and not demo_ko_started:
		demo_ko_started = true
		if screen == "fight":
			fighters[1].hp = 0
			finish(0)
		panel.visible = false

func sound(kind: int, action: String) -> void:
	if muted or smoke: return
	var player: AudioStreamPlayer = sound_players[0]
	for candidate in sound_players:
		if not candidate.playing:
			player = candidate
			break
	var path := "res://assets/audio/%s_%s.ogg" % [R.AUDIO[kind],action]
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
		var base: float = [330.0,110.0,220.0,150.0,82.0,270.0][kind]
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
	if screen == "fight":
		for f in fighters:
			if f.kind == 3 and f.trigger_time > 0:
				draw_rect(Rect2(0,122,1152,418),Color(0.65,0.025,0.015,0.18))
	if screen != "select":
		for p in projectiles:
			if p.delay > 0: continue
			var pos: Vector2 = p.position
			var color: Color = R.COLORS[int(p.kind)]
			if p.kind == 5:
				draw_rect(Rect2(pos-Vector2(23,20),Vector2(46,40)),Color("e7b723"))
				draw_line(pos-Vector2(23,0),pos+Vector2(23,0),Color("654d22"),4)
			elif p.kind == 3:
				draw_circle(pos,22,Color("cab52b"))
				draw_circle(pos+Vector2(12,12),13,Color("e0cc45"))
			elif p.kind == 0:
				draw_arc(pos,25,-1.4,1.4,8,color,7)
				draw_arc(pos-Vector2(12,0),17,-1.4,1.4,6,color.lightened(0.4),4)
			else:
				var triangle := PackedVector2Array([pos+Vector2(-18,15),pos+Vector2(0,-22 if not p.flat else -4),pos+Vector2(20,15)])
				draw_colored_polygon(triangle,Color("d2a86d") if p.flat else Color("f2b337"))
				if p.trap: draw_line(pos+Vector2(-23,7),pos+Vector2(23,7),Color("ffe6a0"),3)
		for e in effects:
			var pos: Vector2 = e.at
			var color := Color("73bbff") if e.guard else Color("ffe2a2")
			for j in range(8):
				var ray := Vector2.from_angle(j*TAU/8)
				draw_line(pos+ray*12,pos+ray*(30+(0.32-e.life)*90),color,4)
			text(pos+Vector2(-15,-50),"防御" if e.guard else str(e.damage),23,color)
	if paused:
		draw_rect(Rect2(0,0,1152,648),Color(0,0,0,0.65))
		center(225,"食物链暂停",42,Color("f2d7a0"))
	if show_help: draw_help()
	# Thin CRT scanlines over the procedural low-resolution shapes.
	for y in range(0,648,4):
		draw_line(Vector2(0,y),Vector2(1152,y),Color(0,0,0,0.065))

func draw_portrait(at: Vector2, kind: int) -> void:
	var duo := kind in [0,2]
	var sheet := ("gugu_actions.png" if kind == 0 else "cat_actions.png") if duo else "meme_fighters_atlas.png"
	var pose: Dictionary = Frames.get_frame(sheet,0 if duo else kind)
	var rect := Rect2(at-Vector2(70,70),Vector2(140,140))
	draw_texture_rect(pose.texture,Frames.fit_rect(pose,rect),false)
	if kind == 2:
		for chip in Frames.attachments(pose,rect,true): draw_colored_polygon(chip,Color("ecb439"))

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

func draw_help() -> void:
	draw_rect(Rect2(35,22,1082,605),Color("111b29"))
	text(Vector2(67,65),"荒野格斗手册 · " + R.NAMES[selected] + " / F1 或 Esc 关闭",28,Color("efcf95"))
	text(Vector2(67,106),"W 跳跃 · A/D 移动 · S 蹲下 · 远离=格挡 · 远离+S=蹲防",20)
	text(Vector2(67,143),"J/K/L 拳 · U/I/O 腿 · G 投 · V 技能 · B 触发（新角色）· T 挑衅",20)
	for move in range(3):
		text(Vector2(67,200+move*44),R.COMMANDS[selected][move]+"   "+R.SPECIALS[selected][move],22,R.COLORS[selected])
		text(Vector2(580,200+move*44),R.EX[selected][move],19,Color("f0d18b"))
	text(Vector2(67,346),"V · "+R.V[selected]+" / "+R.V_HELP[selected],20)
	text(Vector2(67,390),"B · "+R.TRIGGERS[selected]+" / 新角色需满 100 V 槽，持续 8 秒",20,Color("ffbb8f"))
	text(Vector2(67,434),"CA · "+R.CA[selected]+"   "+R.CA_COMMANDS[selected],23,Color("f2d494"))
	text(Vector2(67,478),"方向相对朝向 · 0.85 秒缓冲 · Shift+必杀 = EX（1 格）· CA 消耗 3 格",18)
	text(Vector2(67,520),"原三角克制保留 +8%；新角色无额外属性克制。投技可破当身与霸体。",18)
	text(Vector2(67,564),"奶蛙：触发时防御降低 / 牛来：蓄力受击清空 / 袋鼠：触发踢技为中段",18)
	text(Vector2(67,602),"Enter/Space 跳过特写 · F3 演出鉴赏 · 先胜两个回合获胜",16,Color("9cabb8"))

func run_dlc_checks() -> void:
	# Frogs must earn a hit-confirm before spending their cancel resource.
	selected = 3
	rival = 4
	start_match(true,false)
	var a = fighters[0]
	var b = fighters[1]
	a.position = Vector2(500,532)
	b.position = Vector2(590,532)
	a.v_skill()
	assert(a.v_meter == 100, "Whiff cannot V-cancel")
	a.normal(1,false)
	a.tick(0.016,false)
	assert(a.cancel_window > 0)
	a.v_skill()
	assert(a.active == 0 and a.cooldown == 0 and a.v_meter < 66, "Hit-confirm cancel spends 35 V")
	a.trigger()
	assert(a.trigger_time == 0, "Trigger requires full V")
	a.v_meter = 100
	a.trigger()
	assert(a.trigger_time == 8 and a.v_meter == 0)
	var before: float = a.hp
	a.receive({"damage":100},b)
	assert(is_equal_approx(before-a.hp,125), "Frog trigger weakens defense")
	print("DLC PASS: frog hit-confirm cancel / V resource / trigger defense tradeoff")
	selected = 4
	rival = 0
	start_match(true,false)
	a = fighters[0]
	b = fighters[1]
	a.v_skill()
	a.tick(2.0,false)
	assert(a.charging and a.charge >= 2, "Bull builds charge over time")
	a.special(2,false)
	assert(a.attack.damage > 200 and a.charge == 0 and not a.charging, "Charge strengthens next special")
	a.cooldown = 0
	a.active = 0
	a.v_skill()
	a.charge = 2
	a.receive({"damage":30},b)
	assert(not a.charging and a.charge == 0, "Getting hit interrupts charge")
	a.stun = 0
	a.cooldown = 0
	a.special(0,true)
	before = a.hp
	a.receive({"damage":20},b)
	assert(a.hp < before and a.stun == 0 and a.active > 0, "Armor takes damage without hitstun")
	a.receive({"damage":20,"throw":true},b)
	assert(a.stun > 0, "Throw defeats armor")
	a.active = 0
	a.stun = 0
	a.motion = [[2,0],[1,0.1],[4,0.2],[2,0.3],[1,0.4],[4,0.5]]
	a.meter = 3
	a.press(KEY_J)
	assert(a.meter == 0 and a.attack.get("throw",false), "Bull CA uses double back-quarter-circle punch")
	cinematic = 0
	print("DLC PASS: bull moving charge / damage / interruption / armor / CA command")
	selected = 5
	rival = 2
	start_match(true,false)
	a = fighters[0]
	b = fighters[1]
	a.trigger()
	a.normal(0,true)
	assert(a.attack.air and a.attack.damage > 38, "Trigger kicks are overhead and stronger")
	a.active = 0
	a.cooldown = 0
	a.motion = [[2,0],[3,0.1],[6,0.2],[2,0.3],[3,0.4],[6,0.5]]
	a.meter = 3
	a.press(KEY_U)
	assert(a.meter == 0, "Kangaroo CA uses kick")
	cinematic = 0
	projectiles.clear()
	spawn_projectile(a,0,false)
	projectiles[0].position = b.position+Vector2(0,-65)
	tick_projectiles(0)
	assert(projectiles.size() == 1 and projectiles[0].bounced, "Box bounces after first collision")
	projectiles[0].position = b.position+Vector2(0,-65)
	before = b.hp
	tick_projectiles(0)
	assert(projectiles.is_empty() and b.hp < before, "Bounced box has a second damaging collision")
	print("DLC PASS: kangaroo trigger overhead / CA kick / bouncing box second hit")
	for who in range(R.NAMES.size()):
		for other in range(R.NAMES.size()):
			assert(not R.intro(who,other).is_empty())
			assert(not R.ending(who,other).is_empty())
	selected = 3
	start_match(false,true)
	var opponents: Array = [rival]
	for n in range(4):
		next_arcade()
		assert(not rival in opponents and rival != selected, "Arcade visits five distinct opponents")
		opponents.append(rival)
	assert(opponents.size() == 5)
	print("DLC PASS: 36 matchup dialogues / endings / five-opponent arcade progression")

func run_duo_checks() -> void:
	selected = 0
	rival = 1
	start_match(true,false)
	intro_time = 0
	var a = fighters[0]
	var b = fighters[1]
	a.v_skill()
	var resource_before: float = a.meter
	a.special(1,false)
	assert(a.meter == resource_before and a.attack.damage == 145,"Migration enhances dash without EX meter cost")
	var before: float = a.hp
	a.receive({"damage":50,"projectile":true},b)
	assert(a.hp == before,"Penguin slide phases high projectiles")
	a.receive({"damage":50,"projectile":true,"low":true},b)
	assert(a.hp < before,"Low projectile still catches slide")
	a.stun = 0
	a.active = 0
	a.cooldown = 0
	a.v_time = 0
	a.grounded = false
	a.special(1,true)
	assert(a.velocity.y == 330 and a.attack.knockdown,"Air EX dive descends and knocks down")
	a.active = 0
	a.cooldown = 0
	a.special(2,false)
	assert(a.attack.air and a.remaining_hits == 1,"Air spin is a two-hit aerial attack")
	var turn := InputEventKey.new()
	turn.keycode = KEY_A
	turn.physical_keycode = KEY_A
	turn.pressed = true
	Input.parse_input_event(turn)
	Input.flush_buffered_events()
	a.player_input(0.2)
	var release := turn.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	assert(a.velocity.x < 0,"Real directional input can reverse aerial spin movement")
	projectiles.clear()
	spawn_projectile(a,55,true)
	projectiles[0].position = b.position+Vector2(0,-65)
	before = b.hp
	tick_projectiles(0.06)
	assert(b.hp == before,"Delayed migration wave cannot hit before activation")
	tick_projectiles(0.07)
	tick_projectiles(0)
	assert(b.hp < before,"Delayed wave activates and hits")
	print("DUO PASS: penguin migration / high-shot phase / low-shot vulnerability / air dive / spin / wave timing")
	selected = 2
	rival = 1
	start_match(true,false)
	intro_time = 0
	a = fighters[0]
	b = fighters[1]
	a.special(0,false)
	assert(a.horns > 0 and not projectiles[0].flat,"First chip shot removes horns")
	a.active = 0
	a.cooldown = 0
	a.special(0,false)
	assert(projectiles[-1].flat and projectiles[-1].damage < projectiles[0].damage,"Hornless shot has different damage and visual shape")
	a.horns = 0.01
	a.tick(0.02,false)
	assert(a.horns == 0,"Horns regenerate on timer")
	a.active = 0
	a.cooldown = 0
	a.special(2,false)
	a.tick(0.016,false)
	assert(a.guard_time > 0 and a.v_time == 0,"Backstep guards without arming a counter")
	before = a.hp
	var enemy_before: float = b.hp
	a.receive({"damage":100},b)
	assert(a.hp < before and before-a.hp < 10 and b.hp == enemy_before,"Backstep blocks instead of auto countering")
	a.active = 0
	a.cooldown = 0
	a.stun = 0
	a.guard_time = 0
	a.blocking = false
	a.special(1,false)
	before = a.hp
	a.receive({"damage":30},b)
	assert(a.hp < before and a.v_time == 0,"Slow counter can be interrupted during startup")
	a.stun = 0
	a.active = 0
	a.v_cooldown = 0
	a.v_skill()
	before = a.hp
	a.receive({"damage":30},b)
	assert(a.hp == before and a.horns > 0,"V counter succeeds and visibly removes chip horns")
	projectiles.clear()
	a.horns = 0
	spawn_projectile(a,0,true)
	projectiles[0].position = Vector2(650,515)
	b.position = Vector2(900,532)
	tick_projectiles(0.02)
	assert(projectiles.size() == 1 and projectiles[0].trap,"Missed EX chip settles into a real ground trap")
	b.position = Vector2(650,440)
	b.grounded = false
	before = b.hp
	tick_projectiles(0)
	assert(b.hp == before,"Jumping avoids ground shards")
	b.position.y = 532
	b.grounded = true
	b.invulnerable = 0
	tick_projectiles(0)
	assert(b.hp < before and b.stun >= 0.4 and projectiles.is_empty(),"Stepping on shards trips once and consumes trap")
	print("DUO PASS: cat horn loss / blunt shot / regeneration / guarded retreat / counter startup / EX ground traps / jump avoidance")

func run_presentation_checks() -> void:
	selected = 0
	rival = 2
	start_match(false,false)
	var a = fighters[0]
	var b = fighters[1]
	a.hp = R.HP[0]*0.5
	presentation.update_gauges(0.1)
	assert(presentation.life_trail[0] == 1,"Damage leaves a delayed health trail")
	presentation.update_gauges(0.35)
	assert(presentation.life_trail[0] < 1 and presentation.life_trail[0] >= 0.5)
	presentation.update_gauges(2)
	assert(is_equal_approx(presentation.life_trail[0],0.5),"Health trail settles on actual HP")
	a.hp = R.HP[0]
	presentation.update_gauges(0.1)
	assert(presentation.life_trail[0] == 1,"Healing immediately synchronizes trail")
	a.meter = 0.99
	assert(presentation.meter_count(a) == 0)
	a.meter = 1.01
	assert(presentation.meter_count(a) == 1)
	a.meter = 3
	assert(presentation.meter_count(a) == 3)
	a.v_cooldown = 3.5
	assert(is_equal_approx(presentation.v_ratio(a),0.5),"Old roster V gauge reflects cooldown")
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.physical_keycode = KEY_ENTER
	_unhandled_key_input(enter)
	assert(intro_time == 0,"Intro can be skipped")
	assert(a.visual.state == "idle","Skipping intro releases its visual animation lock")
	a.super_move()
	_unhandled_key_input(enter)
	assert(cinematic == 0 and a.meter == 0 and a.active > 0,"Skipping CA cannot refund meter or cancel attack")
	a.meter = 1.6
	b.meter = 0.4
	finish(0)
	assert(round_wins == [1,0] and not match_complete,"First win is a round, not the match")
	primary_result()
	assert(round_number == 2 and round_wins == [1,0] and fighters[0].meter == 1.6)
	assert(fighters[0].hp == R.HP[selected],"Next round restores health and preserves super meter")
	finish(1)
	primary_result()
	assert(round_number == 3 and round_wins == [1,1])
	finish(0)
	assert(match_complete and round_wins == [2,1],"First to two completes match")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	_unhandled_key_input(escape)
	assert(screen == "select","Results can return to selection with Escape")
	restart_match()
	assert(round_number == 1 and round_wins == [0,0])
	print("HUD PASS: delayed HP / gauge thresholds / V cooldown / skip safety / real best-of-three")
	selected = 3
	start_match(true,false)
	a = fighters[0]
	b = fighters[1]
	a.v_meter = 50
	assert(is_equal_approx(presentation.v_ratio(a),0.5),"New roster V gauge reflects actual resource")
	b.stun = 0
	b.receive({"damage":40},a)
	b.receive({"damage":40},a)
	assert(combo[0] == 2 and combo_damage[0] == 80,"True linked hits accumulate damage for the real attacker")
	b.stun = 0
	b.receive({"damage":40},a)
	assert(combo[0] == 1 and combo_damage[0] == 40,"A recovered opponent starts a new combo")
	print("HUD PASS: independent V resource / correct-side combo / damage tally / combo break")
	start_demo()
	_unhandled_key_input(escape)
	assert(not demo_mode and screen == "select","Showcase can be exited without watching the full sequence")
	start_demo()
	assert(demo_mode and demo_segment == 0 and selected == 0)
	update_demo(6.01)
	assert(demo_ca_started and ca_kind == 0 and cinematic > 0)
	update_demo(4.01)
	assert(demo_ko_started and screen == "result")
	update_demo(2.0)
	assert(demo_segment == 1 and selected == 1)
	update_demo(60)
	assert(not demo_mode and screen == "select","Showcase ends cleanly after six scenes")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(255,350)
	_unhandled_input(click)
	assert(selected == 3,"Character portraits select their whole card, not only the label button")
	print("PRESENTATION PASS: scripted 72-second showcase / scheduled CA / KO / next scene / automatic exit")

func run_frame_checks() -> void:
	var count := 0
	for sheet in Frames.data().sheets:
		var entries: Array = Frames.data().sheets[sheet].frames
		for index in range(entries.size()):
			var pose: Dictionary = Frames.get_frame(sheet,index)
			var image: Image = pose.texture.get_image()
			var actual := image.get_data()
			var original: PackedByteArray = Frames.raw_sources[sheet]
			var runs: Array = entries[index].runs
			for n in range(0,runs.size(),3):
				var target := int(runs[n])*4
				var length := int(runs[n+1])*4
				var source := int(runs[n+2])*4
				assert(actual.slice(target,target+length) == original.slice(source,source+length),"Isolated frame must retain its original pixels")
			var container := Rect2(0,0,180,100)
			assert(container.grow(0.001).encloses(Frames.fit_rect(pose,container)),"Whole weapon must fit portrait bounds")
			for polygon in Frames.attachments(pose,container,true):
				for point in polygon:
					assert(container.grow(0.001).has_point(point),"Detachable chip horns must fit UI bounds")
			var ref: Rect2 = pose.reference
			var core: Array = entries[index].core_box
			var foot := (float(core[1])+float(core[3])-ref.position.y)/ref.size.y*192-96-88
			assert(absf(foot) < 0.001,"Foot anchor must remain stable across poses")
			count += 1
	assert(count == 56)
	var upright: Dictionary = Frames.get_frame("cat_actions.png",0)
	var crouched: Dictionary = Frames.get_frame("cat_actions.png",3)
	var head_up: Vector2 = Frames.attachments(upright,Rect2(-96,-96,192,192))[0][0]
	var head_down: Vector2 = Frames.attachments(crouched,Rect2(-96,-96,192,192))[0][0]
	assert(head_down.y-head_up.y > 20,"Chip horns must follow the lowered crouching head")
	var thrust: Dictionary = Frames.get_frame("meme_fighters_atlas.png",7)
	var raised: Dictionary = Frames.get_frame("meme_fighters_atlas.png",19)
	assert(thrust.box.end.x > 534 and raised.box.position.y < 734,"Cross-cell sword pixels must remain in dog frames")
	print("FRAME PASS: 56 isolated poses / original pixels / no clipped sword / stable anchors / bounded UI")

func run_smoke() -> void:
	# Exercise real combat rules, not only parsing or scene existence.
	for kind in range(R.NAMES.size()):
		selected = kind
		rival = (kind+1)%R.NAMES.size()
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
		if kind == 2:
			assert(b.hp == before,"Cat normal has a real windup")
			a.tick(0.15,false)
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
		if kind in [1,2,5]:
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
	for kind in range(R.NAMES.size()):
		selected = kind
		rival = (kind+1)%R.NAMES.size()
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
	run_dlc_checks()
	run_duo_checks()
	run_presentation_checks()
	run_frame_checks()
	for character in range(R.NAMES.size()):
		selected = character
		start_match(true,false)
		var visual = fighters[0].visual
		assert(visual.texture != null,"Pixel art atlas must be imported")
		if character in [0,2]:
			assert(visual.dedicated,"Duo characters must load their dedicated action sheets")
			assert(visual.texture.get_width() == visual.texture.get_height() and visual.texture.get_width() >= 512)
		else:
			assert(visual.texture.get_width() % 6 == 0 and visual.texture.get_height() % 4 == 0)
		var library: Dictionary = (visual.PENGUIN_CLIPS if character == 0 else visual.CAT_CLIPS) if visual.dedicated else visual.CLIPS
		for clip in library:
			assert(library[clip].size() >= 4,"Every state has a frame sequence")
			for pose in library[clip]:
				assert(pose >= 0 and pose < (16 if visual.dedicated else 4),"Pose index fits the imported atlas")
			fighters[0].velocity = Vector2(100,0) if clip == "walk" else Vector2.ZERO
			fighters[0].grounded = clip != "jump"
			fighters[0].crouching = clip == "crouch"
			fighters[0].charging = clip == "charge"
			visual.play(clip,0.5)
			visual._process(0.2)
			assert(visual.state == clip and visual.clock > 0,"Animation playback must advance")
		print("ANIMATION PASS: ",R.NAMES[character]," / ",visual.CLIPS.size()," clips")
	back_to_menu()
	assert(panel.get_child_count() == 15,"Selection menu buttons")
	print("MEME BRAWL SMOKE PASS")
	get_tree().quit(0)
