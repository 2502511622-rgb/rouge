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
	print("VISUAL CHECK PASS: horn-ready / horn-loss / regrowth / ground-shard / migration")
	quit(0)
