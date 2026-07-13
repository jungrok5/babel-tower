extends Node2D
class_name TowerBase
## 쌓아 올릴 "바닥" 물리 리그. 자이로 없이 바닥 종류마다 다른 물리로 난이도를 낸다.
##   ground      : 고정 지면 + 돌 제단(안정)
##   water_melon : 물 위에 뜬 참외(부력·무게 실리면 가라앉고 기우뚱)
##   water_raft  : 물 위 뗏목(넓고 평평, 좌우로 롤링)
##   seesaw      : 받침점 위 널빤지(무게중심 벗어나면 기울어짐)
##
## main이 쓰는 인터페이스:
##   support_top_y()  현재 지지면(첫 블록이 얹히는 면)의 월드 y
##   base_line_y      높이 측정 기준(고정)
##   kill_y()         이 y보다 아래로 내려간 블록 = 붕괴(지면/수면)

const BASE_X := 360.0
const GROUND_Y := 1050.0
const WATER_Y := 1015.0
# 물 붕괴선은 수면보다 한참 아래 — 하중으로 배가 출렁이며 수면에 살짝 잠기는 건 붕괴 아님.
# 블록이 이 깊이까지 '가라앉아야'(떨어져 나갔거나 배가 완전히 침몰) 붕괴로 본다.
const WATER_KILL := WATER_Y + 150.0

var kind := "ground"
var support_body: PhysicsBody2D = null
var base_line_y := 988.0
var _kill_y := GROUND_Y
var _support_off := 0.0          # 지지체 중심 → 윗면 거리
var _ground_fixed_top := 988.0   # ground: 제단 윗면(고정)

# 부력 파라미터
var _float := false
var _samples := 7
var _half_w := 60.0
var _keel := 78.0                # 지지체 중심 → 바닥(키일)
var _buoy_k := 5.0               # 선형(수면 근처 부드럽게)
var _buoy_k2 := 0.5              # 2차(깊이 들어가면 뻣뻣하게 저항 → 많이 실어도 잘 안 잠김)
var _center_k := 8.0             # 가로 중앙 복원(천천히)


func setup(kindname: String) -> void:
	kind = kindname
	match kind:
		"water_melon": _build_melon()
		"water_raft": _build_raft()
		"seesaw": _build_seesaw()
		_: _build_ground()


## 지지면(첫 블록이 얹히는 면)의 현재 월드 y
func support_top_y() -> float:
	if kind == "ground":
		return _ground_fixed_top
	if support_body != null and is_instance_valid(support_body):
		return support_body.global_position.y - _support_off
	return base_line_y


func kill_y() -> float:
	return _kill_y


func _physics_process(_delta: float) -> void:
	if _float and support_body != null and is_instance_valid(support_body):
		_apply_buoyancy(support_body)


func _apply_buoyancy(body: RigidBody2D) -> void:
	var xf := body.global_transform
	var com := body.global_position
	for i in _samples:
		var fx := lerpf(-_half_w, _half_w, float(i) / float(_samples - 1))
		var wp: Vector2 = xf * Vector2(fx, _keel)
		var d := wp.y - WATER_Y
		if d > 0.0:
			var up := _buoy_k * d + _buoy_k2 * d * d
			body.apply_force(Vector2(0.0, -up), wp - com)
	# 가로로 흘러가지 않게 중앙으로 아주 약하게 복원
	body.apply_central_force(Vector2((BASE_X - com.x) * _center_k, 0.0))


# ---------------------------------------------------------------- 땅 (고정)

func _build_ground() -> void:
	var g := _build_ground_plate()
	# 돌 제단(초석) — 충돌 + 비주얼
	var fcs := CollisionShape2D.new()
	var fshape := RectangleShape2D.new()
	fshape.size = Vector2(180.0, 62.0)
	fcs.shape = fshape
	fcs.position = Vector2(BASE_X, 988.0 - 31.0)   # 윗면 988
	g.add_child(fcs)
	_build_pedestal(Vector2(BASE_X, 1050.0))
	_build_ground_decor()
	support_body = g
	_ground_fixed_top = 988.0
	base_line_y = 988.0
	_kill_y = GROUND_Y


## 흙+잔디 정적 지면 (땅·시소 공용). 충돌 지면 + 비주얼.
func _build_ground_plate() -> StaticBody2D:
	var g := StaticBody2D.new()
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.0
	g.physics_material_override = mat
	var cs := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = Vector2(4200.0, 200.0)
	cs.shape = shp
	cs.position = Vector2(BASE_X, GROUND_Y + 100.0)
	g.add_child(cs)
	add_child(g)
	g.add_child(_rect_poly(Vector2(BASE_X, GROUND_Y + 1000.0), Vector2(4200.0, 2000.0), Color(0.34, 0.24, 0.14)))
	g.add_child(_rect_poly(Vector2(BASE_X, GROUND_Y + 22.0), Vector2(4200.0, 26.0), Color(0.26, 0.40, 0.16)))
	g.add_child(_rect_poly(Vector2(BASE_X, GROUND_Y + 6.0), Vector2(4200.0, 14.0), Color(0.36, 0.56, 0.22)))
	return g


func _build_pedestal(base_pt: Vector2) -> void:
	var foot := Color(0.30, 0.29, 0.34)
	var body := Color(0.40, 0.39, 0.45)
	var cap := Color(0.50, 0.49, 0.55)
	add_child(_rect_poly(base_pt + Vector2(0, -10.0), Vector2(232, 24), foot))
	add_child(_rect_poly(base_pt + Vector2(0, -33.0), Vector2(188, 50), body))
	add_child(_rect_poly(base_pt + Vector2(-45.0, -33.0), Vector2(3, 50), body.darkened(0.25)))
	add_child(_rect_poly(base_pt + Vector2(45.0, -33.0), Vector2(3, 50), body.darkened(0.25)))
	add_child(_rect_poly(base_pt + Vector2(0, -59.0), Vector2(206, 16), cap))
	add_child(_rect_poly(base_pt + Vector2(0, -65.0), Vector2(206, 4), cap.lightened(0.18)))


func _build_ground_decor() -> void:
	var leaf := Color(0.34, 0.58, 0.24)
	var leaf_hi := Color(0.46, 0.70, 0.30)
	var rock := Color(0.55, 0.56, 0.63)
	for bx in [BASE_X - 300.0, BASE_X + 320.0]:
		for o in [Vector2(-26, -4), Vector2(26, -4), Vector2(0, -22), Vector2(-48, 2), Vector2(48, 2)]:
			add_child(_circle_poly(Vector2(bx, GROUND_Y - 14) + o, 26.0, leaf))
		add_child(_circle_poly(Vector2(bx - 10, GROUND_Y - 30), 15.0, leaf_hi))
	for rx in [BASE_X - 190.0, BASE_X + 230.0]:
		add_child(_circle_poly(Vector2(rx, GROUND_Y - 10), 22.0, rock, 6))
		add_child(_circle_poly(Vector2(rx - 6, GROUND_Y - 16), 9.0, rock.lightened(0.18), 6))
	for gx in [-460.0, -360.0, -120.0, -70.0, 90.0, 150.0, 400.0, 470.0]:
		_add_grass_tuft(BASE_X + gx, leaf, leaf_hi)


func _add_grass_tuft(x: float, col: Color, hi: Color) -> void:
	for dx in [-9.0, 0.0, 9.0]:
		var blade := Polygon2D.new()
		var tip := Vector2(x + dx * 1.6, GROUND_Y + 2.0 - 26.0 - absf(dx) * 0.4)
		blade.polygon = PackedVector2Array([
			Vector2(x + dx - 5, GROUND_Y + 2.0), Vector2(x + dx + 5, GROUND_Y + 2.0), tip])
		blade.color = hi if dx == 0.0 else col
		add_child(blade)


# ---------------------------------------------------------------- 물 위 참외

func _build_melon() -> void:
	_build_water()
	var r := 78.0
	var melon := RigidBody2D.new()
	melon.position = Vector2(BASE_X, 958.0)
	var cs := CollisionShape2D.new()
	var shp := CircleShape2D.new()
	shp.radius = r
	cs.shape = shp
	melon.add_child(cs)
	# 윗면 평평한 받침 — 둥근 참외 위에도 블록/동전이 얹히도록 넓은 플랫폼
	var topcs := CollisionShape2D.new()
	var tshape := RectangleShape2D.new()
	tshape.size = Vector2(104.0, 14.0)
	topcs.shape = tshape
	topcs.position = Vector2(0, -r + 6.0)
	melon.add_child(topcs)
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.0
	melon.physics_material_override = mat
	melon.mass = 1.7
	melon.linear_damp = 3.2
	melon.angular_damp = 11.0
	melon.gravity_scale = 1.0
	melon.can_sleep = false
	# 참외 비주얼(노랑 몸통 + 세로 줄무늬 + 꼭지 + 하이라이트)
	melon.add_child(_circle_poly(Vector2.ZERO, r, Color(0.93, 0.82, 0.30), 26))
	for sx in [-46.0, -18.0, 12.0, 40.0]:
		melon.add_child(_rect_poly(Vector2(sx, 0), Vector2(9, r * 1.7), Color(0.86, 0.74, 0.22)))
	melon.add_child(_circle_poly(Vector2(0, 0), r, Color(0.20, 0.18, 0.12), 26, true))  # 외곽선
	melon.add_child(_circle_poly(Vector2(-24, -26), 20.0, Color(0.99, 0.92, 0.55)))
	melon.add_child(_rect_poly(Vector2(6, -r - 6), Vector2(10, 20), Color(0.42, 0.55, 0.25)))  # 꼭지
	add_child(melon)
	# 물 표면을 참외 아래쪽 위에 덮어 '물에 잠긴' 느낌 (참외 다음에 그려 아랫부분을 가림)
	_draw_water_surface()
	support_body = melon
	_support_off = r
	_float = true
	_samples = 9
	_half_w = 70.0
	_keel = r
	_buoy_k = 11.0
	_buoy_k2 = 1.6
	_center_k = 14.0
	base_line_y = 958.0 - r + 12.0
	_kill_y = WATER_KILL


# ---------------------------------------------------------------- 물 위 뗏목

func _build_raft() -> void:
	_build_water()
	var hw := 140.0
	var hh := 20.0
	var raft := RigidBody2D.new()
	raft.position = Vector2(BASE_X, 992.0)
	var cs := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = Vector2(hw * 2.0, hh * 2.0)
	cs.shape = shp
	raft.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.95
	mat.bounce = 0.0
	raft.physics_material_override = mat
	raft.mass = 2.2
	raft.linear_damp = 2.8
	raft.angular_damp = 8.0
	raft.gravity_scale = 1.0
	raft.can_sleep = false
	# 통나무 뗏목 비주얼
	raft.add_child(_rect_poly(Vector2(0, 2), Vector2(hw * 2.0, hh * 2.0), Color(0.55, 0.40, 0.24)))
	for lx in range(-2, 3):
		raft.add_child(_rect_poly(Vector2(lx * 56.0, -hh), Vector2(50, 12), Color(0.62, 0.46, 0.28)))
		raft.add_child(_circle_poly(Vector2(lx * 56.0, -hh), 6.0, Color(0.70, 0.54, 0.34)))
	raft.add_child(_rect_poly(Vector2(0, -hh - 6), Vector2(hw * 2.0, 5), Color(0.66, 0.5, 0.3)))
	add_child(raft)
	_draw_water_surface()
	support_body = raft
	_support_off = hh + 12.0
	_float = true
	_samples = 9
	_half_w = hw - 16.0
	_keel = hh
	_buoy_k = 12.0
	_buoy_k2 = 1.1
	_center_k = 14.0
	base_line_y = 992.0 - hh - 12.0
	_kill_y = WATER_KILL


# ---------------------------------------------------------------- 시소

func _build_seesaw() -> void:
	_build_ground_plate()
	# 받침점(고정) — 핀 조인트 앵커 + 삼각형 비주얼
	var fulcrum := StaticBody2D.new()
	fulcrum.position = Vector2(BASE_X, 992.0)
	add_child(fulcrum)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(BASE_X - 40, GROUND_Y), Vector2(BASE_X + 40, GROUND_Y), Vector2(BASE_X, 984.0)])
	tri.color = Color(0.46, 0.42, 0.48)
	add_child(tri)
	# 널빤지(강체)
	var plank := RigidBody2D.new()
	plank.position = Vector2(BASE_X, 978.0)
	var cs := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = Vector2(300.0, 26.0)
	cs.shape = shp
	plank.add_child(cs)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.95
	mat.bounce = 0.0
	plank.physics_material_override = mat
	plank.mass = 3.0
	plank.angular_damp = 2.2
	plank.linear_damp = 0.4
	plank.gravity_scale = 1.0
	plank.can_sleep = false
	plank.add_child(_rect_poly(Vector2(0, 0), Vector2(300, 26), Color(0.60, 0.44, 0.26)))
	plank.add_child(_rect_poly(Vector2(0, -8), Vector2(300, 6), Color(0.70, 0.52, 0.32)))
	add_child(plank)
	var joint := PinJoint2D.new()
	joint.position = Vector2(BASE_X, 992.0)
	add_child(joint)
	joint.node_a = plank.get_path()
	joint.node_b = fulcrum.get_path()
	support_body = plank
	_support_off = 13.0
	base_line_y = 965.0
	_kill_y = GROUND_Y


# ---------------------------------------------------------------- 물 비주얼

func _build_water() -> void:
	# 깊은 물(불투명). 참외/뗏목 앞에 표면을 덮는 건 _draw_water_surface에서.
	add_child(_rect_poly(Vector2(BASE_X, WATER_Y + 1500.0), Vector2(4200.0, 3000.0), Color(0.16, 0.42, 0.62)))


func _draw_water_surface() -> void:
	# 참외/뗏목보다 뒤(이 함수는 그것들 다음에 add되므로 앞에 그려짐) — 잠긴 부분을 가려 '물에 잠김' 표현
	add_child(_rect_poly(Vector2(BASE_X, WATER_Y + 1500.0), Vector2(4200.0, 3000.0), Color(0.18, 0.46, 0.66, 0.86)))
	add_child(_rect_poly(Vector2(BASE_X, WATER_Y + 3.0), Vector2(4200.0, 6.0), Color(0.62, 0.82, 0.92, 0.7)))


# ---------------------------------------------------------------- 그리기 헬퍼

func _rect_poly(center: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	p.polygon = PackedVector2Array([
		center + Vector2(-hw, -hh), center + Vector2(hw, -hh),
		center + Vector2(hw, hh), center + Vector2(-hw, hh)])
	p.color = color
	return p


## outline=true면 채우지 않고 테두리만(Line2D 근사).
func _circle_poly(center: Vector2, r: float, color: Color, seg: int = 16, outline: bool = false) -> Node2D:
	if outline:
		var l := Line2D.new()
		l.width = 3.0
		l.default_color = color
		l.closed = true
		var pts := PackedVector2Array()
		for i in seg:
			var a := TAU * float(i) / float(seg)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		l.points = pts
		return l
	var p := Polygon2D.new()
	var poly := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		poly.append(center + Vector2(cos(a), sin(a)) * r)
	p.polygon = poly
	p.color = color
	return p
