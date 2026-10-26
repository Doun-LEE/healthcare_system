import 'dart:convert';
import 'dart:io';

import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/engine/planner.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

AppData _sample() {
  final u = UserProfile(id: 'u', name: '도운', splitDays: 4, cautions: {InjuryArea.knee}, injuries: {InjuryArea.wrist})
    ..warmupMode = 'custom'
    ..warmupIds.add('dyn_stretch')
    ..warmupByGroupIds['back'] = ['db_pullover']
    ..restMode = 'keep'
    ..dayStartHour = 5;
  var n = 0;
  final plans = Planner(PlannerInput(
    profile: u, from: DateTime(2026, 10, 20), to: DateTime(2026, 10, 26), restDays: const {},
    available: EquipmentType.values.toSet(), progress: {}, history: [], newId: () => 'p${n++}',
  )).build();
  plans[0]
    ..finishedAt = DateTime(2026, 10, 20, 21)
    ..startedAt = DateTime(2026, 10, 20, 19)
    ..rpe = 7
    ..partnerName = '유주연'
    ..custom = true;
  plans[0].exercises.first.sets.first
    ..completed = true
    ..doneReps = 8
    ..doneWeight = 62.5;
  plans[1].skipped = true;
  return AppData(
    profiles: [u],
    gyms: [Gym(id: 'g', name: '보스턴 피트니스', equipment: [
      GymEquipment(id: 'e1', type: EquipmentType.legPress, weightBasis: 'perSide'),
      GymEquipment(id: 'e2', type: EquipmentType.dumbbell),
    ])],
    plans: plans,
    currentUserId: 'u',
    deleted: {'gym:x': DateTime(2026, 1, 1)},
    editedAt: {'gym:g': DateTime(2026, 10, 26)},
  )..unsynced = true;
}

void main() {
  test('saving and loading keeps everything (no field dropped)', () {
    final a = _sample();
    final j1 = jsonEncode(a.toJson());
    final b = AppData.fromJson(jsonDecode(j1) as Map<String, dynamic>);
    expect(jsonEncode(b.toJson()), j1);
    expect(b.skippedItems, 0);
    expect(b.unsynced, isTrue);
  });

  test('one unreadable item (unknown machine from a newer version) does not wipe the rest, and is flagged', () {
    final j = _sample().toJson();
    final gym = ((j['gyms'] as List).first as Map<String, dynamic>);
    (gym['equipment'] as List).add({'id': 'e9', 'type': 'someFutureMachine'});
    final b = AppData.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);
    expect(b.skippedItems, greaterThan(0));
    expect(b.plans.length, _sample().plans.length);
    expect(b.profiles.single.name, '도운');
  });

  test('local file: a broken main file falls back to the last good copy', () async {
    final dir = await Directory.systemTemp.createTemp('fr_safety');
    final f = File('${dir.path}/data.json');
    final store = LocalStore(f);
    await store.save(_sample()); // first run: creates file
    final store2 = LocalStore(f);
    await store2.save(_sample()..plans.removeLast()); // second run: backs up the first, then writes
    expect(await File('${f.path}.bak').exists(), isTrue);
    await f.writeAsString('{ broken'); // crash mid-write / corruption
    final back = await LocalStore(f).load();
    expect(back.plans, isNotEmpty);
    expect(back.profiles.single.name, '도운');
    await dir.delete(recursive: true);
  });

  test('local file: missing main file but finished temp file is recovered', () async {
    final dir = await Directory.systemTemp.createTemp('fr_safety2');
    final f = File('${dir.path}/data.json');
    await File('${f.path}.tmp').writeAsString(jsonEncode(_sample().toJson()));
    final back = await LocalStore(f).load();
    expect(back.gyms.single.name, '보스턴 피트니스');
    await dir.delete(recursive: true);
  });
}
