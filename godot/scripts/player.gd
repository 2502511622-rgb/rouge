extends Node2D
## Independently implemented placeholder controller; not recovered GBA code.
@export var speed: float = 145.0
@export var max_hp: int = 100
@export var attack_damage: int = 15
@export var attack_reach: float = 56.0
var hp: int = 100
var potions: int = 3
var experience: int = 0
var facing := Vector2.DOWN
var attack_left: float = 0.0
var invulnerable: float = 0.0
var world: Node2D

func _process(delta: float) -> void:
	if world == null or world.browser.visible or world.editor_mode:
		return
	attack_left = maxf(0.0, attack_left - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length() > 0:
		facing = direction.normalized()
		var step := direction * speed * delta
		if world.walkable(position + Vector2(step.x, 0)):
			position.x += step.x
		if world.walkable(position + Vector2(0, step.y)):
			position.y += step.y
	if Input.is_action_just_pressed("attack") and attack_left <= 0.0:
		attack_left = 0.32
		world.attack(position, facing, attack_damage, attack_reach)
	if Input.is_action_just_pressed("potion") and potions > 0 and hp < max_hp:
		potions -= 1
		hp = mini(max_hp, hp + 45)
	queue_redraw()

func hurt(amount: int) -> void:
	if invulnerable > 0:
		return
	hp -= amount
	invulnerable = 0.75
	if hp <= 0:
		world.message = "Defeated — press R to reset the prototype."
		set_process(false)

func _draw() -> void:
	draw_ellipse_shadow()
	var color := Color("80daf5") if invulnerable <= 0 else Color("ffffff")
	draw_rect(Rect2(-9, -11, 18, 23), color)
	draw_circle(Vector2(0, -16), 8, Color("f0cc9f"))
	draw_rect(Rect2(-9, -23, 18, 7), Color("5a70b6"))
	draw_line(Vector2.ZERO, facing * 19, Color("ffefb0"), 4)
	if attack_left > 0.16:
		var angle := facing.angle()
		draw_arc(Vector2.ZERO, 38, angle - 0.9, angle + 0.9, 18, Color("ffdf82"), 5)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
