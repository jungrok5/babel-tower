extends RefCounted
class_name BlockTypes
## 쌓을 수 있는 실생활 물품(블록) 정의 모음.
## 각 타입은 여러 파트(사각형/원)로 이루어지고, 그 파트가 그대로 충돌 형태이자 그림이 된다.
## parts 좌표는 블록 중심(0,0) 기준. y가 음수면 위쪽.

## 모든 블록 타입 (쉬움 → 어려움)
static func all() -> Array:
	return [
		{
			"id": "brick", "name": "벽돌",
			"bbox": Vector2(180, 62), "friction": 0.42,
			"parts": [
				{"kind": "rect", "rect": Rect2(-90, -31, 180, 62), "color": Color(0.80, 0.73, 0.57)},
			],
		},
		{
			"id": "box", "name": "상자",
			"bbox": Vector2(140, 130), "friction": 0.52,
			"parts": [
				{"kind": "rect", "rect": Rect2(-70, -65, 140, 130), "color": Color(0.72, 0.52, 0.30)},
				{"kind": "rect", "rect": Rect2(-70, -8, 140, 16), "color": Color(0.60, 0.42, 0.24)},
			],
		},
		{
			"id": "desk", "name": "책상",
			"bbox": Vector2(196, 92), "friction": 0.5,
			"parts": [
				{"kind": "rect", "rect": Rect2(-98, -46, 196, 22), "color": Color(0.66, 0.45, 0.28)},
				{"kind": "rect", "rect": Rect2(-84, -24, 18, 70), "color": Color(0.50, 0.34, 0.20)},
				{"kind": "rect", "rect": Rect2(66, -24, 18, 70), "color": Color(0.50, 0.34, 0.20)},
			],
		},
		{
			"id": "chair", "name": "의자",
			"bbox": Vector2(108, 118), "friction": 0.5,
			"parts": [
				{"kind": "rect", "rect": Rect2(-54, -60, 16, 62), "color": Color(0.82, 0.62, 0.36)},
				{"kind": "rect", "rect": Rect2(-54, -14, 108, 16), "color": Color(0.88, 0.70, 0.44)},
				{"kind": "rect", "rect": Rect2(-50, 2, 14, 44), "color": Color(0.72, 0.54, 0.32)},
				{"kind": "rect", "rect": Rect2(36, 2, 14, 44), "color": Color(0.72, 0.54, 0.32)},
			],
		},
		{
			"id": "ball", "name": "공",
			"bbox": Vector2(112, 112), "friction": 0.58,
			"parts": [
				{"kind": "circle", "pos": Vector2(0, 0), "r": 56.0, "color": Color(0.88, 0.30, 0.26)},
			],
		},
	]


static func get_type(id: String) -> Dictionary:
	for t in all():
		if t["id"] == id:
			return t
	return all()[0]


## 타입의 파트들을 CanvasItem에 그린다 (블록 본체·선택 아이콘 공용). sc = 배율.
static func draw_parts(ci: CanvasItem, type: Dictionary, sc: float) -> void:
	for p in type["parts"]:
		if p["kind"] == "rect":
			var r: Rect2 = p["rect"]
			var rr := Rect2(r.position * sc, r.size * sc)
			var col: Color = p["color"]
			ci.draw_rect(rr, col)
			ci.draw_rect(rr, col.darkened(0.4), false, maxf(1.0, 2.0 * sc))
		else:
			var col2: Color = p["color"]
			var pos: Vector2 = p["pos"]
			var rad: float = p["r"]
			ci.draw_circle(pos * sc, rad * sc, col2)
			ci.draw_circle(pos * sc, rad * sc, col2.darkened(0.35), false, maxf(1.0, 2.0 * sc))
			ci.draw_circle((pos + Vector2(-rad * 0.32, -rad * 0.34)) * sc, rad * 0.2 * sc, col2.lightened(0.4))
