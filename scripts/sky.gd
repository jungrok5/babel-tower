extends Control
## 높이(미터)에 따라 변하는 하늘 배경: 그라데이션 + 구름 + 별.
## CanvasLayer(화면 고정) 위에 그려져 카메라와 무관하게 배경으로 깔린다.

var meters: float = 0.0     # 현재 높이(미터) — main이 매 프레임 갱신
var t: float = 0.0          # 흐른 시간 — 구름/별 애니메이션용
var wind: float = 0.0       # 현재 바람(-1..1, main이 갱신) — 스트릭 방향/세기

const VW := 720.0
const VH := 1280.0

# (미터, 위색, 아래색) 키프레임 — 맑은 대낮 → 파란 하늘 → 남색 고공 → 우주 (카툰풍)
const SKY := [
	[0.0,   Color(0.40, 0.68, 0.95), Color(0.73, 0.89, 0.99)],
	[230.0, Color(0.20, 0.42, 0.78), Color(0.44, 0.64, 0.92)],
	[480.0, Color(0.10, 0.14, 0.38), Color(0.20, 0.20, 0.48)],
	[820.0, Color(0.010, 0.012, 0.03), Color(0.02, 0.02, 0.06)],
]

var _stars := []            # [Vector2 pos, float size, float phase]
var _clouds := []           # [Vector2 pos, float scale, float speed]
var _streaks := []          # [float y, float len, float phase] — 바람 스트릭


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 90:
		_stars.append([Vector2(randf() * VW, randf() * VH * 0.85), randf_range(1.0, 2.6), randf() * TAU])
	for i in 7:
		_clouds.append([Vector2(randf() * VW, randf_range(120, 900)), randf_range(0.7, 1.6), randf_range(6.0, 16.0)])
	for i in 14:
		_streaks.append([randf() * VH, randf_range(40, 110), randf() * VW])


func _process(delta: float) -> void:
	queue_redraw()


func _sky_colors() -> Array:
	var m := meters
	for i in range(SKY.size() - 1):
		var a = SKY[i]
		var b = SKY[i + 1]
		if m <= b[0]:
			var f := clampf((m - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return [a[1].lerp(b[1], f), a[2].lerp(b[2], f)]
	return [SKY[-1][1], SKY[-1][2]]


func _draw() -> void:
	var cols := _sky_colors()
	var top: Color = cols[0]
	var bot: Color = cols[1]
	# 세로 그라데이션 (여러 밴드로 근사)
	var bands := 24
	for i in bands:
		var f := float(i) / float(bands - 1)
		var c := top.lerp(bot, f)
		draw_rect(Rect2(0, VH * i / bands, VW, VH / bands + 1), c)

	# 해 — 지상에서 밝게 떠 있다가 고공(성층권~우주)으로 갈수록 사라진다
	var sun_a := clampf((300.0 - meters) / 160.0, 0.0, 1.0)
	if sun_a > 0.0:
		_draw_sun(Vector2(VW - 150.0, 210.0), sun_a)

	# 별 — 고공에서 서서히 나타남 (>350m)
	var star_a := clampf((meters - 350.0) / 400.0, 0.0, 1.0)
	if star_a > 0.0:
		for s in _stars:
			var tw := 0.5 + 0.5 * sin(t * 2.0 + s[2])
			draw_circle(s[0], s[1], Color(1, 1, 1, star_a * (0.4 + 0.6 * tw)))

	# 구름 — 지상 근처(0~)부터 폭신하게 떠 있다가 성층권(340m~)에서 사라짐
	var cloud_a := clampf((meters + 40.0) / 80.0, 0.0, 1.0) \
		* clampf((340.0 - meters) / 90.0, 0.0, 1.0)
	if cloud_a > 0.0:
		for c in _clouds:
			var x := fmod(c[0].x + t * c[2], VW + 400.0) - 200.0
			_draw_cloud(Vector2(x, c[0].y), c[1], cloud_a)

	# 바람 스트릭 — 바람이 부는 방향/세기를 시각화
	var ws := absf(wind)
	if ws > 0.06:
		var dir := signf(wind)
		for st in _streaks:
			var x := fmod(st[2] + t * dir * (200.0 + 500.0 * ws), VW + 200.0) - 100.0
			var a := ws * 0.35
			draw_line(Vector2(x, st[0]), Vector2(x - dir * st[1], st[0]),
				Color(0.85, 0.9, 1.0, a), 2.0)


## 카툰 해 — 부드러운 후광 + 둥근 몸통 + 은은한 외곽선
func _draw_sun(c: Vector2, a: float) -> void:
	draw_circle(c, 96.0, Color(1.0, 0.94, 0.66, 0.18 * a))
	draw_circle(c, 76.0, Color(1.0, 0.95, 0.72, 0.30 * a))
	draw_circle(c, 56.0, Color(1.0, 0.90, 0.42, a))
	draw_circle(c, 56.0, Color(1.0, 0.98, 0.85, 0.9 * a), false, 3.0)
	draw_circle(c + Vector2(-16, -18), 16.0, Color(1.0, 0.98, 0.86, 0.55 * a))


## 카툰 구름 — 폭신한 원 뭉치 + 밝은 아랫면 + 부드러운 흰 외곽선
func _draw_cloud(pos: Vector2, sc: float, a: float) -> void:
	var lobes := [Vector2(0, 0), Vector2(46, 8), Vector2(-46, 8), Vector2(24, -14), Vector2(-24, -12)]
	var body := Color(0.99, 0.99, 1.0, 0.92 * a)
	var edge := Color(0.78, 0.84, 0.95, 0.55 * a)
	# 외곽선(살짝 큰 원)
	for o in lobes:
		draw_circle(pos + o * sc, 37.0 * sc, edge)
	# 몸통
	for o in lobes:
		draw_circle(pos + o * sc, 34.0 * sc, body)
	# 아랫면 그림자(살짝 회색 → 입체감)
	draw_circle(pos + Vector2(0, 12) * sc, 30.0 * sc, Color(0.86, 0.89, 0.96, 0.35 * a))
