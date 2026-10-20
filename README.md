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
| 13 | 신체 스펙(체중·골격근량·체지방률·나이·성별·숙련도) → 1RM 추정 → 운동별 무게·세트·횟수 자동 설정. 이후 수행 결과로 자동 보정 | `lib/engine/load_estimator.dart` |
| + | **신체 스펙 확장**: 3대+OHP 실제 기록(있으면 추정 대신 사용), 운동 목표(근비대/근력/다이어트 → 횟수·휴식·유산소), 부상 부위(허리/무릎/어깨/손목/팔꿈치 → 해당 운동 제외) | `lib/engine/load_estimator.dart`, `catalog.dart` `injuryExclusions` |
| + | **파트너 운동**: 이메일로 파트너 등록 → 오늘 탭 👥 → 두 사람의 오늘 부위·보유 기구를 맞춘 공통 루틴, 운동마다 내 무게/파트너 무게 표시, 파트너 앱에 루틴 전송(받은편지함 → 적용) | `lib/services/partner.dart`, `lib/ui/widgets/partner_widgets.dart` |
| + | **기록 탭**: 2/4/12주 부위별 완료 세트 밸런스(부족 부위 표시), 주간 세션 수, 주요 운동 무게 추이, 유산소 분 | `lib/engine/stats.dart`, `lib/ui/stats_screen.dart` |
| + | **오늘 컨디션**(1~10) + 무게 % + 오늘 운동 시간 → 루틴 재조정. **운동 후 강도(RPE 1~10)** → 다음 무게 상향 폭 조절 | `lib/ui/widgets/condition_card.dart`, `lib/engine/progression.dart` |

추가로: 무게/횟수 **스크롤 휠 입력**(기구 단위로 증감), **루틴 공유 코드**(카톡으로 보내면 상대는 '루틴 불러오기'로 같은 운동을 자기 무게로 수행 → 분할이 달라도 파트너 운동 가능), **오늘의 명언**, 세트 간 휴식 타이머, 운동 교체/제외/세트 추가, 하루 루틴 재생성, 완료율·연속 주 통계, 깨진 저장파일 복구.

## 설치 안내 페이지 (친구에게 이 링크 하나만)

**https://doun-lee.github.io/healthcare_system/get.html** — 기기를 감지해 안드로이드는 최신 APK 버튼, 아이폰은 홈 화면 추가 안내, 그 외는 웹앱. QR 포함.

## APK 배포 (정식)

`main`에 push될 때마다 GitHub Actions가 버전을 자동으로 올리고(패치 +1, 커밋 메시지에 `#minor`/`#major`로 조절) 릴리스 키로 서명한 `ldw_healthcare_system_vX.Y.Z.apk`를 **Releases**에 올립니다. 앱의 **내 정보 → 앱 정보**에서 현재 버전과 새 버전 알림/다운로드를 확인할 수 있습니다.

필요한 GitHub Secrets (Settings → Secrets and variables → Actions): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`. 키스토어는 저장소에 넣지 않습니다. 없으면 debug 서명 아티팩트만 만들고 릴리스는 생략합니다.

## 웹앱 (개발 확인용)

`main`에 push될 때마다 GitHub Pages로 배포됩니다: **https://doun-lee.github.io/healthcare_system/**

폰 브라우저로 열고 **홈 화면에 추가**(Chrome: ⋮ → 홈 화면에 추가 / Safari: 공유 → 홈 화면에 추가)하면 앱처럼 실행됩니다. 데이터는 그 브라우저의 저장소에 남습니다. 오프라인에서도 열립니다.

## 설치 (폰, APK)

1. GitHub **Actions** 탭 → 최근 `Build APK` 실행 → `fit-routine-apk` 아티팩트 다운로드, 또는
   `v1.0.0` 같은 태그를 푸시하면 **Releases**에 APK가 자동 등록됩니다.
2. 안드로이드 폰에서 APK 설치(출처를 알 수 없는 앱 허용).
3. 첫 실행: 이름 입력 + 접근 코드 `23007344`.
4. **헬스장** 탭에서 기구 등록(「기본 기구 16종 일괄 추가」로 시작 가능) → **달력** 탭에서 휴식일 길게 눌러 지정 → ✨ 버튼으로 주/월 루틴 생성.
5. **내 정보** 탭에서 신체 스펙(인바디 수치) 입력.

iOS는 Xcode에서 `ios/` 를 열어 본인 Apple 계정으로 서명 후 설치하면 됩니다.

## 노트북에서 확인하기 (웹)

폰 없이 Chrome에서 바로 돌려볼 수 있습니다. 데이터는 브라우저 localStorage에 저장됩니다.

```bash
run_web.bat
```

코드를 고친 뒤 그 터미널에서 `r`(핫 리로드) 또는 `R`(재시작). 카메라/앨범 대신 파일 선택창이 뜹니다.

## 계정 동기화 (Firebase)

`lib/firebase_options.dart`에 Firebase 웹앱 config를 넣으면 **내 정보 → 계정 로그인/가입**이 활성화됩니다.
이메일/비밀번호 계정으로 로그인하면 폰·노트북 어디서 열어도 같은 데이터(프로필·헬스장·계획·기록)를 봅니다.
로컬 저장이 항상 1차라 오프라인에서도 동작하고, 변경 1초 뒤 Firestore `users/{uid}/data/app`에 올라갑니다.
다른 기기에서 더 최신이면 앱 시작/로그인 시 내려받습니다.

Firebase 콘솔 설정: Authentication → 이메일/비밀번호·Google 사용, 승인된 도메인에 `doun-lee.github.io`, Firestore 생성, 규칙은 `firestore.rules` 내용을 붙여넣기(파트너 기능은 `public`/`inbox`/`emails` 규칙이 필요).

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
  services/      계정 동기화(Firebase), 루틴 공유 코드, 앱 업데이트 확인
  state/         AppState (ChangeNotifier) — 저장소를 메모리에 올려 두고 변경 시 저장
  core/          단일 JSON 파일 저장소
  ui/            화면: 로그인 / 오늘 / 달력 / 헬스장 / 내 정보
test/            엔진·저장소·3D 모델 단위 테스트
```

### 무게 추정 방식

성별·체중·숙련도로 스쿼트/벤치/데드/OHP/로우 1RM 추정 → 인바디 골격근량·체지방률·나이로 보정 → 운동별 비율(`Exercise.ratio`) → Epley 공식으로 목표 횟수의 무게 → 기구 단위(바벨 2.5 / 덤벨 2 / 머신 5kg)로 반올림, 첫 세션은 90%.
이후는 더블 프로그레션: 전 세트 성공 +1단위(여유 있으면 +2), 더 무겁게 들었으면 그 무게가 새 기준, 2회 연속 실패 시 10% 디로드.

