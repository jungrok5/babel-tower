extends Node
## 렌더된 실제 게임 화면을 여러 상황에서 PNG로 캡처한다(시각 검증용).
## 헤드리스가 아니라 xvfb + 소프트웨어 GL 위에서 실행되어 실제 프레임을 저장한다.
## 저장 위치: res://shots/*.png  (CI가 이 폴더를 'screenshots' 브랜치로 올린다)
## State: CALIB=0, READY=1, OVER=2, SELECT=3, TUTORIAL=4

var main: Node
const OUT := "res://shots"


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func():
		print("[SHOT] FAILSAFE QUIT — 무언가 멈춤")
		get_tree().quit())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Locale.set_lang("ko")              # 한국어 화면으로 캡처
	Graveyard.tutorial_seen = true     # 기본은 튜토리얼 생략(개별 테스트에서 켠다)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	print("[SHOT] main added, state=%d" % int(main.state))

	# ---- 메뉴 흐름 (시작 화면 → 랭킹 → 설정 → 언어) ----
	await _settle(10)
	await _shot("00_select")            # 홈: 엠블럼 + 블록 선택 그리드 + 랭킹/설정

	Graveyard.by_type["brick"] = {"best": 400, "records": [400]}
	main._open_leaderboard()
	await _settle(8); await _shot("00b_rank")   # 랭킹(블록 아이콘 + 금색 '나' 행)
	main._close_leaderboard()
	Graveyard.by_type.erase("brick")

	main._open_settings()
	await _settle(6); await _shot("00f_settings")
	main._open_language()
	await _settle(6); await _shot("00g_language")
	main._close_language(); main._close_settings()

	# ---- 손 모양 튜토리얼 (보정 완료 후 첫 진입 시 자동으로 뜬다) ----
	Graveyard.tutorial_seen = false
	main._choose_type("brick")          # → 보정 → (첫 플레이라) 튜토리얼
	# 보정이 끝나 튜토리얼 오버레이가 뜰 때까지 대기
	var tw := 0
	while (main.tutorial == null or not main.tutorial.visible) and tw < 600:
		await get_tree().physics_frame
		tw += 1
	if main.tutorial != null and main.tutorial.visible:
		main.tutorial.t = 1.2; await _settle(3); await _shot("00c_tut_drag")
		main.tutorial.t = 2.5; await _settle(3); await _shot("00c2_tut_drop")
		main.tutorial.t = 3.6; await _settle(3); await _shot("00d_tut_rotate")
		main.tutorial.t = 6.8; await _settle(3); await _shot("00e_tut_still")
		main.tutorial.finished.emit(true)   # '다음부터 안 보기' 체크하고 시작

	# READY까지 대기
	var t := 0
	while int(main.state) != 1 and t < 800:
		await get_tree().physics_frame
		t += 1
	await _settle(24)
	await _shot("01_start")             # 지면(잔디·덤불·바위) + 제단 + 낮은 하늘/해/구름

	# 이 판에서 최고기록을 깨도록 낮은 기존 기록 설정(→ 공유 버튼/캡처 확인)
	Graveyard.by_type["brick"] = {"best": 8, "records": [8]}

	await _build(5)
	await _settle(40)
	await _shot("02_stack")             # 몇 층 쌓인 모습

	# 회전 데모 — 세운 벽돌(기둥) 두 개
	main.aim_rot = PI * 0.5
	main._drop_block(main.BASE_X - 30.0)
	await _wait_land()
	main.aim_rot = PI * 0.5
	main._drop_block(main.BASE_X + 24.0)
	await _wait_land()
	main.aim_rot = 0.0
	await _settle(30)
	await _shot("03_rotate")            # 90° 회전한 기둥 블록

	# 기울임 데모 — 센서를 강제로 기울여 바닥이 경사지고 탑이 쏠림(아직 붕괴 전)
	Motion.set_process(false)
	Motion._sway = 0.5
	await _settle(75)
	await _shot("05_tilt")             # 기운 바닥 + 쏠린 탑
	Motion._sway = 0.0
	await _settle(80)                  # 다시 수평 → 안정화

	# (개발용) 관찰 카메라: 신선한 안정 탑(READY)에서 지면→우주 자유 스크롤 시연
	main._restart()
	Motion._sway = 0.0
	await _build(4)
	await _settle(30)
	main._toggle_inspect()             # inspect ON (지면=구름 없음 + 안내 문구)
	await _settle(55)
	await _shot("04_inspect")          # 지면: 맑음(구름 없음) + 해
	main.inspect_pan.y = -2862.0       # ~250m: 구름 가득 밴드
	await _settle(70)
	await _shot("04c_clouds")          # 구름 층 통과
	main.inspect_pan.y = -5340.0       # ~450m: 성층권(권운) 진입
	await _settle(70)
	await _shot("04d_strato")          # 성층권 얇은 권운
	main.inspect_pan.y = -9900.0       # ~817m: 우주(별)
	await _settle(80)
	await _shot("04b_inspect_space")   # 우주(어두운 하늘 + 별)
	main._toggle_inspect()             # inspect OFF
	await _settle(30)

	# 바람 이펙트 — 강제로 최대 바람
	for i in range(6):
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
	await _shot("08b_gameover")        # 결과 + 결과 공유 버튼

	# 다른 블록 타입 물리 시연 (바닥 수평 유지로 깔끔히 쌓기)
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

	# 새 도형: 고깔(삼각 poly) / 병(세로형 poly+rect)
	main._restart()
	main.current_type = BlockTypes.get_type("cone")
	await _build(4)
	await _settle(70)
	await _shot("11_cone")             # 고깔(뾰족한 삼각형)

	main._restart()
	main.current_type = BlockTypes.get_type("bottle")
	await _build(3)
	await _settle(70)
	await _shot("12_bottle")           # 병(세로로 긴 형태)

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
