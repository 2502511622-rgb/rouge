extends SceneTree
const Arena = preload("res://scripts/arena.gd")
const Motion = preload("res://scripts/skill_motion.gd")
var arena: Node2D
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	arena = Arena.new()
	root.add_child(arena)
	arena.smoke = true
	arena.set_physics_process(false)
	assert(arena.combat_audio.clips.size() == 19)
	for clip in arena.combat_audio.clips.values(): assert(clip.get_length() > 0.1 and clip.get_length() < 0.8)
	DirAccess.make_dir_recursive_absolute("/tmp/meme-fx-visual")
	for kind in range(6):
		arena.selected = kind
		arena.rival = (kind+1)%6
		arena.start_match(true,false)
		arena.intro_time = 0
		var actor = arena.fighters[0]
		actor.position.x = 475
		for move in range(3):
			for ex in [false,true]:
				actor.cooldown = 0
				actor.meter = 3
				actor.special(move,ex)
				assert(not arena.fx.events.is_empty())
				for step in range(11):
					var motion: Dictionary = Motion.sample(kind,move,ex,step/10.0)
					assert(motion.offset.is_finite() and motion.scale.is_finite())
					assert(motion.offset.length() < 70 and motion.scale.x > 0 and motion.scale.y > 0)
				arena.fx.clear()
		actor.cooldown = 0
		actor.meter = 3
		actor.special(2 if kind in [1,4] else 0,true)
		actor.visual.clock = actor.visual.duration*0.4
		actor.visual.set_process(false)
		arena.fx.impact(Vector2(660,440),kind,false,2,{},1)
		arena.fx._process(0.06)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/meme-fx-visual/skill_%d.png"%kind)
	if DisplayServer.get_name() != "headless":
		var actor = arena.fighters[0]
		actor.velocity.x = 600
		actor.active = 0.4
		arena.fx.trail_clock = 0
		arena.fx._process(0.05)
		assert(not arena.fx.ghosts.is_empty(),"Rush must capture isolated pose afterimages")
	arena.fx.clear()
	arena.fx.impact(Vector2.ZERO,1,true,0,{},1)
	assert(arena.fx.events[0].mode == "guard")
	arena.fx.clear()
	for i in range(120): arena.fx.emit("dust",Vector2.ZERO,0)
	assert(arena.fx.events.size() == 96)
	arena.new_round()
	assert(arena.fx.events.is_empty() and arena.fx.ghosts.is_empty())
	arena.intro_time = 0
	arena.hit_effect(Vector2(600,440),false,100,0,false,"",{"strength":2})
	assert(arena.hit_pause > 0)
	var before: float = arena.time_left
	arena.training = false
	arena._physics_process(0.016)
	assert(arena.time_left == before,"Hit pause must freeze combat timer")
	arena.toggle_mute()
	for player in arena.combat_audio.players: assert(not player.playing)
	print("EFFECTS PASS: 36 special variants / finite motion / 19 loaded sounds / event cap / reset / hit pause / mute")
	quit()
