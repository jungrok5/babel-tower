extends Node
## 헤드리스 물리 진단 — 실제 Main/Block/기우는 바닥을 그대로 사용.
##   1) 수평에서 떨림(x,y)과 '붕 뜸'(블록 간 틈) 측정
##   2) 바닥을 기울였을 때(경사) 위 블록이 넘어지는가
## State: CALIB=0, READY=1, OVER=2

var main: Node


func _ready() -> void:
	# 무슨 일이 있어도 로그가 남도록 강제 종료 실패방지 타이머
	get_tree().create_timer(90.0).timeout.connect(func():
		print("[TEST] FAILSAFE QUIT — 무언가 멈춤")
		get_tree().quit())
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	print("[TEST] main added, state=%d" % int(main.state))
	await get_tree().physics_frame
	main._choose_type("brick")            # 선택 화면 건너뛰고 벽돌로 시작
	print("[TEST] chose brick, state=%d" % int(main.state))
	var t := 0
	while int(main.state) != 1 and t < 800:
		await get_tree().physics_frame
		t += 1

	await _build_to(8)
	await _steps(240)
	var r := await _measure(90)
	print("[TEST] LEVEL(8): jitter x=%.2f y=%.2f  maxgap=%.2f px  sleeping=%d/%d" % [
		r.jx, r.jy, _gap(), r.s, main.blocks.size()])

	# 바닥을 서서히 기울여 몇 도에서 넘어지는지 (8층)
	Motion.set_process(false)
	for sway in [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0]:
		Motion._sway = float(sway)
		await _steps(85)
		print("[TEST] TILT sway=%.2f  floor_deg=%.1f  top_rot_deg=%.1f  state=%d" % [
			sway, rad_to_deg(main.floor_body.rotation), rad_to_deg(_top_rot()), int(main.state)])
		if int(main.state) == 2:
			print("[TEST] --> 붕괴")
			break

	# 극단적으로 기울인 채 오래 유지 → 블록이 실제로 바닥에 떨어지면 붕괴해야 한다.
	# (기울기만으로 죽는 게 아니라 '블록이 지면에 닿을 때' 붕괴하는지 확인)
	if int(main.state) != 2:
		Motion._sway = 1.0
		var frames := 0
		while int(main.state) != 2 and frames < 1200:
			await get_tree().physics_frame
			frames += 1
		print("[TEST] HOLD sway=1.00  frames=%d  min_block_y=%.0f  ground_y=%.0f  state=%d" % [
			frames, _min_block_y(), main.GROUND_TOP_Y, int(main.state)])
		print("[TEST] --> 붕괴" if int(main.state) == 2 else "[TEST] --> 유지(붕괴 없음)")

	get_tree().quit()


func _min_block_y() -> float:
	# 가장 아래로 내려간 블록의 아랫변 y (지면에 가까운 정도)
	var m := -1e9
	for b in main.blocks:
		if is_instance_valid(b):
			m = maxf(m, b.global_position.y + b.bbox.y * 0.5)
	return m


func _build_to(n: int) -> void:
	while int(main.state) == 1 and int(main.score) < n:
		main._drop_block()
		await _steps(18)


func _top_rot() -> float:
	var top = main._top_block()
	return top.rotation if top != null else 0.0


func _gap() -> float:
	# 블록들을 세로로 정렬해 인접 간격이 블록 높이보다 얼마나 벌어졌는지(=붕 뜸)
	var ys := []
	for b in main.blocks:
		if is_instance_valid(b):
			ys.append(b.position.y)
	ys.sort()
	var g := 0.0
	for i in range(ys.size() - 1):
		g = maxf(g, absf(ys[i + 1] - ys[i]) - main.BLOCK_SIZE.y)
	return g


func _measure(n: int) -> Dictionary:
	var lo := {}
	var hi := {}
	for k in range(n):
		for idx in main.blocks.size():
			var b = main.blocks[idx]
			if is_instance_valid(b):
				var p: Vector2 = b.position
				if not lo.has(idx):
					lo[idx] = p
					hi[idx] = p
				lo[idx] = Vector2(minf(lo[idx].x, p.x), minf(lo[idx].y, p.y))
				hi[idx] = Vector2(maxf(hi[idx].x, p.x), maxf(hi[idx].y, p.y))
		await get_tree().physics_frame
	var jx := 0.0
	var jy := 0.0
	for idx in lo:
		jx = maxf(jx, hi[idx].x - lo[idx].x)
		jy = maxf(jy, hi[idx].y - lo[idx].y)
	var s := 0
	for b in main.blocks:
		if is_instance_valid(b) and b is RigidBody2D and b.sleeping:
			s += 1
	return {"jx": jx, "jy": jy, "s": s}


func _steps(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
