extends Node
## Settings (autoload) — 사운드/진동/언어/구글플레이 설정. user://에 저장.
## Locale와 연동해 언어를 적용한다.

const SAVE_PATH := "user://settings.json"

var sound_on: bool = true
var haptic_on: bool = true
var gp_connected: bool = false       # 구글 플레이 연결 상태(지금은 목업)


func _ready() -> void:
	var lang := ""
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY:
				sound_on = bool(data.get("sound_on", true))
				haptic_on = bool(data.get("haptic_on", true))
				gp_connected = bool(data.get("gp_connected", false))
				lang = str(data.get("lang", ""))
	# 저장된 언어 없으면 시스템 언어
	Locale.set_lang(lang if lang != "" else Locale.system_default())


func set_sound(v: bool) -> void:
	sound_on = v
	save()


func set_haptic(v: bool) -> void:
	haptic_on = v
	save()


func set_gp(v: bool) -> void:
	gp_connected = v
	save()


func set_lang(code: String) -> void:
	Locale.set_lang(code)
	save()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"sound_on": sound_on, "haptic_on": haptic_on,
		"gp_connected": gp_connected, "lang": Locale.lang}))
	f.close()
