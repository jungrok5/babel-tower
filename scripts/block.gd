extends RigidBody2D
class_name Block
## 탑을 이루는 벽돌 한 장.
## 물리 강체이지만, 기기가 "정지" 상태이면 마찰로 안정적으로 쌓인다.
## 흔들리는 순간 상단 벽돌부터 회전하며 무너진다.

var block_size: Vector2 = Vector2(180.0, 62.0)
var block_color: Color = Color(0.82, 0.76, 0.62)


func setup(size: Vector2, color: Color) -> void:
	block_size = size
	block_color = color


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = block_size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	var mat := PhysicsMaterial.new()
	# 마찰을 낮춰 기울일 때 스택이 '스르륵' 쏠려 보이게 한다(너무 높으면 뻣뻣하다 갑자기 붕괴).
	mat.friction = 0.6
	mat.bounce = 0.0
	physics_material_override = mat

	mass = 2.0
	# 댐핑으로 미세 진동을 가라앉혀 '묵직한 돌' 느낌을 준다.
	linear_damp = 0.7
	angular_damp = 1.4
	# 엔진 중력을 쓴다(방향은 main의 Area2D가 기울기만큼 회전).
	# can_sleep=true → 가만히 있으면 잠들어 물리가 손대지 않는다(떨림 제거).
	gravity_scale = 1.0
	can_sleep = true
	# 빠르게 떨어질 때 벽돌이 서로를 뚫고 지나가는 것 방지
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-block_size * 0.5, block_size)
	draw_rect(r, block_color)
	draw_rect(r, block_color.darkened(0.4), false, 3.0)
	# 상단 하이라이트 — 돌의 질감
	draw_line(
		Vector2(-block_size.x * 0.5 + 5.0, -block_size.y * 0.5 + 4.0),
		Vector2(block_size.x * 0.5 - 5.0, -block_size.y * 0.5 + 4.0),
		block_color.lightened(0.22), 2.0)
