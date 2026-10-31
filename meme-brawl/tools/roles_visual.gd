extends SceneTree
const Arena = preload("res://scripts/arena.gd")
var arena: Node2D
func _initialize() -> void:
	run.call_deferred()
func capture(name: String) -> void:
	arena.queue_redraw()
	arena.fx.queue_redraw()
	arena.fx.glow.queue_redraw()
	for f in arena.fighters: f.visual.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/tmp/meme-roles-visual/"+name) == OK)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("/tmp/meme-roles-visual")
	arena = Arena.new()
	root.add_child(arena)
	arena.muted = true
	arena.set_physics_process(false)
	arena.fx.set_process(false)
	await capture("selection.png")
	for kind in range(6):
		arena.selected = kind
		arena.rival = (kind+1)%6
		arena.start_match(true,false)
		arena.combo_coach.start()
		for f in arena.fighters: f.visual.set_process(false)
		await capture("ready_%d.png"%kind)
		var feature := false
		var finished := false
		var feature_time: float = [0.4,0.03,0.2,0.25,1.0,0.1][kind]
		for i in range(2200):
			arena._physics_process(1.0/120)
			for f in arena.fighters: f.visual._process(1.0/120)
			arena.fx._process(1.0/120)
			if arena.combo_coach.timeout >= feature_time and not feature:
				feature = true
				await capture("role_%d.png"%kind)
			if arena.combo[0] == [7,7,7,14,7,8][kind]:
				await capture("finish_%d.png"%kind)
				finished = true
				break
		assert(finished,"Role screenshot must follow actual hits and cancels")
	arena.back_to_menu()
	arena.choose(3)
	arena.toggle_help()
	arena._physics_process(0)
	await capture("simple_moves.png")
	print("ROLE VISUAL PASS: simple move sheet / role cards / ranged, counter, trap, 14-hit frog, charge, midrange lessons")
	quit()
