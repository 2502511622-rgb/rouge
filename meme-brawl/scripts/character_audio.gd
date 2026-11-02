extends Node
## Original character music, crossfades and contextual mix; no borrowed voices.
const IDS = ["gugu", "dog", "cat", "naiwa", "niulai", "kangaroo"]
const EVENTS = ["skill0", "skill1", "skill2", "v", "ca"]
var arena: Node2D
var music: Array[AudioStreamPlayer] = []
var cues: Array[AudioStreamPlayer] = []
var tracks: Array[AudioStreamOggVorbis] = []
var map_tracks: Array[AudioStreamOggVorbis] = []
var ambience: Dictionary = {}
var ambient_player: AudioStreamPlayer
var clips: Dictionary = {}
var cooldowns: Dictionary = {}
var active_track := -1
var active_slot := 0
var duck_time := 0.0
var cue_cursor := 0

func _ready() -> void:
	for id in IDS:
		var track: AudioStreamOggVorbis = load("res://assets/audio/characters/%s_bgm.ogg" % id)
		track.loop = true
		tracks.append(track)
		for event in EVENTS:
			clips[id+"_"+event] = load("res://assets/audio/characters/%s_%s.ogg" % [id,event])
	for id in IDS:
		var map_track: AudioStreamOggVorbis = load("res://assets/audio/stages/%s_bgm.ogg" % id)
		map_track.loop = true
		map_tracks.append(map_track)
	for id in ["gugu_echo","naiwa_echo","gugu_home"]:
		ambience[id] = load("res://assets/audio/stages/%s.ogg" % id)
	ambient_player = AudioStreamPlayer.new()
	add_child(ambient_player)
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.volume_db = -80
		add_child(player)
		music.append(player)
	for i in range(4):
		var player := AudioStreamPlayer.new()
		add_child(player)
		cues.append(player)

func duck(seconds: float) -> void:
	duck_time = maxf(duck_time, seconds)

func play_cue(kind: int, event: String) -> void:
	if arena.smoke or arena.muted: return
	var key: String = IDS[kind]+"_"+event
	if cooldowns.get(key,0.0) > 0: return
	cooldowns[key] = 1.2 if event == "ca" else 0.22
	var player: AudioStreamPlayer = cues[cue_cursor]
	cue_cursor = (cue_cursor+1)%cues.size()
	player.stream = clips[key]
	player.volume_db = -13 if event != "ca" else -9
	player.play()
	if event == "ca": duck(1.6)

func ambient(kind: int) -> void:
	if arena.smoke or arena.muted or ambient_player.playing: return
	ambient_player.stream = ambience[IDS[kind]+"_echo"]
	ambient_player.volume_db = -23
	ambient_player.play()

func home_call() -> void:
	if arena.smoke or arena.muted: return
	ambient_player.stream = ambience["gugu_home"]
	ambient_player.volume_db = -17
	ambient_player.play()
	duck(1.2)

func silence() -> void:
	ambient_player.stop()
	ambient_player.stream = null
	for player in music:
		player.stop()
		player.stream = null
	for player in cues:
		player.stop()
		player.stream = null
	active_track = -1

func _process(dt: float) -> void:
	for key in cooldowns: cooldowns[key] = maxf(0, cooldowns[key]-dt)
	duck_time = maxf(0, duck_time-dt)
	if arena.smoke or arena.muted:
		silence()
		return
	var in_map: bool = arena.screen in ["fight","result"]
	var kind: int = arena.stage if in_map else arena.selected
	var track_key: int = kind+6 if in_map else kind
	if track_key != active_track:
		active_slot = 1-active_slot
		music[active_slot].stream = map_tracks[kind] if in_map else tracks[kind]
		music[active_slot].volume_db = -80
		music[active_slot].play()
		active_track = track_key
	ambient_player.stream_paused = arena.paused or arena.show_help
	if not in_map: ambient_player.stop()
	var dialogue := false
	for player in arena.sound_players:
		if player.playing: dialogue = true
	var reduced: bool = duck_time > 0 or dialogue or arena.cinematic > 0
	var target := -28.0 if reduced else -19.0
	if arena.paused or arena.screen == "settings": target = -32.0
	for i in range(2):
		var player: AudioStreamPlayer = music[i]
		var volume := target if i == active_slot else -80.0
		player.volume_db = move_toward(player.volume_db, volume, dt*(150.0 if reduced else 65.0))
		if i != active_slot and player.volume_db <= -79: player.stop()
