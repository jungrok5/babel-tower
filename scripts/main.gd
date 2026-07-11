extends Node2D
## Babel Tower — 메인 게임 매니저
##
## 핵심 규칙: 기기를 최대한 움직이지 마라.
## 흔들리면 탑이 요동치고, 높이 올라갈수록 작은 떨림도 치명적이 된다.

enum State { CALIB, READY, OVER, SELECT, TUTORIAL }

## 화면에 표시되는 빌드 버전 — 캐시된 옛 빌드인지 확인용. 변경 시마다 올린다.
const GAME_VERSION := "v3.5"
const ROTATE_STEP := PI * 0.25       # 두 손가락 탭 1회 = 45°

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
var inspect := false                # (개발용) 관찰 카메라 — 안정화 + 자유 시점(탑 전체 보기)
var inspect_pan := Vector2.ZERO     # 관찰 모드 카메라 이동
var last_milestone := 0             # 마지막으로 돌파한 미터 구간
var record_broken := false          # 이번 판에 최고기록을 깼는가(갱신 팝업용)
var record_saved := false           # 이번 판 기록 캡처 완료
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
var ingame_ui: Control               # 인게임 상단/개발 버튼 묶음
var pause_btn: Button
var inspect_btn: Button
var pause_panel: Control             # 일시정지 메뉴
var select_panel: Control
var tutorial: Control                # 손 모양 조작 튜토리얼 오버레이
var tut_from_select := false         # 선택화면 '조작법'으로 열었는가(끝나면 선택화면 복귀)
var lb_panel: Control                # 랭킹(리더보드) 오버레이
var lb_rows: VBoxContainer           # 랭킹 행 목록
var lb_title: Label
var lb_view := 0                     # 랭킹에서 보고 있는 블록 타입 인덱스
var lb_icon: Control                 # 랭킹 헤더의 블록 미리보기 아이콘
var settings_panel: Control          # 설정 오버레이
var settings_body: VBoxContainer     # 설정 항목 목록
var lang_panel: Control              # 언어 선택 오버레이
var lang_rows: VBoxContainer         # 언어 목록
var lang_search: LineEdit            # 언어 검색창
var record_img: Image = null         # 최고기록 갱신 순간의 스크린샷
var _want_capture := false           # 다음 프레임에 기록 스크린샷 캡처
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
	if not Settings.sound_on:
		return
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
	floor_body.add_child(_make_rect_poly(Vector2(0, 1000.0), Vector2(4200.0, 2000.0),
		Color(0.34, 0.24, 0.14)))                                  # 흙(줌아웃에도 하늘 안 비치게 깊게)
	floor_body.add_child(_make_rect_poly(Vector2(0, 22.0), Vector2(4200.0, 26.0),
		Color(0.26, 0.40, 0.16)))                                  # 잔디 아래 진한 경계
	floor_body.add_child(_make_rect_poly(Vector2(0, 6.0), Vector2(4200.0, 14.0),
		Color(0.36, 0.56, 0.22)))                                  # 잔디(윗면, 밝게)

	# 초석(제단/기단) — 피벗 바로 위, 바닥과 함께 기운다. 블록이 아니라 '쌓는 받침대'로 보이게
	# 돌 제단처럼 그린다(창세기/바벨 테마). 충돌은 안정적인 사각형 유지.
	var fcs := CollisionShape2D.new()
	var fshape := RectangleShape2D.new()
	fshape.size = BLOCK_SIZE
	fcs.shape = fshape
	fcs.position = Vector2(0, -BLOCK_SIZE.y * 0.5)
	floor_body.add_child(fcs)
	_build_pedestal(floor_body)
	_build_ground_decor(floor_body)

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


## 돌 제단(기단) 비주얼 — '블록'이 아니라 쌓아 올리는 받침대로 보이게. (충돌은 별도 사각형)
func _build_pedestal(parent: Node) -> void:
	var foot := Color(0.30, 0.29, 0.34)
	var body := Color(0.40, 0.39, 0.45)
	var cap := Color(0.50, 0.49, 0.55)
	parent.add_child(_make_rect_poly(Vector2(0, -10.0), Vector2(232, 24), foot))   # 기단(맨 아래, 넓게)
	parent.add_child(_make_rect_poly(Vector2(0, -33.0), Vector2(188, 50), body))   # 몸통
	parent.add_child(_make_rect_poly(Vector2(-45.0, -33.0), Vector2(3, 50), body.darkened(0.25)))  # 이음새
	parent.add_child(_make_rect_poly(Vector2(45.0, -33.0), Vector2(3, 50), body.darkened(0.25)))
	parent.add_child(_make_rect_poly(Vector2(0, -59.0), Vector2(206, 16), cap))    # 윗판(블록 올리는 면)
	parent.add_child(_make_rect_poly(Vector2(0, -65.0), Vector2(206, 4), cap.lightened(0.18)))  # 윗면 하이라이트


## 카툰 지면 장식 — 잔디 포기·덤불·바위 (바닥과 함께 기운다). 제단 주변을 채워 완성도↑
func _build_ground_decor(parent: Node) -> void:
	var leaf := Color(0.34, 0.58, 0.24)
	var leaf_hi := Color(0.46, 0.70, 0.30)
	var rock := Color(0.55, 0.56, 0.63)
	# 덤불 — 원 뭉치(제단 양옆 멀찍이)
	for bx in [-300.0, 320.0]:
		for o in [Vector2(-26, -4), Vector2(26, -4), Vector2(0, -22), Vector2(-48, 2), Vector2(48, 2)]:
			parent.add_child(_make_circle_poly(Vector2(bx, -14) + o, 26.0, leaf))
		parent.add_child(_make_circle_poly(Vector2(bx - 10, -30), 15.0, leaf_hi))
	# 바위 — 둥근 육각 돌덩이
	for rx in [-190.0, 230.0]:
		parent.add_child(_make_circle_poly(Vector2(rx, -10), 22.0, rock, 6))
		parent.add_child(_make_circle_poly(Vector2(rx - 6, -16), 9.0, rock.lightened(0.18), 6))
	# 잔디 포기 — 뾰족한 삼각 잎(지면 윗면을 따라 흩뿌림)
	var xs := [-460.0, -360.0, -120.0, -70.0, 90.0, 150.0, 400.0, 470.0]
	for gx in xs:
		_add_grass_tuft(parent, gx, leaf, leaf_hi)


## 원을 근사한 Polygon2D (덤불·바위용). seg=꼭짓점 수(작을수록 각진 돌).
func _make_circle_poly(center: Vector2, r: float, color: Color, seg: int = 16) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	p.polygon = pts
	p.color = color
	return p


## 잔디 한 포기 — 뾰족한 잎 세 갈래
func _add_grass_tuft(parent: Node, x: float, col: Color, hi: Color) -> void:
	var base_y := 2.0
	for dx in [-9.0, 0.0, 9.0]:
		var blade := Polygon2D.new()
		var tip := Vector2(x + dx * 1.6, base_y - 26.0 - absf(dx) * 0.4)
		blade.polygon = PackedVector2Array([
			Vector2(x + dx - 5, base_y), Vector2(x + dx + 5, base_y), tip])
		blade.color = hi if dx == 0.0 else col
		parent.add_child(blade)


# ---------------------------------------------------------------- 게임 흐름

## 시작: 무엇을 쌓을지(블록 타입) 고르는 화면
func _begin_selection() -> void:
	state = State.SELECT
	select_panel.visible = true
	calib_panel.visible = false
	over_panel.visible = false


## 블록 타입 선택 → 보정으로 진행 (첫 조작법 튜토리얼은 보정 완료 후 뜬다)
func _choose_type(id: String) -> void:
	current_type = BlockTypes.get_type(id)
	select_panel.visible = false
	_begin_calibration()


## 설정에서 '조작법 다시 보기'
func _replay_tutorial() -> void:
	tut_from_select = true
	_begin_tutorial()


## 손 모양 조작 튜토리얼을 띄운다
func _begin_tutorial() -> void:
	state = State.TUTORIAL
	select_panel.visible = false
	calib_panel.visible = false
	over_panel.visible = false
	if tutorial == null:
		tutorial = load("res://scripts/tutorial.gd").new()
		tutorial.setup(ui_font)
		tutorial.finished.connect(_on_tutorial_done)
		ui.add_child(tutorial)
	ui.move_child(tutorial, ui.get_child_count() - 1)
	tutorial.visible = true


## 튜토리얼 종료. dont_show=true면 다시 안 봄. 보정 후 튜토리얼이면 바로 플레이.
func _on_tutorial_done(dont_show: bool) -> void:
	if tutorial != null:
		tutorial.visible = false
	if dont_show:
		Graveyard.set_tutorial_seen()
	if tut_from_select:
		tut_from_select = false
		if settings_panel != null and is_instance_valid(settings_panel):
			settings_panel.visible = true    # 설정에서 열었으면 설정으로 복귀
	else:
		state = State.READY


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


## 놓을 블록을 45° 회전 (두 손가락 탭)
func _rotate_block() -> void:
	aim_rot = fmod(aim_rot + ROTATE_STEP, TAU)


## (개발용) 관찰 카메라 토글 — 바닥을 수평 고정(안정화)하고 탑 전체를 자유롭게 본다.
func _toggle_inspect() -> void:
	inspect = not inspect
	inspect_pan = Vector2.ZERO
	if inspect_btn != null:
		inspect_btn.modulate = Color(1.0, 0.7, 0.3, 0.95) if inspect else Color(1, 1, 1, 0.5)


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
	_vibe(12)
	_play("place", 0.14)
	_check_progress()


## 높이 미터 구간 돌파 / 최고 기록 갱신 시 이펙트
func _check_progress() -> void:
	var m := _meters()
	if m >= last_milestone + MILESTONE_M:
		last_milestone = (m / MILESTONE_M) * MILESTONE_M
		_popup(Locale.t("milestone") % last_milestone, Color(0.45, 0.85, 1.0))
		go_shake = maxf(go_shake, 9.0)
		_vibe(35)
		_play("milestone")
	# 자기 최고 높이를 넘으면(첫 판 포함) 그 순간을 캡처해 결과 공유에 쓴다.
	var best := Graveyard.best_for(current_type.get("id", "brick"))
	if not record_saved and _peak_meters() > best:
		record_saved = true
		_want_capture = true            # 이 순간 스크린샷 캡처(다음 프레임)
		if best > 0:                    # 기존 기록이 있었을 때만 '갱신' 이펙트
			record_broken = true
			_popup(Locale.t("record_break"), Color(1.0, 0.82, 0.25))
			go_shake = maxf(go_shake, 15.0)
			_vibe(70)
			_play("record")


## 진동(설정에 따라 켜짐/꺼짐)
func _vibe(ms: int) -> void:
	if Settings.haptic_on:
		Input.vibrate_handheld(ms)


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
	_vibe(400)                          # 붕괴의 햅틱
	Graveyard.add_record(current_type.get("id", "brick"), _peak_meters())
	# 완전히 다 무너지는 장면(줌아웃)을 끝까지 보여준 뒤 결과 화면을 띄운다
	await _wait_collapse_settled()
	if state == State.OVER:             # 그 사이 재시작하지 않았다면
		_show_game_over()


## 블록들이 다 무너져 대부분 멈출 때까지(최대 5초) 기다린다
func _wait_collapse_settled() -> void:
	var frames := 0
	var still_for := 0
	while state == State.OVER and frames < 600:      # 최대 ~5초
		await get_tree().physics_frame
		frames += 1
		if frames < 36:
			continue
		var moving := false
		for b in blocks:
			if is_instance_valid(b) and b is RigidBody2D and b.linear_velocity.length() > 24.0:
				moving = true
				break
		still_for = still_for + 1 if not moving else 0
		if still_for > 42:                            # ~0.35초 정지 유지되면 종료
			break


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
	record_saved = false
	record_img = null
	_want_capture = false
	inspect = false
	inspect_pan = Vector2.ZERO
	if inspect_btn != null:
		inspect_btn.modulate = Color(1, 1, 1, 0.5)
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
	# 키보드(개발/데스크톱): Space=낙하, R=회전, G=관찰 카메라
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_SPACE:
					if state == State.READY and _can_drop() and not inspect:
						_drop_block(_clamp_aim(BASE_X))
				KEY_R:
					if state == State.READY:
						_rotate_block()
				KEY_G:
					_toggle_inspect()
		return

	# 관찰 모드: 드래그로 카메라를 자유롭게 이동(탑 상단 확인). 낙하/조준 없음.
	if inspect:
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			inspect_pan += event.relative / cam.zoom.x
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
	if inspect:
		# (개발용) 관찰 모드: 바닥을 수평 고정하고 바람도 잦아들게 한다(안정화)
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
	if not inspect:                          # 관찰 중엔 붕괴 판정 안 함(자유롭게 보기)
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
	# 붕괴 판정 = '블록이 지면(흙 윗면)에 닿음'. 기울어져 있어도 안 떨어졌으면 살아있다.
	# 중요: 바닥(토대)이 통째로 기울면 그 위 블록도 함께 기운다. 이때 '세계 기준 수평선'과
	# 블록의 '절대 회전'으로 판정하면, 멀쩡히 토대에 얹힌 블록도 죽는 오판이 난다.
	# → 기울어진 '바닥 로컬 좌표'에서, 바닥에 대한 '상대 회전'으로 최저점을 계산한다.
	# 바닥 피벗(FLOOR_PIVOT)이 지면 윗면이므로 로컬 y=0이 지면. 얹힌 블록은 음수(위)로 유지된다.
	if not is_instance_valid(floor_body):
		return
	var floor_rot := floor_body.global_rotation
	for b in blocks:
		if not is_instance_valid(b):
			continue
		var lp := floor_body.to_local(b.global_position)          # 기울어진 바닥 기준 좌표
		var rel := b.global_rotation - floor_rot                   # 바닥에 대한 상대 회전(얹힌 블록 ≈ 0)
		var ext := 0.5 * (absf(b.bbox.x * sin(rel)) + absf(b.bbox.y * cos(rel)))
		if lp.y + ext > -6.0:                                      # 최저점이 지면(로컬 y=0)에 닿음
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
		var tv := -80.0
		if Settings.sound_on:
			tv = lerpf(-60.0, -13.0, clampf((float(_meters()) - 60.0) / 500.0, 0.0, 1.0))
		amb_wind.volume_db = lerpf(amb_wind.volume_db, tv, 0.04)
	_update_camera(delta)
	_update_ui(delta)
	queue_redraw()  # 낙하 위치/중심 가이드 갱신
	if _want_capture:
		_want_capture = false
		_capture_record()


## 최고기록 순간의 화면을 이미지로 저장(끝나고 공유용)
func _capture_record() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		record_img = img


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
			draw_string(ui_font, Vector2(BASE_X - 400, ry - 14), "%s %d m" % [Locale.t("best_short"), best_m],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.82, 0.3, 0.7))

	# 2) 조준 중일 때만: 회전을 반영한 실제 블록 모양 고스트 + 바닥까지 내려가는 낙하 컬럼
	if aiming:
		var half_h := _aim_half_h()
		var center := Vector2(aim_x, top_edge - half_h - DROP_HEIGHT)
		var fill := Color(0.98, 0.92, 0.55, 0.18)
		var edge := Color(0.98, 0.92, 0.55, 0.75)
		draw_set_transform(center, aim_rot, Vector2.ONE)
		for p in current_type.get("parts", []):
			match p["kind"]:
				"rect":
					draw_rect(p["rect"], fill)
					draw_rect(p["rect"], edge, false, 2.5)
				"circle":
					draw_circle(p["pos"], p["r"], fill)
					draw_circle(p["pos"], p["r"], edge, false, 2.5)
				"poly":
					draw_colored_polygon(p["pts"], fill)
					var n: int = p["pts"].size()
					for i in n:
						draw_line(p["pts"][i], p["pts"][(i + 1) % n], edge, 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_dashed_line(
			Vector2(aim_x, center.y + half_h),
			Vector2(aim_x, GROUND_TOP_Y),
			Color(0.98, 0.92, 0.55, 0.5), 2.0, 12.0)


func _update_camera(delta: float) -> void:
	var target: Vector2
	var z: float
	if inspect and state == State.READY:
		# (개발용) 관찰: 지면~꼭대기 전체를 담고, 드래그 이동(inspect_pan) 반영
		var tower_top_y := minf(_lowest_top(), GROUND_TOP_Y - 300.0)
		var mid_y := (GROUND_TOP_Y + tower_top_y) * 0.5
		var needed := (GROUND_TOP_Y - tower_top_y) + 400.0
		z = clampf(1280.0 / needed, 0.08, 1.0)
		target = Vector2(BASE_X, mid_y) + inspect_pan
	elif state == State.OVER:
		# 붕괴 시: 지면~꼭대기 전체가 보이도록 줌아웃 (무너지는 걸 다 볼 수 있게)
		var tower_top_y := minf(_lowest_top(), GROUND_TOP_Y - 200.0)
		var mid_y := (GROUND_TOP_Y + tower_top_y) * 0.5
		var needed := (GROUND_TOP_Y - tower_top_y) + 700.0   # 여백 포함 높이
		z = clampf(1280.0 / needed, 0.16, 1.0)
		target = Vector2(BASE_X, mid_y)
	elif state == State.CALIB or state == State.SELECT or state == State.TUTORIAL:
		target = Vector2(BASE_X, GROUND_TOP_Y - 200.0)
		z = 1.0
	else:
		target = Vector2(BASE_X, _tower_top_edge() - 200.0)
		# 높이 오를수록 줌아웃 → 작은 떨림도 크게 보이는 "공포" 시스템
		z = clampf(1.0 - float(score) * 0.03, 0.42, 1.0)
	var lerp_amt := 0.16 if inspect else 0.09
	cam.position = cam.position.lerp(target, lerp_amt)
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 0.06)

	# 카메라 셰이크는 '붕괴 순간'에만. (예전엔 센서 움직임에 반응해 화면이 위아래로
	# 떨렸는데 그게 위아래 떨림의 원인이었다 — 제거)
	go_shake = maxf(0.0, go_shake - delta * 45.0)
	var amp := go_shake
	cam.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))


func _update_ui(delta: float) -> void:
	# 인게임 HUD는 플레이(READY) 중에만 보인다
	var playing := state == State.READY
	height_label.visible = playing
	best_label.visible = playing
	ingame_ui.visible = playing
	if playing:
		height_label.text = "%d m" % _meters()
		best_label.text = "%s %d m" % [Locale.t("best_short"),
			maxi(Graveyard.best_for(current_type.get("id", "brick")), _peak_meters())]

	if state == State.CALIB:
		if awaiting_sensor:
			calib_label.text = Locale.t("sensor_prompt")
		else:
			calib_timer -= delta
			calib_label.text = Locale.t("calib_wait")
			if not Motion.is_calibrating():
				calib_panel.visible = false
				# 보정 완료 → 첫 플레이면 조작법 튜토리얼, 아니면 바로 시작
				if not Graveyard.tutorial_seen:
					tut_from_select = false
					_begin_tutorial()
				else:
					state = State.READY


# ---------------------------------------------------------------- UI 구성

func _build_ui() -> void:
	# 다국어 폰트: Pretendard(라틴/한글/키릴) + 시스템 폰트 폴백(CJK/데바나가리/태국/아랍 등).
	# 100개국 대비 — 없는 글리프는 기기 시스템 폰트로 자동 대체. (완전 보장은 추후 Noto 번들)
	var pre: FontFile = load("res://fonts/Pretendard-Regular.otf")
	var sysfb := SystemFont.new()
	sysfb.font_names = PackedStringArray([
		"Noto Sans CJK KR", "Noto Sans CJK JP", "Noto Sans CJK SC", "Noto Sans JP",
		"Noto Sans", "Noto Sans Devanagari", "Noto Sans Thai", "Noto Sans Arabic",
		"Arial Unicode MS", "sans-serif"])
	sysfb.allow_system_fallback = true
	pre.fallbacks = [sysfb]
	ui_font = pre

	ui = CanvasLayer.new()
	ui.layer = 5                     # 전경 바람 이펙트(layer 1)보다 위에 UI가 오도록
	ui.process_mode = Node.PROCESS_MODE_ALWAYS   # 일시정지 중에도 메뉴 동작
	add_child(ui)

	# 현재 높이 (미터) — 좌상단, 크게
	height_label = _make_label("0 m", 58, Color(0.97, 0.95, 0.86))
	height_label.position = Vector2(40, 40)
	ui.add_child(height_label)

	# 최고 기록 (미터) — 우상단
	best_label = _make_label("", 28, Color(0.82, 0.7, 0.35))
	best_label.position = Vector2(360, 52)
	best_label.size = Vector2(236, 40)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(best_label)

	# 인게임 상단 버튼 그룹 (플레이 중에만 보임)
	ingame_ui = Control.new()
	ingame_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ingame_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(ingame_ui)
	# 메뉴(일시정지) 버튼 — 우상단
	pause_btn = _make_text_button("=", 34, Vector2(64, 60), _open_pause)
	pause_btn.position = Vector2(614, 44)
	ingame_ui.add_child(pause_btn)
	# (개발용) 관찰 카메라 토글 — 좌하단, 작고 은은하게
	inspect_btn = _make_text_button("DEV", 20, Vector2(84, 46), _toggle_inspect)
	inspect_btn.position = Vector2(20, 1174)
	inspect_btn.modulate = Color(1, 1, 1, 0.5)
	ingame_ui.add_child(inspect_btn)

	_build_select_panel()
	_build_leaderboard_panel()
	_build_settings_panel()
	_build_language_panel()
	_build_pause_panel()
	_build_calib_panel()
	_build_over_panel()


## 블록 선택 화면 — 실생활 물품 타일 중 하나를 골라 시작
func _build_select_panel() -> void:
	select_panel = _make_overlay(Color(0.06, 0.07, 0.11, 1.0))
	select_panel.mouse_filter = Control.MOUSE_FILTER_STOP    # 뒤 입력 차단
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	select_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var emblem: Control = load("res://scripts/emblem.gd").new()
	emblem.custom_minimum_size = Vector2(210, 150)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_centered(emblem))
	box.add_child(_centered(_make_label("GENESIS 11", 40, Color(0.86, 0.78, 0.55))))
	box.add_child(_centered(_make_label(Locale.t("select_title"), 32, Color(0.9, 0.9, 0.82))))
	box.add_child(_centered(_make_label(Locale.t("select_sub"), 24, Color(0.6, 0.63, 0.72))))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	box.add_child(_centered(grid))
	for t in BlockTypes.all():
		grid.add_child(_make_type_tile(t))
	box.add_child(_spacer(2))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	actions.add_child(_make_text_button(Locale.t("view_leaderboard"), 28, Vector2(220, 64), _open_leaderboard))
	actions.add_child(_make_text_button(Locale.t("settings"), 28, Vector2(180, 64), _open_settings))
	box.add_child(_centered(actions))
	box.add_child(_spacer(2))
	var ver := _make_label(GAME_VERSION, 20, Color(0.4, 0.42, 0.5))
	box.add_child(_centered(ver))
	ui.add_child(select_panel)


## 선택 타일: 위에 미니 미리보기, 아래 이름. 누르면 그 타입으로 시작.
func _make_type_tile(t: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(212, 172)
	b.focus_mode = Control.FOCUS_NONE
	_style_button(b, Color(0.11, 0.13, 0.18), Color(0.32, 0.37, 0.48))
	b.pressed.connect(_choose_type.bind(t["id"]))
	var icon: Control = load("res://scripts/type_icon.gd").new()
	icon.type_def = t
	icon.position = Vector2(46, 14)
	icon.size = Vector2(120, 112)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var lb := _make_label(_type_name(t), 28, Color(0.93, 0.9, 0.82))
	lb.position = Vector2(0, 126)
	lb.size = Vector2(212, 40)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lb)
	return b


## 블록 타입의 표시 이름.
## 우선순위: i18n 키(번역이 있으면) → 원본 name → 빈 문자열(아이콘만).
## 이름은 선택 사항이라, 번역 없는(예: 유저가 등록한) 블록은 아이콘만으로도 동작한다.
func _type_name(t: Dictionary) -> String:
	var key: String = str(t.get("i18n", ""))
	if key != "":
		var s := Locale.t(key)
		if s != key:
			return s
	return str(t.get("name", ""))


# ---------------------------------------------------------------- 랭킹(리더보드)

## 인게임 랭킹 화면. 지금은 목업 데이터, 나중에 Google Play Games에서 받아 채운다.
func _build_leaderboard_panel() -> void:
	lb_panel = _make_overlay(Color(0.06, 0.07, 0.11, 1.0))
	lb_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	lb_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	lb_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(640, 0)
	center.add_child(box)

	# 헤더: <  [블록아이콘] 랭킹·이름  >
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 12)
	header.add_child(_make_text_button("<", 40, Vector2(64, 66), _lb_prev))
	lb_icon = load("res://scripts/type_icon.gd").new()
	lb_icon.custom_minimum_size = Vector2(64, 64)
	lb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(lb_icon)
	lb_title = _make_label(Locale.t("leaderboard"), 36, Color(0.98, 0.86, 0.4))
	lb_title.custom_minimum_size = Vector2(300, 0)
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(lb_title)
	header.add_child(_make_text_button(">", 40, Vector2(64, 66), _lb_next))
	box.add_child(header)

	box.add_child(_lb_header_row())
	lb_rows = VBoxContainer.new()
	lb_rows.add_theme_constant_override("separation", 4)
	box.add_child(lb_rows)

	box.add_child(_spacer(10))
	box.add_child(_centered(_make_text_button(Locale.t("close"), 30, Vector2(240, 66), _close_leaderboard)))
	ui.add_child(lb_panel)


func _lb_header_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(600, 40)
	var c := Color(0.55, 0.58, 0.66)
	row.add_child(_lb_cell(Locale.t("col_rank"), 24, c, 90, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_lb_cell(Locale.t("col_name"), 24, c, 330, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_lb_cell(Locale.t("col_height"), 24, c, 180, HORIZONTAL_ALIGNMENT_RIGHT))
	return row


func _lb_cell(text: String, fsize: int, color: Color, w: float, align: int) -> Label:
	var l := _make_label(text, fsize, color)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = align
	return l


func _open_leaderboard() -> void:
	lb_view = _type_index(current_type.get("id", "brick"))
	_refresh_leaderboard()
	ui.move_child(lb_panel, ui.get_child_count() - 1)   # 다른 패널 위로
	lb_panel.visible = true


func _close_leaderboard() -> void:
	lb_panel.visible = false


func _lb_prev() -> void:
	lb_view = (lb_view + BlockTypes.all().size() - 1) % BlockTypes.all().size()
	_refresh_leaderboard()


func _lb_next() -> void:
	lb_view = (lb_view + 1) % BlockTypes.all().size()
	_refresh_leaderboard()


func _type_index(id: String) -> int:
	var all := BlockTypes.all()
	for i in all.size():
		if all[i]["id"] == id:
			return i
	return 0


## 목업 랭킹을 다시 그린다. 내 최고 기록이 있으면 내 자리를 끼워 강조한다.
func _refresh_leaderboard() -> void:
	var t: Dictionary = BlockTypes.all()[lb_view]
	lb_title.text = "%s · %s" % [Locale.t("leaderboard"), _type_name(t)]
	if lb_icon != null:
		lb_icon.type_def = t
		lb_icon.queue_redraw()
	for c in lb_rows.get_children():
		c.queue_free()
	var rows: Array = Leaderboard.entries(t["id"], Graveyard.best_for(t["id"]), Locale.t("you"))
	var me_row: Dictionary = {}
	var count := 0
	for e in rows:
		if e["me"]:
			me_row = e
		if count < 8:
			lb_rows.add_child(_lb_entry_row(e))
			count += 1
	# 내 기록이 top 8 밖이면 구분선과 함께 따로 표시
	if not me_row.is_empty() and int(me_row["rank"]) > 8:
		lb_rows.add_child(_lb_cell("...", 24, Color(0.5, 0.52, 0.6), 600, HORIZONTAL_ALIGNMENT_CENTER))
		lb_rows.add_child(_lb_entry_row(me_row))


func _lb_entry_row(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(600, 52)
	var rank: int = e["rank"]
	var col := Color(0.86, 0.87, 0.92)
	if e["me"]:
		col = Color(1.0, 0.84, 0.32)          # 내 기록 = 금색
	elif rank == 1:
		col = Color(1.0, 0.86, 0.45)
	elif rank == 2:
		col = Color(0.82, 0.85, 0.92)
	elif rank == 3:
		col = Color(0.86, 0.66, 0.45)
	var name_txt: String = ("> " + str(e["name"])) if e["me"] else str(e["name"])
	row.add_child(_lb_cell("%d" % rank, 30, col, 90, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_lb_cell(name_txt, 30, col, 330, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_lb_cell("%d m" % int(e["m"]), 30, col, 180, HORIZONTAL_ALIGNMENT_RIGHT))
	return row


# ---------------------------------------------------------------- 설정 / 언어

func _build_settings_panel() -> void:
	settings_panel = _make_overlay(Color(0.06, 0.07, 0.11, 1.0))
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(600, 0)
	center.add_child(box)
	box.add_child(_centered(_make_label(Locale.t("settings"), 44, Color(0.95, 0.92, 0.82))))
	box.add_child(_spacer(6))
	settings_body = VBoxContainer.new()
	settings_body.add_theme_constant_override("separation", 12)
	box.add_child(settings_body)
	box.add_child(_spacer(10))
	box.add_child(_centered(_make_text_button(Locale.t("close"), 30, Vector2(240, 66), _close_settings)))
	ui.add_child(settings_panel)


func _refresh_settings() -> void:
	for c in settings_body.get_children():
		c.queue_free()
	var green := Color(0.4, 0.85, 0.5)
	var gray := Color(0.6, 0.62, 0.7)
	settings_body.add_child(_settings_row(Locale.t("sound"),
		Locale.t("on") if Settings.sound_on else Locale.t("off"),
		green if Settings.sound_on else gray, _toggle_sound))
	settings_body.add_child(_settings_row(Locale.t("haptic"),
		Locale.t("on") if Settings.haptic_on else Locale.t("off"),
		green if Settings.haptic_on else gray, _toggle_haptic))
	var cur := _lang_native(Locale.lang)
	settings_body.add_child(_settings_row(Locale.t("language"), cur, Color(0.8, 0.85, 0.95), _open_language))
	settings_body.add_child(_settings_row(Locale.t("google_play"),
		Locale.t("connected") if Settings.gp_connected else Locale.t("connect"),
		green if Settings.gp_connected else gray, _toggle_gp))
	settings_body.add_child(_settings_row(Locale.t("how_to_replay"), ">", Color(0.8, 0.85, 0.95), _settings_replay_tutorial))
	settings_body.add_child(_spacer(4))
	settings_body.add_child(_centered(_make_label("%s  %s" % [Locale.t("version"), GAME_VERSION],
		22, Color(0.45, 0.47, 0.55))))


func _settings_row(label: String, value: String, vcol: Color, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(560, 68)
	var l := _make_label(label, 32, Color(0.9, 0.9, 0.85))
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var b := _make_text_button(value, 28, Vector2(240, 60), cb)
	b.add_theme_color_override("font_color", vcol)
	row.add_child(b)
	return row


func _open_settings() -> void:
	_refresh_settings()
	ui.move_child(settings_panel, ui.get_child_count() - 1)
	settings_panel.visible = true


func _close_settings() -> void:
	settings_panel.visible = false


func _toggle_sound() -> void:
	Settings.set_sound(not Settings.sound_on)
	_refresh_settings()


func _toggle_haptic() -> void:
	Settings.set_haptic(not Settings.haptic_on)
	_vibe(20)
	_refresh_settings()


func _toggle_gp() -> void:
	# 목업: 나중에 Google Play Games 로그인 연동
	Settings.set_gp(not Settings.gp_connected)
	_refresh_settings()


func _settings_replay_tutorial() -> void:
	settings_panel.visible = false
	_replay_tutorial()


func _lang_native(code: String) -> String:
	for l in Locale.LANGUAGES:
		if l[0] == code:
			return l[1]
	return code


# ---- 일시정지 메뉴 ----

func _build_pause_panel() -> void:
	pause_panel = _make_overlay(Color(0.03, 0.04, 0.07, 0.86))
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	box.add_child(_centered(_make_label("GENESIS 11", 40, Color(0.86, 0.78, 0.55))))
	box.add_child(_spacer(10))
	box.add_child(_centered(_make_text_button(Locale.t("resume"), 34, Vector2(300, 84), _close_pause)))
	box.add_child(_centered(_make_text_button(Locale.t("settings"), 30, Vector2(300, 74), _open_settings)))
	box.add_child(_centered(_make_text_button(Locale.t("home"), 30, Vector2(300, 74), _pause_home)))
	ui.add_child(pause_panel)


func _open_pause() -> void:
	if state != State.READY:
		return
	pause_panel.visible = true
	ui.move_child(pause_panel, ui.get_child_count() - 1)
	get_tree().paused = true


func _close_pause() -> void:
	get_tree().paused = false
	pause_panel.visible = false


func _pause_home() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	_restart_to_select()


# ---- 언어 선택 (검색 포함, 100개국 대비) ----

func _build_language_panel() -> void:
	lang_panel = _make_overlay(Color(0.06, 0.07, 0.11, 1.0))
	lang_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	lang_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	lang_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(600, 0)
	center.add_child(box)
	box.add_child(_centered(_make_label(Locale.t("language"), 42, Color(0.95, 0.92, 0.82))))
	lang_search = LineEdit.new()
	lang_search.placeholder_text = Locale.t("search")
	if ui_font:
		lang_search.add_theme_font_override("font", ui_font)
	lang_search.add_theme_font_size_override("font_size", 30)
	lang_search.custom_minimum_size = Vector2(560, 66)
	lang_search.text_changed.connect(func(_s): _refresh_language())
	box.add_child(_centered(lang_search))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	lang_rows = VBoxContainer.new()
	lang_rows.add_theme_constant_override("separation", 8)
	lang_rows.custom_minimum_size = Vector2(580, 0)
	scroll.add_child(lang_rows)
	box.add_child(_centered(_make_text_button(Locale.t("close"), 28, Vector2(220, 60), _close_language)))
	ui.add_child(lang_panel)


func _refresh_language() -> void:
	var q := lang_search.text.strip_edges() if lang_search != null else ""
	for c in lang_rows.get_children():
		c.queue_free()
	for l in Locale.LANGUAGES:
		var code: String = l[0]
		var native: String = l[1]
		var eng: String = l[2]
		if q != "" and native.findn(q) == -1 and eng.findn(q) == -1 and code.findn(q) == -1:
			continue
		lang_rows.add_child(_lang_row(code, native, eng))


func _lang_row(code: String, native: String, eng: String) -> Control:
	var ready := Locale.is_ready(code)
	var txt := "%s   ·   %s" % [native, eng]
	if not ready:
		txt += "   (soon)"
	var b := _make_text_button(txt, 30, Vector2(560, 68), _pick_language.bind(code))
	if code == Locale.lang:
		b.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	elif not ready:
		b.add_theme_color_override("font_color", Color(0.55, 0.57, 0.64))
	return b


func _pick_language(code: String) -> void:
	Settings.set_lang(code)
	_rebuild_menus()
	_begin_selection()


## 언어 변경 후 메뉴들을 새 언어로 다시 만든다
func _rebuild_menus() -> void:
	for p in [select_panel, lb_panel, settings_panel, lang_panel]:
		if is_instance_valid(p):
			p.queue_free()
	_build_select_panel()
	_build_leaderboard_panel()
	_build_settings_panel()
	_build_language_panel()


func _open_language() -> void:
	if lang_search != null:
		lang_search.text = ""
	_refresh_language()
	ui.move_child(lang_panel, ui.get_child_count() - 1)
	lang_panel.visible = true


func _close_language() -> void:
	lang_panel.visible = false


## 텍스트 버튼 헬퍼 (게임 느낌의 둥근 스타일박스)
func _make_text_button(text: String, fsize: int, min_size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if ui_font:
		b.add_theme_font_override("font", ui_font)
	b.add_theme_font_size_override("font_size", fsize)
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	_style_button(b, Color(0.15, 0.17, 0.23), Color(0.40, 0.45, 0.56))
	b.pressed.connect(cb)
	return b


## 버튼에 둥근 배경/테두리/그림자 스타일 적용 (카툰풍)
func _style_button(b: Button, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = border
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.bg_color = bg.lightened(0.12)
	hov.border_color = border.lightened(0.2)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))


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
	calib_button.text = Locale.t("sensor_on")
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
	var tname: String = _type_name(current_type)
	over_body.add_child(_centered(_make_label(Locale.t("go_title"), 72, Color(0.9, 0.35, 0.32))))
	over_body.add_child(_centered(_make_label(Locale.t("go_line1"), 32, Color(0.82, 0.8, 0.85))))
	over_body.add_child(_spacer(10))
	over_body.add_child(_centered(_make_label(
		Locale.t("go_this") % [tname, _peak_meters()], 40, Color(0.95, 0.93, 0.8))))
	over_body.add_child(_centered(_make_label(
		Locale.t("go_best") % Graveyard.best_for(tid), 28, Color(0.6, 0.62, 0.7))))

	# 역대 잔해 무덤 (이 블록 타입)
	var recent: Array = Graveyard.recent(tid, 6)
	if recent.size() > 0:
		over_body.add_child(_spacer(12))
		over_body.add_child(_centered(_make_label(
			Locale.t("go_graveyard") % tname, 24, Color(0.5, 0.5, 0.58))))
		var line := ""
		for h in recent:
			line += "%d   " % int(h)
		over_body.add_child(_centered(_make_label(
			line.strip_edges(), 26, Color(0.55, 0.5, 0.45))))

	over_body.add_child(_spacer(20))
	# 최고 높이를 캡처했으면 결과 공유 버튼 (강조색)
	if record_img != null:
		var share := _make_text_button(Locale.t("share"), 32, Vector2(300, 84), _share_record)
		_style_button(share, Color(0.20, 0.42, 0.66), Color(0.45, 0.72, 1.0))
		over_body.add_child(_centered(share))
	over_body.add_child(_centered(_make_text_button(Locale.t("retry"), 34, Vector2(300, 84), _restart)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_make_text_button(Locale.t("view_leaderboard"), 26, Vector2(190, 64), _open_leaderboard))
	row.add_child(_make_text_button(Locale.t("change_block"), 26, Vector2(190, 64), _restart_to_select))
	over_body.add_child(_centered(row))

	over_panel.visible = true


## 최고기록 순간 스크린샷을 저장/공유. 웹은 navigator.share(없으면 다운로드), 그 외엔 파일 저장.
func _share_record() -> void:
	if record_img == null:
		return
	var png: PackedByteArray = record_img.save_png_to_buffer()
	if OS.has_feature("web"):
		var b64 := Marshalls.raw_to_base64(png)
		var js := """
		(function(){
		  try{
		    var bin=atob('%s'); var len=bin.length; var arr=new Uint8Array(len);
		    for(var i=0;i<len;i++){arr[i]=bin.charCodeAt(i);}
		    var blob=new Blob([arr],{type:'image/png'});
		    var file=new File([blob],'genesis11.png',{type:'image/png'});
		    if(navigator.canShare && navigator.canShare({files:[file]})){
		      navigator.share({files:[file], title:'Genesis 11', text:'%s'});
		    } else {
		      var url=URL.createObjectURL(blob); var a=document.createElement('a');
		      a.href=url; a.download='genesis11.png'; document.body.appendChild(a); a.click();
		      setTimeout(function(){URL.revokeObjectURL(url); a.remove();},1000);
		    }
		  }catch(e){console.error(e);}
		})();
		""" % [b64, Locale.t("record_break")]
		JavaScriptBridge.eval(js, true)
	else:
		record_img.save_png("user://genesis11_record.png")


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
