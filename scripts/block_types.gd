extends RefCounted
class_name BlockTypes
## 쌓을 수 있는 물품(블록) 정의 + 등록 시스템.
##
## 블록 하나는 여러 "파트"로 이루어진다. 파트가 곧 충돌 형태이자 그림이다.
## 파트 좌표는 블록 중심(0,0) 기준(y가 음수면 위).
##
## 블록을 추가하려면 정의(Dictionary) 하나를 register()로 넘기면 끝이다:
##   BlockTypes.register({
##       "id": "myblock",                 # 고유 id (필수)
##       "name": "내 블록",                # 표시 이름 (선택 — 없으면 아이콘만)
##       "i18n": "blk_myblock",            # 다국어 키 접두사 (선택 — 내장 블록용)
##       "friction": 0.5, "bounce": 0.0, "mass": 2.0,   # 물리 (선택, 기본값 있음)
##       "parts": [                        # 외형=충돌체 (필수)
##           {"kind": "rect",   "rect": Rect2(-90,-31,180,62), "color": Color(...)},
##           {"kind": "circle", "pos": Vector2(0,0), "r": 56.0, "color": Color(...)},
##           {"kind": "poly",   "pts": [Vector2(...), ...],    "color": Color(...)},
##       ],
##       # "bbox": Vector2(...)  # 선택 — 없으면 parts에서 자동 계산
##   })
## bbox·이름·물리값은 생략 가능하며 자동 보정된다. → 나중에 인게임에서 유저가
## 폼으로 입력해 등록하는 "워크샵" 형태로 확장하기 쉽다(_load_custom 참고).

const OUTLINE := Color(0.13, 0.11, 0.12)
const CUSTOM_PATH := "user://custom_blocks.json"

# 등록된 블록들(초기화 후 채워짐). all()이 최초 호출될 때 1회 구성된다.
static var _registry: Array = []
static var _loaded: bool = false


## ------------------------------------------------------------ 등록 API

## 블록 정의를 정규화(기본값 채우기·bbox 자동계산)해 레지스트리에 넣는다.
## 같은 id가 있으면 교체한다. 정규화된 정의를 반환.
static func register(def: Dictionary) -> Dictionary:
	var d := _normalize(def)
	for i in _registry.size():
		if _registry[i]["id"] == d["id"]:
			_registry[i] = d
			return d
	_registry.append(d)
	return d


## 등록된 모든 블록(등록 순서 = 선택 화면 표시 순서)
static func all() -> Array:
	_ensure()
	return _registry


static func get_type(id: String) -> Dictionary:
	_ensure()
	for t in _registry:
		if t["id"] == id:
			return t
	return _registry[0]


static func has(id: String) -> bool:
	_ensure()
	for t in _registry:
		if t["id"] == id:
			return true
	return false


## ------------------------------------------------------------ 내부 초기화

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for d in _builtins():
		register(d)
	_load_custom()


## 정의를 정규화: 기본 물리값 보정 + bbox 자동계산
static func _normalize(def: Dictionary) -> Dictionary:
	var d := def.duplicate(true)
	d["friction"] = float(d.get("friction", 0.5))
	d["bounce"] = float(d.get("bounce", 0.0))
	d["mass"] = float(d.get("mass", 2.0))
	if not d.has("bbox") or not (d["bbox"] is Vector2):
		d["bbox"] = _auto_bbox(d.get("parts", []))
	return d


## parts의 실제 경계로 bbox(전체 폭·높이)를 계산
static func _auto_bbox(parts: Array) -> Vector2:
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in parts:
		match p.get("kind", ""):
			"rect":
				var r: Rect2 = p["rect"]
				mn = mn.min(r.position)
				mx = mx.max(r.position + r.size)
			"circle":
				var c: Vector2 = p["pos"]
				var rad: float = p["r"]
				mn = mn.min(c - Vector2(rad, rad))
				mx = mx.max(c + Vector2(rad, rad))
			"poly":
				for pt in p["pts"]:
					mn = mn.min(pt)
					mx = mx.max(pt)
	if mx.x < mn.x:
		return Vector2(180, 62)
	return mx - mn


## ------------------------------------------------------------ 유저(커스텀) 블록 로딩
## user://custom_blocks.json 이 있으면 읽어 등록한다. (없으면 조용히 통과)
## JSON은 Vector2/Rect2/Color를 담을 수 없으므로 숫자 배열로 표현한다:
##   { "blocks": [ {
##       "id":"star", "name":"별", "friction":0.5, "bounce":0.0, "mass":2.0,
##       "parts":[ {"kind":"rect","rect":[x,y,w,h],"color":[r,g,b]},
##                 {"kind":"circle","pos":[x,y],"r":30,"color":[r,g,b]},
##                 {"kind":"poly","pts":[[x,y],...],"color":[r,g,b]} ] } ] }
static func _load_custom() -> void:
	if not FileAccess.file_exists(CUSTOM_PATH):
		return
	var f := FileAccess.open(CUSTOM_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for raw in data.get("blocks", []):
		var def := _from_json(raw)
		if not def.is_empty():
			register(def)


## JSON dict(숫자 배열) → 엔진 타입 정의로 변환
static func _from_json(raw: Dictionary) -> Dictionary:
	if not raw.has("id") or not raw.has("parts"):
		return {}
	var parts: Array = []
	for p in raw["parts"]:
		var kind: String = p.get("kind", "rect")
		var col := _to_color(p.get("color", [0.8, 0.7, 0.5]))
		match kind:
			"rect":
				var a: Array = p["rect"]
				parts.append({"kind": "rect",
					"rect": Rect2(a[0], a[1], a[2], a[3]), "color": col})
			"circle":
				var c: Array = p["pos"]
				parts.append({"kind": "circle",
					"pos": Vector2(c[0], c[1]), "r": float(p["r"]), "color": col})
			"poly":
				var pts := PackedVector2Array()
				for xy in p["pts"]:
					pts.append(Vector2(xy[0], xy[1]))
				parts.append({"kind": "poly", "pts": pts, "color": col})
	return {
		"id": str(raw["id"]),
		"name": str(raw.get("name", "")),
		"friction": float(raw.get("friction", 0.5)),
		"bounce": float(raw.get("bounce", 0.0)),
		"mass": float(raw.get("mass", 2.0)),
		"parts": parts,
		"custom": true,
	}


static func _to_color(a) -> Color:
	if a is Array and a.size() >= 3:
		return Color(a[0], a[1], a[2], a[3] if a.size() > 3 else 1.0)
	return Color(0.8, 0.7, 0.5)


## ------------------------------------------------------------ 내장 블록들 (쉬움 → 어려움)

static func _builtins() -> Array:
	return [
		{
			"id": "brick", "name": "벽돌", "i18n": "blk_brick", "friction": 0.42,
			"parts": [
				{"kind": "rect", "rect": Rect2(-90, -31, 180, 62), "color": Color(0.80, 0.73, 0.57)},
			],
		},
		{
			"id": "box", "name": "상자", "i18n": "blk_box", "friction": 0.52,
			"parts": [
				{"kind": "rect", "rect": Rect2(-70, -65, 140, 130), "color": Color(0.72, 0.52, 0.30)},
				{"kind": "rect", "rect": Rect2(-70, -8, 140, 16), "color": Color(0.60, 0.42, 0.24)},
			],
		},
		{
			"id": "desk", "name": "책상", "i18n": "blk_desk", "friction": 0.5,
			"parts": [
				{"kind": "rect", "rect": Rect2(-98, -46, 196, 22), "color": Color(0.66, 0.45, 0.28)},
				{"kind": "rect", "rect": Rect2(-84, -24, 18, 70), "color": Color(0.50, 0.34, 0.20)},
				{"kind": "rect", "rect": Rect2(66, -24, 18, 70), "color": Color(0.50, 0.34, 0.20)},
			],
		},
		{
			"id": "chair", "name": "의자", "i18n": "blk_chair", "friction": 0.5,
			"parts": [
				{"kind": "rect", "rect": Rect2(-54, -60, 16, 62), "color": Color(0.82, 0.62, 0.36)},
				{"kind": "rect", "rect": Rect2(-54, -14, 108, 16), "color": Color(0.88, 0.70, 0.44)},
				{"kind": "rect", "rect": Rect2(-50, 2, 14, 44), "color": Color(0.72, 0.54, 0.32)},
				{"kind": "rect", "rect": Rect2(36, 2, 14, 44), "color": Color(0.72, 0.54, 0.32)},
			],
		},
		{
			# 고깔 — 삼각형(뾰족한 위) : 위에 올리기 어려운 도형
			"id": "cone", "name": "고깔", "i18n": "blk_cone", "friction": 0.54,
			"parts": [
				{"kind": "poly", "pts": PackedVector2Array([
					Vector2(-80, 56), Vector2(80, 56), Vector2(0, -76)]),
					"color": Color(0.90, 0.52, 0.24)},
				{"kind": "poly", "pts": PackedVector2Array([
					Vector2(-80, 56), Vector2(0, -76), Vector2(-24, 20)]),
					"color": Color(0.98, 0.66, 0.34)},
			],
		},
		{
			# 병 — 좁고 높은 세로형 : 무게중심 높아 매우 까다로움
			"id": "bottle", "name": "병", "i18n": "blk_bottle", "friction": 0.5,
			"parts": [
				{"kind": "rect", "rect": Rect2(-38, -18, 76, 104), "color": Color(0.28, 0.55, 0.55)},
				{"kind": "poly", "pts": PackedVector2Array([
					Vector2(-38, -18), Vector2(38, -18), Vector2(16, -52), Vector2(-16, -52)]),
					"color": Color(0.32, 0.60, 0.60)},
				{"kind": "rect", "rect": Rect2(-16, -70, 32, 20), "color": Color(0.32, 0.60, 0.60)},
				{"kind": "rect", "rect": Rect2(-18, -82, 36, 14), "color": Color(0.86, 0.80, 0.58)},
			],
		},
		{
			"id": "ball", "name": "공", "i18n": "blk_ball", "friction": 0.58,
			"parts": [
				{"kind": "circle", "pos": Vector2(0, 0), "r": 56.0, "color": Color(0.88, 0.30, 0.26)},
			],
		},
	]


## ------------------------------------------------------------ 그리기 (본체·아이콘 공용)
## 카툰풍: 굵고 어두운 외곽선 + 상단 하이라이트. sc = 배율.

static func draw_parts(ci: CanvasItem, type: Dictionary, sc: float) -> void:
	var ow := maxf(1.5, 3.5 * sc)
	for p in type["parts"]:
		match p["kind"]:
			"rect":
				var r: Rect2 = p["rect"]
				var rr := Rect2(r.position * sc, r.size * sc)
				var col: Color = p["color"]
				ci.draw_rect(rr, col)
				ci.draw_rect(Rect2(rr.position, Vector2(rr.size.x, rr.size.y * 0.28)), col.lightened(0.14))
				ci.draw_rect(rr, OUTLINE, false, ow)
			"circle":
				var col2: Color = p["color"]
				var pos: Vector2 = p["pos"]
				var rad: float = p["r"]
				ci.draw_circle(pos * sc, rad * sc, col2)
				ci.draw_circle((pos + Vector2(-rad * 0.3, -rad * 0.34)) * sc, rad * 0.42 * sc, col2.lightened(0.16))
				ci.draw_circle((pos + Vector2(-rad * 0.34, -rad * 0.36)) * sc, rad * 0.16 * sc, col2.lightened(0.4))
				ci.draw_arc(pos * sc, rad * sc, 0, TAU, 40, OUTLINE, ow)
			"poly":
				var col3: Color = p["color"]
				var pts := PackedVector2Array()
				for pt in p["pts"]:
					pts.append(pt * sc)
				ci.draw_colored_polygon(pts, col3)
				var n := pts.size()
				for i in n:
					ci.draw_line(pts[i], pts[(i + 1) % n], OUTLINE, ow)
