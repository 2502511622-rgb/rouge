extends RefCounted
## Shared ink, light and print texture for the arcade interface.
const BG = Color("0b1018")
const PAPER = Color("fff6e5")
const EMBER = Color("ff8b34")
const SKY = Color("5acbff")
const RED = Color("ff6548")
const MUTED = Color("8998a8")
static var glow: GradientTexture2D
static func warmup() -> void:
	if glow != null: return
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.22))
	gradient.set_color(1,Color(1,1,1,0))
	gradient.add_point(0.4,Color(1,1,1,0.07))
	glow = GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5,0.5)
	glow.fill_to = Vector2(1,0.5)
static func backdrop(canvas: CanvasItem, clock: float, header_line := true) -> void:
	warmup()
	canvas.draw_rect(Rect2(0,0,1152,648),BG)
	canvas.draw_texture_rect(glow,Rect2(-420,-230,1250,1000),false,Color("18678d"))
	canvas.draw_texture_rect(glow,Rect2(490,-160,1100,1000),false,Color("924523"))
	for i in range(6):
		var x := 590+i*56.0
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+20,0),Vector2(x-340,648),Vector2(x-360,648)]),Color(0.5,0.65,0.8,0.018))
	for y in range(16):
		for x in range(15):
			canvas.draw_circle(Vector2(980+x*12,90+y*12),1.25,Color(0.9,0.6,0.3,0.05))
	for i in range(7):
		var x := float(i*145)-fmod(clock*8,145)
		canvas.draw_line(Vector2(x,648),Vector2(x+100,562),Color(0.5,0.7,0.9,0.045),1)
	if header_line: canvas.draw_line(Vector2(32,59),Vector2(1120,59),Color("26323f"),1)
static func plate(canvas: CanvasItem, rect: Rect2, color: Color, cut := 10.0) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([rect.position+Vector2(cut,0),Vector2(rect.end.x,rect.position.y),rect.end-Vector2(cut,0),Vector2(rect.position.x,rect.end.y)]),color)
