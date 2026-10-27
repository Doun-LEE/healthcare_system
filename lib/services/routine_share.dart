/// 루틴 공유 코드 (멤버끼리 루틴 공유 / 파트너 운동).
///
/// 하루 계획의 "운동·세트·횟수"만 짧은 JSON으로 묶어 base64 텍스트로 만든다.
/// 무게는 넣지 않는다 — 불러오는 사람의 신체 스펙과 이력으로 다시 계산하기 때문에
/// 3분할 하는 사람과 무분할 하는 사람이 같은 운동을 각자 무게로 할 수 있다.
library;

import 'dart:convert';

import '../data/catalog.dart';
import '../models/models.dart';

const _prefix = 'FR1:';

class SharedVenue {
  const SharedVenue({required this.owner, required this.gymId, required this.name, required this.types});
  final String owner;
  final String gymId;
  final String name;
  final List<EquipmentType> types;
}

class SharedRoutine {
  SharedRoutine({required this.title, required this.focus, required this.items, this.from, this.venue, this.at, this.group = const []});

  /// 그룹 운동이면 참가자 전원(보낸 사람 포함). 1:1이면 비어 있을 수 있다.
  final List<GroupMember> group;
  final SharedVenue? venue;

  /// 보낸 쪽에서 이 루틴을 마지막으로 바꾼 시각(UTC).
  final DateTime? at;
  final String title;
  final List<MuscleGroup> focus;
  final List<SharedItem> items;

  /// 공유한 사람 이름.
  final String? from;
}

class SharedItem {
  SharedItem({required this.exerciseId, required this.sets, required this.reps, this.equipment});
  final String exerciseId;
  final int sets;
  final int reps;
  final EquipmentType? equipment;
}

/// [venue]: 파트너 운동 장소(누구의 어떤 헬스장). 받는 쪽이 같은 장소 기준으로 맞춘다.
String encodeRoutine(DayPlan plan, {String? from, SharedVenue? venue, DateTime? at, List<GroupMember> group = const []}) {
  final j = {
    if (at != null) 'a': at.toUtc().toIso8601String(),
    if (group.isNotEmpty) 'g': group.map((m) => m.toJson()).toList(),
    't': plan.title ?? '',
    'f': plan.focus.map((g) => g.name).toList(),
    'u': from,
    if (venue != null)
      'v': {'o': venue.owner, 'g': venue.gymId, 'n': venue.name, 'q': venue.types.map((t) => t.name).toList()},
    'e': [
      for (final pe in plan.exercises)
        if (!pe.personal) {
          'i': pe.exerciseId,
          's': pe.sets.length,
          'r': pe.sets.isEmpty ? 10 : pe.sets.first.targetReps,
          'q': pe.equipmentType.name,
        },
    ],
  };
  return _prefix + base64UrlEncode(utf8.encode(jsonEncode(j)));
}

/// 잘못된 코드면 null.
SharedRoutine? decodeRoutine(String code) {
  var c = code.trim();
  // 카톡 등에서 앞뒤 문장과 같이 붙여넣은 경우 코드만 뽑는다.
  final m = RegExp(r'FR1:[A-Za-z0-9_\-=]+').firstMatch(c);
  if (m == null) return null;
  c = m.group(0)!.substring(_prefix.length);
  try {
    final j = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(c)))) as Map<String, dynamic>;
    final items = <SharedItem>[];
    for (final e in (j['e'] as List).cast<Map<String, dynamic>>()) {
      final id = e['i'] as String;
      if (exerciseById(id) == null) continue;
      EquipmentType? eq;
      try {
        eq = EquipmentType.parse(e['q'] as String);
      } catch (_) {}
      items.add(SharedItem(
        exerciseId: id,
        sets: (e['s'] as num).toInt().clamp(1, 10),
        reps: (e['r'] as num).toInt().clamp(1, 60),
        equipment: eq,
      ));
    }
    if (items.isEmpty) return null;
    return SharedRoutine(
      title: (j['t'] as String?) ?? '',
      focus: ((j['f'] as List?) ?? [])
          .map((f) {
            try {
              return MuscleGroup.parse(f as String);
            } catch (_) {
              return null;
            }
          })
          .whereType<MuscleGroup>()
          .toList(),
      items: items,
      from: j['u'] as String?,
      venue: _venue(j['v']),
      at: j['a'] == null ? null : DateTime.tryParse(j['a'] as String),
      group: [
        for (final m in (j['g'] as List?) ?? const [])
          if (m is Map && m['u'] is String) GroupMember(m['u'] as String, (m['n'] as String?) ?? ''),
      ],
    );
  } catch (_) {
    return null;
  }
}

SharedVenue? _venue(dynamic v) {
  if (v is! Map) return null;
  try {
    return SharedVenue(
      owner: v['o'] as String,
      gymId: v['g'] as String,
      name: (v['n'] as String?) ?? '',
      types: [
        for (final n in ((v['q'] as List?) ?? const []))
          if (EquipmentType.values.any((t) => t.name == n)) EquipmentType.parse(n as String),
      ],
    );
  } catch (_) {
    return null;
  }
}
