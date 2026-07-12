extends Control
## 바닥 선택 타일의 미니 미리보기 — 종류별로 간단히 그린다.

var kind := "ground"


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var ground_y := h * 0.72
	match kind:
		"water_melon":
			_water(w, h, ground_y)
			draw_circle(Vector2(cx, ground_y - 10), 26, Color(0.93, 0.82, 0.30))
			for sx in [-14.0, 0.0, 14.0]:
				draw_line(Vector2(cx + sx, ground_y - 30), Vector2(cx + sx, ground_y + 8), Color(0.86, 0.74, 0.22), 3.0)
			draw_arc(Vector2(cx, ground_y - 10), 26, 0, TAU, 20, Color(0.2, 0.18, 0.12), 2.0)
			draw_rect(Rect2(0, ground_y, w, h - ground_y), Color(0.18, 0.46, 0.66, 0.7))  # 수면 덮기
		"water_raft":
			_water(w, h, ground_y)
			draw_rect(Rect2(cx - 34, ground_y - 12, 68, 16), Color(0.58, 0.42, 0.26))
			draw_rect(Rect2(0, ground_y + 2, w, h - ground_y), Color(0.18, 0.46, 0.66, 0.6))
		"seesaw":
			draw_rect(Rect2(0, ground_y, w, h - ground_y), Color(0.34, 0.52, 0.22))
			var tri := PackedVector2Array([Vector2(cx - 16, ground_y), Vector2(cx + 16, ground_y), Vector2(cx, ground_y - 22)])
			draw_colored_polygon(tri, Color(0.46, 0.42, 0.48))
			draw_set_transform(Vector2(cx, ground_y - 22), 0.18, Vector2.ONE)
			draw_rect(Rect2(-44, -6, 88, 12), Color(0.60, 0.44, 0.26))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:  # ground
			draw_rect(Rect2(0, ground_y, w, h - ground_y), Color(0.34, 0.52, 0.22))
			draw_rect(Rect2(0, ground_y + 10, w, h - ground_y), Color(0.34, 0.24, 0.14))
			draw_rect(Rect2(cx - 24, ground_y - 22, 48, 24), Color(0.44, 0.43, 0.49))
			draw_rect(Rect2(cx - 28, ground_y - 26, 56, 6), Color(0.52, 0.51, 0.57))


func _water(w: float, h: float, ground_y: float) -> void:
	draw_rect(Rect2(0, ground_y, w, h - ground_y), Color(0.16, 0.42, 0.62))
	draw_line(Vector2(0, ground_y + 2), Vector2(w, ground_y + 2), Color(0.62, 0.82, 0.92, 0.8), 2.0)
