extends Node
## Separate material SFX bus; voice overrides remain in Arena.sound().

const NAMES = ["swing","kick","hit_light","hit_medium","hit_heavy","block","metal","slash","sonic","shard","slime","quake","uppercut","counter","ex","ca","land","power","throw"]
var arena: Node2D
var clips: Dictionary = {}
var players: Array = []
var cursor := 0

func _ready() -> void:
	for name in NAMES:
		var path: String = "res://assets/audio/combat/"+name+".ogg"
		if ResourceLoader.exists(path): clips[name] = load(path)
	for i in range(16):
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)

func play_clip(name: String, strength := 1, quiet := false) -> void:
	if arena.muted or arena.smoke or not clips.has(name): return
	var player: AudioStreamPlayer = players[cursor]
	cursor = (cursor+1)%players.size()
	player.stream = clips[name]
	player.pitch_scale = [1.08,1.0,0.93][clampi(strength,0,2)]
	player.volume_db = -15 if quiet else (-10 if strength == 0 else -8)
	player.play()

func stop_all() -> void:
	for player in players: player.stop()

func skill_name(kind: int, move: int) -> String:
	return [["sonic","swing","kick"],["metal","uppercut","slash"],["shard","counter","swing"],["slime","swing","quake"],["quake","uppercut","quake"],["kick","uppercut","throw"]][kind][move]

func skill(kind: int, move: int, ex: bool) -> void:
	play_clip(skill_name(kind,move),2 if ex else 1)
	if ex: play_clip("ex",1,true)

func impact(kind: int, guarded: bool, strength: int, data: Dictionary, shield := false) -> void:
	if data.get("finisher",false) and not guarded:
		play_clip("ca",2,true)
		play_clip("hit_heavy",2)
		return
	if guarded:
		play_clip("metal" if shield else "block",0)
	elif data.get("counter",false): play_clip("counter",2)
	elif data.get("throw",false): play_clip("throw",2)
	else:
		play_clip(["hit_light","hit_medium","hit_heavy"][clampi(strength,0,2)],strength)
		if kind == 1: play_clip("metal",0,true)
		elif kind == 2: play_clip("shard",0,true)
		elif kind == 4 and data.get("special",false): play_clip("quake",1,true)
