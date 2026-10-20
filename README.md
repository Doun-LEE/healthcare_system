# FitRoutine

내 헬스장이 보유한 기구로 **자동 생성되는 운동 루틴** 앱 (Flutter · Android/iOS).
서버 없이 폰 안에서 모두 동작하고, APK는 GitHub Actions가 자동으로 빌드합니다.

## 기능

| # | 기능 | 구현 위치 |
|---|------|-----------|
| 3 | 헬스장별 기구 추가/수정/삭제, 별칭·최대중량·메모 | `lib/ui/gym_screen.dart` |
| 4 | 접근 코드 로그인 (기본 `23007344`, 설정에서 변경), 다중 프로필 | `lib/ui/login_screen.dart` |
| 5 | 1~6분할 템플릿 (무분할 / 상하체 / PPL / 4·5·6분할) | `lib/engine/splits.dart` |
| 6 | 부위별 세트 간 휴식(초)과 회복 시간(h): 하체 150s/72h, 가슴·등 120s/48h, 어깨 90s, 팔 75s, 복근 40s … | `lib/data/catalog.dart` `restRules` |
| 7 | 시간 예산(기본 120분) 안에서 부위 균형을 맞춘 세션 자동 생성 | `lib/engine/session_generator.dart` |
| 8 | 운동별 마지막 수행일을 기억 → 오래 안 한 운동/처음 하는 운동 우선 선택 | `session_generator.dart` `_best()` |
| 9 | 기구·운동마다 세부 타깃(등 하부, 윗가슴, 삼두 장두 …)을 내장. 세션 안에서 세부 타깃이 겹치지 않게 분산 | `catalog.dart` `emphasis`, `equipmentCatalog` |
| 10 | 주/월/4주 단위 플래너. 달력에서 휴식일을 길게 눌러 지정 → 회복 시간·연속 운동일(4일↑ 볼륨↓, 6일↑ 자동 휴식)·8일 이상 방치된 부위 끼워넣기 | `lib/engine/planner.dart`, `lib/ui/calendar_screen.dart` |
| 11 | 기구별 3D 모델 (외부 에셋 없이 Dart로 렌더링, 드래그 회전) | `lib/ui/widgets/equipment_3d.dart`, `lib/data/equipment_models.dart` |
| 12 | 운동일에 세트×횟수×무게 제시, 세트 체크, 실제 수행(더 들었거나 더 당긴 것) 입력 → 다음 루틴 강도 자동 상향/디로드 | `lib/ui/day_plan_view.dart`, `lib/engine/progression.dart` |
| 13 | 인바디 결과지 사진 → Claude 비전으로 체중/골격근량/체지방률 추출 → 1RM 추정 → 운동별 무게·세트·횟수 자동 설정. 이후 수행 결과로 자동 보정 | `lib/services/inbody_scanner.dart`, `lib/engine/load_estimator.dart` |

추가로: 세트 간 휴식 타이머, 운동 교체/제외/세트 추가, 하루 루틴 재생성, 완료율·연속 주 통계, 깨진 저장파일 복구.

## 설치 (폰)

1. GitHub **Actions** 탭 → 최근 `Build APK` 실행 → `fit-routine-apk` 아티팩트 다운로드, 또는
   `v1.0.0` 같은 태그를 푸시하면 **Releases**에 APK가 자동 등록됩니다.
2. 안드로이드 폰에서 APK 설치(출처를 알 수 없는 앱 허용).
3. 첫 실행: 이름 입력 + 접근 코드 `23007344`.
4. **헬스장** 탭에서 기구 등록(「기본 기구 16종 일괄 추가」로 시작 가능) → **달력** 탭에서 휴식일 길게 눌러 지정 → ✨ 버튼으로 주/월 루틴 생성.
5. **내 정보** 탭에서 인바디 스캔(Claude API 키 필요) 또는 수치 직접 입력.

iOS는 Xcode에서 `ios/` 를 열어 본인 Apple 계정으로 서명 후 설치하면 됩니다.

## 노트북에서 확인하기 (웹)

폰 없이 Chrome에서 바로 돌려볼 수 있습니다. 데이터는 브라우저 localStorage에 저장됩니다.

```bash
run_web.bat
```

코드를 고친 뒤 그 터미널에서 `r`(핫 리로드) 또는 `R`(재시작). 카메라/앨범 대신 파일 선택창이 뜹니다.

## 개발

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

> Windows에서 경로에 한글이 포함되면 `flutter analyze`의 분석 서버가 죽습니다.
> `C:\dev\fitroutine` 같은 ASCII 경로로 정션(junction)을 만들어 거기서 실행하세요.

### 구조

```
lib/
  models/        도메인 모델 (프로필, 헬스장, 기구, 계획, 세트, 진행상태)
  data/          운동 70종 + 기구 30종 지식 베이스, 3D 모델 정의
  engine/        무게 추정 · 분할 · 세션 생성 · 플래너 · 점진적 과부하
  services/      인바디 사진 분석 (Claude API, HTTP 직접 호출)
  state/         AppState (ChangeNotifier) — 저장소를 메모리에 올려 두고 변경 시 저장
  core/          단일 JSON 파일 저장소
  ui/            화면: 로그인 / 오늘 / 달력 / 헬스장 / 내 정보
test/            엔진·저장소·3D 모델 단위 테스트
```

### 무게 추정 방식

성별·체중·숙련도로 스쿼트/벤치/데드/OHP/로우 1RM 추정 → 인바디 골격근량·체지방률·나이로 보정 → 운동별 비율(`Exercise.ratio`) → Epley 공식으로 목표 횟수의 무게 → 기구 단위(바벨 2.5 / 덤벨 2 / 머신 5kg)로 반올림, 첫 세션은 90%.
이후는 더블 프로그레션: 전 세트 성공 +1단위(여유 있으면 +2), 더 무겁게 들었으면 그 무게가 새 기준, 2회 연속 실패 시 10% 디로드.

### 인바디 스캔

`내 정보 → Claude API 키`에 키를 넣으면 사진 분석이 활성화됩니다. 모델 `claude-opus-5-5`, JSON 스키마 강제 출력.
키는 폰 내부 저장소에만 저장되며 서버로 전송되지 않습니다(API 호출 외).
