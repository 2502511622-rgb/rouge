extends RefCounted
## Physical keyboard bindings shared by gameplay, hints and settings.
const ORDER = ["left","right","jump","crouch","light","medium","heavy","skill1","skill2","skill3","super","ex","v","throw","trigger","taunt","kick_light","kick_medium","kick_heavy"]
const LABELS = {"left":"向左移动","right":"向右移动","jump":"跳跃","crouch":"蹲下","light":"快速攻击","medium":"中攻击","heavy":"重攻击","skill1":"技能一","skill2":"技能二","skill3":"技能三","super":"大招 CA","ex":"强化修饰键 EX","v":"角色特色 V 技能","throw":"投技","trigger":"爆发状态","taunt":"挑衅","kick_light":"进阶轻腿","kick_medium":"进阶中腿","kick_heavy":"进阶重腿"}
const DEFAULTS = {"left":KEY_A,"right":KEY_D,"jump":KEY_W,"crouch":KEY_S,"light":KEY_J,"medium":KEY_K,"heavy":KEY_L,"skill1":KEY_U,"skill2":KEY_I,"skill3":KEY_O,"super":KEY_P,"ex":KEY_SHIFT,"v":KEY_V,"throw":KEY_G,"trigger":KEY_B,"taunt":KEY_T,"kick_light":KEY_Z,"kick_medium":KEY_X,"kick_heavy":KEY_C}
const RESERVED = [KEY_ESCAPE,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_TAB,KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_M,KEY_R]
var held: Dictionary = {}
var bindings: Dictionary = DEFAULTS.duplicate()
var path := "user://controls.cfg"
func key(action: String) -> int:
	return int(bindings.get(action,0))
func label(action: String) -> String:
	return OS.get_keycode_string(key(action))
func action_for(code: int) -> String:
	for action in ORDER:
		if key(action) == code: return action
	return ""
func pressed(action: String) -> bool:
	return bool(held.get(key(action),false))
func feed(event: InputEventKey) -> void:
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if event.pressed: held[code] = true
	else: held.erase(code)
func release_all() -> void:
	held.clear()
func ex_from_event(event: InputEventKey) -> bool:
	match key("ex"):
		KEY_SHIFT: return event.shift_pressed
		KEY_CTRL: return event.ctrl_pressed
		KEY_ALT: return event.alt_pressed
	return pressed("ex")
func bind(action: String, code: int) -> String:
	if not action in ORDER: return "未知操作"
	if code <= 0 or code in RESERVED: return "此键保留给菜单，请换一个按键"
	if code in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META] and action != "ex": return "修饰键只能用于 EX 强化"
	var other := action_for(code)
	if other != "" and other != action: return "此键已用于「%s」，请先调整该操作" % LABELS[other]
	bindings[action] = code
	return ""
func reset_defaults() -> void:
	bindings = DEFAULTS.duplicate()
func save_bindings() -> Error:
	var config := ConfigFile.new()
	config.set_value("profile","version",1)
	for action in ORDER: config.set_value("keys",action,key(action))
	var error := config.save(path+".pending")
	if error != OK: return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".pending"),ProjectSettings.globalize_path(path))
func load_bindings() -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK: return error
	var candidate := DEFAULTS.duplicate()
	var seen: Array = []
	for action in ORDER:
		var value: Variant = config.get_value("keys",action,DEFAULTS[action])
		if not value is int or int(value) <= 0 or int(value) in RESERVED or int(value) in seen: return ERR_INVALID_DATA
		if int(value) in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META] and action != "ex": return ERR_INVALID_DATA
		candidate[action] = value
		seen.append(value)
	bindings = candidate
	return OK
func hint(value: String) -> String:
	for action in ORDER: value = value.replace("{"+action+"}",label(action))
	return value
