extends RefCounted

const NAMES = ["咕咕嘎嘎", "刀盾狗", "妙脆角猫"]
const ENGLISH = ["GUGU GAGA", "DAO DUN GOU", "MIAOCUI CAT"]
const ROLES = ["机动骚扰 / 迁徙信号", "攻防一体 / 持盾架招", "诡异反击 / 磨平棱角"]
const COLORS = [Color("68ddde"), Color("f09858"), Color("d3b0ed")]
const HP = [900.0, 1150.0, 1000.0]
const SPEED = [265.0, 165.0, 195.0]
const SPECIALS = [["咕嘎冲击波", "踏浪滑冲", "振翅回旋"], ["盾击冲撞", "刀盾上挑", "回旋斩"], ["妙脆角弹", "歪头拍击", "慵懒滑步"]]
const EX = [["EX · 群鹅迁徙", "EX · 雪崩俯冲", "EX · 振翅回旋"], ["EX · 连环突刺", "EX · 刀盾上挑", "EX · 壁垒架杀"], ["EX · 遍地脆角", "EX · 歪头拍击", "EX · 别来沾边"]]
const CA = ["全域咕咕嘎嘎", "我的刀盾！", "干嘛？"]
const V = ["迁徙信号", "持盾架招", "磨平棱角"]
const TAUNT = ["咕咕？嘎嘎？", "What the dog doing？", "干嘛？"]
const WIN = ["咕咕嘎嘎！（蹦跳转圈）", "我的刀盾！（举刀盾朝天）", "干嘛。（趴下，懒得庆祝）"]
const LOSE = ["咕……", "刀盾……", "（妙脆角碎掉一块，蔫掉）"]
const STAGES = ["AI 荒原草地", "冰原迁徙地", "碎石伏击谷", "零食荒野"]
const ENDINGS = [
 ["迁徙从不停止。荒野在一声咕嘎里重新醒来。", "猎手扑了个空。黑白色的小身影已越过下一片荒原。", "企鹅送来一块冰。猫看着它，终于眨了眨眼。"],
 ["脚印消失在盾牌之后。猎手停下来，听见远处新的迁徙信号。", "刀与盾相碰，回声成为荒野里新的狩猎号角。", "猎手得到一片碎角。猫趴在盾上：干嘛？"],
 ["迁徙的终点是一处阴凉。猫和企鹅无言地并排坐下。", "刀停在半空。被磨平的棱角，才是猎手算不到的锋利。", "两只猫同时躺平。食物链今天暂停营业。"]]

static func intro(who: int, opponent: int) -> String:
	if who == 0:
		return "咕咕嘎嘎！（慌张后退）" if opponent == 1 else "咕咕～嘎嘎！（歪头示好）"
	if who == 1:
		return "……（盯紧妙脆角耳朵）" if opponent == 2 else "我的刀盾！"
	return "干嘛？" if opponent == 1 else "……（面无表情）"
