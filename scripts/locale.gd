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
		"tut_still": "③ Off-balance towers fall — stack slowly and true",
		"tut_hint": "(Stack as high as you can)",
		"go_title": "COLLAPSE",
		"go_line1": "You built a name to reach the heavens,\nyet Babel scattered in the end.",
		"go_this": "[%s]  This run  %d m",
		"go_best": "Best here  %d m",
		"go_graveyard": "— Past %s ruins —",
		"hint_play": "Drag to aim, release to drop · Two-finger tap = rotate",
		"blk_brick": "Brick", "blk_box": "Box", "blk_desk": "Desk", "blk_chair": "Chair",
		"blk_cone": "Cone", "blk_bottle": "Bottle", "blk_ball": "Ball", "blk_coin": "Coin",
		"best_short": "Best", "dont_show": "Don't show again", "resume": "Resume",
		"home": "Home", "how_to_replay": "How to play", "version": "Version",
		"inspect_hint": "Drag to preview the sky · up to space",
		"base_title": "Where will you stack?",
		"base_sub": "Each base has its own physics — and its own ranking",
		"back": "Back",
		"base_ground": "Ground", "base_melon": "Melon on water",
		"base_seesaw": "Seesaw", "base_raft": "Raft",
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
		"tut_still": "③ 균형을 잃으면 무너집니다 — 천천히 정확하게",
		"tut_hint": "(최대한 높이 쌓으세요)",
		"go_title": "붕괴",
		"go_line1": "하늘에 닿으려 이름을 쌓았으나,\n바벨은 결국 흩어지고 말았습니다.",
		"go_this": "[%s]  이번 높이  %d m",
		"go_best": "여기 최고 기록  %d m",
		"go_graveyard": "— 역대 %s 잔해 —",
		"hint_play": "끌어서 위치 정하고 떼면 낙하 · 두 손가락 탭 = 회전",
		"blk_brick": "벽돌", "blk_box": "상자", "blk_desk": "책상", "blk_chair": "의자",
		"blk_cone": "고깔", "blk_bottle": "병", "blk_ball": "공", "blk_coin": "동전",
		"best_short": "최고", "dont_show": "다음부터 안 보기", "resume": "계속하기",
		"home": "홈", "how_to_replay": "조작법 보기", "version": "버전",
		"inspect_hint": "드래그로 하늘 미리보기 · 우주까지",
		"base_title": "어디에 쌓을까요?",
		"base_sub": "바닥마다 물리와 랭킹이 따로예요",
		"back": "뒤로",
		"base_ground": "땅", "base_melon": "물 위 참외",
		"base_seesaw": "시소", "base_raft": "뗏목",
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
		"tut_still": "③ バランスを崩すと崩れる — ゆっくり正確に",
		"tut_hint": "（できるだけ高く積もう）",
		"go_title": "崩壊",
		"go_line1": "天に届こうと名を積み上げたが、\nバベルは結局散らされた。",
		"go_this": "[%s]  今回の高さ  %d m",
		"go_best": "ここの最高記録  %d m",
		"go_graveyard": "— これまでの %s の残骸 —",
		"hint_play": "ドラッグで位置、離すと落下 · 二本指タップ=回転",
		"blk_brick": "レンガ", "blk_box": "箱", "blk_desk": "机", "blk_chair": "椅子",
		"blk_cone": "コーン", "blk_bottle": "びん", "blk_ball": "ボール", "blk_coin": "コイン",
		"best_short": "最高", "dont_show": "次回から表示しない", "resume": "続ける",
		"home": "ホーム", "how_to_replay": "操作方法", "version": "バージョン",
		"inspect_hint": "ドラッグで空をプレビュー · 宇宙まで",
		"base_title": "どこに積む？",
		"base_sub": "土台ごとに物理もランキングも別々",
		"back": "戻る",
		"base_ground": "地面", "base_melon": "水に浮くマクワ",
		"base_seesaw": "シーソー", "base_raft": "いかだ",
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
