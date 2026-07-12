extends RefCounted
class_name Leaderboard
## 랭킹 데이터 제공자.
## 지금은 목업(가짜) 데이터. 나중에 Google Play Games Services에서 받아와
## entries()만 실제 비동기 fetch로 교체하면 인게임 랭킹 UI는 그대로 동작한다.
##
## 반환 형식: [{ "rank": int, "name": String, "m": int, "me": bool }, ...]  (높이 내림차순)

# 블록 타입별 목업 상위권 (이름, 높이m). 창세기/바벨 테마 + 일반 유저 섞음.
const _MOCK := {
	"brick": [["니므롯", 512], ["시날의왕", 470], ["BabelPro", 431], ["벽돌장인", 402],
		["스택마스터", 377], ["Mason_K", 351], ["지혜", 328], ["Tower99", 305], ["민준", 288], ["hana", 265]],
	"box":   [["창고의신", 438], ["박스킹", 401], ["QuietHand", 372], ["상자탑", 349],
		["보급관", 320], ["정우", 298], ["Cargo", 276], ["레고", 255], ["소윤", 233], ["packer", 214]],
	"desk":  [["책상수호자", 356], ["FurnitureX", 331], ["목수길드", 308], ["서재", 285],
		["DeskDojo", 264], ["현우", 246], ["집중", 227], ["woodly", 205], ["지민", 188], ["desk_it", 171]],
	"chair":  [["의자연금술", 372], ["ChairLord", 342], ["앉은뱅이탑", 316], ["가구공방", 292],
		["균형왕", 271], ["서준", 250], ["Nap", 231], ["흔들의자", 210], ["예은", 193], ["stool", 176]],
	"ball":  [["구르는돌", 284], ["BallGod", 251], ["평정심", 229], ["공굴리기", 208],
		["ZenHand", 189], ["도현", 171], ["Sphere", 155], ["또르르", 139], ["유나", 124], ["rollie", 110]],
	"cone":  [["고깔탑", 268], ["ConeKing", 238], ["뾰족장인", 214], ["삼각뿔", 193],
		["ApexHand", 175], ["서윤", 158], ["Peak", 142], ["꼭짓점", 127], ["하준", 113], ["conez", 101]],
	"bottle": [["병뚜껑", 233], ["BottleZen", 205], ["균형의달인", 184], ["유리병", 165],
		["SteadyPour", 149], ["지안", 134], ["Cork", 120], ["도미노", 107], ["수아", 95], ["bottl", 84]],
}


## 바닥×블록 랭킹 목록 + 내 최고 기록(my_best>0이면 내 자리를 끼워 정렬).
## 어려운 바닥일수록(diff↑) 목업 높이를 낮춰 조합마다 다른 판을 만든다.
static func entries(base_id: String, block_id: String, my_best: int, my_name := "나") -> Array:
	var src: Array = _MOCK.get(block_id, _MOCK["brick"])
	var diff: float = float(BaseTypes.get_type(base_id).get("diff", 1.0))
	var scale: float = 1.0 / diff
	var out: Array = []
	for e in src:
		out.append({"name": e[0], "m": int(round(int(e[1]) * scale)), "me": false})
	if my_best > 0:
		out.append({"name": my_name, "m": my_best, "me": true})
	out.sort_custom(func(a, b): return a["m"] > b["m"])
	for i in out.size():
		out[i]["rank"] = i + 1
	return out
