extends SceneTree
const Arena = preload("res://scripts/arena.gd")
var arena: Node2D
var visual := false

func _initialize() -> void:
	visual = "--capture-stages" in OS.get_cmdline_user_args()
	run.call_deferred()

func run() -> void:
	arena = Arena.new()
	root.add_child(arena)
	arena.smoke = true
	arena.combo_help = false
	arena.set_physics_process(false)
	arena.character_audio.set_process(false)
	assert(arena.R.STAGES.size() == 6)
	assert(arena.home_stages.backgrounds.size() == 6 and arena.home_stages.props.size() == 6)
	for texture in arena.home_stages.backgrounds:
		assert(texture.get_width() >= 1152 and texture.get_height() >= 648)
	var prop_image = arena.home_stages.props[0].atlas.get_image()
	assert(prop_image.get_format() == Image.FORMAT_RGBA8 and prop_image.get_pixel(0,0).a == 0,"Props require a genuinely transparent background")
	var stages = arena.home_stages
	DirAccess.make_dir_recursive_absolute("res://docs/stages")
	for kind in range(6):
		arena.manual_stage = false
		arena.selected = kind
		arena.rival = (kind+1)%6
		arena.start_match(true,false)
		arena.intro_time = 0
		arena.cinematic = 0
		assert(arena.stage == kind and stages.stage == kind,"Default home stage follows player")
		assert(stages.backdrop.texture == stages.backgrounds[kind],"Correct illustrated map must be loaded")
		var hp: Array = [arena.fighters[0].hp,arena.fighters[1].hp]
		var meter: Array = [arena.fighters[0].meter,arena.fighters[1].meter]
		for i in range(1200): stages.tick(1.0/60)
		assert([arena.fighters[0].hp,arena.fighters[1].hp] == hp,"Decorations cannot damage fighters")
		assert([arena.fighters[0].meter,arena.fighters[1].meter] == meter)
		assert(arena.projectiles.is_empty(),"Map effects cannot enter combat projectiles")
		assert(stages.sparks.size() <= 80 and stages.drops.size() < 12)
		arena.paused = true
		var age: float = stages.clock
		stages.tick(1)
		assert(stages.clock == age,"Paused map animation must freeze")
		arena.paused = false
		if visual:
			stages.clock = 10.3 if kind == 1 else 8.5
			await capture("stage_%d" % kind)
		# Trigger from actual battle methods rather than only calling visual setters.
		var fighter = arena.fighters[0]
		fighter.active = 0
		fighter.cooldown = 0
		fighter.special(0,false)
		if kind == 1: assert(stages.pulse > 0,"Dog skill lights wall cuts")
		fighter.active = 0
		fighter.cooldown = 0
		fighter.meter = 3
		fighter.super_move()
		if kind in [2,3,5]: assert(stages.burst > 0,"CA must trigger home backdrop")
		arena.cinematic = 0
		if kind == 4:
			fighter.active = 0
			fighter.cooldown = 0
			fighter.v_skill()
			assert(fighter.charging)
			fighter.charge = 1.5
			fighter.grounded = false
			fighter.position.y = 531
			fighter.velocity.y = 100
			fighter.tick(.03,false)
			assert(stages.crack > 0 and not stages.sparks.is_empty(),"Real bull landing must raise dust")
			stages.crack = 0
			arena.fighters[1].invulnerable = 0
			arena.fighters[1].blocking = false
			arena.fighters[1].receive({"damage":100,"strength":2},fighter)
			assert(stages.crack > 0,"Real heavy impact must expand cracks")
		if visual:
			stages.tick(.35)
			await capture("stage_%d_link" % kind)
		stages.reset(kind)
		assert(stages.burst == 0 and stages.pulse == 0 and stages.sparks.is_empty())
	# Manual stage selection is preserved; arcade chooses opponent's home.
	arena.manual_stage = true
	arena.stage = 5
	arena.selected = 0
	arena.start_match(true,false)
	assert(arena.stage == 5)
	var visited: Array = []
	for i in range(6):
		arena.cycle_stage()
		visited.append(arena.stage)
	assert(visited == [0,1,2,3,4,5])
	arena.manual_stage = false
	arena.start_match(false,true)
	assert(arena.stage == arena.rival)
	arena.next_arcade()
	assert(arena.stage == arena.rival)
	# Match soundtrack follows map even when a different fighter is selected.
	arena.smoke = false
	arena.manual_stage = true
	arena.stage = 3
	arena.selected = 1
	arena.start_match(true,false)
	arena.character_audio._process(2)
	assert(arena.character_audio.active_track == 9)
	assert(arena.character_audio.map_tracks.size() == 6)
	arena.manual_stage = false
	arena.selected = 0
	arena.start_match(true,false)
	assert(arena.banner.contains("咕咕～"))
	assert(arena.character_audio.ambient_player.stream == arena.character_audio.ambience["gugu_home"])
	arena.smoke = true
	for player in arena.sound_players:
		player.stop()
		player.stream = null
	arena.character_audio.silence()
	print("HOME STAGES PASS: six homes / manual selection / arcade homes / real skill and CA hooks / harmless bounded effects / pause / reset / map soundtrack")
	arena.queue_free()
	await process_frame
	await create_timer(.4).timeout
	quit()

func capture(filename: String) -> void:
	arena.banner_time = 0
	arena.home_stages.update_backdrop()
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png("res://docs/stages/%s.png" % filename) == OK)
