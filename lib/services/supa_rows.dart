/// 앱 모델 ↔ Postgres 행 변환(순수 Dart, 네트워크 없음 → 테스트 가능).
///
/// 원칙: 분석에 쓰는 값은 열(column)로, 나머지는 `extra` jsonb 에 모델 원본 JSON 을 그대로 넣어
/// 열에 없는 필드가 생겨도 손실이 없게 한다. 세트는 `sets` 행으로 풀어 쓴다(사실 테이블).
library;

import 'dart:convert';

import '../core/store.dart';
import '../models/models.dart';
import '../services/partner.dart';

String planExerciseId(String planId, int index) => '$planId:$index';

/// 변경 감지용 해시(내용이 같으면 같은 값).
String contentHash(Object json) {
  final s = jsonEncode(json);
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return '${s.length}:${h.toRadixString(16)}';
}

String _dateStr(DateTime d) => dateKey(d);

// ───────── 모델 → 행 ─────────

Map<String, dynamic> userRow(UserProfile p, String uid) {
  final j = p.toJson();
  return {
    'id': uid,
    'name': p.name,
    'sex': p.sex.name,
    'height_cm': p.heightCm,
    'weight_kg': p.weightKg,
    'age': p.age,
    'skeletal_muscle_kg': p.skeletalMuscleKg,
    'body_fat_pct': p.bodyFatPct,
    'level': p.level.name,
    'goal': p.goal.name,
    'split_days': p.splitDays,
    'session_minutes': p.sessionMinutes,
    'include_cardio': p.includeCardio,
    'cardio_on_leg_days': p.cardioOnLegDays,
    'auto_adjust': p.autoAdjust,
    'rest_mode': p.restMode,
    'warmup_mode': p.warmupMode,
    'theme': p.theme,
    'injuries': p.injuries.map((i) => i.name).toList(),
    'cautions': p.cautions.map((i) => i.name).toList(),
    'squat_1rm': p.squat1rm,
    'bench_1rm': p.bench1rm,
    'deadlift_1rm': p.deadlift1rm,
    'ohp_1rm': p.ohp1rm,
    'active_gym_id': p.activeGymId,
    'prefs': j, // 모델 원본 전체(손실 없음)
  };
}

Map<String, dynamic> gymRow(Gym g, String uid) => {'id': g.id, 'user_id': uid, 'name': g.name, 'deleted_at': null};

List<Map<String, dynamic>> equipmentRows(Gym g) => [
      for (final e in g.equipment)
        {
          'id': e.id,
          'gym_id': g.id,
          'type': e.type.name,
          'extra_types': e.extraTypes.map((t) => t.name).toList(),
          'custom_name': e.customName,
          'brand': e.brand,
          'mechanism': e.mechanism.name,
          'step_kg': e.stepKg,
          'max_weight_kg': e.maxWeightKg,
          'weight_basis': e.weightBasis,
          'plate_basis': e.plateBasis,
          'empty_kg': e.emptyKg,
          'dual_stack': e.dualStack,
          'note': e.note,
          'extra': e.toJson(),
          'deleted_at': null,
        }
    ];

Map<String, dynamic> planRow(DayPlan p, String uid) {
  final j = p.toJson()..remove('exercises');
  return {
    'id': p.id,
    'user_id': uid,
    'date': _dateStr(p.date),
    'kind': p.kind.name,
    'title': p.title,
    'focus': p.focus.map((g) => g.name).toList(),
    'gym_id': p.gymId,
    'estimated_min': p.estimatedMinutes,
    'intensity_factor': p.intensityFactor,
    'load_factor': p.loadFactor,
    'condition': p.condition,
    'rpe': p.rpe,
    'custom': p.custom,
    'skipped': p.skipped,
    'started_at': p.startedAt?.toIso8601String(),
    'ended_at': p.endedAt?.toIso8601String(),
    'finished_at': p.finishedAt?.toIso8601String(),
    'partner_name': p.partnerName,
    'members': [for (final m in p.members) {'uid': m.uid, 'name': m.name}],
    'venue': p.venueName == null ? null : {'owner': p.venueOwner, 'gymId': p.venueGymId, 'name': p.venueName, 'types': p.venueTypes.map((t) => t.name).toList()},
    'extra': j,
    'deleted_at': null,
  };
}

List<Map<String, dynamic>> planExerciseRows(DayPlan p) => [
      for (var i = 0; i < p.exercises.length; i++)
        {
          'id': planExerciseId(p.id, i),
          'plan_id': p.id,
          'position': i,
          'exercise_id': p.exercises[i].exerciseId,
          'equipment_type': p.exercises[i].equipmentType.name,
          'rest_sec': p.exercises[i].restSeconds,
          'note': p.exercises[i].note,
          'warmup': p.exercises[i].warmup,
          'pinned': p.exercises[i].pinned,
          'one_side': p.exercises[i].oneSide,
          'personal': p.exercises[i].personal,
          'group_override': p.exercises[i].groupOverride?.name,
          'extra': p.exercises[i].toJson()
            ..remove('sets')
            ..remove('cardio'),
          'deleted_at': null,
        }
    ];

List<Map<String, dynamic>> setRows(DayPlan p, String uid) => [
      for (var i = 0; i < p.exercises.length; i++)
        for (var k = 0; k < p.exercises[i].sets.length; k++)
          {
            'id': '${planExerciseId(p.id, i)}:$k',
            'plan_exercise_id': planExerciseId(p.id, i),
            'user_id': uid,
            'date': _dateStr(p.date),
            'position': k,
            'target_reps': p.exercises[i].sets[k].targetReps,
            'target_weight': p.exercises[i].sets[k].targetWeight,
            'done_reps': p.exercises[i].sets[k].doneReps,
            'done_weight': p.exercises[i].sets[k].doneWeight,
            'level': p.exercises[i].sets[k].level,
            'done_level': p.exercises[i].sets[k].doneLevel,
            'completed': p.exercises[i].sets[k].completed,
            'extra': p.exercises[i].sets[k].extra,
          }
    ];

List<Map<String, dynamic>> cardioRows(DayPlan p, String uid) => [
      for (var i = 0; i < p.exercises.length; i++)
        if (p.exercises[i].cardio case final c? when !c.isEmpty)
          {
            'plan_exercise_id': planExerciseId(p.id, i),
            'user_id': uid,
            'date': _dateStr(p.date),
            'duration_sec': c.durationSec,
            'distance_km': c.distanceKm,
            'active_kcal': c.activeKcal,
            'total_kcal': c.totalKcal,
            'avg_hr': c.avgHr,
            'max_hr': c.maxHr,
            'pace_sec': c.paceSec,
            'cadence': c.cadence,
            'stride_m': c.strideM,
            'contact_ms': c.contactMs,
            'power_w': c.powerW,
            'elevation_m': c.elevationM,
            'speed_kmh': c.speedKmh,
            'effort': c.effort,
            'splits': c.toJson()['sp'] ?? [],
            'source': c.source,
          }
    ];

List<Map<String, dynamic>> progressRows(Map<String, ExerciseProgress> progress, String uid) => [
      for (final e in progress.values)
        {
          'user_id': uid,
          'exercise_id': e.exerciseId,
          'working_weight': e.workingWeight,
          'target_reps': e.targetReps,
          'level': e.level,
          'last_performed': e.lastPerformed == null ? null : _dateStr(e.lastPerformed!),
          'times_performed': e.timesPerformed,
          'consecutive_success': e.consecutiveSuccess,
          'consecutive_fail': e.consecutiveFail,
        }
    ];

List<Map<String, dynamic>> partnerRows(List<PartnerLink> partners, String uid) => [
      for (final p in partners)
        {
          'user_id': uid,
          'partner_id': p.uid,
          'pending': p.pending,
          'read_at': p.readAt?.toIso8601String(),
        }
    ];

// ───────── 행 → 모델 ─────────

UserProfile profileFromRow(Map<String, dynamic> r, {required String localId}) {
  final j = Map<String, dynamic>.from((r['prefs'] as Map?) ?? const {});
  j['id'] = localId; // 프로필 id 는 기기 로컬 id 를 유지(계정 uid 와 별개)
  return UserProfile.fromJson(j);
}

Gym gymFromRows(Map<String, dynamic> g, List<Map<String, dynamic>> equipment) => Gym(
      id: g['id'] as String,
      name: (g['name'] as String?) ?? '',
      equipment: [
        for (final e in equipment)
          if (e['extra'] is Map) GymEquipment.fromJson(Map<String, dynamic>.from(e['extra'] as Map)),
      ],
    );

/// plans 행 + 그 계획의 plan_exercises/sets/cardio 행 → DayPlan.
DayPlan planFromRows(
  Map<String, dynamic> plan,
  List<Map<String, dynamic>> exercises,
  List<Map<String, dynamic>> sets,
  List<Map<String, dynamic>> cardio, {
  required String localUserId,
}) {
  final j = Map<String, dynamic>.from((plan['extra'] as Map?) ?? const {});
  j['id'] = plan['id'];
  j['userId'] = localUserId;
  j['date'] = plan['date'];
  final byPe = <String, List<Map<String, dynamic>>>{};
  for (final s in sets) {
    byPe.putIfAbsent(s['plan_exercise_id'] as String, () => []).add(s);
  }
  final cardioBy = {for (final c in cardio) c['plan_exercise_id'] as String: c};
  final sorted = [...exercises]..sort((a, b) => (a['position'] as num).compareTo(b['position'] as num));
  j['exercises'] = [
    for (final e in sorted)
      {
        ...Map<String, dynamic>.from((e['extra'] as Map?) ?? const {}),
        'exerciseId': e['exercise_id'],
        'equipmentType': e['equipment_type'],
        'restSeconds': (e['rest_sec'] as num?)?.toInt() ?? 90,
        'sets': [
          for (final s in (byPe[e['id']] ?? const <Map<String, dynamic>>[])..sort((a, b) => (a['position'] as num).compareTo(b['position'] as num)))
            {
              'targetReps': (s['target_reps'] as num).toInt(),
              'targetWeight': (s['target_weight'] as num).toDouble(),
              'doneReps': (s['done_reps'] as num?)?.toInt(),
              'doneWeight': (s['done_weight'] as num?)?.toDouble(),
              'completed': s['completed'] == true,
              'level': (s['level'] as num?)?.toInt(),
              'doneLevel': (s['done_level'] as num?)?.toInt(),
              if (s['extra'] == true) 'extra': true,
            }
        ],
        if (cardioBy[e['id']] case final c?) 'cardio': _cardioJson(c),
      }
  ];
  return DayPlan.fromJson(j);
}

Map<String, dynamic> _cardioJson(Map<String, dynamic> c) => CardioStats(
      durationSec: (c['duration_sec'] as num?)?.toInt(),
      distanceKm: (c['distance_km'] as num?)?.toDouble(),
      activeKcal: (c['active_kcal'] as num?)?.toInt(),
      totalKcal: (c['total_kcal'] as num?)?.toInt(),
      avgHr: (c['avg_hr'] as num?)?.toInt(),
      maxHr: (c['max_hr'] as num?)?.toInt(),
      paceSec: (c['pace_sec'] as num?)?.toInt(),
      cadence: (c['cadence'] as num?)?.toInt(),
      strideM: (c['stride_m'] as num?)?.toDouble(),
      contactMs: (c['contact_ms'] as num?)?.toInt(),
      powerW: (c['power_w'] as num?)?.toInt(),
      elevationM: (c['elevation_m'] as num?)?.toInt(),
      speedKmh: (c['speed_kmh'] as num?)?.toDouble(),
      effort: (c['effort'] as num?)?.toInt(),
      splits: [
        for (final s in ((c['splits'] as List?) ?? const []))
          if (s is Map) CardioSplit.fromJson(Map<String, dynamic>.from(s)),
      ],
      source: c['source'] as String?,
    ).toJson();

ExerciseProgress progressFromRow(Map<String, dynamic> r) => ExerciseProgress(
      exerciseId: r['exercise_id'] as String,
      workingWeight: (r['working_weight'] as num?)?.toDouble() ?? 0,
      targetReps: (r['target_reps'] as num?)?.toInt() ?? 10,
      level: (r['level'] as num?)?.toInt(),
      lastPerformed: r['last_performed'] == null ? null : DateTime.tryParse(r['last_performed'] as String),
      timesPerformed: (r['times_performed'] as num?)?.toInt() ?? 0,
      consecutiveSuccess: (r['consecutive_success'] as num?)?.toInt() ?? 0,
      consecutiveFail: (r['consecutive_fail'] as num?)?.toInt() ?? 0,
    );

PartnerLink partnerFromRow(Map<String, dynamic> r, {String name = '', String handle = ''}) => PartnerLink(
      uid: r['partner_id'] as String,
      name: name,
      handle: handle,
      pending: r['pending'] == true,
      readAt: r['read_at'] == null ? null : DateTime.tryParse(r['read_at'] as String),
    );

/// 전체 데이터를 행 묶음으로(첫 이전·전체 올리기).
class RowBundle {
  RowBundle({
    required this.user,
    required this.gyms,
    required this.equipment,
    required this.plans,
    required this.planExercises,
    required this.sets,
    required this.cardio,
    required this.progress,
    required this.partners,
  });
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> gyms, equipment, plans, planExercises, sets, cardio, progress, partners;

  static RowBundle fromData(AppData d, String uid, {String? userId}) {
    final profile = d.profiles.where((p) => p.id == (userId ?? d.currentUserId)).firstOrNull ?? d.profiles.firstOrNull;
    final myPlans = d.plans.where((p) => profile == null || p.userId == profile.id).toList();
    return RowBundle(
      user: profile == null ? null : userRow(profile, uid),
      gyms: [for (final g in d.gyms) gymRow(g, uid)],
      equipment: [for (final g in d.gyms) ...equipmentRows(g)],
      plans: [for (final p in myPlans) planRow(p, uid)],
      planExercises: [for (final p in myPlans) ...planExerciseRows(p)],
      sets: [for (final p in myPlans) ...setRows(p, uid)],
      cardio: [for (final p in myPlans) ...cardioRows(p, uid)],
      progress: progressRows(d.progress[profile?.id] ?? const {}, uid),
      partners: partnerRows(d.partners, uid),
    );
  }
}
