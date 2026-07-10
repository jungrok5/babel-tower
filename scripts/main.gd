extends Node2D
## Babel Tower — 메인 게임 매니저
##
## 핵심 규칙: 기기를 최대한 움직이지 마라.
## 흔들리면 탑이 요동치고, 높이 올라갈수록 작은 떨림도 치명적이 된다.

enum State { CALIB, READY, OVER }

## 화면에 표시되는 빌드 버전 — 캐시된 옛 빌드인지 확인용. 변경 시마다 올린다.
const GAME_VERSION := "v0.7 · rapid"

const BASE_X := 360.0
const GROUND_TOP_Y := 1050.0
const BLOCK_SIZE := Vector2(180.0, 62.0)
const DROP_HEIGHT := 150.0          # 다음 벽돌이 떨어지기 시작하는 높이(짧게 = 연사 쌓기 쾌감)
const TIP_ANGLE := 0.75             # 이 각도 이상 기울면 붕괴 (라디안)
const COLLAPSE_FALL := 170.0        # 바닥 아래로 이만큼 떨어지면 붕괴
const MAX_FLOOR_TILT := 0.7         # 기기를 최대로 기울였을 때 '바닥'이 기우는 각도(라디안)
const GRAVITY_MAG := 1100.0         # 중력 크기 (블록에 직접 적용)

var state: int = State.CALIB
var score: int = 0
var blocks: Array[Block] = []
var calib_timer: float = 0.0
var go_shake: float = 0.0           # 붕괴 순간의 카메라 흔들림 버스트
var web_permission_asked := false

var cam: Camera2D
var ui: CanvasLayer
var height_label: Label
var best_label: Label
var hint_label: Label
var stab_fill: ColorRect
var calib_panel: Control
var calib_label: Label
var calib_button: Button
var awaiting_sensor: bool = false
var over_panel: Control
var over_body: VBoxContainer
var ui_font: Font


func _ready() -> void:
	randomize()
	_build_world()
	_build_ui()
	_begin_calibration()


## 현재 상태에 맞는 '아래' 방향. 플레이 중엔 기기 기울기만큼 회전한다.
func _gravity_dir() -> Vector2:
	if state == State.READY:
		var theta := clampf(Motion.get_sway(), -1.0, 1.0) * MAX_FLOOR_TILT
		return Vector2(sin(theta), cos(theta))  # (0,1) = 화면 아래
	return Vector2(0, 1)  # 보정/게임오버: 수평(잔해는 똑바로 낙하)


# ---------------------------------------------------------------- 월드 구성

func _build_world() -> void:
	# 바닥
	var ground := StaticBody2D.new()
	ground.position = Vector2(BASE_X, GROUND_TOP_Y + 100.0)
	var gshape := RectangleShape2D.new()
	gshape.size = Vector2(2400.0, 200.0)
	var gcs := CollisionShape2D.new()
	gcs.shape = gshape
	ground.add_child(gcs)
	var gvis := Polygon2D.new()
	gvis.polygon = PackedVector2Array([
		Vector2(-1200, -100), Vector2(1200, -100),
		Vector2(1200, 100), Vector2(-1200, 100)])
	gvis.color = Color(0.12, 0.13, 0.18)
	ground.add_child(gvis)
	add_child(ground)

	# 카메라
	cam = Camera2D.new()
	cam.position = Vector2(BASE_X, GROUND_TOP_Y - 200.0)
	cam.zoom = Vector2.ONE
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()

	# 초석 (첫 벽돌) — 점수에 포함되지 않는 토대
	var base := _make_block(0)
	base.position = Vector2(BASE_X, GROUND_TOP_Y - BLOCK_SIZE.y * 0.5 - 1.0)
	add_child(base)
	blocks.append(base)


func _make_block(level: int) -> Block:
	var b := Block.new()
	b.setup(BLOCK_SIZE, _brick_color(level))
	return b


func _brick_color(level: int) -> Color:
	# 층마다 미묘하게 색을 달리해 쌓임을 시각적으로 구분
	var base := Color(0.80, 0.73, 0.57)
	var t := fmod(float(level) * 0.13, 1.0)
	return base.lerp(Color(0.62, 0.55, 0.42), t)


# ---------------------------------------------------------------- 게임 흐름

func _begin_calibration() -> void:
	state = State.CALIB
	calib_panel.visible = true
	over_panel.visible = false
	# 웹: 사용자가 "센서 켜기"를 눌러야 모션 권한 요청 + 보정 시작 (iOS 제스처 요건)
	if OS.has_feature("web") and not web_permission_asked:
		awaiting_sensor = true
		calib_button.visible = true
	else:
		# 네이티브(Android/iOS 앱)/재보정: 곧바로 보정 시작
		_start_calibration_countdown()


func _start_calibration_countdown() -> void:
	awaiting_sensor = false
	calib_button.visible = false
	calib_timer = 1.6
	Motion.start_calibration(calib_timer)


func _on_sensor_enable() -> void:
	if not web_permission_asked:
		web_permission_asked = true
		Motion.request_web_permission()
	_start_calibration_countdown()


## 탭 즉시 다음 벽돌을 떨어뜨린다. 안착을 기다리지 않으므로 파파파팍 연사 가능.
func _drop_block() -> void:
	var top := _top_block()
	var sx := BASE_X
	var sy := GROUND_TOP_Y - BLOCK_SIZE.y * 0.5 - DROP_HEIGHT
	if top != null:
		# 기울어 있어도 탑 꼭대기 바로 위에 떨어뜨린다
		sx = top.position.x
		sy = top.position.y - top.block_size.y * 0.5 - DROP_HEIGHT
	var b := _make_block(score + 1)
	b.position = Vector2(sx, sy)
	add_child(b)
	blocks.append(b)
	score += 1


func _top_block() -> Block:
	var top: Block = null
	for b in blocks:
		if is_instance_valid(b) and (top == null or b.position.y < top.position.y):
			top = b
	return top


func _game_over() -> void:
	if state == State.OVER:
		return
	state = State.OVER
	go_shake = 26.0
	Input.vibrate_handheld(400)         # 붕괴의 햅틱
	Graveyard.add_record(score)
	_show_game_over()


func _restart() -> void:
	for b in blocks:
		if is_instance_valid(b):
			b.queue_free()
	blocks.clear()
	score = 0
	cam.offset = Vector2.ZERO
	cam.zoom = Vector2.ONE
	cam.position = Vector2(BASE_X, GROUND_TOP_Y - 200.0)

	var base := _make_block(0)
	base.position = Vector2(BASE_X, GROUND_TOP_Y - BLOCK_SIZE.y * 0.5 - 1.0)
	add_child(base)
	blocks.append(base)

	over_panel.visible = false
	state = State.READY


# ---------------------------------------------------------------- 입력

func _unhandled_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE:
		tapped = true
	if not tapped:
		return

	# 웹 모션 권한은 보정 화면의 "센서 켜기" 버튼에서 처리한다.
	if state == State.READY:
		_drop_block()


# ---------------------------------------------------------------- 물리

func _physics_process(delta: float) -> void:
	# 중력은 모든 상태에서 블록에 직접 넣는다(gravity_scale=0이므로).
	# 플레이 중엔 기기 기울기만큼 '아래'가 회전 → 탑이 낮은 쪽으로 쏠린다.
	# 코히런트한 힘이라 덜덜거림이 없고, 매 프레임 받으므로 블록이 잠들지 않는다.
	var gdir := _gravity_dir()
	for b in blocks:
		if is_instance_valid(b):
			b.apply_central_force(gdir * GRAVITY_MAG * b.mass)

	if state == State.CALIB or state == State.OVER:
		return

	_check_collapse()


func _check_collapse() -> void:
	var collapse_y := GROUND_TOP_Y + COLLAPSE_FALL
	for b in blocks:
		if not is_instance_valid(b):
			continue
		if absf(b.rotation) > TIP_ANGLE:
			_game_over()
			return
		if b.global_position.y > collapse_y:
			_game_over()
			return


func _tower_top_edge() -> float:
	var top := GROUND_TOP_Y
	for b in blocks:
		if is_instance_valid(b):
			top = minf(top, b.position.y - b.block_size.y * 0.5)
	return top


# ---------------------------------------------------------------- 프레임 업데이트

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_ui(delta)


func _update_camera(delta: float) -> void:
	var target := Vector2(BASE_X, _tower_top_edge() - 200.0)
	if state == State.CALIB:
		target = Vector2(BASE_X, GROUND_TOP_Y - 200.0)
	cam.position = cam.position.lerp(target, 0.08)

	# 높이 오를수록 줌아웃 → 작은 떨림도 크게 보이는 "공포" 시스템
	var z := clampf(1.0 - float(score) * 0.03, 0.42, 1.0)
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 0.05)

	# 흔들림/붕괴 카메라 셰이크
	go_shake = maxf(0.0, go_shake - delta * 45.0)
	var amp := Motion.get_shake() * 12.0 + go_shake
	if state == State.CALIB:
		amp = 0.0
	cam.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))


func _update_ui(delta: float) -> void:
	height_label.text = "높이  %d" % score
	best_label.text = "최고  %d" % Graveyard.best

	# 안정도 = 얼마나 수평인가. 기울일수록(또는 흔들수록) 빨갛게.
	var inst := clampf(absf(Motion.get_sway()) * 1.1 + Motion.get_shake() * 0.3, 0.0, 1.0)
	stab_fill.size.x = 300.0 * clampf(1.0 - inst, 0.02, 1.0)
	stab_fill.color = Color(0.32, 0.85, 0.45).lerp(Color(0.92, 0.26, 0.26), inst)

	match state:
		State.CALIB:
			hint_label.text = ""
			if awaiting_sensor:
				calib_label.text = "센서를 켜고\n탑 쌓기를 시작하세요\n\n(모션 권한을 허용해 주세요)"
			else:
				calib_timer -= delta
				if not Motion.is_calibrating():
					calib_panel.visible = false
					state = State.READY
				calib_label.text = "가장 편안한 자세로\n기기를 잡으세요\n\n· 보정 중 ·"
		State.READY:
			hint_label.text = "탭해서 계속 쌓으세요\n기기를 수평으로 — 기울면 탑이 쏠립니다"
		State.OVER:
			hint_label.text = ""


# ---------------------------------------------------------------- UI 구성

func _build_ui() -> void:
	# 한글 글리프가 포함된 폰트 (기본 폰트엔 한글이 없어 '두부'로 깨진다)
	ui_font = load("res://fonts/NanumGothic-Regular.ttf")

	ui = CanvasLayer.new()
	add_child(ui)

	height_label = _make_label("높이  0", 46, Color(0.95, 0.93, 0.85))
	height_label.position = Vector2(40, 44)
	ui.add_child(height_label)

	best_label = _make_label("최고  0", 30, Color(0.6, 0.62, 0.7))
	best_label.position = Vector2(440, 54)
	best_label.size = Vector2(240, 40)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(best_label)

	# 안정도 바
	var stab_bg := ColorRect.new()
	stab_bg.color = Color(0.16, 0.17, 0.22)
	stab_bg.position = Vector2(210, 128)
	stab_bg.size = Vector2(300, 18)
	ui.add_child(stab_bg)
	stab_fill = ColorRect.new()
	stab_fill.color = Color(0.32, 0.85, 0.45)
	stab_fill.position = Vector2(210, 128)
	stab_fill.size = Vector2(300, 18)
	ui.add_child(stab_fill)
	var stab_cap := _make_label("안정도", 22, Color(0.55, 0.57, 0.65))
	stab_cap.position = Vector2(210, 148)
	ui.add_child(stab_cap)

	# 하단 힌트
	hint_label = _make_label("", 30, Color(0.78, 0.8, 0.88))
	hint_label.position = Vector2(0, 1120)
	hint_label.size = Vector2(720, 120)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(hint_label)

	# 빌드 버전 (좌하단) — 캐시 확인용
	var ver := _make_label(GAME_VERSION, 22, Color(0.45, 0.47, 0.55))
	ver.position = Vector2(20, 1234)
	ui.add_child(ver)

	_build_calib_panel()
	_build_over_panel()


func _build_calib_panel() -> void:
	calib_panel = _make_overlay(Color(0.04, 0.045, 0.07, 0.92))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	calib_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	calib_label = _make_label("", 42, Color(0.9, 0.88, 0.8))
	calib_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_centered(calib_label))

	calib_button = Button.new()
	calib_button.text = "센서 켜기 ▶"
	if ui_font:
		calib_button.add_theme_font_override("font", ui_font)
	calib_button.add_theme_font_size_override("font_size", 40)
	calib_button.custom_minimum_size = Vector2(320, 96)
	calib_button.visible = false
	calib_button.pressed.connect(_on_sensor_enable)
	box.add_child(_centered(calib_button))

	ui.add_child(calib_panel)


func _build_over_panel() -> void:
	over_panel = _make_overlay(Color(0.03, 0.03, 0.05, 0.9))
	over_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_panel.add_child(center)
	over_body = VBoxContainer.new()
	over_body.add_theme_constant_override("separation", 16)
	over_body.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(over_body)
	ui.add_child(over_panel)


func _show_game_over() -> void:
	for c in over_body.get_children():
		c.queue_free()

	over_body.add_child(_centered(_make_label("붕괴", 72, Color(0.9, 0.35, 0.32))))
	over_body.add_child(_centered(_make_label(
		"당신도 수많은 욕망의\n잔해 중 하나가 되었습니다.", 34, Color(0.82, 0.8, 0.85))))
	over_body.add_child(_spacer(10))
	over_body.add_child(_centered(_make_label(
		"이번 탑의 높이  %d" % score, 40, Color(0.95, 0.93, 0.8))))
	over_body.add_child(_centered(_make_label(
		"최고 기록  %d" % Graveyard.best, 28, Color(0.6, 0.62, 0.7))))

	# 역대 욕망의 잔해 무덤
	var recent: Array = Graveyard.recent(6)
	if recent.size() > 0:
		over_body.add_child(_spacer(12))
		over_body.add_child(_centered(_make_label(
			"— 역대 욕망의 잔해 —", 24, Color(0.5, 0.5, 0.58))))
		var line := ""
		for h in recent:
			line += "%d   " % int(h)
		over_body.add_child(_centered(_make_label(
			line.strip_edges(), 26, Color(0.55, 0.5, 0.45))))

	over_body.add_child(_spacer(20))
	var retry := Button.new()
	retry.text = "다시 쌓기"
	if ui_font:
		retry.add_theme_font_override("font", ui_font)
	retry.add_theme_font_size_override("font_size", 38)
	retry.custom_minimum_size = Vector2(280, 90)
	retry.pressed.connect(_restart)
	over_body.add_child(_centered(retry))

	over_panel.visible = true


# ---------------------------------------------------------------- UI 헬퍼

func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if ui_font:
		l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_overlay(color: Color) -> Control:
	var panel := ColorRect.new()
	panel.color = color
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _centered(node: Control) -> Control:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if node is Label:
		(node as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(node)
	return box


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
