extends Node
## Graveyard (autoload)
## "역대 유저들의 실패한 바벨탑 무덤" — 과거 도전들의 높이를 저장한다.
## "당신도 수많은 욕망의 잔해 중 하나가 되었습니다."

const SAVE_PATH := "user://graveyard.json"
const MAX_RECORDS := 50

var records: Array = []   # 과거 붕괴 높이들 (최근 것이 뒤)
var best: int = 0


func _ready() -> void:
	_load()


func add_record(height: int) -> void:
	records.append(height)
	if records.size() > MAX_RECORDS:
		records = records.slice(records.size() - MAX_RECORDS)
	best = maxi(best, height)
	_save()


## 무덤 화면에 보여줄 최근 잔해들 (최신순)
func recent(count: int = 6) -> Array:
	var out: Array = records.duplicate()
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
		records = data.get("records", [])
		best = int(data.get("best", 0))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"records": records, "best": best}))
	f.close()
