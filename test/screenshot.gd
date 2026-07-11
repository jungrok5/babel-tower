extends Node
## 렌더된 실제 게임 화면을 여러 상황에서 PNG로 캡처한다(시각 검증용).
## 헤드리스가 아니라 xvfb + 소프트웨어 GL 위에서 실행되어 실제 프레임을 저장한다.
## 저장 위치: res://shots/*.png  (CI가 이 폴더를 'screenshots' 브랜치로 올린다)
## State: CALIB=0, READY=1, OVER=2 / Bird.S: FLY_IN=0 ROAM=1 APPROACH=2 PERCH=3 FLY_OUT=4

var main: Node
const OUT := "res://shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

	# READY(보정 완료)까지 대기
	var t := 0
	while int(main.state) != 1 and t < 800:
		await get_tree().physics_frame
		t += 1
	await _settle(24)
	await _shot("01_start")            # 지면 + 토대 + 낮은 하늘

	# 낮은 탑 쌓기
	await _build(6)
	await _settle(40)
	await _shot("02_stack")            # 몇 층 쌓인 모습

	# 바닥(판자) 기울이기 → 경사로 탑이 쏠림
	Motion.set_process(false)
	Motion._sway = 0.5
	await _settle(70)
	await _shot("03_tilt")             # 기운 바닥 + 쏠린 탑
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
	await _shot("04_wind")             # 전경 바람결/티끌

	# 앉은 새 — 상태를 PERCH(3)로 강제해 앉은 자세를 캡처
	_force_perched_bird()
	await _settle(24)
	await _shot("05_bird")             # 블록 위에 앉은 새

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
	await _shot("06_collapse")         # 붕괴/줌아웃

	get_tree().quit()


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
