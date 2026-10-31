extends Node2D
## Four authored atlas poses + per-frame pose, offset, rotation and squash keys.
## These are original assets; this is not a rip of a meme video or another game.

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
var fighter: Node2D
var texture: Texture2D
var state := "idle"
var clock := 0.0
var duration := 0.6
var locked := false

func _ready() -> void:
	if ResourceLoader.exists(ATLAS_PATH): texture = load(ATLAS_PATH)

func play(clip: String, seconds := 0.6) -> void:
	assert(CLIPS.has(clip))
	state = clip
	clock = 0
	duration = maxf(0.1,seconds)
	locked = clip not in ["idle","walk","crouch","jump","charge"]
	queue_redraw()

func _process(dt: float) -> void:
	if fighter == null: return
	if fighter.arena.paused or fighter.arena.show_help: return
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
	var keys: Array = CLIPS[state]
	var t := clampf(clock / duration,0,0.999) if locked else fmod(clock / duration,1.0)
	var frame := mini(keys.size()-1,int(t*keys.size()))
	var row: int = keys[frame]
	var cell := Vector2(texture.get_width()/6.0,texture.get_height()/4.0)
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
	var face: float = fighter.facing
	draw_set_transform(Vector2(0,-88)+offset*Vector2(face,1),angle*face,scale_pose*Vector2(face,1))
	var region := Rect2(Vector2(fighter.kind*cell.x,row*cell.y),cell).grow(-10)
	var tint := Color.WHITE
	if fighter.flash > 0: tint = Color(2.2,1.5,1.3)
	if state.begins_with("ex"):
		draw_texture_rect_region(texture,Rect2(-104,-102,208,208),region,Color(1,0.75,0.15,0.22))
	draw_texture_rect_region(texture,Rect2(-96,-96,192,192),region,tint)
	draw_set_transform(Vector2.ZERO)
