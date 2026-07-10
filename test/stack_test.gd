extends Node
## 헤드리스 물리 테스트 — 실제 Main 씬/Block/중력 모델을 그대로 사용한다.
## 검증 항목:
##   1) 수평(입력 0) 상태에서 탑이 '떨림 없이' 가만히 있는가 (jitter≈0)
##   2) 기울이면(Motion._sway 강제) 탑이 실제로 쏠리는가
##   3) 다시 수평으로 돌리면 안정되어 떨림이 사라지는가
##
## State enum: CALIB=0, READY=1, OVER=2

var main: Node


func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

	var t := 0
	while int(main.state) != 1 and t < 800:
		await get_tree().physics_frame
		t += 1
	print("[TEST] READY after %d frames" % t)

	# 25개 쌓기 (수평)
	for i in range(25):
		if int(main.state) != 1:
			break
		main._drop_block()
		await _steps(14)
	print("[TEST] built score=%d state=%d" % [int(main.score), int(main.state)])

	# 1) 수평 유지 중 떨림 측정
	var jl := await _measure_jitter(120)
	print("[TEST] LEVEL-HOLD jitter=%.4f px  (0 이면 떨림 완전 없음)" % jl)

	# 2) 기울임 — Motion 갱신을 멈추고 sway를 강제한다
	Motion.set_process(false)
	Motion._sway = 0.6
	var before := _top_x()
	await _steps(90)
	var after := _top_x()
	print("[TEST] TILT lean dx=%.1f px  state=%d  (기울이면 쏠려야 함)" % [after - before, int(main.state)])

	# 3) 다시 수평 → 안정 + 떨림 재측정
	Motion._sway = 0.0
	await _steps(150)
	var jr := await _measure_jitter(120)
	print("[TEST] AFTER-LEVEL jitter=%.4f px  state=%d" % [jr, int(main.state)])

	get_tree().quit()


func _top_x() -> float:
	var top = main._top_block()
	return top.position.x if top != null else 0.0


func _measure_jitter(n: int) -> float:
	var lo := {}
	var hi := {}
	for k in range(n):
		for idx in main.blocks.size():
			var b = main.blocks[idx]
			if is_instance_valid(b):
				var x: float = b.position.x
				if not lo.has(idx):
					lo[idx] = x
					hi[idx] = x
				lo[idx] = minf(lo[idx], x)
				hi[idx] = maxf(hi[idx], x)
		await get_tree().physics_frame
	var j := 0.0
	for idx in lo:
		j = maxf(j, hi[idx] - lo[idx])
	return j


func _steps(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
