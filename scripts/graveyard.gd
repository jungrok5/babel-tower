extends Node
## Graveyard (autoload)
## "역대 유저들의 실패한 바벨탑 무덤" — 과거 도전의 '실제 높이(m)'를 블록 타입별로 저장한다.
## 랭킹/최고 기록은 블록 타입마다 따로 관리된다(앞으로 붙일 온라인 랭킹과 동일 구조).

const SAVE_PATH := "user://graveyard.json"
const MAX_RECORDS := 50

# id -> { "best": int(m), "records": Array[int] }  (records: 최근 것이 뒤)
var by_type: Dictionary = {}
var tutorial_seen: bool = false      # 조작 튜토리얼을 봤는가


func _ready() -> void:
	_load()


func set_tutorial_seen() -> void:
	tutorial_seen = true
	_save()


func _bucket(type_id: String) -> Dictionary:
	if not by_type.has(type_id):
		by_type[type_id] = {"best": 0, "records": []}
	return by_type[type_id]


## 붕괴한 탑의 높이(m)를 해당 타입 기록에 추가
func add_record(type_id: String, meters: int) -> void:
	var e := _bucket(type_id)
	e["records"].append(meters)
	if e["records"].size() > MAX_RECORDS:
		e["records"] = e["records"].slice(e["records"].size() - MAX_RECORDS)
	e["best"] = maxi(int(e["best"]), meters)
	_save()


func best_for(type_id: String) -> int:
	if not by_type.has(type_id):
		return 0
	return int(by_type[type_id].get("best", 0))


## 무덤 화면에 보여줄 최근 잔해들(해당 타입, 최신순)
func recent(type_id: String, count: int = 6) -> Array:
	if not by_type.has(type_id):
		return []
	var out: Array = by_type[type_id]["records"].duplicate()
	out.reverse()
	return out.slice(0, count)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_DICTIONARY:
		by_type = data.get("by_type", {})
		tutorial_seen = bool(data.get("tutorial_seen", false))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"by_type": by_type, "tutorial_seen": tutorial_seen}))
	f.close()
