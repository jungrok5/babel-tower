extends Node
## 헤드리스 물리 진단 — 실제 Main/Block/기우는 바닥을 그대로 사용.
##   1) 수평에서 떨림(x,y)과 '붕 뜸'(블록 간 틈) 측정
##   2) 바닥을 기울였을 때(경사) 위 블록이 넘어지는가
## State: CALIB=0, READY=1, OVER=2

var main: Node


func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	var t := 0
	while int(main.state) != 1 and t < 800:
		await get_tree().physics_frame
		t += 1

	await _build_to(6)
	await _steps(240)
	var r := await _measure(90)
	print("[TEST] LEVEL(6): jitter x=%.2f y=%.2f  maxgap=%.2f px  sleeping=%d/%d" % [
		r.jx, r.jy, _gap(), r.s, main.blocks.size()])

	# 바닥을 여러 각도로 기울여 넘어지는 시점 확인
	Motion.set_process(false)
	for sway in [0.4, 0.7, 1.0]:
		Motion._sway = float(sway)
		await _steps(80)
		print("[TEST] TILT sway=%.1f  floor_deg=%.1f  top_rot_deg=%.1f  state=%d" % [
			sway, rad_to_deg(main.floor_body.rotation), rad_to_deg(_top_rot()), int(main.state)])
		if int(main.state) == 2:
			break

	get_tree().quit()


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
