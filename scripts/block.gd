extends RigidBody2D
class_name Block
## 탑을 이루는 물품 하나(벽돌·상자·책상·의자·공 등).
## 타입 정의(parts)에 따라 여러 충돌 형태가 합쳐진 물리 강체가 된다.
## 물리 강체이지만, 기기가 "정지" 상태이면 마찰로 안정적으로 쌓인다.

signal landed                       ## 처음 무언가에 닿는 순간(=착지) 발생

var type_def: Dictionary = {}
var bbox: Vector2 = Vector2(180.0, 62.0)      ## 회전/높이 계산용 대략 경계 크기
var tint: Color = Color(0.82, 0.76, 0.62)     ## 먼지 등에 쓰는 대표 색
var _friction: float = 0.42
var _bounce: float = 0.0
var _mass: float = 2.0
var _landed := false


func setup(t: Dictionary) -> void:
	type_def = t
	bbox = t.get("bbox", Vector2(180.0, 62.0))
	_friction = t.get("friction", 0.42)
	_bounce = t.get("bounce", 0.0)
	_mass = t.get("mass", 2.0)
	var parts: Array = t.get("parts", [])
	if parts.size() > 0:
		tint = parts[0]["color"]


func has_landed() -> bool:
	return _landed


func _ready() -> void:
	# 타입의 각 파트를 충돌 형태로 추가(합성 콜라이더)
	for p in type_def.get("parts", []):
		var cs := CollisionShape2D.new()
		match p["kind"]:
			"rect":
				var rect: Rect2 = p["rect"]
				var rshape := RectangleShape2D.new()
				rshape.size = rect.size
				cs.shape = rshape
				cs.position = rect.position + rect.size * 0.5
			"circle":
				var cshape := CircleShape2D.new()
				cshape.radius = p["r"]
				cs.shape = cshape
				cs.position = p["pos"]
			"poly":
				var pshape := ConvexPolygonShape2D.new()
				pshape.points = PackedVector2Array(p["pts"])   # 이미 블록 로컬 좌표
				cs.shape = pshape
		add_child(cs)

	var mat := PhysicsMaterial.new()
	# 마찰: 너무 높으면 바닥에 딱 붙어 통째로 기울기만 하고 안 넘어진다.
	mat.friction = _friction
	mat.bounce = _bounce
	physics_material_override = mat

	mass = _mass
	# 댐핑으로 미세 진동을 가라앉혀 '묵직한' 느낌을 준다.
	linear_damp = 0.7
	angular_damp = 1.4
	# 엔진 중력 사용, 가만히 있으면 잠들어(sleep) 떨림 제거.
	gravity_scale = 1.0
	can_sleep = true
	# 빠르게 떨어질 때 서로 뚫는 것 방지
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# 착지 감지
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(_body: Node) -> void:
	if _landed:
		return
	_landed = true
	_spawn_dust()
	_flash()
	landed.emit()


## 착지 먼지 파티클 — 블록 좌우 양끝에서 뿜는다(타격감)
func _spawn_dust() -> void:
	for sx in [-1.0, 1.0]:
		_dust_at(Vector2(sx * bbox.x * 0.5, bbox.y * 0.5), sx)


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
	p.color = tint.lightened(0.12)
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## 착지 순간 밝게 번쩍
func _flash() -> void:
	self_modulate = Color(1.5, 1.45, 1.3)
	var tw := create_tween()
	tw.tween_property(self, "self_modulate", Color.WHITE, 0.18)


func _draw() -> void:
	BlockTypes.draw_parts(self, type_def, 1.0)
