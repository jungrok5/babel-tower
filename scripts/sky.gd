extends Control
## 고도(미터)에 따라 스크롤하는 "실제 대기층" 배경.
## CanvasLayer(화면 고정) 위에 그려지지만, 구름·별을 각자의 고도에 배치하고
## 현재 고도만큼 아래로 밀어 그려서 — 올라갈수록 구름/별이 아래로 지나간다(패럴랙스).
##
## 실제 대기층 순서(아래→위):
##   0~60m   : 맑음(구름 없음)          · (새는 main이 15m~ 띄움)
##   70~170m : 높은 조각구름(드문드문)
##   120~600m: 바람(스트릭)
##   190~330m: 구름 가득(층운/적운)
##   330~430m: 구름 위(맑음)
##   440~660m: 성층권(얇은 권운)
##   560m~   : 별이 보이기 시작
##   820m~   : 우주(칠흑)

var meters: float = 0.0     # 현재 고도(미터) — main이 매 프레임 갱신
var t: float = 0.0          # 흐른 시간 — 반짝임/미세 흐름용
var wind: float = 0.0       # 현재 바람(-1..1) — 스트릭 방향/세기

const VW := 720.0
const VH := 1280.0
const REF_Y := VH * 0.52    # 고도==물체고도일 때 그 물체가 놓이는 화면 y(기준선)
const PX_PER_M := 12.0      # 고도 1m당 배경이 내려가는 픽셀(패럴랙스 기본치)

# (미터, 위색, 아래색) — 맑은 대낮 → 파란 하늘 → 성층권 남색 → 우주 칠흑
const SKY := [
	[0.0,   Color(0.40, 0.68, 0.95), Color(0.74, 0.90, 0.99)],
	[240.0, Color(0.22, 0.46, 0.82), Color(0.46, 0.68, 0.94)],
	[470.0, Color(0.12, 0.20, 0.52), Color(0.24, 0.36, 0.66)],
	[660.0, Color(0.05, 0.07, 0.24), Color(0.10, 0.13, 0.34)],
	[850.0, Color(0.010, 0.012, 0.03), Color(0.02, 0.02, 0.06)],
]

# 구름 인스턴스: {alt(고도m), x(화면x), scale, par(패럴랙스계수), kind("puffy"|"cirrus")}
var _clouds: Array = []
# 별 인스턴스: {alt, x, size, ph(반짝임 위상), par}
var _stars: Array = []
# 바람 스트릭: {alt, len, x0}
var _streaks: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 구름 밴드: [고도min, 고도max, 개수, 종류] — 실제 대기층 밀도 프로파일
	var bands := [
		[70.0, 170.0, 6, "puffy"],     # 높은 조각구름(드문드문)
		[190.0, 330.0, 20, "puffy"],   # 구름 가득(빽빽)
		[440.0, 660.0, 8, "cirrus"],   # 성층권 얇은 권운
	]
	for b in bands:
		for i in int(b[2]):
			_clouds.append({
				"alt": randf_range(b[0], b[1]),
				"x": randf() * VW,
				"scale": randf_range(0.7, 1.5),
				"par": randf_range(0.78, 1.16),
				"kind": b[3],
			})
	_clouds.sort_custom(func(a, c): return float(a["par"]) < float(c["par"]))  # 먼 것 먼저(뒤에)

	# 별: 고도 580~1400m에 넓게. 먼 배경이라 par 작게(천천히 흐름).
	for i in 130:
		_stars.append({
			"alt": randf_range(580.0, 1400.0),
			"x": randf() * VW,
			"size": randf_range(1.0, 2.7),
			"ph": randf() * TAU,
			"par": randf_range(0.30, 0.52),
		})

	# 바람 스트릭: 바람 부는 고도대(120~600m)에 분포
	for i in 16:
		_streaks.append({"alt": randf_range(120.0, 600.0), "len": randf_range(40.0, 120.0), "x0": randf() * VW})


func _process(_delta: float) -> void:
	queue_redraw()


## 어떤 고도(alt)의 물체가 지금 화면 어디(y)에 오는가 — 고도가 오를수록 아래로 내려온다.
func _alt_to_y(alt: float, par: float) -> float:
	return REF_Y + (meters - alt) * PX_PER_M * par


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
	# 세로 그라데이션
	var bands := 28
	for i in bands:
		var f := float(i) / float(bands - 1)
		draw_rect(Rect2(0, VH * i / bands, VW, VH / bands + 1), top.lerp(bot, f))

	# 해 — 지상에서 밝게. 올라갈수록 서서히 내려가며(고도감) 성층권 전에 사라진다.
	# (아무리 올라도 해보다 높이 갈 순 없으니 완전히 지나치진 않고 위쪽에서 페이드아웃)
	var sun_a := clampf((300.0 - meters) / 150.0, 0.0, 1.0)
	if sun_a > 0.0:
		var sun_y := 200.0 + meters * 0.45      # 오를수록 살짝 아래로(움직임 체감)
		_draw_sun(Vector2(VW - 148.0, sun_y), sun_a)

	# 별 — 고도별 위치. 올라가면 아래로 흐른다(우주로 상승하는 느낌).
	var star_a := clampf((meters - 560.0) / 160.0, 0.0, 1.0)
	if star_a > 0.0:
		for s in _stars:
			var sy := _alt_to_y(float(s["alt"]), float(s["par"]))
			if sy < -20.0 or sy > VH + 20.0:
				continue
			var tw := 0.45 + 0.55 * sin(t * 2.0 + float(s["ph"]))
			draw_circle(Vector2(float(s["x"]), sy), float(s["size"]), Color(1, 1, 1, star_a * tw))

	# 바람 스트릭 — 바람 세기에 따라. 고도 위치로 배치되어 함께 흐른다.
	var ws := absf(wind)
	if ws > 0.06:
		var dir := signf(wind)
		for st in _streaks:
			var sy := _alt_to_y(float(st["alt"]), 1.0)
			if sy < 0.0 or sy > VH:
				continue
			var x := fmod(float(st["x0"]) + t * dir * (200.0 + 500.0 * ws), VW + 200.0) - 100.0
			draw_line(Vector2(x, sy), Vector2(x - dir * float(st["len"]), sy),
				Color(0.9, 0.94, 1.0, ws * 0.4), 2.0)

	# 구름 — 각자의 고도에 배치. 올라갈수록 아래로 지나간다(패럴랙스).
	for c in _clouds:
		var cy := _alt_to_y(c["alt"], c["par"])
		if cy < -240.0 or cy > VH + 240.0:
			continue
		# 화면 위/아래 가장자리에서 부드럽게 사라지도록 페이드
		var a := clampf((cy + 220.0) / 150.0, 0.0, 1.0) * clampf((VH + 220.0 - cy) / 150.0, 0.0, 1.0)
		# 가벼운 가로 흐름 + 바람 밀림
		var cx := float(c["x"]) + sin(t * 0.08 + float(c["alt"]) * 0.7) * 16.0 + wind * 40.0 * float(c["par"])
		if c["kind"] == "cirrus":
			_draw_cirrus(Vector2(cx, cy), float(c["scale"]), a)
		else:
			_draw_cloud(Vector2(cx, cy), float(c["scale"]), a)


## 카툰 해 — 부드러운 후광 + 둥근 몸통 + 은은한 외곽선
func _draw_sun(c: Vector2, a: float) -> void:
	draw_circle(c, 96.0, Color(1.0, 0.94, 0.66, 0.18 * a))
	draw_circle(c, 76.0, Color(1.0, 0.95, 0.72, 0.30 * a))
	draw_circle(c, 56.0, Color(1.0, 0.90, 0.42, a))
	draw_circle(c, 56.0, Color(1.0, 0.98, 0.85, 0.9 * a), false, 3.0)
	draw_circle(c + Vector2(-16, -18), 16.0, Color(1.0, 0.98, 0.86, 0.55 * a))


## 폭신한 적운(뭉게구름) — 원 뭉치 + 밝은 아랫면 + 부드러운 흰 외곽선
func _draw_cloud(pos: Vector2, sc: float, a: float) -> void:
	var lobes := [Vector2(0, 0), Vector2(46, 8), Vector2(-46, 8), Vector2(24, -14), Vector2(-24, -12)]
	var body := Color(0.99, 0.99, 1.0, 0.94 * a)
	var edge := Color(0.78, 0.84, 0.95, 0.5 * a)
	for o in lobes:
		draw_circle(pos + o * sc, 37.0 * sc, edge)
	for o in lobes:
		draw_circle(pos + o * sc, 34.0 * sc, body)
	draw_circle(pos + Vector2(0, 12) * sc, 30.0 * sc, Color(0.86, 0.89, 0.96, 0.32 * a))


## 얇게 늘어진 권운(성층권) — 가로로 긴 옅은 띠 몇 겹
func _draw_cirrus(pos: Vector2, sc: float, a: float) -> void:
	var col := Color(0.92, 0.95, 1.0, 0.42 * a)
	for row in [-10.0, 0.0, 10.0]:
		for k in range(-3, 4):
			var p := pos + Vector2(k * 34.0 * sc, row * sc + sin(k * 1.3 + pos.x * 0.01) * 4.0)
			draw_circle(p, 20.0 * sc, col)
