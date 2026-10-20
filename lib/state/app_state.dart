/// 앱 전역 상태. 저장소를 메모리에 올려두고 변경 시마다 저장한다.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/store.dart';
import '../data/catalog.dart';
import '../engine/planner.dart';
import '../engine/progression.dart';
import '../engine/session_generator.dart';
import '../models/models.dart';
import '../engine/load_estimator.dart';
import '../services/cloud_sync.dart';
import '../services/inbody_scanner.dart';
import '../services/routine_share.dart';

String newId() {
  final r = Random();
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final s = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  return '$t$s';
}

class AppState extends ChangeNotifier {
  AppState(this._store);

  final DataStore _store;
  AppData _data = AppData();
  bool _loaded = false;
  bool _authed = false;

  bool get loaded => _loaded;
  bool get authed => _authed && currentUser != null;
  AppData get data => _data;

  UserProfile? get currentUser => _data.profiles
      .where((p) => p.id == _data.currentUserId)
      .firstOrNull;

  List<UserProfile> get profiles => _data.profiles;
  List<Gym> get gyms => _data.gyms;

  Gym? get activeGym {
    final u = currentUser;
    if (u == null) return null;
    return _data.gyms.where((g) => g.id == u.activeGymId).firstOrNull ??
        _data.gyms.firstOrNull;
  }

  Set<EquipmentType> get availableEquipment =>
      activeGym?.availableTypes ?? {EquipmentType.bodyweight};

  Map<EquipmentType, double> get equipmentMax {
    final m = <EquipmentType, double>{};
    for (final e in activeGym?.equipment ?? const <GymEquipment>[]) {
      if (e.maxWeightKg != null) {
        m[e.type] = max(m[e.type] ?? 0, e.maxWeightKg!);
      }
    }
    return m;
  }

  Map<String, ExerciseProgress> get progress =>
      _data.progress.putIfAbsent(currentUser?.id ?? '_', () => {});

  Future<void> load() async {
    _data = await _store.load();
    _loaded = true;
    notifyListeners();
    if (cloudSignedIn) {
      // 다른 기기에서 바꾼 내용이 있으면 내려받는다 (실패해도 로컬로 계속).
      try {
        await _pullIfNewer();
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    _data.updatedAt = DateTime.now();
    await _store.save(_data);
    notifyListeners();
    if (cloudSignedIn) _pushDebounce(_pushNow);
  }

  // ───────── 계정 / 클라우드 동기화 ─────────

  final _pushDebounce = Debouncer(const Duration(seconds: 1));
  String? syncError;
  DateTime? lastSyncedAt;
  bool syncing = false;

  bool get cloudAvailable => CloudSync.isConfigured;
  bool get cloudSignedIn => cloudAvailable && CloudSync.instance.signedIn;
  String? get cloudEmail => cloudAvailable ? CloudSync.instance.email : null;

  Future<void> _pushNow() async {
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await CloudSync.instance.push(_data);
      lastSyncedAt = DateTime.now();
    } catch (e) {
      syncError = '업로드 실패: $e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// 클라우드가 로컬보다 최신이면 내려받아 교체.
  Future<bool> _pullIfNewer() async {
    final remote = await CloudSync.instance.pull();
    if (remote == null) return false;
    final (data, _) = remote;
    if (data.updatedAt.isAfter(_data.updatedAt)) {
      _data = data;
      await _store.save(_data);
      lastSyncedAt = DateTime.now();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 로그인 또는 회원가입 뒤 호출. 반환값은 사용자에게 보여줄 결과 메시지.
  ///
  /// - 클라우드에 데이터가 있으면 그걸 기준으로 하고, 이 기기에만 있던 것은 합친다.
  /// - 클라우드가 비어 있으면 지금 기기의 데이터를 올린다(첫 가입).
  Future<String> cloudSignIn(String email, String password, {bool create = false}) async {
    if (!cloudAvailable) throw CloudException('클라우드가 설정되지 않았습니다.');
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      if (create) {
        await CloudSync.instance.signUp(email, password);
      } else {
        await CloudSync.instance.signIn(email, password);
      }
      final remote = await CloudSync.instance.pull();
      if (remote != null && !remote.$1.isEmpty) {
        final local = _data;
        _data = remote.$1;
        _mergeFrom(local);
        _data.updatedAt = DateTime.now();
        await _store.save(_data);
        await CloudSync.instance.push(_data);
        lastSyncedAt = DateTime.now();
        notifyListeners();
        return '계정의 데이터를 불러왔어요. 이제 어느 기기에서든 같은 데이터를 봅니다.';
      }
      await CloudSync.instance.push(_data);
      lastSyncedAt = DateTime.now();
      notifyListeners();
      return create ? '가입 완료. 이 기기의 데이터를 계정에 올렸어요.' : '로그인 완료. 이 기기의 데이터를 계정에 올렸어요.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// 이 기기에만 있던 프로필/헬스장/계획/진행을 현재 데이터에 합친다(같은 것은 현재 우선).
  void _mergeFrom(AppData local) {
    for (final p in local.profiles) {
      if (!_data.profiles.any((x) => x.id == p.id)) _data.profiles.add(p);
    }
    for (final g in local.gyms) {
      if (!_data.gyms.any((x) => x.id == g.id)) _data.gyms.add(g);
    }
    for (final pl in local.plans) {
      final dup = _data.plans.any((x) =>
          x.id == pl.id || (x.userId == pl.userId && dateKey(x.date) == dateKey(pl.date)));
      if (!dup) _data.plans.add(pl);
    }
    for (final e in local.progress.entries) {
      final target = _data.progress.putIfAbsent(e.key, () => {});
      for (final p in e.value.entries) {
        target.putIfAbsent(p.key, () => p.value);
      }
    }
    _data.currentUserId ??= local.currentUserId;
    if (_data.currentUserId != null && !_data.profiles.any((p) => p.id == _data.currentUserId)) {
      _data.currentUserId = _data.profiles.firstOrNull?.id;
    }
  }

  Future<void> cloudSignOut() async {
    if (!cloudAvailable) return;
    _pushDebounce.cancel();
    await CloudSync.instance.signOut();
    notifyListeners();
  }

  Future<void> cloudResetPassword(String email) => CloudSync.instance.resetPassword(email);

  /// 수동 동기화: 더 최신이면 내려받고, 아니면 올린다.
  Future<String> syncNow() async {
    if (!cloudSignedIn) return '계정에 로그인되어 있지 않아요.';
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final pulled = await _pullIfNewer();
      if (!pulled) await CloudSync.instance.push(_data);
      lastSyncedAt = DateTime.now();
      return pulled ? '다른 기기의 최신 데이터를 내려받았어요.' : '이 기기의 데이터를 올렸어요.';
    } catch (e) {
      syncError = '동기화 실패: $e';
      return syncError!;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  // ───────── 인증 / 프로필 ─────────

  bool checkCode(String code) => code.trim() == _data.accessCode;

  Future<bool> login(String profileId, String code) async {
    if (!checkCode(code)) return false;
    if (!_data.profiles.any((p) => p.id == profileId)) return false;
    _data.currentUserId = profileId;
    _authed = true;
    await _save();
    return true;
  }

  Future<UserProfile?> createProfile(String name, String code) async {
    if (!checkCode(code) || name.trim().isEmpty) return null;
    final p = UserProfile(id: newId(), name: name.trim());
    if (_data.gyms.isNotEmpty) p.activeGymId = _data.gyms.first.id;
    _data.profiles.add(p);
    _data.currentUserId = p.id;
    _authed = true;
    await _save();
    return p;
  }

  void logout() {
    _authed = false;
    notifyListeners();
  }

  Future<void> updateProfile(void Function(UserProfile) edit) async {
    final u = currentUser;
    if (u == null) return;
    edit(u);
    await _save();
  }

  Future<void> deleteProfile(String id) async {
    _data.profiles.removeWhere((p) => p.id == id);
    _data.plans.removeWhere((p) => p.userId == id);
    _data.progress.remove(id);
    if (_data.currentUserId == id) {
      _data.currentUserId = null;
      _authed = false;
    }
    await _save();
  }

  Future<void> setAccessCode(String code) async {
    if (code.trim().length < 4) return;
    _data.accessCode = code.trim();
    await _save();
  }

  Future<void> setApiKey(String key) async {
    _data.apiKey = key.trim();
    await _save();
  }

  // ───────── 헬스장 / 기구 ─────────

  Future<Gym> addGym(String name) async {
    final g = Gym(id: newId(), name: name.trim().isEmpty ? '내 헬스장' : name.trim());
    _data.gyms.add(g);
    currentUser?.activeGymId ??= g.id;
    await _save();
    return g;
  }

  Future<void> renameGym(String id, String name) async {
    final g = _data.gyms.where((g) => g.id == id).firstOrNull;
    if (g == null) return;
    g.name = name;
    await _save();
  }

  Future<void> deleteGym(String id) async {
    _data.gyms.removeWhere((g) => g.id == id);
    for (final p in _data.profiles) {
      if (p.activeGymId == id) p.activeGymId = _data.gyms.firstOrNull?.id;
    }
    await _save();
  }

  Future<void> setActiveGym(String id) async {
    await updateProfile((u) => u.activeGymId = id);
  }

  Future<void> addEquipment(String gymId, EquipmentType type,
      {String? name, double? maxWeight, String? note}) async {
    final g = _data.gyms.where((g) => g.id == gymId).firstOrNull;
    if (g == null) return;
    g.equipment.add(GymEquipment(
        id: newId(), type: type, customName: name, maxWeightKg: maxWeight, note: note));
    await _save();
  }

  Future<void> updateEquipment(String gymId, GymEquipment eq) async {
    final g = _data.gyms.where((g) => g.id == gymId).firstOrNull;
    if (g == null) return;
    final i = g.equipment.indexWhere((e) => e.id == eq.id);
    if (i >= 0) g.equipment[i] = eq;
    await _save();
  }

  Future<void> removeEquipment(String gymId, String equipmentId) async {
    final g = _data.gyms.where((g) => g.id == gymId).firstOrNull;
    if (g == null) return;
    g.equipment.removeWhere((e) => e.id == equipmentId);
    await _save();
  }

  /// 대중적인 헬스장 기본 구성을 한 번에 추가.
  Future<void> addStandardEquipment(String gymId) async {
    const standard = [
      EquipmentType.barbell,
      EquipmentType.dumbbell,
      EquipmentType.flatBench,
      EquipmentType.inclineBench,
      EquipmentType.squatRack,
      EquipmentType.smithMachine,
      EquipmentType.cableMachine,
      EquipmentType.latPulldown,
      EquipmentType.seatedRow,
      EquipmentType.chestPress,
      EquipmentType.legPress,
      EquipmentType.legExtension,
      EquipmentType.legCurl,
      EquipmentType.pullUpBar,
      EquipmentType.treadmill,
      EquipmentType.bike,
    ];
    final g = _data.gyms.where((g) => g.id == gymId).firstOrNull;
    if (g == null) return;
    final have = g.availableTypes;
    for (final t in standard) {
      if (!have.contains(t)) g.equipment.add(GymEquipment(id: newId(), type: t));
    }
    await _save();
  }

  // ───────── 계획 ─────────

  List<DayPlan> get myPlans {
    final u = currentUser;
    if (u == null) return const [];
    final list = _data.plans.where((p) => p.userId == u.id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  DayPlan? planOn(DateTime date) {
    final k = dateKey(date);
    return myPlans.where((p) => dateKey(p.date) == k).firstOrNull;
  }

  DayPlan? get todayPlan => planOn(DateTime.now());

  /// 사용자가 달력에서 체크한 휴식일(계획이 있는 날 중 '직접 설정' 휴식).
  Set<String> get manualRestDays => myPlans
      .where((p) => p.isRest && (p.title ?? '').contains('직접'))
      .map((p) => dateKey(p.date))
      .toSet();

  /// 기간 계획 생성. 이미 완료된 날은 건드리지 않는다.
  Future<List<DayPlan>> generatePlans({
    required DateTime from,
    required DateTime to,
    required Set<String> restDays,
  }) async {
    final u = currentUser;
    if (u == null) return [];
    final f = dateOnly(from);
    final t = dateOnly(to);

    final history = myPlans
        .where((p) => p.isFinished || p.date.isBefore(f))
        .toList();
    final keep = <String>{
      for (final p in myPlans)
        if (p.isFinished && !p.date.isBefore(f) && !p.date.isAfter(t)) dateKey(p.date),
    };

    final generated = Planner(PlannerInput(
      profile: u,
      from: f,
      to: t,
      restDays: restDays,
      available: availableEquipment,
      progress: progress,
      history: history,
      newId: newId,
      equipmentMax: equipmentMax,
    )).build();

    _data.plans.removeWhere((p) =>
        p.userId == u.id &&
        !p.date.isBefore(f) &&
        !p.date.isAfter(t) &&
        !keep.contains(dateKey(p.date)));
    _data.plans.addAll(generated.where((p) => !keep.contains(dateKey(p.date))));
    await _save();
    return generated;
  }

  /// 특정 날을 휴식일로 토글. 완료된 날은 변경 불가.
  Future<void> toggleRestDay(DateTime date) async {
    final u = currentUser;
    if (u == null) return;
    final existing = planOn(date);
    if (existing != null && existing.isFinished) return;
    if (existing != null && existing.isRest) {
      // 휴식 → 그날 하루만 운동으로 재생성
      _data.plans.remove(existing);
      await regenerateDay(date);
      return;
    }
    if (existing != null) _data.plans.remove(existing);
    _data.plans.add(DayPlan(
      id: newId(),
      userId: u.id,
      date: dateOnly(date),
      kind: DayKind.rest,
      focus: const [],
      title: '휴식 (직접 설정)',
    ));
    await _save();
  }

  /// 하루만 다시 생성(기구 변경 등 반영).
  Future<DayPlan?> regenerateDay(DateTime date) async {
    final u = currentUser;
    if (u == null) return null;
    final d = dateOnly(date);
    final existing = planOn(d);
    if (existing != null && existing.isFinished) return existing;
    final rest = manualRestDays..remove(dateKey(d));
    final history = myPlans.where((p) => dateKey(p.date) != dateKey(d)).toList();
    final gen = Planner(PlannerInput(
      profile: u,
      from: d,
      to: d,
      restDays: rest,
      available: availableEquipment,
      progress: progress,
      history: history,
      newId: newId,
      equipmentMax: equipmentMax,
    )).build();
    if (existing != null) _data.plans.remove(existing);
    _data.plans.addAll(gen);
    await _save();
    return gen.firstOrNull;
  }

  Future<void> deletePlansFrom(DateTime from) async {
    final u = currentUser;
    if (u == null) return;
    final f = dateOnly(from);
    _data.plans.removeWhere(
        (p) => p.userId == u.id && !p.date.isBefore(f) && !p.isFinished);
    await _save();
  }

  // ───────── 운동 수행 ─────────

  Future<void> toggleSet(DayPlan plan, PlannedExercise ex, int setIndex) async {
    final s = ex.sets[setIndex];
    s.completed = !s.completed;
    await _save();
  }

  Future<void> updateSet(DayPlan plan, PlannedExercise ex, int setIndex,
      {int? reps, double? weight, bool? completed}) async {
    final s = ex.sets[setIndex];
    if (reps != null) s.doneReps = reps;
    if (weight != null) s.doneWeight = weight;
    if (completed != null) s.completed = completed;
    await _save();
  }

  Future<void> addSet(DayPlan plan, PlannedExercise ex) async {
    final last = ex.sets.last;
    ex.sets.add(SetEntry(
        targetReps: last.targetReps, targetWeight: last.targetWeight));
    await _save();
  }

  Future<void> removeExercise(DayPlan plan, PlannedExercise ex) async {
    plan.exercises.remove(ex);
    await _save();
  }

  /// 운동 하나를 다른 운동으로 교체(같은 부위, 보유 기구로 가능한 것 중 선택).
  Future<void> swapExercise(DayPlan plan, PlannedExercise old, Exercise to) async {
    final i = plan.exercises.indexOf(old);
    if (i < 0) return;
    final u = currentUser!;
    final gen = SessionGenerator(SessionRequest(
      groups: [to.group],
      available: availableEquipment,
      progress: progress,
      profile: u,
      minutesBudget: 30,
      equipmentMax: equipmentMax,
    ));
    // 생성기의 처방 로직을 재사용하려고 단일 운동 세션을 만든 뒤 해당 운동만 뽑는다.
    final planned = gen.generate().where((p) => p.exerciseId == to.id).firstOrNull ??
        _planSingle(to, u);
    plan.exercises[i] = planned;
    await _save();
  }

  PlannedExercise _planSingle(Exercise ex, UserProfile u) {
    final gen = SessionGenerator(SessionRequest(
      groups: [ex.group],
      available: {...availableEquipment, ...ex.equipment},
      progress: progress,
      profile: u,
      minutesBudget: 120,
      equipmentMax: equipmentMax,
    ));
    return gen.generate().firstWhere((p) => p.exerciseId == ex.id,
        orElse: () => gen.generate().first);
  }

  /// 세션 완료 → 진행 상태 갱신. 운동별 한 줄 메시지를 돌려준다.
  Future<List<String>> finishDay(DayPlan plan) async {
    final msgs = <String>[];
    final now = DateTime.now();
    for (final pe in plan.exercises) {
      if (!pe.anyCompleted) continue;
      final ex = exerciseById(pe.exerciseId);
      if (ex == null) continue;
      final cur = progress.putIfAbsent(
        pe.exerciseId,
        () => ExerciseProgress(
          exerciseId: pe.exerciseId,
          workingWeight: pe.sets.first.targetWeight,
          targetReps: pe.sets.first.targetReps,
        ),
      );
      if (cur.workingWeight == 0 && pe.sets.first.targetWeight > 0) {
        cur.workingWeight = pe.sets.first.targetWeight;
      }
      final r = Progression.apply(pe, cur, now);
      msgs.add('${ex.name}: ${r.message}');
    }
    plan.finishedAt = now;
    await _save();
    return msgs;
  }

  Future<void> reopenDay(DayPlan plan) async {
    plan.finishedAt = null;
    await _save();
  }

  // ───────── 루틴 공유 / 파트너 ─────────

  String shareCode(DayPlan plan) => encodeRoutine(plan, from: currentUser?.name);

  /// 공유 코드를 특정 날짜의 계획으로 가져온다. 운동·세트·횟수는 그대로,
  /// 무게는 내 이력/신체 스펙으로 다시 계산하고, 기구는 내 헬스장에 맞춘다.
  /// 코드가 잘못됐거나 그날이 이미 완료됐으면 null.
  Future<DayPlan?> importRoutine(String code, DateTime date) async {
    final u = currentUser;
    if (u == null) return null;
    final shared = decodeRoutine(code);
    if (shared == null) return null;
    final d = dateOnly(date);
    final existing = planOn(d);
    if (existing != null && existing.isFinished) return null;

    final est = LoadEstimator(u);
    final available = availableEquipment;
    final exercises = <PlannedExercise>[];
    for (final item in shared.items) {
      final ex = exerciseById(item.exerciseId)!;
      final canDo = ex.canDoWith(available);
      final eq = canDo
          ? ex.pickEquipment(available)
          : (item.equipment ?? ex.equipment.first);
      final prog = progress[ex.id];
      final weight = (prog != null && prog.workingWeight > 0)
          ? prog.workingWeight
          : est.initialWeight(ex, item.reps, maxWeightKg: equipmentMax[eq]);
      final rule = restRules[ex.group]!;
      exercises.add(PlannedExercise(
        exerciseId: ex.id,
        equipmentType: eq,
        restSeconds: ex.compound ? rule.compoundRestSec : rule.isolationRestSec,
        sets: List.generate(item.sets, (_) => SetEntry(targetReps: item.reps, targetWeight: weight)),
        note: canDo ? '공유 루틴 · 무게는 내 기준' : '⚠ 우리 헬스장에 없는 기구 (${eq.label})',
      ));
    }
    final focus = shared.focus.isNotEmpty
        ? shared.focus
        : exercises.map((p) => exerciseById(p.exerciseId)!.group).toSet().toList();
    final plan = DayPlan(
      id: newId(),
      userId: u.id,
      date: d,
      kind: DayKind.workout,
      focus: focus,
      exercises: exercises,
      estimatedMinutes: SessionGenerator.estimateMinutes(exercises),
      title: '${shared.title.isEmpty ? '공유 루틴' : shared.title}${shared.from == null ? '' : ' (${shared.from} 공유)'}',
    );
    if (existing != null) _data.plans.remove(existing);
    _data.plans.add(plan);
    await _save();
    return plan;
  }

  // ───────── 인바디 ─────────

  Future<InBodyResult> scanInBody(Uint8List bytes) async {
    final result = await InBodyScanner(apiKey: _data.apiKey).scan(bytes);
    await updateProfile(result.applyTo);
    return result;
  }

  /// 신체 스펙 변경 후 아직 하지 않은 미래 계획의 무게를 다시 추정.
  Future<void> recalibrateFuture() async {
    final u = currentUser;
    if (u == null) return;
    final today = dateOnly(DateTime.now());
    final future = myPlans.where((p) => !p.isFinished && !p.date.isBefore(today)).toList();
    if (future.isEmpty) return;
    final rest = manualRestDays;
    final from = future.first.date;
    final to = future.last.date;
    await generatePlans(from: from, to: to, restDays: rest);
  }

  // ───────── 통계 ─────────

  int get completedSessions => myPlans.where((p) => p.isFinished && !p.isRest).length;

  int get currentStreakWeeks {
    // 최근 주 단위로 완료 세션이 1개 이상인 주가 연속 몇 주인지.
    var weeks = 0;
    var cursor = dateOnly(DateTime.now());
    while (true) {
      final start = cursor.subtract(Duration(days: cursor.weekday - 1));
      final any = myPlans.any((p) =>
          p.isFinished &&
          !p.date.isBefore(start) &&
          p.date.isBefore(start.add(const Duration(days: 7))));
      if (!any) break;
      weeks++;
      cursor = start.subtract(const Duration(days: 1));
      if (weeks > 200) break;
    }
    return weeks;
  }
}
