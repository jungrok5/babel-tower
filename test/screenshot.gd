extends Node
## 렌더된 실제 게임 화면을 여러 상황에서 PNG로 캡처(시각 검증).
## 자이로 없음 · 바닥(base) 선택제. State: BASE_SELECT=0 READY=1 OVER=2 SELECT=3 TUTORIAL=4

var main: Node
const OUT := "res://shots"


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func():
		print("[SHOT] FAILSAFE QUIT — 무언가 멈춤")
		get_tree().quit())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Locale.set_lang("ko")
	Graveyard.tutorial_seen = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	print("[SHOT] main added, state=%d" % int(main.state))

	# ---- 메뉴 (블록 선택 → 랭킹 → 설정 → 언어) ----
	await _settle(10)
	await _shot("00_select")

	Graveyard.by_type["ground:brick"] = {"best": 300, "records": [300]}
	main._open_leaderboard()
	await _settle(8); await _shot("00b_rank")      # 바닥×블록 랭킹
	main._close_leaderboard()
	Graveyard.by_type.erase("ground:brick")

	main._open_settings()
	await _settle(6); await _shot("00f_settings")
	main._open_language()
	await _settle(6); await _shot("00g_language")
	main._close_language(); main._close_settings()

	# ---- 바닥 선택 화면 ----
	main._choose_type("brick")
	await _settle(8); await _shot("00h_base")       # 땅/참외/시소/뗏목

	# ---- 튜토리얼(첫 진입) ----
	Graveyard.tutorial_seen = false
	main._choose_base("ground")                     # → 바닥 구성 + 튜토리얼
	var tw := 0
	while (main.tutorial == null or not main.tutorial.visible) and tw < 400:
		await get_tree().physics_frame
		tw += 1
	if main.tutorial != null and main.tutorial.visible:
		main.tutorial.t = 1.2; await _settle(3); await _shot("00c_tut_drag")
		main.tutorial.t = 3.6; await _settle(3); await _shot("00d_tut_rotate")
		main.tutorial.t = 6.8; await _settle(3); await _shot("00e_tut_still")
		main.tutorial.finished.emit(true)

	var t := 0
	while int(main.state) != 1 and t < 500:
		await get_tree().physics_frame
		t += 1
	await _settle(24)
	await _shot("01_start")                         # 땅 + 제단

	Graveyard.by_type["ground:brick"] = {"best": 8, "records": [8]}
	await _build(5)
	await _settle(40); await _shot("02_stack")

	# 관찰 카메라: 지면 → 우주까지 스크롤
	main.sky.force_all_env()
	main._toggle_inspect()
	await _settle(55); await _shot("04_inspect")
	main.inspect_pan.y = -770.0
	await _settle(70); await _shot("04c_clouds")
	main.inspect_pan.y = -2560.0
	await _settle(80); await _shot("04b_inspect_space")
	main._toggle_inspect()
	await _settle(24)

	# 바람 — 강제로 최대
	for i in range(8):
		main.wind_cur = 1.0
		if main.wind_fx != null:
			main.wind_fx.wind = 1.0
		await get_tree().physics_frame
	await _shot("06_wind")

	# 붕괴 — 위쪽 블록에 옆으로 강한 충격 → 무너짐
	main.wind_cur = 0.0
	for b in main.blocks:
		if is_instance_valid(b):
			b.apply_central_impulse(Vector2(560.0, -40.0))
	var g := 0
	while int(main.state) != 2 and g < 900:
		await get_tree().physics_frame
		g += 1
	await _settle(80); await _shot("08_collapse")
	var gp := 0
	while (not main.over_panel.visible) and gp < 600:
		await get_tree().physics_frame
		gp += 1
	await _settle(6); await _shot("08b_gameover")   # 바벨 붕괴 문구 + 공유

	# ---- 바닥별 물리 시연 ----
	await _play_base("coin", "melon", 6, "20_melon")     # 물 위 참외 + 동전
	await _play_base("brick", "seesaw", 4, "21_seesaw")  # 시소
	await _play_base("brick", "raft", 6, "22_raft")      # 뗏목
	await _play_base("cone", "ground", 4, "23_cone")     # 고깔
	await _play_base("coin", "ground", 6, "24_coin")     # 동전(땅)

	get_tree().quit()


## 바닥×블록을 골라 몇 개 쌓고 캡처
func _play_base(block_id: String, base_id: String, n: int, name: String) -> void:
	main._restart_to_select()
	await _settle(4)
	main._choose_type(block_id)
	main._choose_base(base_id)
	var t := 0
	while int(main.state) != 1 and t < 400:
		await get_tree().physics_frame
		t += 1
	await _settle(40)                # 바닥 자리잡기
	await _build(n)
	await _settle(70)
	await _shot(name)


func _build(n: int) -> void:
	for i in range(n):
		if int(main.state) != 1:
			return
		main._drop_block(main.BASE_X + randf_range(-14.0, 14.0))
		var w := 0
		while main.settling != null and is_instance_valid(main.settling) and w < 130:
			await get_tree().physics_frame
			w += 1


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	img.save_png(path)
	print("[SHOT] %s  %dx%d" % [path, img.get_width(), img.get_height()])
