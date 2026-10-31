extends Node2D
## Isolated pose textures + per-frame pose, offset, rotation and squash keys.
## These are original assets; this is not a rip of a meme video or another game.

const Motion = preload("res://scripts/skill_motion.gd")
const Frames = preload("res://scripts/sprite_frames.gd")
const ATLAS_PATH = "res://assets/art/meme_fighters_atlas.png"
const CLIPS = {
	"idle": [0,0,0,0,0,0], "walk": [0,1,0,0,1,0,0,0],
	"crouch": [0,0,0,0], "jump": [0,2,2,0,0,0],
	"punch_0": [0,1,1,0,0], "punch_1": [0,0,1,1,1,0,0],
	"punch_2": [0,3,1,1,1,0,0,0],
	"kick_0": [0,2,2,0,0], "kick_1": [0,0,2,2,2,0,0],
	"kick_2": [0,3,2,2,2,0,0,0],
	"special_0": [0,3,3,1,1,0,0,0],
	"special_1": [0,0,1,1,2,2,0,0],
	"special_2": [0,2,3,3,2,0,0,0],
	"ex_0": [0,3,1,2,1,2,1,3,0,0],
	"ex_1": [0,1,1,0,1,1,0,1,2,0],
	"ex_2": [0,3,2,3,2,3,2,3,0,0],
	"ca": [0,0,3,3,3,1,2,1,2,1,2,3,3,0],
	"v": [0,3,3,0,3,0], "trigger": [0,0,3,3,3,0,3,0],
	"throw": [0,1,1,3,2,0,0], "hit": [0,3,3,0,0],
	"block": [0,0,1,0,0], "ko": [0,3,3,0,0,0,0,0],
	"win": [0,3,0,3,3,0,3,0], "taunt": [0,3,3,0,3,0,0,0],
	"charge": [0,3,0,3,3,0], "intro": [0,0,3,0,3,0],
}
const DUO_PATHS = {0:"res://assets/art/gugu_actions.png",2:"res://assets/art/cat_actions.png"}
const PENGUIN_CLIPS = {
 "idle":[0,0,0,0,0,0],"walk":[1,0,2,0,1,0,2,0],"crouch":[3,3,3,3],"jump":[4,4,5,5,0],
 "punch_0":[0,6,6,0],"punch_1":[0,6,7,6,0],"punch_2":[3,7,7,0],
 "kick_0":[0,8,8,0],"kick_1":[0,9,9,0],"kick_2":[3,9,12,0],
 "special_0":[0,10,10,0],"special_1":[3,11,11,0],"special_2":[4,12,12,5,0],
 "ex_0":[10,0,10,0,10,0],"ex_1":[4,11,12,11,5,0],"ex_2":[4,12,12,12,5],
 "ca":[3,10,10,10,10,0],"v":[0,4,10,4,0],"trigger":[0,4,10,4,0],
 "throw":[0,6,7,12,0],"hit":[0,14,14,0],"block":[0,13,13,0],"ko":[14,15,15,15,15],
 "win":[0,4,12,0,4,0],"taunt":[0,10,0,3,0],"charge":[0,3,3,0],"intro":[0,4,10,0]}
const CAT_CLIPS = {
 "idle":[0,0,0,0,0,0],"walk":[1,0,2,0,1,0,2,0],"crouch":[3,3,3,3],"jump":[4,4,4,0],
 "punch_0":[0,5,5,0],"punch_1":[0,5,6,5,0],"punch_2":[0,9,6,6,0],
 "kick_0":[0,7,7,0],"kick_1":[0,3,7,0],"kick_2":[3,7,7,0],
 "special_0":[0,8,8,0],"special_1":[0,9,9,9,0],"special_2":[2,13,1,13,0],
 "ex_0":[0,8,8,8,11,0],"ex_1":[0,9,10,10,11],"ex_2":[0,9,9,10,11],
 "ca":[0,9,10,10,10,11],"v":[9,9,10,10,11],"trigger":[0,9,10,11],
 "throw":[0,5,6,10,0],"hit":[0,14,14,0],"block":[0,13,13,0],"ko":[14,15,15,15,15],
 "win":[0,3,3,15,15,15],"taunt":[0,9,0,11,0],"charge":[0,9,9,0],"intro":[0,9,0,0]}
var dedicated := false
var fighter: Node2D
var texture: Texture2D
var state := "idle"
var clock := 0.0
var duration := 0.6
var locked := false
var recorded: Dictionary = {}

func _ready() -> void:
	var path: String = DUO_PATHS.get(fighter.kind,ATLAS_PATH)
	if ResourceLoader.exists(path):
		texture = load(path)
		dedicated = fighter.kind in DUO_PATHS
	elif ResourceLoader.exists(ATLAS_PATH): texture = load(ATLAS_PATH)

func play(clip: String, seconds := 0.6) -> void:
	assert(CLIPS.has(clip))
	state = clip
	clock = 0
	duration = maxf(0.1,seconds)
	locked = clip not in ["idle","walk","crouch","jump","charge"]
	queue_redraw()

func _process(dt: float) -> void:
	if fighter == null: return
	if fighter.arena.paused or fighter.arena.show_help or fighter.arena.hit_pause > 0: return
	clock += dt
	if locked and clock >= duration:
		if state in ["ko","win"]:
			clock = duration - 0.001
		else: locked = false
	if not locked:
		var next := "idle"
		if fighter.hp <= 0: next = "ko"
		elif fighter.stun > 0: next = "hit"
		elif fighter.blocking: next = "block"
		elif fighter.charging: next = "charge"
		elif not fighter.grounded: next = "jump"
		elif fighter.crouching: next = "crouch"
		elif absf(fighter.velocity.x) > 25: next = "walk"
		if state != next: play(next,0.5)
	queue_redraw()

func _draw() -> void:
	if texture == null or fighter == null: return
	var keys: Array = (PENGUIN_CLIPS if fighter.kind == 0 else CAT_CLIPS)[state] if dedicated else CLIPS[state]
	var t := clampf(clock / duration,0,0.999) if locked else fmod(clock / duration,1.0)
	var frame := mini(keys.size()-1,int(t*keys.size()))
	var row: int = keys[frame]
	var offset := Vector2.ZERO
	var scale_pose := Vector2.ONE
	var angle := 0.0
	var beat := sin(t*TAU)
	if state == "idle":
		offset.y = roundf(beat*2)
		scale_pose.y = 1+beat*0.018
	elif state == "walk":
		offset.y = -absf(beat)*6
		angle = beat*0.05
	elif state == "crouch":
		scale_pose = Vector2(1.12,0.68)
		offset.y = 25
	elif state == "jump":
		angle = -0.15*beat
		scale_pose = Vector2(0.96,1.06)
	elif state == "ko":
		angle = -1.5*minf(1,t*2.5)
		offset = Vector2(-22*t,65*t)
	elif state == "hit":
		offset.x = -sin(t*PI)*18
		angle = -sin(t*PI)*0.22
	elif state == "block":
		offset.x = -8*absf(beat)
		scale_pose.x = 0.94
	elif state.begins_with("punch") or state.begins_with("kick") or state.begins_with("special") or state.begins_with("ex"):
		offset.x = sin(t*PI)*16
		angle = sin(t*PI)*0.12
		scale_pose = Vector2(1+sin(t*PI)*0.08,1-sin(t*PI)*0.04)
		if fighter.kind == 3 and state == "ex_0": angle = t*TAU*2
		if state.ends_with("2") and fighter.kind == 3: offset.y -= sin(t*PI)*30
	elif state == "ca":
		offset.x = sin(t*PI*6)*10
		scale_pose = Vector2.ONE*(1+sin(t*PI)*0.17)
	elif state in ["v","trigger","charge","taunt","win"]:
		offset.y = -absf(beat)*8
		angle = beat*0.08
	if state.begins_with("special_") or state.begins_with("ex_"):
		var motion: Dictionary = Motion.sample(fighter.kind,int(state.right(1)),state.begins_with("ex_"),t)
		offset = motion.offset
		angle = motion.angle
		scale_pose = motion.scale
	if dedicated and state == "ko":
		angle = 0
		offset = Vector2(-10*minf(1,t*2),0)
	if dedicated and state == "crouch":
		offset = Vector2.ZERO
		scale_pose = Vector2.ONE
	if dedicated and fighter.kind == 0 and state in ["special_2","ex_2"]:
		angle = t*TAU
	if dedicated and fighter.kind == 0 and state == "win":
		angle = t*TAU
		offset.y = -absf(beat)*14
	if dedicated and fighter.kind == 2 and state == "win":
		angle = 0
		offset = Vector2.ZERO
	if dedicated and fighter.kind == 2:
		if fighter.v_time > 0 and state in ["idle","v","special_1","ex_2"]: row = 9 if fighter.counter_startup <= 0 else 0
		if fighter.horns > 0:
			if row == 0: row = 11
			if row in [5,6]: row = 12
	var face: float = fighter.facing
	draw_set_transform(Vector2(0,-88)+offset*Vector2(face,1),angle*face,scale_pose*Vector2(face,1))
	var sheet := ("gugu_actions.png" if fighter.kind == 0 else "cat_actions.png") if dedicated else "meme_fighters_atlas.png"
	var index: int = row if dedicated else row*6+fighter.kind
	var pose: Dictionary = Frames.get_frame(sheet,index)
	var isolated: Texture2D = pose.texture
	recorded = {"texture":isolated,"rect":Frames.battle_rect(pose,Rect2(-96,-96,192,192)),"transform":Transform2D(angle*face,scale_pose*Vector2(face,1),0,Vector2(0,-88)+offset*Vector2(face,1))}
	var tint := Color.WHITE
	if fighter.flash > 0: tint = Color(2.2,1.5,1.3)
	if state.begins_with("ex"):
		draw_texture_rect(isolated,Frames.battle_rect(pose,Rect2(-104,-102,208,208)),false,Color(1,0.75,0.15,0.22))
	draw_texture_rect(isolated,Frames.battle_rect(pose,Rect2(-96,-96,192,192)),false,tint)
	if dedicated and state == "ca":
		if fighter.kind == 0:
			for ring in range(4):
				draw_arc(Vector2(55,0),45+ring*28+sin(clock*16)*5,-1.4,1.4,14,Color(0.45,0.93,1.0,0.8-ring*0.12),4)
		elif fighter.kind == 2:
			for shard in range(10):
				var direction := Vector2.from_angle(shard*TAU/10+clock*2)
				var at := direction*(95+sin(clock*18)*18)
				draw_colored_polygon(PackedVector2Array([at+direction*20,at-direction*7+direction.orthogonal()*9,at-direction*7-direction.orthogonal()*9]),Color("f0bc4b"))
	if dedicated and fighter.kind == 2 and fighter.horns <= 0 and state != "ko":
		for chip in Frames.attachments(pose,Rect2(-96,-96,192,192)):
			draw_colored_polygon(chip,Color("ecb439"))
			draw_polyline(PackedVector2Array([chip[0],chip[1],chip[2],chip[0]]),Color("744c22"),2)
	draw_set_transform(Vector2.ZERO)

func snapshot() -> Dictionary:
	if recorded.is_empty(): return {}
	var result := recorded.duplicate()
	result.transform = fighter.transform * recorded.transform
	return result
