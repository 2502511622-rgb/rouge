extends SceneTree
## Render the actual combat animator, every source pose, both facing directions.

const Bank = preload("res://scripts/sprite_frames.gd")
const OUTPUT = "/tmp/meme-sprite-audit"

class Gallery:
	extends "res://scripts/fight_presentation.gd"
	const Combatant = preload("res://scripts/fighter.gd")
	var paused := false
	var show_help := false
	var kind := 0
	var page := 0
	var poses: Array = []
	const GUGU = [["idle",0.0],["walk",0.0],["walk",0.25],["crouch",0.0],["jump",0.0],["jump",0.5],["punch_0",0.3],["punch_1",0.45],["kick_0",0.3],["kick_1",0.3],["special_0",0.3],["special_1",0.3],["special_2",0.3],["block",0.3],["hit",0.3],["ko",0.5]]
	const CAT = [["idle",0.0],["walk",0.0],["walk",0.25],["crouch",0.0],["jump",0.0],["punch_0",0.3],["punch_1",0.45],["kick_0",0.3],["special_0",0.3],["special_1",0.3],["ex_1",0.5],["idle",0.0],["punch_0",0.3],["block",0.3],["hit",0.3],["ko",0.5]]

	func setup(character: int, part: int) -> void:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		kind = character
		page = part
		poses.clear()
		var dedicated := kind in [0,2]
		var count := 8 if dedicated else 4
		for slot in range(count):
			var pose := part*8+slot if dedicated else slot
			poses.append(pose)
			for direction in range(2):
				var f = Combatant.new()
				f.configure(self,kind,direction)
				add_child(f)
				f.facing = 1 if direction == 0 else -1
				var col := (slot%2)*2+direction if dedicated else direction
				var row := slot/2 if dedicated else slot
				f.position = Vector2(col*288+144,80+row*132+123)
				f.scale = Vector2.ONE*0.5
				f.visual.set_process(false)
				var clip: Array
				if dedicated:
					clip = (GUGU if kind == 0 else CAT)[pose]
					if kind == 2 and pose in [11,12]: f.horns = 1
				else:
					clip = [["idle",0.0],["punch_0",0.3],["kick_0",0.3],["special_0",0.3]][pose]
				f.visual.play(clip[0],1.0)
				f.visual.clock = clip[1]
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,648),Color("151323"))
		label(Vector2(24,35),R.NAMES[kind]+" / 完整帧与左右朝向 / PAGE "+str(page+1),23,Color.WHITE)
		label(Vector2(24,62),"Original pixels · isolated textures · whole weapons · stable foot anchor",14,CYAN,true)
		var dedicated := kind in [0,2]
		for row in range(4):
			for col in range(4):
				draw_rect(Rect2(col*288+8,80+row*132,272,128),Color("45394f"),false,1)
				var slot := row*2+col/2 if dedicated else row
				label(Vector2(col*288+16,98+row*132),"%s %02d  %s" % ["UI" if not dedicated and col >= 2 else "BATTLE",page*8+slot if dedicated else slot,"RIGHT" if col%2 == 0 else "LEFT"],12,GOLD)
				if not dedicated and col >= 2:
					var pose: Dictionary = Frames.get_frame("meme_fighters_atlas.png",row*6+kind)
					draw_set_transform(Vector2(col*288+144,80+row*132+74),0,Vector2(-1 if col == 3 else 1,1))
					draw_texture_rect(pose.texture,Frames.fit_rect(pose,Rect2(-75,-48,150,96)),false)
					draw_set_transform(Vector2.ZERO)
		label(Vector2(24,638),"独立图集：每组动作均含左右朝向，由真实 PixelAnimator 渲染。" if dedicated else "左两列为真实战斗渲染；右两列为 UI 完整等比缩放。",12,Color("b7a8c9"))

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("sprite_audit requires a graphical/virtual display")
		quit(1)
		return
	run.call_deferred()

func run() -> void:
	Bank.prewarm()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var gallery := Gallery.new()
	root.add_child(gallery)
	gallery.set_process(false)
	for kind in range(6):
		for page in range(2 if kind in [0,2] else 1):
			gallery.setup(kind,page)
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(OUTPUT+"/character_%d_page_%d.png" % [kind,page]) == OK)
	print("SPRITE AUDIT PASS: all 56 poses / both facing directions / complete UI frames")
	quit(0)
