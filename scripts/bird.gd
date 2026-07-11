extends AnimatableBody2D
## 새: 날아 들어와 잠시 로밍하다 블록 위에 앉는다. 물리 객체라서 앉아 있을 때 그 위로
## 블록을 놓으면 새에 걸쳐 기울고, 날아갈 때 위로 블록을 들어올리며 떠난다.
## 로밍/진입 중에는 충돌을 꺼서 블록을 치지 않는다.

signal left

enum S { FLY_IN, ROAM, APPROACH, PERCH, FLY_OUT }

var s: int = S.FLY_IN
var target_block: Block = null
var _side: float = 1.0          # 앉을 쪽(+1 오른쪽 / -1 왼쪽)
var timer: float = 0.0
var flap: float = 0.0
var t: float = 0.0
var roam_target: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var cshape: CollisionShape2D
var body_col := Color(0.86, 0.28, 0.22)   # 눈에 잘 띄는 붉은 새


func setup(block: Block, from_left: bool) -> void:
	target_block = block
	_side = -1.0 if from_left else 1.0
	sync_to_physics = true
	cshape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(30, 14)      # 바닥면이 블록 윗면에 딱 맞아 밀어내지 않음
	cshape.shape = box
	cshape.disabled = true                # 로밍 중엔 충돌 없음
	add_child(cshape)
	position = _anchor() + Vector2(-_side * 1000.0, -340.0)
	roam_target = _roam_pick()
	s = S.FLY_IN


func _anchor() -> Vector2:
	if is_instance_valid(target_block):
		return target_block.global_position + Vector2(0, -target_block.bbox.y * 0.5)
	return position


func _roam_pick() -> Vector2:
	return _anchor() + Vector2(randf_range(-220, 220), randf_range(-260, -70))


func _perch_point() -> Vector2:
	if is_instance_valid(target_block):
		return target_block.global_position + Vector2(
			_side * target_block.bbox.x * 0.30,
			-target_block.bbox.y * 0.5 - 7.0)   # 블록 윗면에 앉음
	return position


func _physics_process(dt: float) -> void:
	t += dt
	flap += dt * 18.0
	match s:
		S.FLY_IN:
			position = position.lerp(roam_target, 0.05)
			if position.distance_to(roam_target) < 45.0:
				s = S.ROAM
				timer = randf_range(3.0, 6.0)
		S.ROAM:
			position = position.lerp(roam_target, 0.04)
			position.y += sin(t * 3.0) * 0.7
			if position.distance_to(roam_target) < 60.0:
				roam_target = _roam_pick()
			timer -= dt
			if timer <= 0.0:
				s = S.APPROACH          # 충돌 OFF 상태로 앉을 자리로 접근
		S.APPROACH:
			if not is_instance_valid(target_block):
				_leave()
			else:
				var pp := _perch_point()
				position = position.lerp(pp, 0.16)
				if position.distance_to(pp) < 14.0:
					# 자리에 도착한 뒤에야 충돌을 켠다 → 탑을 들이받지 않음
					position = pp
					cshape.disabled = false
					s = S.PERCH
					timer = randf_range(3.5, 6.5)
		S.PERCH:
			if not is_instance_valid(target_block):
				_leave()
			else:
				position = position.lerp(_perch_point(), 0.4)   # 자리에 딱 붙어 앉음
				timer -= dt
				if timer <= 0.0:
					_leave()
		S.FLY_OUT:
			timer -= dt
			if timer > 1.6:
				position += Vector2(0, -150) * dt      # 처음엔 위로 → 블록 들어올림
			else:
				if not cshape.disabled:
					cshape.disabled = true
				position += vel * dt
			if timer <= 0.0:
				queue_free()
	queue_redraw()


func _leave() -> void:
	if s == S.FLY_OUT:
		return
	s = S.FLY_OUT
	timer = 2.0
	vel = Vector2(_side * 320.0, -280.0)
	left.emit()


func _draw() -> void:
	var c := body_col
	if s == S.PERCH:
		_draw_perched(c)
	else:
		_draw_flying(c)


## 나는 모습 — 날개를 퍼덕인다
func _draw_flying(c: Color) -> void:
	var w := sin(flap) * 14.0
	draw_line(Vector2(0, -3), Vector2(-26, -3 - w), c, 5.0)     # 날개
	draw_line(Vector2(0, -3), Vector2(26, -3 - w), c, 5.0)
	draw_circle(Vector2.ZERO, 13.0, c)                          # 몸통
	draw_circle(Vector2(_side * 10.0, -6.0), 8.0, c)            # 머리
	draw_line(Vector2(_side * 17.0, -6.0), Vector2(_side * 27.0, -4.0),
		Color(0.97, 0.72, 0.15), 3.5)                          # 부리
	draw_circle(Vector2(_side * 12.0, -8.0), 2.2, Color(0.05, 0.05, 0.05))  # 눈


## 앉은 모습 — 날개를 접고 두 다리로 블록 위에 앉는다(퍼덕이지 않음)
func _draw_perched(c: Color) -> void:
	var bob := sin(t * 2.2) * 0.7                               # 살짝 고갯짓(퍼덕임 아님)
	var leg := Color(0.86, 0.55, 0.16)
	# 다리 — 몸 아래에서 블록 윗면(로컬 y≈+7)까지
	draw_line(Vector2(-4, 3), Vector2(-4, 8), leg, 2.6)
	draw_line(Vector2(4, 3), Vector2(4, 8), leg, 2.6)
	# 웅크린 몸통
	draw_circle(Vector2(0, -3), 12.5, c)
	# 접은 날개 — 등에 붙인 짧은 곡선(가까운 쪽 한 겹)
	draw_line(Vector2(-_side * 3.0, -8.0), Vector2(-_side * 12.0, -1.0), c.darkened(0.12), 5.5)
	# 꼬리 — 뒤로 살짝
	draw_line(Vector2(-_side * 8.0, -4.0), Vector2(-_side * 20.0, -6.0), c, 4.0)
	# 머리(약간 위로 세워 앉은 자세) + 고갯짓
	var head := Vector2(_side * 8.0, -12.0 + bob)
	draw_circle(head, 7.5, c)
	draw_line(head + Vector2(_side * 6.0, 1.0), head + Vector2(_side * 15.0, 2.5),
		Color(0.97, 0.72, 0.15), 3.2)                          # 부리
	draw_circle(head + Vector2(_side * 2.5, -2.0), 2.1, Color(0.05, 0.05, 0.05))  # 눈
