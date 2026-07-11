extends Control
## 선택 화면 상단의 지구라트(계단식 탑) 엠블럼 — '창세기 11장/바벨' 분위기.

func _draw() -> void:
	var cx := size.x * 0.5
	var tiers := 5
	var h := size.y / (tiers + 0.6)
	var base := Color(0.80, 0.68, 0.46)
	for i in range(tiers):
		var w := size.x * (0.92 - i * 0.15)
		var y := size.y - (i + 1) * h
		var r := Rect2(cx - w * 0.5, y, w, h * 0.9)
		draw_rect(r, base.lightened(i * 0.05))
		draw_rect(r, base.darkened(0.4), false, 2.0)
		# 계단 층 앞면 음영
		draw_rect(Rect2(cx - w * 0.5, y + h * 0.72, w, h * 0.18), base.darkened(0.18))
	# 입구(문)
	draw_rect(Rect2(cx - 15.0, size.y - h * 0.95, 30.0, h * 0.72), Color(0.22, 0.17, 0.13))
