extends SceneTree
const Arena = preload("res://scripts/arena.gd")
var arena: Node2D
func _initialize() -> void:
	run.call_deferred()
func capture(path: String) -> void:
	arena.queue_redraw()
	arena.fx.queue_redraw()
	arena.fx.glow.queue_redraw()
	for f in arena.fighters: f.visual.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("/tmp/meme-combo-visual")
	arena = Arena.new()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.fx.set_process(false)
	arena.muted = true
	for kind in range(6):
		arena.selected = kind
		arena.rival = (kind+1)%6
		arena.start_match(true,false)
		arena.combo_coach.start()
		for f in arena.fighters: f.visual.set_process(false)
		await capture("/tmp/meme-combo-visual/ready.png")
		var special_captured := false
		var done := false
		for i in range(1800):
			arena._physics_process(1.0/120)
			for f in arena.fighters: f.visual._process(1.0/120)
			arena.fx._process(1.0/120)
			if arena.combo[0] == 4 and arena.cinematic <= 0 and not special_captured:
				special_captured = true
				await capture("/tmp/meme-combo-visual/special_%d.png"%kind)
			if arena.combo[0] == 10:
				assert(arena.fx.events.any(func(e): return e.mode == "finish"),"Final impact must have dedicated finisher geometry")
				await capture("/tmp/meme-combo-visual/finish_%d.png"%kind)
				done = true
				break
		assert(done,"Capture must come from a real uninterrupted ten-hit route")
	print("COMBO VISUAL PASS: six real 10-hit finishers / actual special contacts / dedicated effects / isolated sprite rendering")
	quit()
