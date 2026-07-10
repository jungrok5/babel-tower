extends Node
## 헤드리스 물리 테스트 — 실제 Main 씬/Block/중력 모델을 그대로 사용한다.
## 수평(입력 없음) 상태에서 30개까지 쌓으며, 언제 스스로 붕괴하는지 로그로 출력.
## CI(godot --headless res://test/StackTest.tscn)에서 실행되어 실제 엔진 물리를 검증한다.
##
## State enum: CALIB=0, READY=1, OVER=2

func _ready() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)

	# 보정이 끝나 READY(1)가 될 때까지 대기
	var t := 0
	while int(main.state) != 1 and t < 800:
		await get_tree().physics_frame
		t += 1
	print("[TEST] READY after %d frames (state=%d)" % [t, int(main.state)])

	var collapsed_at := -1
	for i in range(30):
		if int(main.state) != 1:
			break
		main._drop_block()
		for j in range(16):          # 낙하/안착 시간
			await get_tree().physics_frame
		var mr := _maxrot(main)
		print("[TEST] drop=%2d blocks=%2d state=%d maxrot=%.3f" % [
			int(main.score), main.blocks.size(), int(main.state), mr])
		if int(main.state) == 2 and collapsed_at < 0:
			collapsed_at = int(main.score)

	# 마지막으로 오래 두고 스스로 무너지는지 확인
	for j in range(300):
		await get_tree().physics_frame
	print("[TEST] === FINAL collapsed_at=%d score=%d state=%d maxrot=%.3f ===" % [
		collapsed_at, int(main.score), int(main.state), _maxrot(main)])
	get_tree().quit()


func _maxrot(main: Node) -> float:
	var m := 0.0
	for b in main.blocks:
		if is_instance_valid(b):
			m = maxf(m, absf(b.rotation))
	return m
