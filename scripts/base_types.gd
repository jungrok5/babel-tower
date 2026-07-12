extends RefCounted
class_name BaseTypes
## 쌓아 올릴 "바닥(base)" 종류 레지스트리.
## 자이로 없이, 바닥마다 다른 물리(고정 지면 / 물 위 부력 / 시소 균형 / 물 위 롤링)로 난이도를 낸다.
## 실제 물리 리그는 base.gd(TowerBase)가 kind로 구성한다.
##
## 필드: id, name(선택), i18n(선택), kind(물리 종류), diff(난이도 계수 · 목업 랭킹 스케일용)

static var _registry: Array = []
static var _loaded: bool = false


static func all() -> Array:
	_ensure()
	return _registry


static func get_type(id: String) -> Dictionary:
	_ensure()
	for t in _registry:
		if t["id"] == id:
			return t
	return _registry[0]


static func index_of(id: String) -> int:
	_ensure()
	for i in _registry.size():
		if _registry[i]["id"] == id:
			return i
	return 0


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for d in _builtins():
		_registry.append(d)


static func _builtins() -> Array:
	return [
		{"id": "ground", "name": "땅", "i18n": "base_ground", "kind": "ground", "diff": 1.0},
		{"id": "melon", "name": "물 위 참외", "i18n": "base_melon", "kind": "water_melon", "diff": 1.7},
		{"id": "seesaw", "name": "시소", "i18n": "base_seesaw", "kind": "seesaw", "diff": 1.9},
		{"id": "raft", "name": "뗏목", "i18n": "base_raft", "kind": "water_raft", "diff": 1.4},
	]
