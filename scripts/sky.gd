extends Control
## 높이(미터)에 따라 변하는 하늘 배경: 그라데이션 + 구름 + 별.
## CanvasLayer(화면 고정) 위에 그려져 카메라와 무관하게 배경으로 깔린다.

var meters: float = 0.0     # 현재 높이(미터) — main이 매 프레임 갱신
var t: float = 0.0          # 흐른 시간 — 구름/별 애니메이션용

const VW := 720.0
const VH := 1280.0

# (미터, 위색, 아래색) 키프레임 — 지상 노을 → 파란 하늘 → 남색 고공 → 우주
const SKY := [
	[0.0,   Color(0.07, 0.10, 0.17), Color(0.12, 0.11, 0.17)],
	[160.0, Color(0.17, 0.30, 0.52), Color(0.40, 0.54, 0.70)],
	[420.0, Color(0.09, 0.10, 0.30), Color(0.20, 0.17, 0.42)],
	[800.0, Color(0.010, 0.012, 0.03), Color(0.02, 0.02, 0.06)],
]

var _stars := []            # [Vector2 pos, float size, float phase]
var _clouds := []           # [Vector2 pos, float scale, float speed]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 90:
		_stars.append([Vector2(randf() * VW, randf() * VH * 0.85), randf_range(1.0, 2.6), randf() * TAU])
	for i in 7:
		_clouds.append([Vector2(randf() * VW, randf_range(120, 900)), randf_range(0.7, 1.6), randf_range(6.0, 16.0)])


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

	# 별 — 고공에서 서서히 나타남 (>350m)
	var star_a := clampf((meters - 350.0) / 400.0, 0.0, 1.0)
	if star_a > 0.0:
		for s in _stars:
			var tw := 0.5 + 0.5 * sin(t * 2.0 + s[2])
			draw_circle(s[0], s[1], Color(1, 1, 1, star_a * (0.4 + 0.6 * tw)))

	# 구름 — 중간 고도에서 잘 안 보이게 흐릿하게 (peak ~150m)
	var cloud_a := clampf(1.0 - absf(meters - 150.0) / 260.0, 0.0, 1.0) * 0.5
	if cloud_a > 0.0:
		for c in _clouds:
			var x := fmod(c[0].x + t * c[2], VW + 300.0) - 150.0
			_draw_cloud(Vector2(x, c[0].y), c[1], Color(0.9, 0.92, 0.96, cloud_a))


func _draw_cloud(pos: Vector2, sc: float, col: Color) -> void:
	for o in [Vector2(0, 0), Vector2(45, 6), Vector2(-45, 6), Vector2(22, -12), Vector2(-22, -10)]:
		draw_circle(pos + o * sc, 34.0 * sc, col)
