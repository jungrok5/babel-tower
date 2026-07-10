extends Node
## 헤드리스 물리 진단 — 실제 Main/Block/중력을 그대로 사용.
## 안착을 충분히 기다린 뒤(steady-state) 수평 유지 중 떨림과 sleep 상태를 측정한다.
## State: CALIB=0, READY=1, OVER=2

var main: Node


func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	var t := 0
	while int(main.state) != 1 and t < 800:
		await get_tree().physics_frame
		t += 1

	await _build_to(5)
	await _steps(300)                 # 완전 안착 대기
	var r1 := await _measure(90)
	print("[TEST] SMALL(5):  steady jitter=%.3f px  sleeping=%d/%d" % [r1.j, r1.s, main.blocks.size()])

	await _build_to(25)
	await _steps(300)
	var r2 := await _measure(90)
	print("[TEST] TALL(25):  steady jitter=%.3f px  sleeping=%d/%d" % [r2.j, r2.s, main.blocks.size()])

	get_tree().quit()


func _build_to(n: int) -> void:
	while int(main.state) == 1 and int(main.score) < n:
		main._drop_block()
		await _steps(18)


func _measure(n: int) -> Dictionary:
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
	var s := 0
	for b in main.blocks:
		if is_instance_valid(b) and b is RigidBody2D and b.sleeping:
			s += 1
	return {"j": j, "s": s}


func _steps(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
