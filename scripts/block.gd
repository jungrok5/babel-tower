extends RigidBody2D
class_name Block
## 탑을 이루는 벽돌 한 장.
## 물리 강체이지만, 기기가 "정지" 상태이면 마찰로 안정적으로 쌓인다.
## 흔들리는 순간 상단 벽돌부터 회전하며 무너진다.

signal landed                       ## 처음 무언가에 닿는 순간(=착지) 발생

var block_size: Vector2 = Vector2(180.0, 62.0)
var block_color: Color = Color(0.82, 0.76, 0.62)
var _landed := false


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
	# 마찰: 너무 높으면 바닥에 딱 붙어 통째로 기울기만 하고 안 넘어진다.
	# 낮춰서 경사에서 상단 블록이 실제로 넘어가게(수평에선 미끄러지지 않음).
	mat.friction = 0.42
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
	# 착지 감지용 접촉 모니터
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(_body: Node) -> void:
	if _landed:
		return
	_landed = true
	_spawn_dust()
	_flash()
	landed.emit()


## 착지 먼지 파티클 (타격감) — 블록 좌우 양끝(블록끼리 만나는 지점)에서 뿜는다
func _spawn_dust() -> void:
	for sx in [-1.0, 1.0]:
		_dust_at(Vector2(sx * block_size.x * 0.5, block_size.y * 0.5), sx)


func _dust_at(pos: Vector2, sx: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 10
	p.lifetime = 0.5
	p.direction = Vector2(sx * 0.6, -1)     # 바깥+위로 퍼짐
	p.spread = 55.0
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = block_color.lightened(0.12)
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## 착지 순간 밝게 번쩍
func _flash() -> void:
	self_modulate = Color(1.5, 1.45, 1.3)
	var tw := create_tween()
	tw.tween_property(self, "self_modulate", Color.WHITE, 0.18)


func _draw() -> void:
	var r := Rect2(-block_size * 0.5, block_size)
	draw_rect(r, block_color)
	draw_rect(r, block_color.darkened(0.4), false, 3.0)
	# 상단 하이라이트 — 돌의 질감
	draw_line(
		Vector2(-block_size.x * 0.5 + 5.0, -block_size.y * 0.5 + 4.0),
		Vector2(block_size.x * 0.5 - 5.0, -block_size.y * 0.5 + 4.0),
		block_color.lightened(0.22), 2.0)
