extends Control
## 손 모양이 실제로 제스처를 시연하는 인게임 튜토리얼(텍스트 카드가 아니라 손이 직접 움직인다).
## 3단계 루프: ① 끌어서 위치  ② 두 손가락 탭 = 회전  ③ 기기를 수평으로.
## "시작하기"를 누르면 finished를 emit한다.

signal finished

const VW := 720.0
const VH := 1280.0
const CYCLE := 9.0        # 한 바퀴(초)
const P1 := 3.0           # 드래그 구간 끝
const P2 := 6.2           # 회전 구간 끝

var t: float = 0.0
var font: Font
var _skin := Color(0.98, 0.82, 0.66)
var _skin_edge := Color(0.80, 0.60, 0.44)


func setup(f: Font) -> void:
	font = f


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var start := Button.new()
	start.text = Locale.t("start")
	if font:
		start.add_theme_font_override("font", font)
	start.add_theme_font_size_override("font_size", 38)
	start.custom_minimum_size = Vector2(300, 88)
	start.position = Vector2(210, 1150)
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func(): finished.emit())
	add_child(start)


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, VW, VH), Color(0.03, 0.04, 0.07, 0.86))
	if font:
		draw_string(font, Vector2(0, 150), Locale.t("tut_title"), HORIZONTAL_ALIGNMENT_CENTER, VW, 56,
			Color(0.96, 0.93, 0.83))

	var ped := Vector2(360, 760)
	_draw_pedestal(ped)
	var bs := Vector2(184, 64)
	var col := Color(0.82, 0.75, 0.58, 0.98)
	var hover_y := ped.y - 49.0 - bs.y * 0.5 - 150.0
	var rest_y := ped.y - 49.0 - bs.y * 0.5
	var cyc := fmod(t, CYCLE)
	var cap := ""

	if cyc < P1:
		# ① 끌어서 좌우 위치 → 놓으면 낙하
		cap = Locale.t("tut_drag")
		if cyc < 1.9:
			var ph_d := cyc / 1.9
			var x_d := 360.0 + sin(ph_d * TAU) * 130.0
			var bc_d := Vector2(x_d, hover_y)
			draw_dashed_line(Vector2(x_d, bc_d.y + bs.y * 0.5), Vector2(x_d, rest_y),
				Color(0.98, 0.92, 0.55, 0.4), 2.0, 12.0)
			_draw_block(bc_d, 0.0, bs, col)
			_draw_hand(bc_d + Vector2(6.0, 6.0), false, 0.0)
			_draw_move_arrows(bc_d, bs)
		else:
			# 손을 떼고 블록이 제단 위로 낙하
			var fp := clampf((cyc - 1.9) / 1.1, 0.0, 1.0)
			var by := lerpf(hover_y, rest_y, fp * fp)   # 가속 낙하
			_draw_block(Vector2(360.0, by), 0.0, bs, col)
			_draw_hand(Vector2(360.0, hover_y + 34.0 + fp * 260.0), false, 0.0)   # 손은 놓고 아래로 빠짐
			if fp > 0.86:
				_draw_landing_puff(Vector2(360.0, rest_y + bs.y * 0.5), (fp - 0.86) / 0.14)
	elif cyc < P2:
		# ② 두 손가락 탭 = 45° 회전
		cap = Locale.t("tut_rotate")
		var lp_r := cyc - P1
		var period := 0.95
		var taps := int(lp_r / period)
		var frac := fmod(lp_r, period) / period
		var rot := deg_to_rad(45.0 * taps)
		if frac < 0.28:
			rot -= deg_to_rad(45.0) * (1.0 - frac / 0.28)
		var bc_r := Vector2(360.0, rest_y - 30.0)
		_draw_block(bc_r, rot, bs, col)
		var press := 1.0 if frac < 0.2 else 0.0
		_draw_hand(bc_r + Vector2(-8.0, 10.0), true, press)
		if frac < 0.45:
			var rp := frac / 0.45
			_draw_ripple(bc_r + Vector2(-34.0, 22.0), rp)
			_draw_ripple(bc_r + Vector2(40.0, 28.0), rp)
	else:
		# ③ 기기를 수평으로 (흔들리면 무너짐)
		cap = Locale.t("tut_still")
		var lp_s := cyc - P2
		var wob := sin(lp_s * 7.0) * 0.05 * clampf((lp_s - 0.3) * 1.5, 0.0, 1.0)
		_draw_mini_tower(ped, bs, wob)
		_draw_level_hint(Vector2(360.0, 430.0), wob)

	if font:
		draw_string(font, Vector2(24, 1064), cap, HORIZONTAL_ALIGNMENT_CENTER, VW - 48, 32,
			Color(0.86, 0.89, 0.96))
		draw_string(font, Vector2(24, 1108), Locale.t("tut_hint"), HORIZONTAL_ALIGNMENT_CENTER,
			VW - 48, 24, Color(0.55, 0.58, 0.66))


# ---------- 그리기 헬퍼 ----------

func _draw_pedestal(c: Vector2) -> void:
	var foot := Color(0.30, 0.29, 0.34)
	var body := Color(0.40, 0.39, 0.45)
	var cap := Color(0.50, 0.49, 0.55)
	_rect(Vector2(c.x, c.y + 6.0), Vector2(232, 24), foot)
	_rect(Vector2(c.x, c.y - 17.0), Vector2(188, 50), body)
	_rect(Vector2(c.x, c.y - 43.0), Vector2(206, 16), cap)
	_rect(Vector2(c.x, c.y - 49.0), Vector2(206, 4), cap.lightened(0.18))


func _draw_block(center: Vector2, rot: float, size: Vector2, col: Color) -> void:
	draw_set_transform(center, rot, Vector2.ONE)
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, col)
	draw_rect(r, col.darkened(0.4), false, 3.0)
	draw_line(Vector2(-size.x * 0.5 + 6, -size.y * 0.5 + 5),
		Vector2(size.x * 0.5 - 6, -size.y * 0.5 + 5), col.lightened(0.22), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_mini_tower(ped: Vector2, bs: Vector2, wob: float) -> void:
	var n := 4
	for i in range(n):
		var yy := ped.y - bs.y - i * bs.y
		var shift := wob * (i + 1) * 26.0
		_draw_block(Vector2(ped.x + shift, yy + bs.y * 0.5), wob * (i + 1) * 0.35,
			bs, Color(0.82, 0.75, 0.58, 0.98))


## 손: 검지(+회전 시 중지)로 화면을 누르는 모습. tip = 닿는 지점.
func _draw_hand(tip: Vector2, two: bool, press: float) -> void:
	var palm := tip + Vector2(30.0, 118.0 - press * 8.0)
	# 손목
	_rect(palm + Vector2(6, 60), Vector2(70, 90), _skin)
	# 손등
	draw_circle(palm, 52.0, _skin)
	# 엄지
	_finger(palm + Vector2(-40, 2), palm + Vector2(-2, 42), 15.0)
	# 검지 → tip
	_finger(palm + Vector2(-20, -20), tip, 17.0)
	if two:
		_finger(palm + Vector2(10, -22), tip + Vector2(46.0, 8.0), 16.0)
	# 손끝 하이라이트 링
	draw_arc(tip, 12.0, 0, TAU, 20, Color(1, 1, 1, 0.5), 2.0)
	if two:
		draw_arc(tip + Vector2(46.0, 8.0), 12.0, 0, TAU, 20, Color(1, 1, 1, 0.5), 2.0)


func _finger(a: Vector2, b: Vector2, r: float) -> void:
	draw_line(a, b, _skin_edge, 2.0 * r + 4.0)
	draw_line(a, b, _skin, 2.0 * r)
	draw_circle(b, r, _skin)


func _draw_ripple(center: Vector2, ph: float) -> void:
	var rr := lerpf(6.0, 44.0, ph)
	draw_arc(center, rr, 0, TAU, 28, Color(1, 1, 1, (1.0 - ph) * 0.55), 3.0)


## 착지 먼지 — 좌우로 퍼지는 원들
func _draw_landing_puff(pos: Vector2, ph: float) -> void:
	var a := (1.0 - ph) * 0.6
	for sx in [-1.0, 1.0]:
		var d := lerpf(6.0, 46.0, ph)
		draw_circle(pos + Vector2(sx * d, -ph * 8.0), lerpf(10.0, 3.0, ph),
			Color(0.85, 0.82, 0.7, a))


func _draw_move_arrows(bc: Vector2, bs: Vector2) -> void:
	var col := Color(0.98, 0.92, 0.55, 0.8)
	var lx := bc.x - bs.x * 0.5 - 34.0
	var rx := bc.x + bs.x * 0.5 + 34.0
	_arrow(Vector2(lx, bc.y), 1.0, col)     # 왼쪽 화살표는 바깥(왼쪽)을 가리킴
	_arrow(Vector2(rx, bc.y), -1.0, col)


func _arrow(tip: Vector2, dir: float, col: Color) -> void:
	draw_line(tip, tip + Vector2(dir * 22.0, -14.0), col, 4.0)
	draw_line(tip, tip + Vector2(dir * 22.0, 14.0), col, 4.0)


func _draw_level_hint(c: Vector2, wob: float) -> void:
	# 수평계 느낌: 기울어진 막대 + 가운데 방울
	var ang := wob * 4.0
	draw_set_transform(c, ang, Vector2.ONE)
	_rect(Vector2.ZERO, Vector2(180, 14), Color(0.22, 0.24, 0.3))
	draw_circle(Vector2(0, 0), 9.0, Color(0.5, 0.85, 0.5) if absf(wob) < 0.02 else Color(0.92, 0.5, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _rect(center: Vector2, size: Vector2, col: Color) -> void:
	draw_rect(Rect2(center - size * 0.5, size), col)
