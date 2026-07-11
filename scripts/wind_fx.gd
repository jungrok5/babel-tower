extends Control
## 전경 바람 이펙트 — 바람이 불 때 화면을 가로지르는 '바람결(streak)'을 그린다.
## 방향 = 흐르는 방향, 세기 = 선의 길이·굵기·개수·투명도로 표현. (텍스트 없이 그 자체로 인지)
## 카메라와 무관하게 화면에 고정(CanvasLayer 위)되어 탑 위로 바람이 스치는 느낌을 준다.

var wind: float = 0.0       # 현재 바람(-1..1, 부호=방향) — main이 매 프레임 갱신
var t: float = 0.0

const VW := 720.0
const VH := 1280.0

var _streaks := []          # [base_x, y, len, thick, avar]
var _wisps := []            # [base_x, y, scale, avar] — 길게 흐르는 옅은 바람 덩어리(구름결)
var _motes := []            # [base_x, y, size] — 바람에 실려 날리는 티끌/잎


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 16:
		_streaks.append([randf() * VW, randf() * VH, randf_range(70, 190),
			randf_range(1.6, 3.2), randf_range(0.5, 1.0)])
	for i in 6:
		_wisps.append([randf() * VW, randf_range(80, VH - 120), randf_range(0.8, 1.7),
			randf_range(0.5, 1.0)])
	for i in 9:
		_motes.append([randf() * VW, randf() * VH, randf_range(1.6, 3.0)])


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var s := absf(wind)
	if s < 0.08:
		return
	var dir := signf(wind)

	# 옅은 바람 덩어리(구름결) — 크고 느리고 투명. '구름처럼' 흐르는 배경 레이어.
	var wisp_speed := 90.0 + 260.0 * s
	for w in _wisps:
		var x := fmod(w[0] + t * dir * wisp_speed + 100000.0, VW + 500.0) - 250.0
		var sc: float = w[2]
		_draw_wisp(Vector2(x, w[1] + sin(t * 0.6 + w[0]) * 8.0), sc * (0.7 + 0.6 * s),
			Color(0.9, 0.94, 1.0, s * 0.10 * w[3]), dir)

	# 바람결(speed line) — 길이·굵기·투명도·개수가 세기에 비례. 방향은 흐르는 쪽. (은은하게)
	var speed := 300.0 + 820.0 * s
	var shown := int(clampf(s * 0.85, 0.12, 0.5) * _streaks.size())
	for i in range(shown):
		var st = _streaks[i]
		var x := fmod(st[0] + t * dir * speed + 100000.0, VW + 400.0) - 200.0
		var y: float = st[1] + sin(t * 1.5 + st[0] * 0.05) * 6.0
		var ln: float = st[2] * (0.35 + 0.9 * s)
		var a: float = s * 0.3 * st[4]
		var th: float = st[3] * (0.6 + 0.6 * s)
		# 꼬리가 옅어지는 두 겹(머리는 진하게, 꼬리는 투명하게)
		var head := Vector2(x, y)
		var tail := Vector2(x - dir * ln, y)
		draw_line(head, tail.lerp(head, 0.4), Color(0.92, 0.96, 1.0, a), th)
		draw_line(tail, tail.lerp(head, 0.4), Color(0.92, 0.96, 1.0, a * 0.35), th)

	# 티끌 — 강한 바람에서만 옅게 실려 날아가 방향/속도감을 준다
	if s > 0.45:
		var mspeed := 480.0 + 660.0 * s
		for m in _motes:
			var x := fmod(m[0] + t * dir * mspeed + 100000.0, VW + 200.0) - 100.0
			var y: float = m[1] + sin(t * 3.0 + m[0]) * 14.0 * s
			draw_circle(Vector2(x, y), m[2], Color(0.96, 0.97, 1.0, (s - 0.45) * 0.4))


func _draw_wisp(pos: Vector2, sc: float, col: Color, dir: float) -> void:
	# 가로로 길쭉한 옅은 덩어리 — 원 여러 개로 근사
	for o in [Vector2(0, 0), Vector2(dir * 55, 4), Vector2(-dir * 55, -3),
			Vector2(dir * 110, 2), Vector2(-dir * 30, 8)]:
		draw_circle(pos + o * sc, 26.0 * sc, col)
