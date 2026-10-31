extends Node2D
## Additive light is separate from the crisp, normally blended pixel edges.
var fx: Node2D
var radial: GradientTexture2D
func _ready() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.8))
	gradient.set_color(1,Color(1,1,1,0))
	gradient.add_point(0.22,Color(1,1,1,0.4))
	gradient.add_point(0.6,Color(1,1,1,0.07))
	radial = GradientTexture2D.new()
	radial.gradient = gradient
	radial.width = 128
	radial.height = 128
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5,0.5)
	radial.fill_to = Vector2(1,0.5)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
func _draw() -> void:
	if radial == null or fx == null or not fx.can_draw(): return
	for e in fx.events:
		var t := 1-float(e.life)/float(e.duration)
		var mode: String = e.mode
		if mode in ["dust","land","spark"]: continue
		var size := 170.0 if e.strong else 100.0
		if mode == "finish": size = 360
		var at: Vector2 = fx.event_position(e)
		var color: Color = fx.palette(e.kind)
		color.a = (1-t)*0.7
		draw_texture_rect(radial,Rect2(at-Vector2.ONE*size/2,Vector2.ONE*size),false,color)
	for p in fx.arena.projectiles:
		if p.delay > 0: continue
		var size := 110.0 if p.ex else 75.0
		draw_texture_rect(radial,Rect2(p.position-Vector2.ONE*size/2,Vector2.ONE*size),false,Color(fx.palette(p.kind),0.5))
