extends Node
## Locale (autoload) — 다국어(i18n).
## 지금은 영어/한국어(+일본어 일부). 언어 추가는 STRINGS에 코드별 사전을 넣기만 하면 된다(100개국 대비).
## 문자열은 키로 참조: Locale.t("start"). 없는 키/언어는 영어 → 키 순으로 폴백.

signal changed

var lang: String = "en"

# 언어 선택 UI 목록 (코드, 자국어 표기, 영어명). 번역이 없는 언어는 영어로 폴백(추후 채움).
const LANGUAGES := [
	["en", "English", "English"],
	["ko", "한국어", "Korean"],
	["ja", "日本語", "Japanese"],
	["zh", "中文", "Chinese"],
	["es", "Español", "Spanish"],
	["fr", "Français", "French"],
	["de", "Deutsch", "German"],
	["pt", "Português", "Portuguese"],
	["ru", "Русский", "Russian"],
	["hi", "हिन्दी", "Hindi"],
	["ar", "العربية", "Arabic"],
	["id", "Bahasa Indonesia", "Indonesian"],
	["vi", "Tiếng Việt", "Vietnamese"],
	["th", "ไทย", "Thai"],
	["tr", "Türkçe", "Turkish"],
	["it", "Italiano", "Italian"],
]

const STRINGS := {
	"en": {
		"select_title": "What will you stack?",
		"select_sub": "Each block keeps its own difficulty and best record",
		"leaderboard": "Ranking",
		"view_leaderboard": "Leaderboard",
		"how_to": "How to play",
		"settings": "Settings",
		"close": "Close",
		"retry": "Play again",
		"change_block": "Change block",
		"start": "Start",
		"sound": "Sound",
		"haptic": "Vibration",
		"language": "Language",
		"google_play": "Google Play",
		"connect": "Connect",
		"connected": "Connected",
		"on": "On",
		"off": "Off",
		"col_rank": "Rank",
		"col_name": "Name",
		"col_height": "Height",
		"you": "You",
		"record_break": "New record!",
		"milestone": "%d m!",
		"share": "Share result",
		"search": "Search language",
		"tut_title": "How to play",
		"tut_drag": "① Drag to set the position, release to drop",
		"tut_rotate": "② Two-finger tap rotates the block 45°",
		"tut_still": "③ Keep the device level — it topples if you shake",
		"tut_hint": "(Stack as high as you can on the altar)",
		"go_title": "COLLAPSE",
		"go_line1": "You too became one of\ncountless ruins of ambition.",
		"go_this": "[%s]  This run  %d m",
		"go_best": "Best for this block  %d m",
		"go_graveyard": "— Past %s ruins —",
		"hint_play": "Drag to aim, release to drop · Two-finger tap = rotate\nKeep the device level — tilting shifts the floor",
		"calib_wait": "Hold the device\nin your most comfortable pose\n\n· calibrating ·",
		"sensor_prompt": "Turn on the sensor\nto start stacking\n\n(please allow motion access)",
		"sensor_on": "Turn on sensor",
		"blk_brick": "Brick", "blk_box": "Box", "blk_desk": "Desk", "blk_chair": "Chair",
		"blk_book": "Book", "blk_log": "Log", "blk_ball": "Ball",
		"best_short": "Best", "dont_show": "Don't show again", "resume": "Resume",
		"home": "Home", "how_to_replay": "How to play", "version": "Version",
	},
	"ko": {
		"select_title": "무엇을 쌓을까요?",
		"select_sub": "블록마다 난이도와 최고 기록이 따로 관리됩니다",
		"leaderboard": "랭킹",
		"view_leaderboard": "랭킹 보기",
		"how_to": "조작법",
		"settings": "설정",
		"close": "닫기",
		"retry": "다시 쌓기",
		"change_block": "블록 바꾸기",
		"start": "시작하기",
		"sound": "사운드",
		"haptic": "진동",
		"language": "언어",
		"google_play": "구글 플레이",
		"connect": "연결",
		"connected": "연결됨",
		"on": "켜짐",
		"off": "꺼짐",
		"col_rank": "순위",
		"col_name": "이름",
		"col_height": "높이",
		"you": "나",
		"record_break": "최고 기록 갱신!",
		"milestone": "%d m 돌파!",
		"share": "결과 공유",
		"search": "언어 검색",
		"tut_title": "조작 방법",
		"tut_drag": "① 끌어서 좌우 위치를 정하고 떼면 놓기",
		"tut_rotate": "② 두 손가락 탭하면 블록이 45° 회전",
		"tut_still": "③ 기기를 수평으로! 흔들리면 무너집니다",
		"tut_hint": "(제단 위로 최대한 높이 쌓으세요)",
		"go_title": "붕괴",
		"go_line1": "당신도 수많은 욕망의\n잔해 중 하나가 되었습니다.",
		"go_this": "[%s]  이번 높이  %d m",
		"go_best": "이 블록 최고 기록  %d m",
		"go_graveyard": "— 역대 %s 잔해 —",
		"hint_play": "끌어서 위치 정하고 떼면 낙하 · 두 손가락 탭 = 회전\n기기를 수평으로 — 기울이면 바닥이 움직여 탑이 쏠립니다",
		"calib_wait": "가장 편안한 자세로\n기기를 잡으세요\n\n· 보정 중 ·",
		"sensor_prompt": "센서를 켜고\n탑 쌓기를 시작하세요\n\n(모션 권한을 허용해 주세요)",
		"sensor_on": "센서 켜기",
		"blk_brick": "벽돌", "blk_box": "상자", "blk_desk": "책상", "blk_chair": "의자",
		"blk_book": "책", "blk_log": "통나무", "blk_ball": "공",
		"best_short": "최고", "dont_show": "다음부터 안 보기", "resume": "계속하기",
		"home": "홈", "how_to_replay": "조작법 보기", "version": "버전",
	},
	"ja": {
		"select_title": "何を積みますか？",
		"select_sub": "ブロックごとに難易度と最高記録が別々に管理されます",
		"leaderboard": "ランキング",
		"view_leaderboard": "ランキング",
		"how_to": "操作方法",
		"settings": "設定",
		"close": "閉じる",
		"retry": "もう一度",
		"change_block": "ブロック変更",
		"start": "スタート",
		"sound": "サウンド",
		"haptic": "バイブ",
		"language": "言語",
		"google_play": "Google Play",
		"connect": "接続",
		"connected": "接続済み",
		"on": "オン",
		"off": "オフ",
		"col_rank": "順位",
		"col_name": "名前",
		"col_height": "高さ",
		"you": "あなた",
		"record_break": "自己ベスト更新！",
		"milestone": "%d m 突破！",
		"share": "結果を共有",
		"search": "言語を検索",
		"tut_title": "操作方法",
		"tut_drag": "① ドラッグで左右位置を決めて離すと置く",
		"tut_rotate": "② 二本指タップでブロックが45°回転",
		"tut_still": "③ 端末を水平に！ 揺れると崩れます",
		"tut_hint": "（祭壇の上にできるだけ高く積もう）",
		"go_title": "崩壊",
		"go_line1": "あなたも数多の欲望の\n残骸の一つになった。",
		"go_this": "[%s]  今回の高さ  %d m",
		"go_best": "このブロックの最高記録  %d m",
		"go_graveyard": "— これまでの %s の残骸 —",
		"hint_play": "ドラッグで位置、離すと落下 · 二本指タップ=回転\n端末を水平に — 傾けると床が動いて塔が傾く",
		"calib_wait": "一番楽な姿勢で\n端末を持ってください\n\n· 調整中 ·",
		"sensor_prompt": "センサーをオンにして\n積み始めましょう\n\n(モーション権限を許可してください)",
		"sensor_on": "センサーオン",
		"blk_brick": "レンガ", "blk_box": "箱", "blk_desk": "机", "blk_chair": "椅子",
		"blk_book": "本", "blk_log": "丸太", "blk_ball": "ボール",
		"best_short": "最高", "dont_show": "次回から表示しない", "resume": "続ける",
		"home": "ホーム", "how_to_replay": "操作方法", "version": "バージョン",
	},
}


func t(key: String) -> String:
	var d: Dictionary = STRINGS.get(lang, STRINGS["en"])
	if d.has(key):
		return d[key]
	if STRINGS["en"].has(key):
		return STRINGS["en"][key]
	return key


func set_lang(code: String) -> void:
	if code == lang:
		return
	lang = code
	changed.emit()


## 번역이 준비된 언어인가 (선택 UI에서 표시용)
func is_ready(code: String) -> bool:
	return STRINGS.has(code)


## 시스템 언어에 맞는 기본값
func system_default() -> String:
	var loc := OS.get_locale().to_lower()
	for l in LANGUAGES:
		if loc.begins_with(l[0]):
			return l[0]
	return "en"
