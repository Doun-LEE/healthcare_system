/// 파트너 운동용 공개 프로필과 받은편지함 모델.
///
/// 각 계정은 `users/{uid}/public/profile` 에 파트너가 봐도 되는 정보만 올린다:
/// 이름, 신체 스펙 요약, 보유 기구, 운동별 작업 중량, 앞뒤 2주 계획의 부위.
/// 무게·세트는 파트너 화면에 "파트너 무게"로 표시되고, 공통 루틴 생성에 쓰인다.
library;

import '../models/models.dart';

class PartnerLink {
  PartnerLink({required this.uid, required this.name, required this.email});
  final String uid;
  String name;
  final String email;

  Map<String, dynamic> toJson() => {'uid': uid, 'name': name, 'email': email};
  factory PartnerLink.fromJson(Map<String, dynamic> j) => PartnerLink(
        uid: j['uid'] as String,
        name: (j['name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
      );
}

class PartnerProfile {
  PartnerProfile({
    required this.uid,
    required this.name,
    required this.profile,
    required this.available,
    required this.workingWeights,
    required this.planFocus,
    required this.planTitles,
  });

  final String uid;
  final String name;

  /// 파트너의 신체 스펙(무게 추정용). 이름/기록만 담긴 축약 프로필.
  final UserProfile profile;
  final Set<EquipmentType> available;

  /// exerciseId → 작업 중량(kg)
  final Map<String, double> workingWeights;

  /// 'yyyy-MM-dd' → 부위 목록
  final Map<String, List<MuscleGroup>> planFocus;
  final Map<String, String> planTitles;

  static Map<String, dynamic> build({
    required String uid,
    required UserProfile me,
    required Set<EquipmentType> available,
    required Map<String, ExerciseProgress> progress,
    required List<DayPlan> plans,
    String? email,
  }) {
    final today = dateOnly(DateTime.now());
    final from = today.subtract(const Duration(days: 7));
    final to = today.add(const Duration(days: 14));
    return {
      'uid': uid,
      'name': me.name,
      'email': email,
      'profile': {
        'sex': me.sex.name,
        'weightKg': me.weightKg,
        'heightCm': me.heightCm,
        'age': me.age,
        'level': me.level.name,
        'goal': me.goal.name,
        'splitDays': me.splitDays,
        'sessionMinutes': me.sessionMinutes,
        'skeletalMuscleKg': me.skeletalMuscleKg,
        'bodyFatPct': me.bodyFatPct,
        'squat1rm': me.squat1rm,
        'bench1rm': me.bench1rm,
        'deadlift1rm': me.deadlift1rm,
        'ohp1rm': me.ohp1rm,
        'injuries': me.injuries.map((i) => i.name).toList(),
      },
      'available': available.map((e) => e.name).toList(),
      'weights': {for (final p in progress.entries) if (p.value.workingWeight > 0) p.key: p.value.workingWeight},
      'plans': {
        for (final p in plans)
          if (!p.isRest && !p.date.isBefore(from) && !p.date.isAfter(to))
            dateKey(p.date): {'focus': p.focus.map((g) => g.name).toList(), 'title': p.title ?? ''},
      },
    };
  }

  factory PartnerProfile.fromJson(Map<String, dynamic> j) {
    final pj = (j['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final profile = UserProfile(
      id: j['uid'] as String,
      name: (j['name'] as String?) ?? '파트너',
      sex: Sex.values.firstWhere((s) => s.name == pj['sex'], orElse: () => Sex.male),
      weightKg: (pj['weightKg'] as num?)?.toDouble() ?? 70,
      heightCm: (pj['heightCm'] as num?)?.toDouble() ?? 170,
      age: (pj['age'] as num?)?.toInt() ?? 28,
      level: TrainingLevel.values.firstWhere((l) => l.name == pj['level'], orElse: () => TrainingLevel.beginner),
      goal: TrainingGoal.parse((pj['goal'] as String?) ?? 'hypertrophy'),
      splitDays: (pj['splitDays'] as num?)?.toInt() ?? 3,
      sessionMinutes: (pj['sessionMinutes'] as num?)?.toInt() ?? 120,
      skeletalMuscleKg: (pj['skeletalMuscleKg'] as num?)?.toDouble(),
      bodyFatPct: (pj['bodyFatPct'] as num?)?.toDouble(),
      squat1rm: (pj['squat1rm'] as num?)?.toDouble(),
      bench1rm: (pj['bench1rm'] as num?)?.toDouble(),
      deadlift1rm: (pj['deadlift1rm'] as num?)?.toDouble(),
      ohp1rm: (pj['ohp1rm'] as num?)?.toDouble(),
      injuries: ((pj['injuries'] as List?) ?? const [])
          .map((v) => InjuryArea.tryParse(v as String))
          .whereType<InjuryArea>()
          .toSet(),
    );
    final available = <EquipmentType>{};
    for (final n in (j['available'] as List?) ?? const []) {
      try {
        available.add(EquipmentType.parse(n as String));
      } catch (_) {}
    }
    final planFocus = <String, List<MuscleGroup>>{};
    final planTitles = <String, String>{};
    for (final e in ((j['plans'] as Map?) ?? const {}).entries) {
      final m = (e.value as Map).cast<String, dynamic>();
      planFocus[e.key as String] = ((m['focus'] as List?) ?? const [])
          .map((f) {
            try {
              return MuscleGroup.parse(f as String);
            } catch (_) {
              return null;
            }
          })
          .whereType<MuscleGroup>()
          .toList();
      planTitles[e.key as String] = (m['title'] as String?) ?? '';
    }
    return PartnerProfile(
      uid: j['uid'] as String,
      name: profile.name,
      profile: profile,
      available: available,
      workingWeights: {
        for (final w in ((j['weights'] as Map?) ?? const {}).entries) w.key as String: (w.value as num).toDouble(),
      },
      planFocus: planFocus,
      planTitles: planTitles,
    );
  }
}

/// 파트너가 보낸 "같이 할 루틴".
class InboxItem {
  InboxItem({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.date,
    required this.code,
    required this.title,
  });
  final String id;
  final String fromUid;
  final String fromName;
  final DateTime date;
  final String code;
  final String title;
}
