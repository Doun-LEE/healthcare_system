# FitRoutine 데이터베이스 설계안

작성: 2026-10-27. 현재(개발 단계, 사용자 10명 한정) 구조의 문제와, 사용자가 늘어도 버티는 구조를 정리한다.
지금 당장 바꾸는 건 아니고, 바꿀 때 이 문서대로 간다.

## 1. 지금 구조

| 경로 | 내용 | 누가 읽고 쓰나 |
|---|---|---|
| `users/{uid}/data/app` | 앱 데이터 **전체** JSON 한 덩어리(프로필, 헬스장, 모든 날짜 루틴, 운동별 진행, 파트너 목록) | 본인 |
| `users/{uid}/data/bk_*`, `data/backups` | 수동 백업 | 본인 |
| `users/{uid}/public/profile` | 파트너용 공개 요약(이름, 공개 ID, 스펙, 기구, 작업 중량, 앞뒤 2주 계획, 헬스장) | 로그인한 사람 get, 본인 write |
| `users/{uid}/inbox/{id}` | 파트너 요청·답장·루틴 제안 | 본인 read/delete, 누구나 create(보낸 사람 검증) |
| `handles/{닉네임#1234}`, `emails/{base64}` | 검색표 → uid | get 만 |
| `chats/{uidA_uidB}/messages/{id}` | 1:1 채팅 | 두 사람 |
| `errors/{id}` | 앱 오류 보고 | create 만 |

클라이언트가 전부 하고 서버 코드는 없다. 동기화는 "로컬 JSON ↔ `data/app` 통째로 비교·병합"이다.

### 문제점
1. **문서 1MB 한도**: 매일 운동하면 하루 2~5KB씩 쌓여 1년 안팎에 `data/app` 이 1MB를 넘는다. 사용자 수와 무관하게 온다.
2. **매번 통째로 쓰기**: 세트 하나 체크해도 전체 JSON을 올린다(디바운스 1초). 쓰기 비용과 충돌 위험(두 기기 동시 수정)이 크다.
3. **메모리**: 앱이 켜질 때 모든 날짜를 읽어 올린다. 몇 년 치면 느려진다.
4. **폴링**: 받은편지함을 2분마다 읽는다. 사용자가 많아지면 읽기 비용의 대부분이 이것이다.
5. 파트너 공개 프로필에 앞뒤 2주 루틴 전체가 들어가 크다(파트너가 많을수록 상대가 읽는 양이 늘어난다).

## 2. 결정: 관계형(Postgres) — Supabase 로 간다

| 후보 | 장점 | 단점 | 판단 |
|---|---|---|---|
| Firestore 재설계(문서 쪼개기) | 지금 코드·규칙 재활용, 오프라인 캐시, 실시간 | 집계·분석이 약함(조인 없음), 읽기 과금이 쿼리 모양에 민감 | 분석 요구가 커지면 결국 옮기게 됨 |
| **Supabase (Postgres)** | 진짜 SQL(조인·집계·뷰·파티션), RLS 로 "본인 것만", 실시간 구독, Flutter SDK, 무료 플랜(DB 500MB·MAU 5만), 표준 Postgres 라 나중에 RDS·Neon 등으로 **덤프만 옮기면 됨** | 기본 오프라인 캐시 없음(지금 로컬 JSON 캐시 유지하면 됨), 무료 프로젝트는 **1주 미사용 시 일시정지**(매일 쓰면 안 걸림, 걸리면 대시보드에서 복구) | **채택** |
| AWS RDS 직접 | ERP 와 같은 운영 방식, 완전한 통제 | 클라이언트가 DB 에 직접 못 붙어 **서버 API 필수**, 무료 없음(월 1.5~3만 원부터), 패치·백업 직접 | 지금 단계엔 과함. Postgres 라 나중에 Supabase 에서 이사 가능 |
| 로컬 우선 동기화(PowerSync·ElectricSQL + Postgres) | 오프라인 완벽, 충돌 자동 | 구성 요소 하나 더, 요금·학습 비용 | 2단계에서 필요하면 추가 |

인증은 **Firebase Auth 를 그대로** 쓰고 Supabase 의 third-party auth(Firebase JWT)로 붙인다(Supabase 공식 지원). 로그인·구글 연동·웹 호스팅은 바뀌지 않는다.
데이터만 Firestore → Postgres 로 옮긴다.

## 3. 스키마

`supabase/schema.sql` 에 전체 DDL + RLS 가 있다. 핵심 테이블:

```
users              사용자 프로필(공개 ID handle, 이메일은 키만)
gyms, gym_equipment 헬스장·기구(무게 기준·빈 기구 무게 포함)
plans              하루 1행 (user_id, date) unique
plan_exercises     루틴의 운동 1행 (순서·휴식·워밍업·고정·한쪽씩·나만)
sets               세트 1행 = 사실(fact) 테이블. 월/연 파티션. 모든 볼륨·PR·근육 집계의 원천
cardio_stats       워치 기록(운동당 0~1행)
exercise_progress  운동별 작업 중량·성공/실패 연속
partners           파트너 링크 + 채팅 읽은 시각
inbox              파트너 요청·루틴 제안
chat_rooms, messages 채팅(방 요약 + 메시지)
error_reports, ai_usage 운영
```

"빅데이터" 대비 포인트:
- 세트를 행으로 저장하니 `sum(weight*reps) group by user, date, exercise` 같은 집계가 SQL 한 줄. 근육별 가중 집계도 `exercise_id → muscles` 참조표를 넣으면 SQL 로 가능.
- `sets` 는 날짜 파티션. 수억 행이 돼도 월별로 잘려 인덱스가 작다.
- 분석이 무거워지면 Postgres 를 읽기 전용 복제본이나 BigQuery/ClickHouse 로 내보낸다(표준 Postgres 라 도구가 다 있다).
- 모든 행에 `updated_at`(+ `deleted_at`) → 기기 간 증분 동기화는 "마지막 동기화 이후 바뀐 행만".

## 4. 앱 쪽 구조 변경

- `DataStore` 추상화를 유지하되, 클라우드 계층을 `CloudSync`(Firestore) → `SupaSync`(Postgres) 로 교체. 로컬 JSON 캐시는 그대로(오프라인용).
- 쓰기: 지금처럼 전체 JSON 이 아니라 **바뀐 행만** upsert(세트 체크 = `sets` 1행 update).
- 읽기: 앱 시작 시 `plans`/`plan_exercises`/`sets` 를 오늘 ±14일만, 달력은 월 단위, 통계는 기간 쿼리. 나머지(프로필·헬스장·진행)는 전부(작다).
- 실시간: `inbox`·`messages`·`chat_rooms` 는 Supabase Realtime 구독(폴링 제거).

## 5. 구현 상태(2026-10-27)

- `lib/services/supa_rows.dart`: 모델 ↔ 행 변환(순수 Dart, 테스트 `test/supa_rows_test.dart`). 분석용 열 + `extra` jsonb 원본으로 손실 없음.
- `lib/services/supa_sync.dart`: `SupaSync.init()`(Firebase ID 토큰을 third-party auth 로 전달), `push`(행 묶음 upsert, 빠진 운동·세트 행 정리), `pull`, `softDeletePlans`, `lookupUser`.
- `lib/state/app_state.dart`: 저장할 때마다 3초 디바운스로 **바뀐 것만**(계획은 날짜 단위 해시 비교) Postgres 에 올린다. 로그인·앱 시작 시 Postgres 에 데이터가 없으면 전부 올린다(첫 이전). `supabasePrimary`(supa_sync.dart) 를 켜면 계획을 Postgres 에서도 읽어 합친다.
- `lib/supabase_options.dart`: URL·anon(publishable) key 자리. 비어 있으면 전부 꺼진다.
- Firebase JWT 에는 `role` 클레임이 없어 요청이 `anon` 역할로 실행된다(role 을 넣으려면 Cloud Functions=Blaze). 그래서 RLS 는 `auth.uid()` 대신 `auth_uid()`(우리 Firebase 프로젝트가 발급한 JWT 의 sub) 로 쓴다. 토큰이 없으면 전부 거부.
- 아직 안 한 것: 받은편지함·채팅의 Realtime 전환(지금은 Firestore 그대로), Postgres 를 유일한 기준으로 쓰는 컷오버.

### 설정 방법(사용자가 할 것, 카드 등록 없음)
1. supabase.com 가입 → New project(무료) → 리전 Northeast Asia(Seoul 또는 Tokyo).
2. SQL Editor 에 `supabase/schema.sql` 전체를 붙여 넣고 실행.
3. Authentication → Sign In / Providers → Third-Party Auth → Firebase 추가, Firebase 프로젝트 ID `healthcare-system-b55c0`.
4. Project Settings → API 의 Project URL 과 publishable(anon) key 를 `lib/supabase_options.dart` 에 넣고 커밋.
5. 앱을 열고 로그인하면 첫 이전이 자동으로 돌고, 이후엔 바뀐 것만 올라간다. Table Editor 에서 `plans`·`sets` 행이 쌓이는지 확인.

## 6. 이전(마이그레이션) 순서
1. Supabase 프로젝트 생성(무료), `schema.sql` 적용, Firebase third-party auth 설정. 비밀값은 앱에 `anon key`(공개 가능)만.
2. 앱에 `SupaSync` 추가: 로그인 시 Firestore `data/app` 을 읽어 Postgres 로 **한 번 쪼개 올리는** 변환기(사용자별, 기기에서 실행).
3. 한동안 **이중 쓰기**(Firestore + Postgres). 읽기는 Postgres 우선.
4. 모든 테스트 사용자(10명)가 새 버전이면 Firestore 쓰기 중단. 채팅·받은편지함도 옮긴다.
5. Firestore 는 백업으로 남기고 규칙을 읽기 전용으로.

예상 작업량: 2~4단계가 며칠(동기화 계층 다시 쓰기). 1단계는 도운 님이 Supabase 가입·프로젝트 생성(10분)만 하면 된다. **카드 등록 없음.**

## 7. 그대로 두는 것
- 인증: Firebase Auth(이메일·구글). 호스팅: Firebase Hosting. APK: GitHub Releases.
- 사진·OCR: 기기 안 ML Kit/Tesseract, 서버 없음. 사진 원본은 올리지 않는다.
- AI(Gemini): 사용자별 하루 한도(코치 5회, 사진 보충 8회).

## 8. (참고) 이전 Firestore 분할안
사용자 수가 적고 분석 요구가 없다면 `users/{uid}/plans/{날짜}` 로 문서만 쪼개는 방법도 있었다. 관계형으로 가기로 해서 보류.

## 9. 보안 규칙 요약(Firestore, 이전 전까지 유효)(2026-10-27 감사 결과 반영)
- 검색표(`handles`, `emails`)는 `get` 만 허용, `list` 금지 → 이메일·ID 전체 수집 불가. 남의 항목 덮어쓰기(ID 가로채기) 금지.
- 공개 프로필도 `list` 금지(사용자 명단 수집 방지).
- 받은편지함·채팅은 보낸 사람 검증 + 필드 종류·길이 상한.
- 그 밖의 모든 경로는 거부.
