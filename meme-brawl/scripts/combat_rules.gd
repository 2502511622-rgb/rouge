extends RefCounted
## Authoritative 60 Hz combat timing. Duration fields describe separate phases.
const HURT_WIDTH = [112.0,110.0,108.0,102.0,132.0,98.0]
const HURT_HEIGHT = [164.0,148.0,158.0,155.0,172.0,156.0]
const PUSH_WIDTH = [104.0,106.0,100.0,98.0,124.0,96.0]
const HZ := 60.0
const FRAME := 1.0 / HZ
const EPS := 0.00001
const INPUT_BUFFER := 5.0 / HZ
const THROW_STARTUP := 5
const THROW_ACTIVE := 2
const THROW_RECOVERY := 24
const THROW_TECH := 7
const WAKE_THROW_PROTECTION := 5

static func frames(seconds: float) -> int:
	return maxi(0,ceili(seconds*HZ-EPS))

static func seconds(value: int) -> float:
	return maxi(0,value)*FRAME

static func normal_startup(kind: int, strength: int) -> int:
	if kind == 2: return [6,8,11][strength]
	if kind == 4: return [6,9,13][strength]
	return [4,6,9][strength]

static func profile(type: String, data: Dictionary, duration: float, old_total: float) -> Dictionary:
	var startup: int = int(data.get("startup_frames",frames(float(data.get("startup",0)))))
	if startup <= 0: startup = 12 if type == "super" else (5 if type == "throw" else 8)
	var effective: int = int(data.get("active_frames",frames(duration)))
	if type == "special" and not data.get("multi",false) and not data.has("active_frames"): effective = mini(effective,6)
	var recovery: int = int(data.get("recovery_frames",maxi(8,frames(old_total-duration))))
	return {"startup":startup,"active":maxi(1,effective),"recovery":recovery,
		"hitstun":int(data.get("hitstun_frames",frames(float(data.get("hitstun",.3))))),
		"blockstun":int(data.get("blockstun_frames",12))}
