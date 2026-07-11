extends Node
## 렌더된 실제 게임 화면을 여러 상황에서 PNG로 캡처한다(시각 검증용).
## 헤드리스가 아니라 xvfb + 소프트웨어 GL 위에서 실행되어 실제 프레임을 저장한다.
## 저장 위치: res://shots/*.png  (CI가 이 폴더를 'screenshots' 브랜치로 올린다)
## State: CALIB=0, READY=1, OVER=2 / Bird.S: FLY_IN=0 ROAM=1 APPROACH=2 PERCH=3 FLY_OUT=4

var main: Node
const OUT := "res://shots"


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func():
		print("[SHOT] FAILSAFE QUIT — 무언가 멈춤")
		get_tree().quit())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Locale.set_lang("ko")              # 한국어 화면으로 캡처
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	print("[SHOT] main added, state=%d" % int(main.state))

	# 블록 선택 화면 (모든 타입 아이콘)
	await _settle(10)
	await _shot("00_select")

	# 랭킹 UI (목업) — 내 기록을 하나 넣어 강조(금색 '나' 행) 확인
	Graveyard.by_type["brick"] = {"best": 400, "records": [400]}
	main._open_leaderboard()
	await _settle(8)
	await _shot("00b_rank")
	main._close_leaderboard()
	Graveyard.by_type.erase("brick")   # 테스트 아티팩트 제거

	# 설정 / 언어 선택 UI
	main._open_settings()
	await _settle(6); await _shot("00f_settings")
	main._open_language()
	await _settle(6); await _shot("00g_language")
	main._close_language(); main._close_settings()

	# 손 모양 튜토리얼 — 각 단계 캡처(끌기/낙하/회전/수평)
	Graveyard.tutorial_seen = false
	main._choose_type("brick")         # 첫 플레이 → 튜토리얼
	await _settle(8)
	if main.tutorial != null:
		main.tutorial.t = 1.2          # ① 드래그
		await _settle(3); await _shot("00c_tut_drag")
		main.tutorial.t = 2.5          # ①-2 낙하
		await _settle(3); await _shot("00c2_tut_drop")
		main.tutorial.t = 3.6          # ② 회전(45°)
		await _settle(3); await _shot("00d_tut_rotate")
		main.tutorial.t = 6.8          # ③ 수평 유지
		await _settle(3); await _shot("00e_tut_still")
		main.tutorial.finished.emit()  # 튜토리얼 종료 → 보정

	# READY(보정 완료)까지 대기
	var t := 0
	while int(main.state) != 1 and t < 800:
		await get_tree().physics_frame
		t += 1
	await _settle(24)
	await _shot("01_start")            # 지면 + 토대 + 낮은 하늘

	# 이 판에서 최고기록을 깨도록 낮은 기존 기록 설정(→ 공유 버튼/캡처 확인)
	Graveyard.by_type["brick"] = {"best": 8, "records": [8]}

	# 낮은 탑 쌓기
	await _build(5)
	await _settle(40)
	await _shot("02_stack")            # 몇 층 쌓인 모습

	# 회전 데모 — 세운 벽돌(기둥) 두 개
	main.aim_rot = PI * 0.5
	main._drop_block(main.BASE_X - 30.0)
	await _wait_land()
	main.aim_rot = PI * 0.5
	main._drop_block(main.BASE_X + 24.0)
	await _wait_land()
	main.aim_rot = 0.0
	await _settle(30)
	await _shot("03_rotate")           # 90° 회전한 기둥 블록

	# (개발용) 자이로 잠금 검증: 최대로 기울여도 바닥이 수평 유지
	Motion.set_process(false)
	main.gyro_locked = true
	Motion._sway = 1.0
	await _settle(75)
	await _shot("04_gyrolock")         # 바닥 수평 유지(탑 안 쏠림)

	# 잠금 해제 → 기울이면 바닥이 경사져 탑이 쏠림
	main.gyro_locked = false
	Motion._sway = 0.5
	await _settle(75)
	await _shot("05_tilt")             # 기운 바닥 + 쏠린 탑
	Motion._sway = 0.0
	await _settle(70)

	# 더 높이 → 바람 이펙트 강제로 켜서 캡처
	await _build(10)                   # 총 16층
	await _settle(40)
	for i in range(6):                 # 몇 프레임 동안 바람을 최대로 유지
		main.wind_cur = 1.0
		if main.wind_fx != null:
			main.wind_fx.wind = 1.0
		await get_tree().physics_frame
	await _shot("06_wind")             # 전경 바람결/티끌

	# 앉은 새 — 상태를 PERCH(3)로 강제해 앉은 자세를 캡처
	_force_perched_bird()
	await _settle(24)
	await _shot("07_bird")             # 블록 위에 앉은 새

	# 붕괴 — 세게 기울여 블록이 바닥에 닿게 만든 뒤 줌아웃 장면
	if is_instance_valid(main.bird):
		main.bird.queue_free()
		main.bird = null
	Motion._sway = 1.0
	var g := 0
	while int(main.state) != 2 and g < 1600:
		await get_tree().physics_frame
		g += 1
	await _settle(90)                  # 카메라 줌아웃 대기
	await _shot("08_collapse")         # 붕괴/줌아웃

	# 결과(게임오버) 패널 — 완전히 무너진 뒤 뜬다. 공유 버튼 포함.
	var gp := 0
	while (not main.over_panel.visible) and gp < 700:
		await get_tree().physics_frame
		gp += 1
	await _settle(6)
	await _shot("08b_gameover")

	# 다른 블록 타입 물리 시연 (자이로 잠금 상태로 깔끔히 쌓기)
	main.gyro_locked = true
	Motion._sway = 0.0
	main._restart()
	main.current_type = BlockTypes.get_type("desk")
	await _build(4)
	await _settle(70)
	await _shot("09_desk")             # 책상(다리 있는 합성 콜라이더)

	main._restart()
	main.current_type = BlockTypes.get_type("ball")
	await _build(4)
	await _settle(80)
	await _shot("10_ball")             # 공(원형, 잘 구름)

	get_tree().quit()


## 방금 놓은 블록이 착지할 때까지 대기
func _wait_land() -> void:
	var w := 0
	while main.settling != null and is_instance_valid(main.settling) and w < 150:
		await get_tree().physics_frame
		w += 1


## n개 블록을 놓되, 각 블록이 착지(settling 해제)할 때까지 기다린다.
func _build(n: int) -> void:
	for i in range(n):
		if int(main.state) != 1:
			return
		main._drop_block(main.BASE_X + randf_range(-16.0, 16.0))
		var w := 0
		while main.settling != null and is_instance_valid(main.settling) and w < 130:
			await get_tree().physics_frame
			w += 1


## 현재 꼭대기 블록 위에 새를 즉시 '앉은 상태'로 만들어 둔다.
func _force_perched_bird() -> void:
	var top = main._top_block()
	if top == null:
		return
	if is_instance_valid(main.bird):
		main.bird.queue_free()
	var b = load("res://scripts/bird.gd").new()
	b.setup(top, true)
	main.add_child(b)
	main.bird = b
	b.s = 3                            # S.PERCH
	b.timer = 8.0
	if b.cshape != null:
		b.cshape.disabled = false
	b.position = b._perch_point()


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _shot(name: String) -> void:
	# 그리기가 끝난 뒤의 프레임을 캡처
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	img.save_png(path)
	print("[SHOT] %s  %dx%d" % [path, img.get_width(), img.get_height()])
