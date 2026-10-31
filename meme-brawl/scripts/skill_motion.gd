extends RefCounted
## Per-character anticipation / attack / recovery curves for all 18 specials.

static func sample(kind: int, move: int, ex: bool, t: float) -> Dictionary:
	var attack := envelope(t)
	var windup := sin(clampf(t/0.17,0,1)*PI)
	var offset := Vector2(-7*windup,0)
	var angle := 0.0
	var scale_pose := Vector2.ONE
	var power := 1.2 if ex else 1.0
	match kind:
		0:
			if move == 0: offset += Vector2(-16*attack,-3*attack)
			elif move == 1:
				offset += Vector2(16*attack,12*attack)
				scale_pose = Vector2(1+0.12*attack,1-0.22*attack)
				angle = 0.16*attack if ex else 0.05*attack
			else: angle = t*TAU*(1.5 if ex else 1)
		1:
			if move == 0:
				offset += Vector2(23*attack,2*attack)
				angle = 0.16*attack
			elif move == 1:
				offset += Vector2(5*attack,-26*attack)
				angle = -0.4*attack
			else: angle = -0.5+attack*1.0
		2:
			if move == 0: offset += Vector2(-12*attack,-4*attack)
			elif move == 1:
				offset += Vector2(-5*windup,-4*attack)
				angle = -0.12*attack
			else:
				offset += Vector2(-13*attack,5*attack)
				scale_pose = Vector2(1+0.06*attack,1-0.08*attack)
		3:
			if ex and move == 0: angle = t*TAU*2.5
			elif move == 1: angle = 0.28*attack
			elif move == 2:
				offset.y -= 23*attack
				scale_pose = Vector2(1+0.12*attack,1-0.12*attack)
			else: offset.x -= 17*attack
		4:
			if move == 0:
				angle = 0.21*attack
				offset.x += 22*attack
			elif move == 1:
				angle = -0.35*attack
				offset.y -= 24*attack
			else:
				offset.y = -18*sin(t*PI) if t < 0.45 else 8*attack
				scale_pose = Vector2(1+0.12*attack,1-0.1*attack)
		5:
			if move == 0:
				offset += Vector2(23*attack,-10*attack)
				angle = -0.17*attack
			elif move == 1:
				offset.y -= 22*attack
				angle = (-0.2 if not ex else 0.28)*attack
			else: offset += Vector2(15*attack,-7*attack)
	return {"offset":offset*power,"angle":angle,"scale":scale_pose}

static func envelope(t: float) -> float:
	# Hold anticipation, accelerate into the strike, settle through recovery.
	if t < 0.15: return 0.0
	if t < 0.28: return pow((t-0.15)/0.13,0.65)
	if t < 0.46: return 1.0
	return pow(maxf(0,1-(t-0.46)/0.54),2)

static func normal_sample(strength: int, kick: bool, t: float) -> Dictionary:
	var drive := envelope(t)
	var prepare := sin(clampf(t/0.17,0,1)*PI)
	var power := 0.7+strength*0.22
	return {"offset":Vector2((28*drive-10*prepare)*power,(-9 if kick else -3)*drive),"angle":(-0.18 if kick else 0.13)*drive*power,"scale":Vector2(1+0.12*drive,1-0.06*drive)}

static func ca_sample(kind: int, t: float) -> Dictionary:
	var beat := sin(t*TAU*3)
	var finish := clampf((t-0.78)/0.18,0,1)
	var offset := Vector2.ZERO
	var angle := 0.0
	var scale_pose := Vector2.ONE
	match kind:
		0:
			offset = Vector2(-14-absf(beat)*5,-4)
			scale_pose = Vector2(1+absf(beat)*0.12,1+finish*0.15)
		1:
			offset = Vector2(18+beat*16,-7*absf(beat))
			angle = beat*0.25-finish*0.3
		2:
			offset = Vector2(0,-finish*8)
			scale_pose = Vector2.ONE*(1+finish*0.08)
		3:
			offset = Vector2(18+beat*15,12*absf(beat))
			angle = beat*0.3
			scale_pose = Vector2(1+absf(beat)*0.16,1-absf(beat)*0.1)
		4:
			offset = Vector2(10*beat,-25*absf(beat)+finish*12)
			angle = beat*0.16
		5:
			offset = Vector2(15,-20*absf(beat)+finish*15)
			angle = -0.15*absf(beat)
	return {"offset":offset,"angle":angle,"scale":scale_pose}
