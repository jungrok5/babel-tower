extends Control
## 고도(미터)에 따라 스크롤하는 "살아있는 대기층" 배경.
## 구름·별·환경요소(나비·새떼·풍선·비행기·위성·우주정거장·우주인·행성·별똥별)를
## 각자의 고도에 배치하고, 현재 고도만큼 아래로 밀어 그린다(패럴랙스) → 올라갈수록 아래로 지나간다.
##
## 대기층 순서(아래→위, 미터) — 간격을 넓혀 올라갈수록 천천히 하나씩 등장:
##   0~40    맑음(나비)
##   30~110  높은 조각구름 · 새떼
##   40~260  바람
##   90~200  구름 가득
##   90~170  비행기
##   170~280 위성
##   230~300 성층권(권운)
##   220~    별
##   240~340 우주정거장
##   300~410 우주인(희귀)
##   320~    행성 · 별똥별 · 깊은 우주(칠흑, ~360+)

var meters: float = 0.0
var t: float = 0.0
var wind: float = 0.0

const VW := 720.0
const VH := 1280.0
const REF_Y := VH * 0.5
const PX_PER_M := 10.0        # 고도 1m당 배경이 내려가는 픽셀
const OUTLINE := Color(0.12, 0.11, 0.14)

# (미터, 위색, 아래색) — 대낮 → 파랑 → 성층권 남색 → 우주 칠흑 (고도 낮춰 도달 쉽게)
const SKY := [
	[0.0,   Color(0.40, 0.68, 0.95), Color(0.74, 0.90, 0.99)],
	[110.0, Color(0.24, 0.48, 0.84), Color(0.48, 0.70, 0.95)],
	[220.0, Color(0.12, 0.20, 0.52), Color(0.24, 0.36, 0.66)],
	[300.0, Color(0.05, 0.07, 0.24), Color(0.10, 0.13, 0.34)],
	[360.0, Color(0.010, 0.012, 0.03), Color(0.02, 0.02, 0.06)],
]

var _clouds: Array = []       # {alt,x,scale,par,kind,vx}
var _stars: Array = []        # {alt,x,size,ph,par}
var _env: Array = []          # {kind,alt,x,par,...}

const _BAL_COLS := [Color(0.92,0.28,0.28), Color(0.30,0.55,0.95), Color(0.98,0.80,0.25),
	Color(0.42,0.78,0.42), Color(0.72,0.42,0.88), Color(0.98,0.55,0.25)]
const _BFLY_COLS := [Color(0.98,0.55,0.20), Color(0.35,0.65,0.95), Color(0.95,0.45,0.70), Color(0.98,0.82,0.30)]
const _PLANET_COLS := [Color(0.82,0.55,0.35), Color(0.60,0.66,0.82), Color(0.70,0.58,0.72)]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gen_sky()
	regen_env()


func _gen_sky() -> void:
	# 구름 밴드: [고도min, 고도max, 개수, 종류] — 수 줄이고 고도 간격 넓힘(덜 산만하게)
	for b in [[40.0, 110.0, 4, "puffy"], [90.0, 200.0, 12, "puffy"], [230.0, 300.0, 4, "cirrus"]]:
		for i in int(b[2]):
			_clouds.append({"alt": randf_range(b[0], b[1]), "x": randf() * VW,
				"scale": randf_range(0.75, 1.5), "par": randf_range(0.78, 1.16),
				"kind": b[3], "vx": randf_range(-11.0, 11.0)})
	_clouds.sort_custom(func(a, c): return float(a["par"]) < float(c["par"]))
	for i in 80:
		_stars.append({"alt": randf_range(230.0, 640.0), "x": randf() * VW,
			"size": randf_range(1.0, 2.5), "ph": randf() * TAU, "par": randf_range(0.30, 0.5)})


## 환경요소를 매 판마다 새로 뿌린다(랜덤 · 희귀 요소 포함) → "이번엔 뭐가 보일까"
func regen_env() -> void:
	_env.clear()
	_add("birdflock", randf_range(30.0, 110.0), {"n": randi_range(3, 5), "dir": _dir(), "spd": randf_range(22.0, 42.0), "par": randf_range(0.7, 1.0)})
	for i in 2:
		_add("balloon", randf_range(60.0, 260.0), {"col": _pick(_BAL_COLS), "rise": randf_range(4.0, 9.0), "ph": randf() * TAU, "par": randf_range(0.85, 1.15)})
	if randf() < 0.8:
		_add("plane", randf_range(90.0, 170.0), {"dir": _dir(), "spd": randf_range(45.0, 75.0), "par": randf_range(0.6, 0.8)})
	_add("satellite", randf_range(170.0, 280.0), {"dir": _dir(), "spd": randf_range(18.0, 30.0), "par": 0.85})
	if randf() < 0.7:
		_add("iss", randf_range(240.0, 340.0), {"dir": _dir(), "spd": randf_range(10.0, 18.0), "par": 0.8})
	if randf() < 0.5:   # 우주인 — 희귀
		_add("astronaut", randf_range(300.0, 410.0), {"ph": randf() * TAU, "par": 0.9})
	if randf() < 0.75:  # 행성 — 멀리, 아주 고공
		_add("planet", randf_range(320.0, 470.0), {"col": _pick(_PLANET_COLS), "r": randf_range(60.0, 108.0), "ring": randf() < 0.5, "par": 0.42})
	_add("shootingstar", randf_range(340.0, 540.0), {"ph": randf() * TAU, "period": randf_range(5.0, 10.0), "dir": _dir(), "par": 0.7})


## 테스트용: 모든 종류를 알려진 고도에 하나씩 강제 배치(스샷 검증).
func force_all_env() -> void:
	_env.clear()
	_add("birdflock", 60.0, {"n": 5, "dir": 1.0, "spd": 30.0, "par": 0.9})
	_add("balloon", 120.0, {"col": _BAL_COLS[0], "rise": 0.0, "ph": 0.0, "par": 1.0})
	_add("plane", 130.0, {"dir": 1.0, "spd": 0.0, "par": 0.7})
	_add("satellite", 210.0, {"dir": 1.0, "spd": 0.0, "par": 0.85})
	_add("iss", 250.0, {"dir": 1.0, "spd": 0.0, "par": 0.8})
	_add("astronaut", 330.0, {"ph": 0.0, "par": 0.9})
	_add("planet", 370.0, {"col": _PLANET_COLS[0], "r": 96.0, "ring": true, "par": 0.42})
	_add("shootingstar", 380.0, {"ph": 0.0, "period": 6.0, "dir": 1.0, "par": 0.5})


func _add(kind: String, alt: float, extra: Dictionary) -> void:
	var d := {"kind": kind, "alt": alt, "x": randf() * VW}
	d.merge(extra)
	_env.append(d)


func _dir() -> float:
	return 1.0 if randf() < 0.5 else -1.0


func _pick(arr: Array):
	return arr[randi() % arr.size()]


func _process(_delta: float) -> void:
	queue_redraw()


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
	var bands := 28
	for i in bands:
		draw_rect(Rect2(0, VH * i / bands, VW, VH / bands + 1), top.lerp(bot, float(i) / float(bands - 1)))

	# 먼 우주 배경(행성) → 별 → 우주 물체(위성/정거장/우주인/별똥별)
	for e in _env:
		if e["kind"] == "planet":
			_draw_env(e)
	_draw_stars()
	for e in _env:
		if e["kind"] in ["satellite", "iss", "astronaut", "shootingstar"]:
			_draw_env(e)

	# 해 (지상) — 오를수록 아래로, 구름대 전에 사라짐
	var sun_a := clampf((90.0 - meters) / 55.0, 0.0, 1.0)
	if sun_a > 0.0:
		_draw_sun(Vector2(VW - 148.0, 200.0 + meters * 0.7), sun_a)

	# (바람 시각화는 전경 wind_fx가 담당 — 하늘 배경엔 스트릭을 그리지 않는다)

	# 구름 (좌우로 흐르고, 바람이 불면 그 방향으로 살짝 쏠린다)
	for c in _clouds:
		var cy := _alt_to_y(float(c["alt"]), float(c["par"]))
		if cy < -240.0 or cy > VH + 240.0:
			continue
		var a := clampf((cy + 220.0) / 150.0, 0.0, 1.0) * clampf((VH + 220.0 - cy) / 150.0, 0.0, 1.0)
		var cx := wrapf(float(c["x"]) + t * float(c["vx"]), -240.0, VW + 240.0) \
			+ sin(t * 0.1 + float(c["alt"])) * 8.0 + wind * 16.0 * float(c["par"])
		if c["kind"] == "cirrus":
			_draw_cirrus(Vector2(cx, cy), float(c["scale"]), a)
		else:
			_draw_cloud(Vector2(cx, cy), float(c["scale"]), a)

	# 가까운 환경요소(구름 앞): 풍선·비행기·새떼·나비
	for e in _env:
		if e["kind"] in ["balloon", "plane", "birdflock", "butterfly"]:
			_draw_env(e)


func _draw_stars() -> void:
	var star_a := clampf((meters - 220.0) / 60.0, 0.0, 1.0)
	if star_a <= 0.0:
		return
	for s in _stars:
		var sy := _alt_to_y(float(s["alt"]), float(s["par"]))
		if sy < -20.0 or sy > VH + 20.0:
			continue
		var tw := 0.45 + 0.55 * sin(t * 2.0 + float(s["ph"]))
		draw_circle(Vector2(float(s["x"]), sy), float(s["size"]), Color(1, 1, 1, star_a * tw))


func _draw_env(e: Dictionary) -> void:
	var par := float(e.get("par", 0.6))
	var y := _alt_to_y(float(e["alt"]), par)
	if y < -160.0 or y > VH + 160.0:
		return
	match e["kind"]:
		"butterfly":
			var bx := float(e["x"]) + sin(t * 2.4 + float(e["ph"])) * 46.0
			_draw_butterfly(Vector2(bx, y + sin(t * 3.3 + float(e["ph"])) * 10.0), e["col"], t * 9.0 + float(e["ph"]))
		"birdflock":
			var fx := wrapf(float(e["x"]) + t * float(e["spd"]) * float(e["dir"]), -160.0, VW + 160.0)
			_draw_birdflock(Vector2(fx, y), int(e["n"]), float(e["dir"]))
		"balloon":
			var alt2 := float(e["alt"]) + fmod(t * float(e["rise"]), 120.0)   # 천천히 상승
			var byy := _alt_to_y(alt2, par)
			var bxx := float(e["x"]) + sin(t * 0.6 + float(e["ph"])) * 18.0
			_draw_balloon(Vector2(bxx, byy), e["col"])
		"plane":
			var px := wrapf(float(e["x"]) + t * float(e["spd"]) * float(e["dir"]), -200.0, VW + 200.0)
			_draw_plane(Vector2(px, y), float(e["dir"]))
		"satellite":
			var sx := wrapf(float(e["x"]) + t * float(e["spd"]) * float(e["dir"]), -160.0, VW + 160.0)
			_draw_satellite(Vector2(sx, y), float(e["dir"]))
		"iss":
			var ix := wrapf(float(e["x"]) + t * float(e["spd"]) * float(e["dir"]), -200.0, VW + 200.0)
			_draw_iss(Vector2(ix, y))
		"astronaut":
			var ax := float(e["x"]) + sin(t * 0.3 + float(e["ph"])) * 34.0
			_draw_astronaut(Vector2(ax, y + sin(t * 0.5 + float(e["ph"])) * 14.0), sin(t * 0.2) * 0.25)
		"planet":
			_draw_planet(Vector2(float(e["x"]), y), float(e["r"]), e["col"], bool(e["ring"]))
		"shootingstar":
			_draw_shootingstar(e, y)


# ---------------------------------------------------------------- 그리기 헬퍼

func _draw_sun(c: Vector2, a: float) -> void:
	draw_circle(c, 96.0, Color(1.0, 0.94, 0.66, 0.18 * a))
	draw_circle(c, 76.0, Color(1.0, 0.95, 0.72, 0.30 * a))
	draw_circle(c, 56.0, Color(1.0, 0.90, 0.42, a))
	draw_circle(c, 56.0, Color(1.0, 0.98, 0.85, 0.9 * a), false, 3.0)
	draw_circle(c + Vector2(-16, -18), 16.0, Color(1.0, 0.98, 0.86, 0.55 * a))


func _draw_cloud(pos: Vector2, sc: float, a: float) -> void:
	var lobes := [Vector2(0, 0), Vector2(46, 8), Vector2(-46, 8), Vector2(24, -14), Vector2(-24, -12)]
	var body := Color(0.99, 0.99, 1.0, 0.94 * a)
	var edge := Color(0.78, 0.84, 0.95, 0.5 * a)
	for o in lobes:
		draw_circle(pos + o * sc, 37.0 * sc, edge)
	for o in lobes:
		draw_circle(pos + o * sc, 34.0 * sc, body)
	draw_circle(pos + Vector2(0, 12) * sc, 30.0 * sc, Color(0.86, 0.89, 0.96, 0.32 * a))


func _draw_cirrus(pos: Vector2, sc: float, a: float) -> void:
	# 부드럽고 옅은 권운 — 가로로 길게 늘어진 획 몇 개(겹치는 원 격자를 없애 눈부심 제거)
	var col := Color(0.90, 0.94, 1.0, 0.14 * a)
	for row in [-14.0, 0.0, 13.0]:
		var y := pos.y + float(row) * sc
		var half := (120.0 + float(row)) * sc
		draw_line(Vector2(pos.x - half, y), Vector2(pos.x + half, y), col, 12.0 * sc)


## 나비 — 색 날개 두 쌍(펄럭임) + 몸통 + 더듬이
func _draw_butterfly(c: Vector2, col: Color, flap: float) -> void:
	var w := 0.45 + 0.55 * absf(sin(flap))       # 날개 펼침 정도(가로 스케일)
	var wc: Color = col
	for sx in [-1.0, 1.0]:
		var dx := float(sx) * 11.0 * w
		draw_circle(c + Vector2(dx, -4.0), 9.0, wc)                 # 윗날개
		draw_circle(c + Vector2(dx * 0.9, 6.0), 7.0, wc.darkened(0.12))  # 아랫날개
		draw_arc(c + Vector2(dx, -4.0), 9.0, 0, TAU, 16, OUTLINE, 1.4)
		draw_arc(c + Vector2(dx * 0.9, 6.0), 7.0, 0, TAU, 16, OUTLINE, 1.4)
	draw_line(c + Vector2(0, -8), c + Vector2(0, 9), Color(0.15, 0.13, 0.16), 2.5)  # 몸통
	draw_line(c + Vector2(0, -8), c + Vector2(-4, -14), Color(0.15, 0.13, 0.16), 1.4)
	draw_line(c + Vector2(0, -8), c + Vector2(4, -14), Color(0.15, 0.13, 0.16), 1.4)


## 새떼 — 느슨한 V 대형, 각자 날갯짓
func _draw_birdflock(c: Vector2, n: int, dir: float) -> void:
	for i in n:
		var off := Vector2((i - n / 2) * 26.0 * dir, absf(i - n / 2) * 15.0)
		_draw_bird_glyph(c + off, sin(t * 6.0 + i) * 0.5)


func _draw_bird_glyph(p: Vector2, flap: float) -> void:
	var col := Color(0.16, 0.17, 0.22)
	var dy := flap * 6.0
	draw_line(p + Vector2(-11, dy), p, col, 3.0)
	draw_line(p + Vector2(11, dy), p, col, 3.0)


## 풍선 — 색 몸통 + 매듭 + 구불구불 줄
func _draw_balloon(c: Vector2, col: Color) -> void:
	draw_circle(c, 20.0, col)
	draw_circle(c + Vector2(0, 4), 20.0, col)               # 살짝 물방울꼴
	draw_circle(c + Vector2(-6, -7), 6.0, col.lightened(0.35))  # 하이라이트
	draw_arc(c, 20.0, 0, TAU, 24, OUTLINE, 2.0)
	var knot := c + Vector2(0, 21)
	draw_colored_polygon(PackedVector2Array([knot + Vector2(-5, 0), knot + Vector2(5, 0), knot + Vector2(0, 8)]), col.darkened(0.2))
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(knot + Vector2(sin(t * 2.0 + k * 0.9) * 5.0, 8.0 + k * 7.0))
	draw_polyline(pts, Color(0.3, 0.3, 0.34, 0.8), 1.6)


## 비행기 — 옆모습 실루엣 (dir 방향)
func _draw_plane(c: Vector2, dir: float) -> void:
	var body := Color(0.93, 0.94, 0.98)
	draw_set_transform(c, 0.0, Vector2(dir, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-34, 0), Vector2(24, -7), Vector2(38, 0), Vector2(24, 7)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -3), Vector2(10, -22), Vector2(18, -3)]), body.darkened(0.08))  # 날개
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -2), Vector2(-22, -16), Vector2(-16, -2)]), body.darkened(0.08))  # 꼬리
	draw_polyline(PackedVector2Array([Vector2(-34, 0), Vector2(24, -7), Vector2(38, 0), Vector2(24, 7), Vector2(-34, 0)]), OUTLINE, 1.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 인공위성 — 본체 + 태양전지판 + 접시 + 깜빡이 불빛
func _draw_satellite(c: Vector2, dir: float) -> void:
	var panel := Color(0.28, 0.42, 0.78)
	for sx in [-1.0, 1.0]:
		var pr := Rect2(c.x + sx * 20.0 - 16.0, c.y - 9.0, 32.0, 18.0)
		draw_rect(pr, panel)
		draw_rect(pr, OUTLINE, false, 1.6)
		for g in range(1, 4):
			draw_line(Vector2(pr.position.x + g * 8.0, pr.position.y), Vector2(pr.position.x + g * 8.0, pr.position.y + 18.0), OUTLINE, 1.0)
	draw_rect(Rect2(c.x - 9.0, c.y - 10.0, 18.0, 20.0), Color(0.85, 0.86, 0.9))
	draw_rect(Rect2(c.x - 9.0, c.y - 10.0, 18.0, 20.0), OUTLINE, false, 1.8)
	draw_circle(c + Vector2(dir * 14.0, -12.0), 6.0, Color(0.8, 0.82, 0.86))   # 접시
	var blink := 0.5 + 0.5 * sin(t * 5.0)
	draw_circle(c + Vector2(0, -13.0), 2.6, Color(1.0, 0.35, 0.3, blink))


## 우주정거장(ISS) — 중앙 모듈 + 큰 태양전지판 여러 장
func _draw_iss(c: Vector2) -> void:
	var panel := Color(0.24, 0.36, 0.72)
	draw_line(c + Vector2(-58, 0), c + Vector2(58, 0), Color(0.7, 0.72, 0.78), 4.0)   # 트러스
	for sx in [-1.0, 1.0]:
		for j in [-1.0, 1.0]:
			var pr := Rect2(c.x + sx * 36.0 - 22.0, c.y + j * 20.0 - 12.0, 44.0, 24.0)
			draw_rect(pr, panel)
			draw_rect(pr, OUTLINE, false, 1.6)
	draw_rect(Rect2(c.x - 14.0, c.y - 9.0, 28.0, 18.0), Color(0.86, 0.87, 0.9))       # 모듈
	draw_rect(Rect2(c.x - 14.0, c.y - 9.0, 28.0, 18.0), OUTLINE, false, 1.8)
	draw_circle(c + Vector2(0, -14.0), 2.6, Color(0.9, 0.95, 1.0, 0.5 + 0.5 * sin(t * 4.0)))


## 우주인 — 헬멧(바이저) + 몸통 + 생명줄
func _draw_astronaut(c: Vector2, tilt: float) -> void:
	draw_set_transform(c, tilt, Vector2.ONE)
	draw_line(Vector2(0, -6), Vector2(-70, -46), Color(0.75, 0.78, 0.82, 0.7), 2.0)   # 생명줄
	var suit := Color(0.92, 0.93, 0.97)
	draw_line(Vector2(-9, 6), Vector2(-20, 20), suit, 8.0)     # 팔다리
	draw_line(Vector2(9, 6), Vector2(20, 18), suit, 8.0)
	draw_line(Vector2(-6, 16), Vector2(-12, 34), suit, 9.0)
	draw_line(Vector2(6, 16), Vector2(12, 34), suit, 9.0)
	draw_rect(Rect2(-13, 12, 26, 10), Color(0.8, 0.82, 0.88))  # 백팩 살짝
	var body := Rect2(-12, -6, 24, 26)
	draw_rect(body, suit)
	draw_rect(body, OUTLINE, false, 2.0)
	draw_circle(Vector2(0, -14), 15.0, suit)                   # 헬멧
	draw_arc(Vector2(0, -14), 15.0, 0, TAU, 22, OUTLINE, 2.0)
	draw_circle(Vector2(0, -14), 10.0, Color(0.20, 0.35, 0.50))  # 바이저
	draw_circle(Vector2(-3, -17), 3.5, Color(0.7, 0.85, 0.95, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 행성 — 큰 원 + 명암 + (옵션)고리
func _draw_planet(c: Vector2, r: float, col: Color, ring: bool) -> void:
	draw_circle(c, r, col)
	draw_circle(c + Vector2(-r * 0.28, -r * 0.28), r * 0.7, col.lightened(0.12))  # 밝은 면
	draw_circle(c + Vector2(r * 0.32, r * 0.30), r * 0.55, col.darkened(0.18))    # 그림자
	draw_arc(c, r, 0, TAU, 48, col.darkened(0.35), 2.0)
	if ring:
		for rr in [r * 1.5, r * 1.62, r * 1.74]:
			draw_arc(c, rr, 0.0, TAU, 60, Color(0.85, 0.82, 0.7, 0.5), 2.5)


## 별똥별 — 주기적으로 대각선으로 지나감
func _draw_shootingstar(e: Dictionary, y: float) -> void:
	var period := float(e["period"])
	var ph := fmod(t + float(e["ph"]), period) / period
	if ph > 0.22:
		return
	var f := ph / 0.22
	var dir := float(e["dir"])
	var head := Vector2(float(e["x"]) + dir * (f - 0.3) * 520.0, y + (f - 0.3) * 240.0)
	var tail := head - Vector2(dir * 90.0, 42.0)
	draw_line(tail, head, Color(1, 1, 1, (1.0 - f) * 0.8), 2.5)
	draw_circle(head, 2.6, Color(1, 1, 1, 1.0 - f))
