# Babel Tower

> 기기를 최대한 **움직이지 않고** 탑을 쌓는 인내의 게임.
> 탑이 흔들리는 게 아니라, **나의 손**이 흔들려서 탑이 무너진다.

Godot 4.7로 만든 "정지(Stillness)" 메카닉 기반 바벨탑 스택 게임.
웹으로 먼저 테스트하고, 이후 Android/iOS로 서비스하는 것을 목표로 한다.

📄 상세 기획은 [`GAME_DESIGN.md`](./GAME_DESIGN.md) 참고.

---

## 조작

- **탭 / 클릭 / Space** — 벽돌 낙하
- 그 다음엔 **가만히.** 기기(또는 마우스)를 움직일수록 탑이 흔들리고, 높아질수록 치명적이다.

## 입력 방식 (플랫폼별 자동)

| 환경 | 흔들림 감지 | 방식 |
|---|---|---|
| Android / iOS 네이티브 앱 | 자이로 + 가속도 | Godot `Input` 센서 |
| **모바일 브라우저 (웹)** | **자이로 + 가속도** | **JS `devicemotion` 브리지** (HTTPS 필요, 보정 화면의 **"센서 켜기"** 버튼에서 권한 요청) |
| 데스크톱 브라우저 | 마우스 움직임 = 손떨림 | 하드웨어 센서가 없는 PC용 폴백 |

> Godot 웹 익스포트는 내장 `Input.get_gyroscope()`로 브라우저 센서를 안정적으로
> 못 주기 때문에, 웹에서는 `JavaScriptBridge`로 브라우저의 `devicemotion`을 직접 연결한다.

## 로컬에서 실행

1. [Godot 4.7](https://godotengine.org/download) 설치
2. 이 폴더의 `project.godot` 열기
3. ▶ (F5) 실행

## 웹으로 익스포트 (수동)

1. Godot 에디터 → **Project → Export**
2. **Web** 프리셋 선택 (`export_presets.cfg`에 이미 구성됨) → *Export Project*
3. `build/web/index.html` 생성
4. 반드시 **HTTPS 로컬 서버**로 서빙 (파일 직접 열기 ❌):
   ```bash
   python3 -m http.server 8000 --directory build/web
   ```
   모바일 센서 테스트는 HTTPS가 필요하므로 배포본(GitHub Pages)에서 확인하는 걸 권장.

## 웹 자동 배포 (GitHub Pages)

`.github/workflows/deploy-web.yml`이 push마다 자동으로 웹 빌드 → Pages 게시.

1. GitHub 저장소 **Settings → Pages → Source**를 **"GitHub Actions"**로 설정
2. `main` 또는 개발 브랜치에 push하면 자동 익스포트/배포
3. Actions 탭의 배포 URL에서 확인 (모바일은 그 HTTPS 주소로 접속하면 자이로 동작)

> Godot 버전을 바꾸려면 워크플로 상단 `GODOT_VERSION`만 수정.

## 모바일 익스포트 (서비스용)

`export_presets.cfg`에 Android/iOS 프리셋과 센서 권한이 미리 구성돼 있다.
Godot의 각 플랫폼 익스포트 템플릿/서명 설정 후:

- **Android**: Project → Export → Android → `.apk`/`.aab`
- **iOS**: Project → Export → iOS → Xcode 프로젝트 → 서명·아카이브

## 구조

```
project.godot                  # Godot 4.7 프로젝트 설정 + autoload
scenes/Main.tscn               # 루트 (스크립트가 나머지를 코드로 생성)
scripts/
  main.gd                      # 게임 매니저: 상태·물리·카메라·UI
  block.gd                     # 벽돌 (RigidBody2D)
  motion_sensor.gd  (autoload) # 정지 감지 3단 폴백 → get_sway()/get_shake()
  graveyard.gd      (autoload) # 과거 붕괴 높이 "무덤" 저장
export_presets.cfg             # Web / Android / iOS 프리셋
.github/workflows/deploy-web.yml
```

## 상태

**v0.1 프로토타입** — 코어 루프(보정 → 낙하·안착 → 붕괴 → 무덤 → 재도전),
높이별 줌아웃 공포, 카메라 셰이크, 햅틱, 최고 기록 구현.
사운드스케이프·재료 시스템·난이도 UI는 로드맵 참고.
