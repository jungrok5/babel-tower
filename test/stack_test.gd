extends Node
## 헤드리스 물리 진단 — 자이로 없이, 바닥(base) 종류별로 쌓임/안정성을 확인.
## 각 바닥을 골라 몇 층 쌓고 지지면·높이·상태를 출력한다. (파스 에러/행 방지 겸용)
## State: BASE_SELECT=0, READY=1, OVER=2, SELECT=3, TUTORIAL=4

var main: Node


func _ready() -> void:
	get_tree().create_timer(85.0).timeout.connect(func():
		print("[TEST] FAILSAFE QUIT — 무언가 멈춤")
		get_tree().quit())
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	print("[TEST] main added, state=%d" % int(main.state))
	Graveyard.tutorial_seen = true
	await get_tree().physics_frame

	for base_id in ["ground", "melon", "seesaw", "raft"]:
		await _run_base(base_id)

	print("[TEST] DONE")
	get_tree().quit()


func _run_base(base_id: String) -> void:
	main._choose_type("brick")        # → BASE_SELECT
	main._choose_base(base_id)        # → 바닥 구성 + READY
	var t := 0
	while int(main.state) != 1 and t < 400:
		await get_tree().physics_frame
		t += 1
	await _steps(45)                  # 바닥(부력/시소)이 자리잡을 시간
	print("[TEST] %s  support_top=%.0f  kill=%.0f  state=%d" % [
		base_id, main.base.support_top_y(), main.base.kill_y(), int(main.state)])

	var n := 0
	while int(main.state) == 1 and n < 10:
		main._drop_block(main.BASE_X + randf_range(-10.0, 10.0))
		var w := 0
		while main.settling != null and is_instance_valid(main.settling) and w < 120:
			await get_tree().physics_frame
			w += 1
		n += 1
	await _steps(80)
	print("[TEST] %s  built=%d  height_m=%d  support_top=%.0f  state=%d" % [
		base_id, int(main.score), main._meters(), main.base.support_top_y(), int(main.state)])
	print("[TEST] --> %s" % ("붕괴" if int(main.state) == 2 else "유지"))

	main._restart_to_select()
	await _steps(6)


func _steps(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
