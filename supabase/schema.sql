-- FitRoutine 관계형 스키마 (Postgres / Supabase)
-- 설계 원칙
--  1) 분석 가능한 사실(fact) 테이블: sets (세트 1개 = 1행), cardio_stats. 집계는 SQL/뷰로.
--  2) 사용자가 늘어도 한 행의 크기는 일정(문서 1MB 한도 같은 벽이 없다).
--  3) 모든 테이블에 updated_at + 소프트 삭제(deleted_at) → 기기 간 증분 동기화("updated_at > 마지막 동기화")가 쉽다.
--  4) Row Level Security 로 "본인 것만", "파트너는 공개 뷰만", "채팅은 둘만".
--  5) id 는 클라이언트가 만드는 uuid(오프라인에서 먼저 만들고 나중에 올림).
--
-- 인증: Firebase Auth 를 그대로 쓰고 Supabase 의 third-party auth(Firebase)로 JWT 를 검증한다.
--       Firebase JWT 에는 role 클레임이 없어 요청이 anon 역할로 실행되므로(role 을 넣으려면 Cloud Functions=Blaze 필요),
--       정책은 auth_uid() 대신 아래 auth_uid()(= 검증된 JWT 의 sub, 우리 Firebase 프로젝트 발급분만)로 쓴다.
--       JWT 가 없으면 auth_uid() 가 null → 모든 정책이 거짓 → 거부.
--       id 는 전부 text(Firebase uid 와 앱의 id 는 uuid 형식이 아니다).

create extension if not exists "pgcrypto";

create or replace function auth_uid() returns text language sql stable as $$
  select case
    when coalesce(auth.jwt() ->> 'iss', '') = 'https://securetoken.google.com/healthcare-system-b55c0'
      then auth.jwt() ->> 'sub'
    else null end
$$;

-- ───────── 사용자 ─────────
create table if not exists users (
  id            text primary key,                 -- auth_uid()
  handle        text unique,                      -- 닉네임#1234 (검색용, 소문자 정규화는 handle_key)
  handle_key    text unique generated always as (lower(replace(handle, ' ', ''))) stored,
  email_key     text unique,                      -- base64url(lower(email)); 이메일 원문은 저장하지 않는다
  name          text not null default '',
  sex           text not null default 'male',
  height_cm     numeric(5,1),
  weight_kg     numeric(5,1),
  age           int,
  skeletal_muscle_kg numeric(5,1),
  body_fat_pct  numeric(4,1),
  level         text not null default 'beginner',
  goal          text not null default 'hypertrophy',
  split_days    int  not null default 3,
  session_minutes int not null default 120,
  include_cardio  boolean not null default true,
  cardio_on_leg_days boolean not null default false,
  auto_adjust   boolean not null default true,
  rest_mode     text not null default 'shift',
  warmup_mode   text not null default 'auto',
  theme         text not null default 'basic',
  prefs         jsonb not null default '{}'::jsonb,  -- 구역 순서·운동 순위·워밍업 선택 등 자주 바뀌는 작은 설정
  injuries      text[] not null default '{}',
  cautions      text[] not null default '{}',
  squat_1rm numeric(6,1), bench_1rm numeric(6,1), deadlift_1rm numeric(6,1), ohp_1rm numeric(6,1),
  active_gym_id text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ───────── 헬스장 / 기구 ─────────
create table if not exists gyms (
  id         text primary key,
  user_id    text not null references users(id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists gyms_user on gyms(user_id) where deleted_at is null;

create table if not exists gym_equipment (
  id            text primary key,
  gym_id        text not null references gyms(id) on delete cascade,
  type          text not null,                    -- EquipmentType.name
  extra_types   text[] not null default '{}',
  custom_name   text,
  brand         text,
  mechanism     text,                             -- pin | plate | free | none
  step_kg       numeric(5,2),
  max_weight_kg numeric(6,1),
  weight_basis  text,                             -- total | perSide
  plate_basis   text,                             -- plates | full
  empty_kg      numeric(5,1),
  dual_stack    boolean not null default false,
  note          text,
  extra         jsonb not null default '{}'::jsonb,  -- 앱 모델 원본(색·사진 유무 등)
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);
create index if not exists gym_equipment_gym on gym_equipment(gym_id) where deleted_at is null;

-- ───────── 하루 계획(루틴) ─────────
create table if not exists plans (
  id             text primary key,
  user_id        text not null references users(id) on delete cascade,
  date           date not null,
  kind           text not null default 'workout',   -- workout | rest
  title          text,
  focus          text[] not null default '{}',      -- MuscleGroup.name[]
  gym_id         text references gyms(id),
  estimated_min  int not null default 0,
  intensity_factor numeric(4,2) not null default 1,
  load_factor    numeric(4,2) not null default 1,
  condition      int,
  rpe            int,
  custom         boolean not null default false,
  skipped        boolean not null default false,
  started_at     timestamptz,
  ended_at       timestamptz,
  finished_at    timestamptz,
  partner_name   text,
  members        jsonb not null default '[]'::jsonb, -- 그룹 운동 멤버·사람별 무게(작아서 jsonb)
  venue          jsonb,                              -- 파트너 헬스장(owner, gymId, name, types)
  extra          jsonb not null default '{}'::jsonb, -- 앱 모델 원본(운동 제외). 열에 없는 필드의 손실 방지
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  unique (user_id, date)
);
create index if not exists plans_user_date on plans(user_id, date desc);

create table if not exists plan_exercises (
  id              text primary key,
  plan_id         text not null references plans(id) on delete cascade,
  position        int not null,                     -- 화면 순서
  exercise_id     text not null,                    -- 카탈로그 id(예: bb_bench)
  equipment_type  text not null,
  rest_sec        int not null default 90,
  note            text,
  warmup          boolean not null default false,
  pinned          boolean not null default false,
  one_side        boolean not null default false,
  personal        boolean not null default false,   -- 파트너 날에 나만 하는 운동
  group_override  text,                             -- 사용자가 바꾼 타깃 부위
  extra           jsonb not null default '{}'::jsonb,
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index if not exists plan_exercises_plan on plan_exercises(plan_id, position);
create index if not exists plan_exercises_exercise on plan_exercises(exercise_id);

-- 세트 1개 = 1행. 분석의 핵심 사실 테이블(볼륨·PR·근육별 집계는 전부 여기서).
create table if not exists sets (
  id               text primary key,
  plan_exercise_id text not null references plan_exercises(id) on delete cascade,
  user_id          text not null references users(id) on delete cascade,   -- 집계 쿼리용 비정규화
  date             date not null,                                            -- 집계 쿼리용 비정규화
  position         int not null,
  target_reps      int not null,
  target_weight    numeric(6,2) not null default 0,
  done_reps        int,
  done_weight      numeric(6,2),
  level            int,            -- 유산소 강도(레벨·경사·저항)
  done_level       int,
  completed        boolean not null default false,
  extra            boolean not null default false,
  completed_at     timestamptz,
  updated_at       timestamptz not null default now()
) partition by range (date);
-- 월 파티션은 운영에서 자동 생성(pg_partman) 또는 아래처럼 미리 만든다.
create table if not exists sets_2026 partition of sets for values from ('2026-01-01') to ('2027-01-01');
create table if not exists sets_2027 partition of sets for values from ('2027-01-01') to ('2028-01-01');
create index if not exists sets_user_date on sets(user_id, date);
create index if not exists sets_pe on sets(plan_exercise_id, position);

-- 워치·러닝 앱 기록(사진 인식 결과). 운동 1개당 0~1개.
create table if not exists cardio_stats (
  plan_exercise_id text primary key references plan_exercises(id) on delete cascade,
  user_id      text not null references users(id) on delete cascade,
  date         date not null,
  duration_sec int, distance_km numeric(7,3), active_kcal int, total_kcal int,
  avg_hr int, max_hr int, pace_sec int, cadence int, stride_m numeric(4,2), contact_ms int,
  power_w int, elevation_m int, speed_kmh numeric(5,2), effort int,
  splits       jsonb not null default '[]'::jsonb,
  source       text,
  updated_at   timestamptz not null default now()
);
create index if not exists cardio_user_date on cardio_stats(user_id, date);

-- ───────── 운동별 진행(작업 중량) ─────────
create table if not exists exercise_progress (
  user_id        text not null references users(id) on delete cascade,
  exercise_id    text not null,
  working_weight numeric(6,2) not null default 0,
  target_reps    int not null default 10,
  level          int,
  last_performed date,
  times_performed int not null default 0,
  consecutive_success int not null default 0,
  consecutive_fail    int not null default 0,
  updated_at     timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

-- ───────── 파트너 / 받은편지함 / 채팅 ─────────
create table if not exists partners (
  user_id     text not null references users(id) on delete cascade,
  partner_id  text not null references users(id) on delete cascade,
  pending     boolean not null default false,
  read_at     timestamptz,                         -- 채팅 읽은 시각
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (user_id, partner_id)
);

create table if not exists inbox (
  id         text primary key default gen_random_uuid()::text,
  to_user    text not null references users(id) on delete cascade,
  from_user  text not null references users(id) on delete cascade,
  type       text not null check (type in ('joint','jointAccepted','partnerRequest','partnerAccept','partnerDecline')),
  date       date,
  title      text,
  payload    jsonb,                                 -- 루틴 코드 등
  created_at timestamptz not null default now()
);
create index if not exists inbox_to on inbox(to_user, created_at desc);

create table if not exists chat_rooms (
  id         text primary key,                      -- 'uidA_uidB' (정렬)
  user_a     text not null references users(id),
  user_b     text not null references users(id),
  last_at    timestamptz,
  last_text  text,
  last_from  text
);
create table if not exists messages (
  id        text primary key default gen_random_uuid()::text,
  room_id   text not null references chat_rooms(id) on delete cascade,
  from_user text not null references users(id),
  text      text not null default '' check (char_length(text) <= 1000),
  emoji     text not null default '' check (char_length(emoji) <= 16),
  burst     int  not null default 0 check (burst between 0 and 60),
  created_at timestamptz not null default now()
);
create index if not exists messages_room on messages(room_id, created_at desc);

-- ───────── 운영 ─────────
create table if not exists error_reports (
  id        text primary key default gen_random_uuid()::text,
  user_id   text references users(id) on delete set null,
  at        timestamptz not null default now(),
  platform  text, version text, where_ text, error text, stack text
);
create table if not exists ai_usage (
  user_id text not null references users(id) on delete cascade,
  day     date not null,
  kind    text not null,                 -- coach | photo
  count   int  not null default 0,
  primary key (user_id, day, kind)
);

-- ───────── 공개 프로필 뷰(파트너가 보는 것만) ─────────
create or replace view public_profiles as
  select id, handle, name, sex, height_cm, weight_kg, level, goal, split_days, session_minutes, include_cardio,
         skeletal_muscle_kg, body_fat_pct, squat_1rm, bench_1rm, deadlift_1rm, ohp_1rm, updated_at
  from users;

-- ───────── 분석 뷰 예시(근육별·부위별 집계는 앱이 하지만, 대시보드용으로 SQL 도 가능) ─────────
create or replace view v_daily_volume as
  select user_id, date,
         count(*) filter (where completed)                               as sets_done,
         sum(coalesce(done_weight, target_weight) * coalesce(done_reps, target_reps)) filter (where completed) as tonnage
  from sets group by user_id, date;

-- ───────── Row Level Security ─────────
alter table users enable row level security;
alter table gyms enable row level security;
alter table gym_equipment enable row level security;
alter table plans enable row level security;
alter table plan_exercises enable row level security;
alter table sets enable row level security;
alter table cardio_stats enable row level security;
alter table exercise_progress enable row level security;
alter table partners enable row level security;
alter table inbox enable row level security;
alter table chat_rooms enable row level security;
alter table messages enable row level security;
alter table error_reports enable row level security;
alter table ai_usage enable row level security;

-- 본인 행만
create policy users_self on users for all using (id = auth_uid()) with check (id = auth_uid());
create policy gyms_self on gyms for all using (user_id = auth_uid()) with check (user_id = auth_uid());
create policy equipment_self on gym_equipment for all
  using (exists (select 1 from gyms g where g.id = gym_id and g.user_id = auth_uid()))
  with check (exists (select 1 from gyms g where g.id = gym_id and g.user_id = auth_uid()));
create policy plans_self on plans for all using (user_id = auth_uid()) with check (user_id = auth_uid());
create policy pe_self on plan_exercises for all
  using (exists (select 1 from plans p where p.id = plan_id and p.user_id = auth_uid()))
  with check (exists (select 1 from plans p where p.id = plan_id and p.user_id = auth_uid()));
create policy sets_self on sets for all using (user_id = auth_uid()) with check (user_id = auth_uid());
create policy cardio_self on cardio_stats for all using (user_id = auth_uid()) with check (user_id = auth_uid());
create policy progress_self on exercise_progress for all using (user_id = auth_uid()) with check (user_id = auth_uid());
create policy partners_self on partners for all using (user_id = auth_uid()) with check (user_id = auth_uid());
create policy ai_self on ai_usage for all using (user_id = auth_uid()) with check (user_id = auth_uid());

-- 파트너(수락된 사이)는 상대의 계획을 "읽기만" (공동 루틴·조건 표시용)
create policy plans_partner_read on plans for select
  using (exists (select 1 from partners p where p.user_id = auth_uid() and p.partner_id = plans.user_id and not p.pending));
create policy pe_partner_read on plan_exercises for select
  using (exists (select 1 from plans pl join partners p on p.partner_id = pl.user_id
                 where pl.id = plan_id and p.user_id = auth_uid() and not p.pending));

-- 받은편지함: 받는 사람이 읽고 지움, 보내는 사람은 자기 이름으로만 만듦
create policy inbox_read on inbox for select using (to_user = auth_uid());
create policy inbox_delete on inbox for delete using (to_user = auth_uid());
create policy inbox_create on inbox for insert with check (from_user = auth_uid());

-- 채팅: 방의 두 사람만
create policy rooms_members on chat_rooms for all
  using (auth_uid() in (user_a, user_b)) with check (auth_uid() in (user_a, user_b));
create policy messages_members on messages for select
  using (exists (select 1 from chat_rooms r where r.id = room_id and auth_uid() in (r.user_a, r.user_b)));
create policy messages_send on messages for insert
  with check (from_user = auth_uid() and exists (select 1 from chat_rooms r where r.id = room_id and auth_uid() in (r.user_a, r.user_b)));

-- 오류 보고: 만들기만
create policy errors_create on error_reports for insert with check (user_id = auth_uid());

-- 공개 ID 검색: 정확한 키로 하나만 (함수로 열어 둔다 → 테이블 나열 불가)
create or replace function lookup_user(q text) returns table(id text, handle text, name text)
language sql security definer stable as $$
  select id, handle, name from users
  where handle_key = lower(replace(q, ' ', '')) or email_key = q
  limit 1
$$;
