extends Control
## 블록 선택 화면의 미니 미리보기 — 타입의 실제 모양을 축소해 그린다.

var type_def: Dictionary = {}


func _draw() -> void:
	if type_def.is_empty():
		return
	var bb: Vector2 = type_def["bbox"]
	var sc := minf(size.x, size.y) / (maxf(bb.x, bb.y) + 24.0)
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
	BlockTypes.draw_parts(self, type_def, sc)
