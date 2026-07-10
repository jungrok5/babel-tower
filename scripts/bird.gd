extends Node2D
## 새: 날아 들어와 블록 한쪽에 앉았다가 떠난다. 앉아 있는 동안 그 쪽에 무게(힘)를
## 실어 미세하게 탑을 기울인다. main이 스폰하고 chirp 사운드를 재생한다.

signal left

enum State { FLY_IN, PERCH, FLY_OUT }

var state: int = State.FLY_IN
var target_block: Block = null
var timer: float = 0.0
var vel: Vector2 = Vector2.ZERO
var flap: float = 0.0
var _side: float = 1.0

const WEIGHT := 240.0       # 앉았을 때 싣는 무게(힘)


func setup(block: Block, from_left: bool) -> void:
	target_block = block
	_side = 1.0 if from_left else -1.0
	position = _perch_world() + Vector2(-_side * 950.0, -280.0)


func _perch_world() -> Vector2:
	if not is_instance_valid(target_block):
		return position
	return target_block.global_position + Vector2(
		_side * target_block.block_size.x * 0.28,
		-target_block.block_size.y * 0.5 - 13.0)


func _physics_process(delta: float) -> void:
	flap += delta * 16.0
	match state:
		State.FLY_IN:
			if not is_instance_valid(target_block):
				_leave()
			else:
				var tgt := _perch_world()
				position = position.lerp(tgt, 0.06)
				if position.distance_to(tgt) < 10.0:
					state = State.PERCH
					timer = randf_range(2.5, 5.0)
		State.PERCH:
			if not is_instance_valid(target_block):
				_leave()
			else:
				position = _perch_world()
				# 앉은 쪽에 아래로 힘 → 토크 → 그 쪽으로 미세하게 기욺
				target_block.apply_force(Vector2(0, WEIGHT),
					Vector2(_side * target_block.block_size.x * 0.28, 0))
				timer -= delta
				if timer <= 0.0:
					_leave()
		State.FLY_OUT:
			position += vel * delta
			timer -= delta
			if timer <= 0.0:
				queue_free()
	queue_redraw()


func _leave() -> void:
	if state == State.FLY_OUT:
		return
	state = State.FLY_OUT
	vel = Vector2(_side * 280.0, -240.0)
	timer = 2.2
	left.emit()


func _draw() -> void:
	var col := Color(0.13, 0.13, 0.18)
	var w := sin(flap) * 11.0
	draw_line(Vector2(0, -2), Vector2(-15, -2 - w), col, 3.0)   # 날개
	draw_line(Vector2(0, -2), Vector2(15, -2 - w), col, 3.0)
	draw_circle(Vector2.ZERO, 8.5, col)                        # 몸통
	draw_circle(Vector2(_side * 7.0, -4.0), 5.0, col)          # 머리
	draw_line(Vector2(_side * 11.0, -4.0), Vector2(_side * 17.0, -3.0),
		Color(0.95, 0.65, 0.2), 2.0)                          # 부리
