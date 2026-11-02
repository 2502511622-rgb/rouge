extends Node2D
## Read-only training display; boxes come from the same geometry used by combat.
const Rules = preload("res://scripts/combat_rules.gd")
const FONT = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var arena: Node2D
var show_boxes := false
var show_frames := true
func _process(_dt: float) -> void: queue_redraw()
func label(at: Vector2,value: String,color := Color.WHITE) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
func outline(rect: Rect2,color: Color) -> void:
	if rect.size == Vector2.ZERO: return
	draw_rect(rect,Color(color,.10))
	draw_rect(rect,color,false,2)
func _draw() -> void:
	if arena.screen != "fight" or arena.show_help or arena.paused: return
	for f in arena.fighters:
		if show_boxes:
			outline(f.push_box(),Color(.9,.8,.3,.35))
			outline(f.hurt_box(),Color("68aaff") if f.invulnerable > 0 else Color("5ae4a1"))
			if not f.attack.is_empty() and not f.attack.get("projectile_only",false):
				outline(f.hit_box(),Color("ff65d3") if f.attack.get("throw",false) else (Color("ff6050") if f.strike_live() else Color("d0a052")))
		if show_frames and arena.training:
			var x := 24.0 if f.side == 0 else 726.0
			draw_rect(Rect2(x,166,402,112),Color(.025,.035,.05,.88))
			label(Vector2(x+10,187),"P%d  %s" % [f.side+1,f.phase_name()],Color("e7d497"))
			var data: Dictionary = f.frame_data
			label(Vector2(x+10,210),"前摇 %dF / 有效 %dF / 收招 %dF" % [data.get("startup",0),data.get("active",0),data.get("recovery",0)])
			label(Vector2(x+10,232),"命中 %dF / 防御 %dF · 硬直剩余 %dF" % [data.get("hitstun",0),data.get("blockstun",0),Rules.frames(f.stun)])
			if f.down_time > 0 or f.rising_time > 0:
				label(Vector2(x+10,254),"倒地剩余 %dF / 起身剩余 %dF" % [Rules.frames(f.down_time),Rules.frames(f.rising_time)],Color("9dceeb"))
			elif not f.grabbed.is_empty():
				label(Vector2(x+10,254),"拆投窗口剩余 %dF" % Rules.frames(f.grabbed.time),Color("f5a7df"))
			elif not f.last_contact.is_empty():
				var suffix := " · 弹体" if f.last_contact.projectile else " · 未计取消"
				label(Vector2(x+10,254),"%s  接触帧差 %+dF%s" % [f.last_contact.result,f.last_contact.advantage,suffix],Color("9dceeb"))
	if show_boxes:
		for p in arena.projectiles:
			if p.delay <= 0: outline(arena.projectile_box(p),Color("ff9d43"))
	if arena.training:
		draw_rect(Rect2(382,281,392,24),Color(.025,.035,.05,.8))
		label(Vector2(390,296),"F6 判定框  F7 帧数  ·  绿受击 / 红攻击 / 紫投技",Color("b7ccd3"))
