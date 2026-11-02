extends SceneTree
const Arena = preload("res://scripts/arena.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	arena.set_physics_process(false)
	var audio = arena.character_audio
	audio.set_process(false)
	assert(audio.tracks.size() == 6 and audio.clips.size() == 30)
	for kind in range(6):
		arena.selected = kind
		arena.rival = (kind+1)%6
		arena.start_match(true,false)
		for voice in arena.sound_players: voice.stop()
		audio.duck_time = 0
		audio._process(2.0)
		await process_frame
		assert(audio.active_track == kind+6)
		assert(audio.music[audio.active_slot].playing)
		assert(not audio.music[1-audio.active_slot].playing,"Previous track must fade out")
		assert(audio.tracks[kind].loop and audio.tracks[kind].get_length() > 25)
		for event in audio.EVENTS:
			audio.play_cue(kind,event)
			var previous: int = audio.cue_cursor
			audio.play_cue(kind,event)
			assert(audio.cue_cursor == previous,"Repeat cue must respect cooldown")
			await create_timer(.025).timeout
		for move in range(3):
			audio.cooldowns.clear()
			var previous: int = audio.cue_cursor
			arena.skill_fx(arena.fighters[0],move,false)
			assert(audio.cue_cursor != previous,"Real skill event routes character cue")
			await create_timer(.025).timeout
		audio.duck_time = 0
		audio._process(2.0)
		assert(is_equal_approx(audio.music[audio.active_slot].volume_db,-19))
		audio.duck(2)
		audio._process(.2)
		assert(audio.music[audio.active_slot].volume_db <= -28)
		audio._process(3)
		assert(is_equal_approx(audio.music[audio.active_slot].volume_db,-19))
		arena.paused = true
		audio._process(1)
		assert(is_equal_approx(audio.music[audio.active_slot].volume_db,-32))
		arena.paused = false
		var voice := AudioStreamWAV.new()
		voice.mix_rate = 22050
		voice.data = PackedByteArray()
		var samples := PackedByteArray()
		samples.resize(44100)
		voice.data = samples
		arena.sound_players[0].stream = voice
		arena.sound_players[0].play()
		audio._process(.1)
		assert(audio.music[audio.active_slot].volume_db <= -28,"Foreground voice ducks music")
		arena.toggle_mute()
		for player in audio.music: assert(not player.playing)
		for player in audio.cues: assert(not player.playing)
		arena.toggle_mute()
		audio._process(2)
		assert(audio.music[audio.active_slot].playing)
	arena.smoke = true
	audio._process(.1)
	for player in audio.music: assert(not player.playing)
	print("CHARACTER AUDIO PASS: six loops / thirty cues / skill routing / repeat limits / duck recovery / mute and resume")
	for player in arena.sound_players:
		player.stop()
		player.stream = null
	arena.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit()
