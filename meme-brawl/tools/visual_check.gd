extends SceneTree
## Deterministic screenshots of short-lived visual states; requires a display.

const Arena = preload("res://scripts/arena.gd")
var arena: Node2D
const OUTPUT = "/tmp/meme-duo-visual"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("visual_check requires a graphical or virtual display")
		quit(1)
		return
	run.call_deferred()

func capture(filename: String) -> void:
	arena.queue_redraw()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT+"/"+filename)
	assert(result == OK,"Screenshot must be saved")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	arena = Arena.new()
	root.add_child(arena)
	arena.muted = true
	arena.selected = 2
	arena.rival = 0
	arena.start_match(true,false)
	arena.intro_time = 0
	await capture("cat_ready.png")
	var cat = arena.fighters[0]
	cat.special(0,false)
	await capture("cat_shot.png")
	assert(cat.horns > 0,"Capture must occur before horns regenerate")
	cat.horns = 0
	cat.active = 0
	cat.cooldown = 0
	cat.visual.play("idle")
	await capture("cat_regrown.png")
	arena.projectiles.clear()
	arena.spawn_projectile(cat,0,true)
	arena.projectiles[0].position = Vector2(570,515)
	arena.tick_projectiles(0.02)
	await capture("cat_trap.png")
	assert(arena.projectiles[0].trap)
	arena.selected = 0
	arena.rival = 2
	arena.new_round()
	arena.intro_time = 0
	arena.fighters[0].v_skill()
	await capture("gugu_migration.png")
	arena.selected = 2
	arena.rival = 1
	arena.start_match(true,false)
	arena.intro_time = 0
	arena.fighters[1].hp = 0
	arena.finish(0)
	arena.result_time = 1.2
	arena.panel.visible = true
	arena.fighters[0].horns = 0
	arena.fighters[0].visual.play("win",1.0)
	arena.fighters[0].visual.clock = 0.9
	arena.fighters[0].visual.set_process(false)
	await capture("cat_win_attachment.png")
	arena.selected = 3
	arena.rival = 4
	arena.start_match(false,false)
	arena.intro_time = 0
	arena.round_wins = [1,1]
	arena.round_number = 3
	arena.fighters[0].hp = 237
	arena.fighters[0].meter = 1.65
	arena.fighters[0].v_meter = 45
	arena.fighters[1].hp = 810
	arena.fighters[1].meter = 3
	arena.fighters[1].v_meter = 80
	arena.presentation.reset()
	await capture("hud_damage.png")
	arena.intro_time = 2.5
	await capture("versus.png")
	arena.intro_time = 0
	arena.begin_ca(4)
	arena.cinematic = arena.ca_duration*0.65
	await capture("critical_art.png")
	arena.cinematic = 0
	arena.fighters[1].hp = 0
	arena.finish(0)
	arena.result_time = 0.3
	await capture("ko.png")
	arena.result_time = 1.2
	arena.panel.visible = true
	await capture("winner.png")
	arena.back_to_menu()
	await capture("selection.png")
	print("UI VISUAL CHECK PASS: health / super / V / final round / VS / CA / KO / winner / selection")
	print("VISUAL CHECK PASS: horn-ready / horn-loss / regrowth / ground-shard / migration")
	quit(0)
