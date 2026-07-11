extends Node2D
## Babel Tower — 메인 게임 매니저
##
## 핵심 규칙: 기기를 최대한 움직이지 마라.
## 흔들리면 탑이 요동치고, 높이 올라갈수록 작은 떨림도 치명적이 된다.

enum State { CALIB, READY, OVER, SELECT }

## 화면에 표시되는 빌드 버전 — 캐시된 옛 빌드인지 확인용. 변경 시마다 올린다.
const GAME_VERSION := "v3.1 · items"

const BASE_X := 360.0
const GROUND_TOP_Y := 1050.0
const BLOCK_SIZE := Vector2(180.0, 62.0)             # 토대(초석) 크기 · 기준 단위
const DROP_HEIGHT := 150.0          # 다음 블록이 떨어지기 시작하는 높이(짧게 = 연사 쌓기 쾌감)
const MAX_TILT_ANGLE := 0.52        # 최대 기울임에서 바닥(판자)이 기우는 각도(라디안 ~30°)
const FOUNDATION_TOP := GROUND_TOP_Y - BLOCK_SIZE.y   # 토대 윗면 Y (수평일 때)
const TILT_DEADZONE := 0.06         # 이보다 작은 기울기는 무시(미세 손떨림 → 떨림 방지)
const FLOOR_PIVOT := Vector2(BASE_X, GROUND_TOP_Y)    # 바닥 회전 피벗(토대 중심 바닥)
const METERS_PER_PX := 5.0 / BLOCK_SIZE.y            # 실제 높이 → 미터 환산(벽돌 1개 높이 = 5m)
const MILESTONE_M := 50                              # 이 미터마다 돌파 이펙트
const WIND_LOW := 120                                # 이 높이부터 바람 발생
const WIND_HIGH := 600                               # 이 높이 위(성층권)는 무풍
const WIND_ANGLE := 0.13                             # 최대 바람이 바닥을 미는 각도(rad)

var state: int = State.SELECT
var score: int = 0
var blocks: Array[Block] = []
var current_type: Dictionary = {}   # 선택한 블록 타입(벽돌/상자/책상/의자/공)
var peak_px: float = 0.0            # 이번 판에서 도달한 최고 실제 높이(px)
var calib_timer: float = 0.0
var go_shake: float = 0.0           # 붕괴 순간의 카메라 흔들림 버스트
var web_permission_asked := false
var floor_body: AnimatableBody2D    # 센서에 따라 좌우로 움직이는 물리 바닥(+토대)
var aiming := false                 # 손을 대고 위치를 조준 중인가
var aim_x := BASE_X                 # 떨어뜨릴 가로 위치(월드 좌표)
var aim_rot := 0.0                  # 놓을 블록의 회전(두 손가락 탭으로 90°씩)
var drag_start_world := 0.0         # 드래그 시작 지점(상대 이동 기준)
var mod_index := -1                 # 두 번째 손가락(회전)의 터치 인덱스
var mod_start := Vector2.ZERO       # 두 번째 손가락이 처음 닿은 화면 좌표
var mod_moved := false              # 두 번째 손가락이 드래그됐는가(드래그면 회전 안 함)
var gyro_locked := false            # (개발용) 자이로 잠금 — 바닥을 수평 고정
var show_guides := false            # 안정도바·중심선 표시 (기본 숨김)
var last_milestone := 0             # 마지막으로 돌파한 미터 구간
var record_broken := false          # 이번 판에 최고기록을 깼는가
var sky: Control                    # 높이별 하늘 배경
var world_time := 0.0               # 구름/별 애니메이션용 시간
var wind_cur := 0.0                 # 현재 바람 세기(-1..1, 부호=방향)
var wind_target := 0.0              # 목표 바람
var wind_timer := 4.0               # 다음 상태 전환까지
var wind_gusting := false           # 지금 부는 중인가
var bird: Node2D = null             # 현재 날아다니는 새(1마리)
var bird_timer := 8.0               # 다음 새까지
var settling: Block = null          # 착지 대기 중인 낙하 블록 — 닿기 전엔 다음 블록 못 놓음
var settle_time := 0.0              # 낙하 후 경과(안전 타임아웃용)
var wind_fx: Control                # 전경 바람 이펙트(방향/세기 시각화)
var sfx := {}                       # 효과음 플레이어 모음
var amb_wind: AudioStreamPlayer     # 바람 앰비언스(고도에 따라 커짐)

var cam: Camera2D
var ui: CanvasLayer
var height_label: Label
var best_label: Label
var hint_label: Label
var stab_fill: ColorRect
var guides_group: Control
var guide_btn: Button
var gyro_btn: Button
var select_panel: Control
var calib_panel: Control
var calib_label: Label
var calib_button: Button
var awaiting_sensor: bool = false
var over_panel: Control
var over_body: VBoxContainer
var ui_font: Font


func _ready() -> void:
	randomize()
	current_type = BlockTypes.get_type("brick")   # 선택 전 기본값
	_build_environment()
	_build_world()
	_build_ui()
	_build_audio()
	_begin_selection()


func _build_environment() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	sky = load("res://scripts/sky.gd").new()
	bg.add_child(sky)

	# 전경 바람 이펙트 — 월드(탑) 위, UI 아래에 그려진다
	var fg := CanvasLayer.new()
	fg.layer = 1
	add_child(fg)
	wind_fx = load("res://scripts/wind_fx.gd").new()
	fg.add_child(wind_fx)


func _build_audio() -> void:
	for n in ["place", "chirp", "milestone", "record", "collapse"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	amb_wind = AudioStreamPlayer.new()
	amb_wind.stream = load("res://assets/sfx/wind.wav")
	amb_wind.volume_db = -60.0
	amb_wind.finished.connect(func(): amb_wind.play())   # 계속 루프
	add_child(amb_wind)
	amb_wind.play()


func _play(name: String, pitch_var := 0.0) -> void:
	if sfx.has(name):
		var p: AudioStreamPlayer = sfx[name]
		p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
		p.play()


# ---------------------------------------------------------------- 월드 구성

func _build_world() -> void:
	# 센서에 따라 '기우는(경사)' 물리 바닥(판자). 중력은 항상 아래로 고정.
	# 바닥이 기울면 그 위 블록들이 경사 때문에 넘어진다(= 판자를 기울이는 것).
	# 피벗(원점)을 토대 중심 바닥에 두고, 자식들은 그 기준 상대 좌표로 배치한다.
	floor_body = AnimatableBody2D.new()
	floor_body.sync_to_physics = true
	floor_body.position = FLOOR_PIVOT
	var fmat := PhysicsMaterial.new()
	fmat.friction = 1.0
	fmat.bounce = 0.0
	floor_body.physics_material_override = fmat

	# 바닥판 (피벗 아래) — 넓게
	var gcs := CollisionShape2D.new()
	var gshape := RectangleShape2D.new()
	gshape.size = Vector2(4200.0, 200.0)
	gcs.shape = gshape
	gcs.position = Vector2(0, 100.0)
	floor_body.add_child(gcs)
	floor_body.add_child(_make_rect_poly(Vector2(0, 100.0), Vector2(4200.0, 200.0),
		Color(0.34, 0.24, 0.14)))                                  # 흙
	floor_body.add_child(_make_rect_poly(Vector2(0, 8.0), Vector2(4200.0, 18.0),
		Color(0.30, 0.45, 0.18)))                                  # 잔디(윗면)

	# 초석(토대) — 피벗 바로 위, 바닥과 함께 기운다
	var fcs := CollisionShape2D.new()
	var fshape := RectangleShape2D.new()
	fshape.size = BLOCK_SIZE
	fcs.shape = fshape
	fcs.position = Vector2(0, -BLOCK_SIZE.y * 0.5)
	floor_body.add_child(fcs)
	floor_body.add_child(_make_rect_poly(Vector2(0, -BLOCK_SIZE.y * 0.5), BLOCK_SIZE, _brick_color(0)))

	add_child(floor_body)

	# 카메라
	cam = Camera2D.new()
	cam.position = Vector2(BASE_X, GROUND_TOP_Y - 200.0)
	cam.zoom = Vector2.ONE
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()


## 사각형 Polygon2D 생성 헬퍼(중심/크기/색)
func _make_rect_poly(center: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	p.polygon = PackedVector2Array([
		center + Vector2(-hw, -hh), center + Vector2(hw, -hh),
		center + Vector2(hw, hh), center + Vector2(-hw, hh)])
	p.color = color
	return p



func _brick_color(level: int) -> Color:
	# 층마다 미묘하게 색을 달리해 쌓임을 시각적으로 구분
	var base := Color(0.80, 0.73, 0.57)
	var t := fmod(float(level) * 0.13, 1.0)
	return base.lerp(Color(0.62, 0.55, 0.42), t)


# ---------------------------------------------------------------- 게임 흐름

## 시작: 무엇을 쌓을지(블록 타입) 고르는 화면
func _begin_selection() -> void:
	state = State.SELECT
	select_panel.visible = true
	calib_panel.visible = false
	over_panel.visible = false


## 블록 타입 선택 → 보정으로 진행
func _choose_type(id: String) -> void:
	current_type = BlockTypes.get_type(id)
	select_panel.visible = false
	_begin_calibration()


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


## 지정한 가로 위치(at_x) 위에서 선택한 타입의 블록을 떨어뜨린다.
## 이 블록이 닿기 전엔 다음 블록을 못 놓는다. 현재 회전(aim_rot)을 반영한다.
func _drop_block(at_x: float = BASE_X) -> void:
	# 세로는 항상 탑 꼭대기 위에서 낙하 (가로는 손 뗀 위치)
	var sy := _tower_top_edge() - _aim_half_h() - DROP_HEIGHT
	var b := Block.new()
	b.setup(current_type)
	b.position = Vector2(at_x, sy)
	b.rotation = aim_rot
	b.landed.connect(_on_block_landed)
	add_child(b)
	blocks.append(b)
	settling = b            # 이 블록이 바닥/탑에 닿기 전까지 다음 블록을 놓을 수 없다
	settle_time = 0.0
	score += 1


## 현재 블록 크기(bbox)와 회전을 반영한 수직 반높이(낙하 시작 높이 계산용)
func _aim_half_h() -> float:
	var bb: Vector2 = current_type.get("bbox", BLOCK_SIZE)
	return 0.5 * (absf(bb.x * sin(aim_rot)) + absf(bb.y * cos(aim_rot)))


## 회전을 반영한 블록의 실제 윗변 y
func _block_top_y(b: Block) -> float:
	var ext := 0.5 * (absf(b.bbox.x * sin(b.rotation)) + absf(b.bbox.y * cos(b.rotation)))
	return b.position.y - ext


## 놓을 블록을 90° 회전 (두 손가락 탭)
func _rotate_block() -> void:
	aim_rot = fmod(aim_rot + PI * 0.5, TAU)


## (개발용) 자이로 잠금 토글 — 바닥을 수평 고정해 '어디까지 쌓이나' 확인용
func _toggle_gyro_lock() -> void:
	gyro_locked = not gyro_locked
	gyro_btn.text = "자이로 풀기" if gyro_locked else "자이로 잠금"
	gyro_btn.add_theme_color_override("font_color",
		Color(1.0, 0.62, 0.3) if gyro_locked else Color(0.8, 0.82, 0.9))


## 다음 블록을 놓을 수 있는가 (직전 블록이 닿았거나 없으면 가능)
func _can_drop() -> bool:
	return settling == null or not is_instance_valid(settling)


## 안착된 탑의 실제 높이(px) — 낙하 중(미착지)인 블록은 제외
func _height_px() -> float:
	return maxf(0.0, FOUNDATION_TOP - _tower_top_edge())


## 현재 실제 높이(미터)
func _meters() -> int:
	return int(round(_height_px() * METERS_PER_PX))


## 이번 판 최고 도달 높이(미터)
func _peak_meters() -> int:
	return int(round(peak_px * METERS_PER_PX))


## 블록이 바닥/탑에 닿는 순간 — 타격감 + 진행 체크(높이 갱신 반영).
func _on_block_landed() -> void:
	settling = null                     # 닿았다 → 다음 블록 허용
	go_shake = maxf(go_shake, 5.0)
	Input.vibrate_handheld(12)
	_play("place", 0.14)
	_check_progress()


## 높이 미터 구간 돌파 / 최고 기록 갱신 시 이펙트
func _check_progress() -> void:
	var m := _meters()
	if m >= last_milestone + MILESTONE_M:
		last_milestone = (m / MILESTONE_M) * MILESTONE_M
		_popup("%d m 돌파!" % last_milestone, Color(0.45, 0.85, 1.0))
		go_shake = maxf(go_shake, 9.0)
		Input.vibrate_handheld(35)
		_play("milestone")
	var best := Graveyard.best_for(current_type.get("id", "brick"))
	if not record_broken and best > 0 and _peak_meters() > best:
		record_broken = true
		_popup("최고 기록 갱신!", Color(1.0, 0.82, 0.25))
		go_shake = maxf(go_shake, 15.0)
		Input.vibrate_handheld(70)
		_play("record")


## 화면 중앙 상단에 팝업 텍스트를 띄우고 커졌다 사라지게 한다
func _popup(text: String, color: Color) -> void:
	var l := _make_label(text, 62, color)
	l.size = Vector2(720, 100)
	l.position = Vector2(0, 430)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(360, 50)
	l.scale = Vector2(0.5, 0.5)
	ui.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", 360.0, 1.3)
	tw.tween_interval(0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _toggle_guides() -> void:
	show_guides = not show_guides
	guides_group.visible = show_guides
	guide_btn.text = "가이드 끄기" if show_guides else "가이드"


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
	aiming = false
	settling = null
	go_shake = 26.0
	if is_instance_valid(bird):
		bird.queue_free()
	bird = null
	_play("collapse")
	Input.vibrate_handheld(400)         # 붕괴의 햅틱
	Graveyard.add_record(current_type.get("id", "brick"), _peak_meters())
	# 붕괴 장면(줌아웃)을 잠깐 보여준 뒤 결과 화면을 띄운다
	await get_tree().create_timer(1.7).timeout
	if state == State.OVER:             # 그 사이 재시작하지 않았다면
		_show_game_over()


func _restart() -> void:
	for b in blocks:
		if is_instance_valid(b):
			b.queue_free()
	blocks.clear()
	score = 0
	peak_px = 0.0
	aiming = false
	settling = null
	aim_x = BASE_X
	aim_rot = 0.0
	mod_index = -1
	last_milestone = 0
	record_broken = false
	wind_cur = 0.0
	wind_target = 0.0
	wind_gusting = false
	wind_timer = randf_range(4.0, 8.0)
	bird_timer = randf_range(6.0, 10.0)
	if is_instance_valid(bird):
		bird.queue_free()
	bird = null
	cam.offset = Vector2.ZERO
	cam.zoom = Vector2.ONE
	cam.position = Vector2(BASE_X, GROUND_TOP_Y - 200.0)
	if is_instance_valid(floor_body):
		floor_body.rotation = 0.0            # 바닥을 수평으로 (토대는 바닥의 일부라 유지됨)
		floor_body.position = FLOOR_PIVOT

	over_panel.visible = false
	state = State.READY


# ---------------------------------------------------------------- 입력

func _unhandled_input(event: InputEvent) -> void:
	# 어디를 눌러도 벽돌은 '중앙'에서 시작. 누른 지점 기준으로 좌우로 끌면 그만큼 이동,
	# 떼면 낙하. (터치는 emulate_mouse_from_touch로 마우스 이벤트가 된다)
	# 키보드(개발/데스크톱): Space=낙하, R=회전, G=자이로 잠금
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_SPACE:
					if state == State.READY and _can_drop():
						_drop_block(_clamp_aim(BASE_X))
				KEY_R:
					if state == State.READY:
						_rotate_block()
				KEY_G:
					_toggle_gyro_lock()
		return

	# 첫 손가락(또는 마우스): 조준/낙하. (터치는 첫 손가락이 마우스로 에뮬레이션됨)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state == State.READY and _can_drop():
				aiming = true
				drag_start_world = _screen_to_world_x(event.position)
				aim_x = BASE_X                     # 무조건 중앙에서 시작
				aim_rot = 0.0                      # 블록마다 회전은 초기화
				mod_index = -1
		else:  # 손을 뗌 → 그 위치에 낙하
			if aiming and state == State.READY:
				_drop_block(aim_x)
			aiming = false
			mod_index = -1
		return
	if event is InputEventMouseMotion and aiming:
		# 누른 지점 대비 이동량만큼 중앙에서 좌우로
		aim_x = _clamp_aim(BASE_X + _screen_to_world_x(event.position) - drag_start_world)
		return
	# 데스크톱 보조: 우클릭 = 회전
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed and aiming:
		_rotate_block()
		return

	# 두 번째 손가락 탭 = 90° 회전 (크게 드래그하면 오탭으로 보고 회전 안 함)
	if event is InputEventScreenTouch and event.index >= 1:
		if event.pressed:
			if aiming and mod_index == -1:
				mod_index = event.index
				mod_start = event.position
				mod_moved = false
		elif event.index == mod_index:
			if not mod_moved:
				_rotate_block()
			mod_index = -1
		return
	if event is InputEventScreenDrag and event.index == mod_index:
		if event.position.distance_to(mod_start) > 24.0:
			mod_moved = true
		return


func _screen_to_world_x(screen_pos: Vector2) -> float:
	return (get_viewport().get_canvas_transform().affine_inverse() * screen_pos).x


func _clamp_aim(x: float) -> float:
	return clampf(x, BASE_X - 620.0, BASE_X + 620.0)


# ---------------------------------------------------------------- 물리

func _physics_process(delta: float) -> void:
	# 센서 기울기만큼 바닥(판자)을 기울인다(경사). 중력은 항상 아래로 고정.
	# 바닥이 수평이면 블록은 잠들어(sleep) 떨림이 없다. 기울면 경사 때문에 위 블록이 넘어진다.
	var target_angle := 0.0
	if gyro_locked:
		# (개발용) 자이로 잠금: 바닥을 수평 고정하고 바람도 잦아들게 한다
		wind_cur = lerpf(wind_cur, 0.0, 0.1)
	else:
		target_angle = _tilt_amount() * MAX_TILT_ANGLE
		if state == State.READY:
			_update_wind(delta)             # 간헐적 돌풍(고도 구간에서만) → 바닥을 민다
			target_angle += wind_cur * WIND_ANGLE
	if is_instance_valid(floor_body):
		floor_body.rotation = lerpf(floor_body.rotation, target_angle, 0.15)

	if state != State.READY:
		return

	peak_px = maxf(peak_px, _height_px())
	_update_birds(delta)
	_check_collapse()

	# 안전장치: 어떤 이유로든 착지 신호가 안 오면 잠깐 뒤 잠금 해제(소프트락 방지)
	if settling != null:
		if not is_instance_valid(settling):
			settling = null
		else:
			settle_time += delta
			if settle_time > 3.0:
				settling = null


func _update_birds(delta: float) -> void:
	if bird != null:
		# 아직 안 앉았으면(FLY_IN/ROAM/APPROACH) 항상 '현재 꼭대기'로 목표 갱신
		if int(bird.s) <= 2:
			var tb := _top_block()
			if tb != null:
				bird.target_block = tb
		return
	bird_timer -= delta
	if bird_timer <= 0.0:
		_spawn_bird()


func _spawn_bird() -> void:
	bird_timer = randf_range(7.0, 13.0)
	var m := _meters()
	if m < 15 or m > 380:          # 지면 근처·우주엔 새 없음
		return
	var top := _top_block()
	if top == null:
		return
	bird = load("res://scripts/bird.gd").new()
	bird.setup(top, randf() < 0.5)
	bird.left.connect(_on_bird_left)
	add_child(bird)
	_play("chirp", 0.08)


func _on_bird_left() -> void:
	bird = null
	bird_timer = randf_range(7.0, 13.0)


## 간헐적 바람: 잠잠 ↔ 돌풍을 번갈아. 정해진 고도 구간에서만 실제로 분다.
func _update_wind(dt: float) -> void:
	var m := float(_meters())
	var band := 0.0
	if m > WIND_LOW and m < WIND_HIGH:
		band = clampf(minf(m - WIND_LOW, WIND_HIGH - m) / 90.0, 0.0, 1.0)
	wind_timer -= dt
	if wind_timer <= 0.0:
		if wind_gusting:
			wind_gusting = false
			wind_target = 0.0
			wind_timer = randf_range(4.0, 8.0)        # 잠잠한 구간
		else:
			wind_gusting = true
			wind_target = (1.0 if randf() < 0.5 else -1.0) * randf_range(0.55, 1.0)
			wind_timer = randf_range(2.0, 4.5)        # 부는 구간
	wind_cur = lerpf(wind_cur, wind_target * band, 0.05)


## 데드존을 적용한 기울기(작은 손떨림은 무시). -1..1
func _tilt_amount() -> float:
	if state != State.READY:
		return 0.0
	var raw := Motion.get_sway()
	if absf(raw) <= TILT_DEADZONE:
		return 0.0
	return signf(raw) * (absf(raw) - TILT_DEADZONE) / (1.0 - TILT_DEADZONE)


func _check_collapse() -> void:
	# 붕괴 판정 = '블록이 바닥(지면)에 닿음'. 기울어져 있어도 안 떨어졌으면 살아있다.
	# 제대로 쌓인 블록은 토대 위(높은 위치)에 있고, 떨어진 블록만 지면 높이로 내려온다.
	for b in blocks:
		if not is_instance_valid(b):
			continue
		var ext := 0.5 * (absf(b.bbox.x * sin(b.rotation)) + absf(b.bbox.y * cos(b.rotation)))
		if b.position.y + ext > GROUND_TOP_Y - 6.0:
			_game_over()
			return


## 안착된 블록들의 최상단 y (낙하 중인 블록은 제외 → 높이가 튀지 않게)
func _tower_top_edge() -> float:
	var top := FOUNDATION_TOP   # 블록이 없으면 토대 윗면
	for b in blocks:
		if is_instance_valid(b) and b.has_landed():
			top = minf(top, _block_top_y(b))
	return top


## 모든 블록(흩어진 것 포함)의 최상단 y — 붕괴 줌아웃 프레이밍용
func _lowest_top() -> float:
	var top := FOUNDATION_TOP
	for b in blocks:
		if is_instance_valid(b):
			top = minf(top, _block_top_y(b))
	return top


# ---------------------------------------------------------------- 프레임 업데이트

func _process(delta: float) -> void:
	world_time += delta
	if state != State.READY:
		wind_cur = lerpf(wind_cur, 0.0, 0.05)   # 플레이 중이 아니면 바람 잦아듦
	if sky != null:
		sky.meters = float(_meters())
		sky.t = world_time
		sky.wind = wind_cur
	if wind_fx != null:
		wind_fx.wind = wind_cur
	if amb_wind != null:
		var tv := lerpf(-60.0, -13.0, clampf((float(_meters()) - 60.0) / 500.0, 0.0, 1.0))
		amb_wind.volume_db = lerpf(amb_wind.volume_db, tv, 0.04)
	_update_camera(delta)
	_update_ui(delta)
	queue_redraw()  # 낙하 위치/중심 가이드 갱신


## 월드 좌표에 그리는 가이드 (블록 뒤에 렌더링된다)
func _draw() -> void:
	if state != State.READY:
		return
	var top_edge := _tower_top_edge()

	# 최고 기록 라인 (해당 블록 타입의 최고 높이) — 이 선을 넘으면 기록 갱신 이펙트
	var best_m := Graveyard.best_for(current_type.get("id", "brick"))
	if best_m > 0:
		var ry := FOUNDATION_TOP - float(best_m) / METERS_PER_PX
		draw_dashed_line(Vector2(BASE_X - 420, ry), Vector2(BASE_X + 420, ry),
			Color(1.0, 0.82, 0.3, 0.5), 3.0, 22.0)
		if ui_font:
			draw_string(ui_font, Vector2(BASE_X - 400, ry - 14), "최고 기록 %d m" % best_m,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.82, 0.3, 0.7))

	# 중심(원위치) 세로 기준선 — 가이드 켤 때만
	if show_guides:
		draw_dashed_line(
			Vector2(BASE_X, top_edge - DROP_HEIGHT - 80.0),
			Vector2(BASE_X, GROUND_TOP_Y + 40.0),
			Color(0.55, 0.6, 0.75, 0.28), 2.0, 14.0)

	# 2) 조준 중일 때만: 회전을 반영한 실제 블록 모양 고스트 + 바닥까지 내려가는 낙하 컬럼
	if aiming:
		var half_h := _aim_half_h()
		var center := Vector2(aim_x, top_edge - half_h - DROP_HEIGHT)
		var fill := Color(0.98, 0.92, 0.55, 0.18)
		var edge := Color(0.98, 0.92, 0.55, 0.75)
		draw_set_transform(center, aim_rot, Vector2.ONE)
		for p in current_type.get("parts", []):
			if p["kind"] == "rect":
				draw_rect(p["rect"], fill)
				draw_rect(p["rect"], edge, false, 2.5)
			else:
				draw_circle(p["pos"], p["r"], fill)
				draw_circle(p["pos"], p["r"], edge, false, 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_dashed_line(
			Vector2(aim_x, center.y + half_h),
			Vector2(aim_x, GROUND_TOP_Y),
			Color(0.98, 0.92, 0.55, 0.5), 2.0, 12.0)


func _update_camera(delta: float) -> void:
	var target: Vector2
	var z: float
	if state == State.OVER:
		# 붕괴 시: 지면~꼭대기 전체가 보이도록 줌아웃 (무너지는 걸 다 볼 수 있게)
		var tower_top_y := minf(_lowest_top(), GROUND_TOP_Y - 200.0)
		var mid_y := (GROUND_TOP_Y + tower_top_y) * 0.5
		var needed := (GROUND_TOP_Y - tower_top_y) + 700.0   # 여백 포함 높이
		z = clampf(1280.0 / needed, 0.16, 1.0)
		target = Vector2(BASE_X, mid_y)
	elif state == State.CALIB or state == State.SELECT:
		target = Vector2(BASE_X, GROUND_TOP_Y - 200.0)
		z = 1.0
	else:
		target = Vector2(BASE_X, _tower_top_edge() - 200.0)
		# 높이 오를수록 줌아웃 → 작은 떨림도 크게 보이는 "공포" 시스템
		z = clampf(1.0 - float(score) * 0.03, 0.42, 1.0)
	cam.position = cam.position.lerp(target, 0.09)
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 0.06)

	# 카메라 셰이크는 '붕괴 순간'에만. (예전엔 센서 움직임에 반응해 화면이 위아래로
	# 떨렸는데 그게 위아래 떨림의 원인이었다 — 제거)
	go_shake = maxf(0.0, go_shake - delta * 45.0)
	var amp := go_shake
	cam.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))


func _update_ui(delta: float) -> void:
	height_label.text = "%d m" % _meters()
	best_label.text = "최고 %d m" % maxi(Graveyard.best_for(current_type.get("id", "brick")), _peak_meters())

	if show_guides:
		# 안정도 = 얼마나 수평인가. 기울일수록 빨갛게.
		var inst := clampf(absf(Motion.get_sway()) * 1.1, 0.0, 1.0)
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
			hint_label.text = "끌어서 위치 정하고 떼면 낙하 · 두 손가락 탭 = 90° 회전\n기기를 수평으로 — 기울이면 바닥이 움직여 탑이 쏠립니다"
		State.OVER:
			hint_label.text = ""
		State.SELECT:
			hint_label.text = ""


# ---------------------------------------------------------------- UI 구성

func _build_ui() -> void:
	# 한글 글리프가 포함된 폰트 (기본 폰트엔 한글이 없어 '두부'로 깨진다)
	ui_font = load("res://fonts/NanumGothic-Regular.ttf")

	ui = CanvasLayer.new()
	ui.layer = 5                     # 전경 바람 이펙트(layer 1)보다 위에 UI가 오도록
	add_child(ui)

	# 현재 높이 (미터) — 좌상단, 크게
	height_label = _make_label("0 m", 58, Color(0.97, 0.95, 0.86))
	height_label.position = Vector2(40, 40)
	ui.add_child(height_label)

	# 최고 기록 (미터) — 우상단
	best_label = _make_label("최고 0 m", 30, Color(0.82, 0.7, 0.35))
	best_label.position = Vector2(380, 56)
	best_label.size = Vector2(300, 40)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(best_label)

	# 안정도·중심선 묶음 (기본 숨김, 버튼으로 토글)
	guides_group = Control.new()
	guides_group.set_anchors_preset(Control.PRESET_FULL_RECT)
	guides_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guides_group.visible = show_guides
	ui.add_child(guides_group)
	var stab_bg := ColorRect.new()
	stab_bg.color = Color(0.16, 0.17, 0.22)
	stab_bg.position = Vector2(210, 132)
	stab_bg.size = Vector2(300, 16)
	guides_group.add_child(stab_bg)
	stab_fill = ColorRect.new()
	stab_fill.color = Color(0.32, 0.85, 0.45)
	stab_fill.position = Vector2(210, 132)
	stab_fill.size = Vector2(300, 16)
	guides_group.add_child(stab_fill)
	var stab_cap := _make_label("안정도", 22, Color(0.55, 0.57, 0.65))
	stab_cap.position = Vector2(210, 150)
	guides_group.add_child(stab_cap)

	# 가이드 on/off 토글 버튼 (우상단)
	guide_btn = Button.new()
	guide_btn.text = "가이드"
	guide_btn.add_theme_font_override("font", ui_font)
	guide_btn.add_theme_font_size_override("font_size", 24)
	guide_btn.position = Vector2(548, 108)
	guide_btn.size = Vector2(132, 52)
	guide_btn.focus_mode = Control.FOCUS_NONE
	guide_btn.pressed.connect(_toggle_guides)
	ui.add_child(guide_btn)

	# (개발용) 자이로 잠금 토글 — 가이드 버튼 아래
	gyro_btn = Button.new()
	gyro_btn.text = "자이로 잠금"
	gyro_btn.add_theme_font_override("font", ui_font)
	gyro_btn.add_theme_font_size_override("font_size", 22)
	gyro_btn.position = Vector2(508, 168)
	gyro_btn.custom_minimum_size = Vector2(172, 48)
	gyro_btn.focus_mode = Control.FOCUS_NONE
	gyro_btn.pressed.connect(_toggle_gyro_lock)
	ui.add_child(gyro_btn)

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

	_build_select_panel()
	_build_calib_panel()
	_build_over_panel()


## 블록 선택 화면 — 실생활 물품 타일 중 하나를 골라 시작
func _build_select_panel() -> void:
	select_panel = _make_overlay(Color(0.04, 0.05, 0.08, 0.97))
	select_panel.mouse_filter = Control.MOUSE_FILTER_STOP    # 뒤 입력 차단
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	select_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	box.add_child(_centered(_make_label("무엇을 쌓을까요?", 50, Color(0.95, 0.92, 0.82))))
	box.add_child(_centered(_make_label(
		"블록마다 난이도와 최고 기록이 따로 관리됩니다", 26, Color(0.6, 0.63, 0.72))))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	box.add_child(_centered(grid))
	for t in BlockTypes.all():
		grid.add_child(_make_type_tile(t))
	ui.add_child(select_panel)


## 선택 타일: 위에 미니 미리보기, 아래 이름. 누르면 그 타입으로 시작.
func _make_type_tile(t: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(212, 172)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_choose_type.bind(t["id"]))
	var icon := load("res://scripts/type_icon.gd").new()
	icon.type_def = t
	icon.position = Vector2(46, 14)
	icon.size = Vector2(120, 112)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var lb := _make_label(t["name"], 30, Color(0.93, 0.9, 0.82))
	lb.position = Vector2(0, 126)
	lb.size = Vector2(212, 40)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lb)
	return b


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

	var tid: String = current_type.get("id", "brick")
	var tname: String = current_type.get("name", "블록")
	over_body.add_child(_centered(_make_label("붕괴", 72, Color(0.9, 0.35, 0.32))))
	over_body.add_child(_centered(_make_label(
		"당신도 수많은 욕망의\n잔해 중 하나가 되었습니다.", 34, Color(0.82, 0.8, 0.85))))
	over_body.add_child(_spacer(10))
	over_body.add_child(_centered(_make_label(
		"[%s] 이번 높이  %d m" % [tname, _peak_meters()], 40, Color(0.95, 0.93, 0.8))))
	over_body.add_child(_centered(_make_label(
		"이 블록 최고 기록  %d m" % Graveyard.best_for(tid), 28, Color(0.6, 0.62, 0.7))))

	# 역대 욕망의 잔해 무덤 (이 블록 타입)
	var recent: Array = Graveyard.recent(tid, 6)
	if recent.size() > 0:
		over_body.add_child(_spacer(12))
		over_body.add_child(_centered(_make_label(
			"— 역대 %s 잔해 —" % tname, 24, Color(0.5, 0.5, 0.58))))
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

	# 블록 바꾸기 — 선택 화면으로
	var change := Button.new()
	change.text = "블록 바꾸기"
	if ui_font:
		change.add_theme_font_override("font", ui_font)
	change.add_theme_font_size_override("font_size", 30)
	change.custom_minimum_size = Vector2(280, 72)
	change.focus_mode = Control.FOCUS_NONE
	change.pressed.connect(_restart_to_select)
	over_body.add_child(_centered(change))

	over_panel.visible = true


## 붕괴 화면에서 '블록 바꾸기' → 판을 리셋하고 선택 화면으로
func _restart_to_select() -> void:
	_restart()
	_begin_selection()


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
