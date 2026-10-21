/// 앱 전역 상태. 저장소를 메모리에 올려두고 변경 시마다 저장한다.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/store.dart';
import '../data/catalog.dart';
import '../engine/planner.dart';
import '../engine/progression.dart';
import '../engine/session_generator.dart';
import '../models/models.dart';
import '../engine/load_estimator.dart';
import '../engine/stats.dart';
import '../services/ai_coach.dart';
import '../services/cloud_sync.dart';
import '../services/partner.dart';
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

  /// 기구 종류별 무게 한 칸(핀 5 / 원판 2.5 / 사용자 지정).
  Map<EquipmentType, double> get equipmentStep {
    final m = <EquipmentType, double>{};
    for (final e in activeGym?.equipment ?? const <GymEquipment>[]) {
      final s = e.effectiveStep;
      if (s > 0) m[e.type] = s;
    }
    return m;
  }

  Map<String, ExerciseProgress> get progress =>
      _data.progress.putIfAbsent(currentUser?.id ?? '_', () => {});

  Future<void> load() async {
    _data = await _store.load();
    _loaded = true;
    if (cloudSignedIn) {
      // 계정 세션이 살아 있으면 로그인 화면을 건너뛴다.
      _ensureProfileForAccount();
      _authed = currentUser != null;
      notifyListeners();
      // 다른 기기에서 바꾼 내용이 있으면 내려받는다 (실패해도 로컬로 계속).
      try {
        await _pullIfNewer();
        _ensureProfileForAccount();
        _authed = currentUser != null;
      } catch (_) {}
      await refreshInbox();
      try {
        await _publishPublic();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// 계정으로 들어왔는데 프로필이 없으면 계정 이름으로 하나 만든다.
  void _ensureProfileForAccount() {
    if (!cloudSignedIn) return;
    if (_data.profiles.isEmpty) {
      final name = CloudSync.instance.displayName?.trim();
      final email = CloudSync.instance.email ?? '';
      final p = UserProfile(
        id: newId(),
        name: (name == null || name.isEmpty) ? email.split('@').first : name,
      );
      if (_data.gyms.isNotEmpty) p.activeGymId = _data.gyms.first.id;
      _data.profiles.add(p);
      _data.currentUserId = p.id;
    } else if (currentUser == null) {
      _data.currentUserId = _data.profiles.first.id;
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
      await _publishPublic();
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

  /// 이메일/비밀번호 로그인 또는 가입.
  Future<String> cloudSignIn(String email, String password, {bool create = false}) =>
      _cloudAuth(() => create
          ? CloudSync.instance.signUp(email, password)
          : CloudSync.instance.signIn(email, password));

  /// 구글(Gmail) 로그인.
  Future<String> cloudSignInWithGoogle() =>
      _cloudAuth(() => CloudSync.instance.signInWithGoogle());

  /// 인증 뒤 데이터 합치기. 반환값은 사용자에게 보여줄 결과 메시지.
  ///
  /// - 클라우드에 데이터가 있으면 그걸 기준으로 하고, 이 기기에만 있던 것은 합친다.
  /// - 클라우드가 비어 있으면 지금 기기의 데이터를 올린다(첫 가입).
  Future<String> _cloudAuth(Future<void> Function() auth) async {
    if (!cloudAvailable) throw CloudException('클라우드가 설정되지 않았습니다.');
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await auth();
      final remote = await CloudSync.instance.pull();
      String msg;
      if (remote != null && !remote.$1.isEmpty) {
        final local = _data;
        _data = remote.$1;
        _mergeFrom(local);
        msg = '계정의 데이터를 불러왔어요. 이제 어느 기기에서든 같은 데이터를 봅니다.';
      } else {
        msg = _data.isEmpty ? '환영합니다! 헬스장 기구를 등록하고 루틴을 만들어 보세요.' : '로그인 완료. 이 기기의 데이터를 계정에 올렸어요.';
      }
      _ensureProfileForAccount();
      _authed = true;
      _data.updatedAt = DateTime.now();
      await _store.save(_data);
      await CloudSync.instance.push(_data);
      try {
        await _publishPublic();
      } catch (_) {}
      lastSyncedAt = DateTime.now();
      notifyListeners();
      await refreshInbox();
      return msg;
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
    _authed = false; // 로그인 화면으로
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

  /// 앱 로그아웃. 계정에 로그인돼 있으면 계정도 함께 로그아웃한다.
  Future<void> logout() async {
    if (cloudSignedIn) {
      await cloudSignOut();
      return;
    }
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
      {String? name, double? maxWeight, String? note, LoadMechanism? mechanism, double? stepKg}) async {
    final g = _data.gyms.where((g) => g.id == gymId).firstOrNull;
    if (g == null) return;
    g.equipment.add(GymEquipment(
        id: newId(), type: type, customName: name, maxWeightKg: maxWeight, note: note, mechanism: mechanism, stepKg: stepKg));
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
      equipmentStep: equipmentStep,
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

  /// 그날의 부위를 바꾸고 루틴을 다시 뽑는다. [shiftFollowing]이면 이후 미완료 날짜를
  /// 이 날 기준으로 다시 배치한다(플래너가 이 날의 제목을 보고 분할 순서를 이어감).
  Future<void> changeDayFocus(
    DateTime date,
    List<MuscleGroup> groups, {
    String? title,
    bool shiftFollowing = false,
  }) async {
    final u = currentUser;
    if (u == null || groups.isEmpty) return;
    final d = dateOnly(date);
    final existing = planOn(d);
    if (existing != null && existing.isFinished) return;
    final exercises = SessionGenerator(SessionRequest(
      groups: groups,
      available: availableEquipment,
      progress: progress,
      profile: u,
      minutesBudget: u.sessionMinutes,
      now: d,
      equipmentMax: equipmentMax,
      equipmentStep: equipmentStep,
      seed: d.millisecondsSinceEpoch ~/ 86400000 + groups.length,
    )).generate();
    final plan = DayPlan(
      id: existing?.id ?? newId(),
      userId: u.id,
      date: d,
      kind: DayKind.workout,
      focus: groups,
      exercises: exercises,
      estimatedMinutes: SessionGenerator.estimateMinutes(exercises),
      title: '${title ?? groups.map((g) => g.label).join('·')}${existing?.partnerName != null ? ' · ${existing!.partnerName}와 함께' : ''}',
      partnerName: existing?.partnerName,
    );
    if (existing != null) _data.plans.remove(existing);
    _data.plans.add(plan);
    await _save();
    await resyncPartnerDay(plan);

    if (shiftFollowing) await rebalanceAfter(d);
  }

  /// [d] 이후의 미완료 날짜를 다시 짠다. 플래너가 [d]까지의 계획을 이력으로 보고
  /// 분할 순서와 부위별 회복 시간을 이어가므로, 중간에 끼워 넣은 파트너 운동이나
  /// 바뀐 부위 뒤에서도 같은 부위가 연달아 오거나 빠지는 일이 없다.
  Future<void> rebalanceAfter(DateTime d) async {
    final future = myPlans.where((p) => p.date.isAfter(d) && !p.isFinished).toList();
    if (future.isEmpty) return;
    await generatePlans(
      from: d.add(const Duration(days: 1)),
      to: future.last.date,
      restDays: manualRestDays,
    );
  }

  // ───────── AI 코치 ─────────

  /// AI에게 그날 루틴을 짜게 한다(미리보기용 — 적용은 [applyAiPlan]).
  Future<AiPlan> aiPlanFor(DateTime date, {String? request}) async {
    final u = currentUser;
    if (u == null) throw AiCoachException('프로필이 없어요.');
    final d = dateOnly(date);
    final existing = planOn(d);
    final focus = (existing != null && !existing.isRest && existing.focus.isNotEmpty)
        ? existing.focus
        : (await regenerateDay(d))?.focus ?? const <MuscleGroup>[];
    if (focus.isEmpty) throw AiCoachException('그날 부위를 정할 수 없어요. 먼저 루틴을 생성하세요.');
    final recent = myPlans.where((p) => p.isFinished && !p.isRest && p.date.isBefore(d)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    PartnerProfile? partner;
    if (existing?.partnerName != null && cloudSignedIn) {
      final link = _data.partners.where((p) => p.name == existing!.partnerName).firstOrNull;
      if (link != null) {
        try {
          partner = await CloudSync.instance.fetchPartner(link.uid);
        } catch (_) {}
      }
    }
    final ctx = AiContext(
      profile: u,
      date: d,
      focus: focus,
      available: availableEquipment,
      progress: progress,
      recent: recent.take(8).toList(),
      stats: Stats.summarize(myPlans, days: 28, now: d),
      condition: existing?.condition,
      loadFactor: existing?.loadFactor ?? 1.0,
      minutes: existing != null && existing.estimatedMinutes > 0 ? null : null,
      partner: partner,
      request: request,
    );
    return AiCoach.generate(ctx);
  }

  Future<DayPlan?> applyAiPlan(DateTime date, AiPlan ai) async {
    final u = currentUser;
    if (u == null) return null;
    final d = dateOnly(date);
    final existing = planOn(d);
    if (existing != null && existing.isFinished) return existing;
    final plan = DayPlan(
      id: existing?.id ?? newId(),
      userId: u.id,
      date: d,
      kind: DayKind.workout,
      focus: ai.focus,
      exercises: ai.exercises,
      estimatedMinutes: SessionGenerator.estimateMinutes(ai.exercises),
      intensityFactor: existing?.intensityFactor ?? 1.0,
      loadFactor: existing?.loadFactor ?? 1.0,
      condition: existing?.condition,
      title: '${ai.title} ✨',
      partnerName: existing?.partnerName,
      partnerWeights: {
        if (existing != null)
          for (final e in existing.partnerWeights.entries)
            if (ai.exercises.any((x) => x.exerciseId == e.key)) e.key: e.value,
      },
    );
    if (existing != null) _data.plans.remove(existing);
    _data.plans.add(plan);
    await _save();
    await resyncPartnerDay(plan);
    return plan;
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
      equipmentStep: equipmentStep,
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
      {int? reps, double? weight, int? level, bool? completed}) async {
    final s = ex.sets[setIndex];
    if (reps != null) s.doneReps = reps;
    if (weight != null) s.doneWeight = weight;
    if (level != null) s.doneLevel = level;
    if (completed != null) s.completed = completed;
    await _save();
  }

  Future<void> addSet(DayPlan plan, PlannedExercise ex) async {
    final last = ex.sets.last;
    ex.sets.add(SetEntry(
        targetReps: last.targetReps, targetWeight: last.targetWeight, level: last.level));
    await _save();
    await resyncPartnerDay(plan);
  }

  Future<void> removeExercise(DayPlan plan, PlannedExercise ex) async {
    plan.exercises.remove(ex);
    await _save();
    await resyncPartnerDay(plan);
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
      equipmentStep: equipmentStep,
    ));
    // 생성기의 처방 로직을 재사용하려고 단일 운동 세션을 만든 뒤 해당 운동만 뽑는다.
    final planned = gen.generate().where((p) => p.exerciseId == to.id).firstOrNull ??
        _planSingle(to, u);
    plan.exercises[i] = planned;
    await _save();
    await resyncPartnerDay(plan);
  }

  PlannedExercise _planSingle(Exercise ex, UserProfile u) {
    final gen = SessionGenerator(SessionRequest(
      groups: [ex.group],
      available: {...availableEquipment, ...ex.equipment},
      progress: progress,
      profile: u,
      minutesBudget: 120,
      equipmentMax: equipmentMax,
      equipmentStep: equipmentStep,
    ));
    return gen.generate().firstWhere((p) => p.exerciseId == ex.id,
        orElse: () => gen.generate().first);
  }

  /// 오늘 컨디션 적용: 같은 부위 구성으로 무게 배율·시간 예산만 바꿔 다시 뽑는다.
  /// [condition] 1~10, [loadFactor] 0.5~1.1, [minutes] 오늘 운동 시간.
  Future<DayPlan?> applyCondition(
    DateTime date, {
    required int condition,
    required double loadFactor,
    required int minutes,
  }) async {
    final u = currentUser;
    if (u == null) return null;
    var existing = planOn(date);
    if (existing == null || existing.isRest) {
      existing = await regenerateDay(date);
      if (existing == null) return null;
    }
    if (existing.isFinished) return existing;

    List<PlannedExercise> exercises;
    var trimmed = false;
    if (existing.partnerName != null) {
      // 파트너 운동일: 운동 구성은 그대로 두고(파트너와 같은 운동), 내 무게만 배율 적용.
      exercises = [
        for (final pe in existing.exercises)
          PlannedExercise(
            exerciseId: pe.exerciseId,
            equipmentType: pe.equipmentType,
            restSeconds: pe.restSeconds,
            note: pe.note,
            sets: [
              for (final s in pe.sets)
                SetEntry(
                  targetReps: s.targetReps,
                  level: s.level,
                  targetWeight: s.targetWeight > 0
                      ? max(
                          exerciseById(pe.exerciseId)!.loadType.increment,
                          LoadEstimator.roundTo(
                            s.targetWeight / existing.loadFactor * loadFactor,
                            exerciseById(pe.exerciseId)!.loadType.increment,
                          ),
                        )
                      : 0,
                ),
            ],
          ),
      ];
      // 시간을 줄였으면 뒤쪽(보조) 운동부터 뺀다. 유산소는 마지막에 남긴다.
      while (exercises.length > 1 && SessionGenerator.estimateMinutes(exercises) > minutes) {
        final idx = exercises.lastIndexWhere((e) => exerciseById(e.exerciseId)!.loadType != LoadType.cardio);
        exercises.removeAt(idx < 0 ? exercises.length - 1 : idx);
        trimmed = true;
      }
    } else {
      exercises = SessionGenerator(SessionRequest(
        groups: existing.focus,
        available: availableEquipment,
        progress: progress,
        profile: u,
        minutesBudget: minutes,
        intensityFactor: existing.intensityFactor,
        loadFactor: loadFactor,
        now: dateOnly(date),
        equipmentMax: equipmentMax,
        equipmentStep: equipmentStep,
        seed: dateOnly(date).millisecondsSinceEpoch ~/ 86400000,
      )).generate();
    }
    final plan = DayPlan(
      id: existing.id,
      userId: u.id,
      date: existing.date,
      kind: DayKind.workout,
      focus: existing.focus,
      exercises: exercises,
      estimatedMinutes: SessionGenerator.estimateMinutes(exercises),
      intensityFactor: existing.intensityFactor,
      loadFactor: loadFactor,
      condition: condition,
      title: existing.title,
      partnerName: existing.partnerName,
      partnerWeights: existing.partnerWeights,
    );
    _data.plans.remove(existing);
    _data.plans.add(plan);
    await _save();
    if (plan.partnerName != null) {
      // 파트너도 내 컨디션을 보고, 줄인 시간은 둘이 같은 루틴이어야 하므로 다시 보낸다.
      unawaited(_publishPublic().catchError((_) {}));
      if (trimmed) await resyncPartnerDay(plan);
    }
    return plan;
  }

  /// 세션 완료 → 진행 상태 갱신. 운동별 한 줄 메시지를 돌려준다.
  /// [rpe] 운동 후 체감 강도 1~10.
  Future<List<String>> finishDay(DayPlan plan, {int? rpe}) async {
    final msgs = <String>[];
    final now = DateTime.now();
    plan.rpe = rpe;
    for (final pe in plan.exercises) {
      if (!pe.anyCompleted) continue;
      final ex = exerciseById(pe.exerciseId);
      if (ex == null) continue;
      // 처음 하는 운동의 기준 무게. 컨디션으로 낮춘 날이면 배율을 되돌려 평소 무게로 잡는다.
      final baseline = plan.loadFactor > 0 && plan.loadFactor != 1.0
          ? LoadEstimator.roundTo(pe.sets.first.targetWeight / plan.loadFactor, ex.loadType.increment)
          : pe.sets.first.targetWeight;
      final baseReps = plan.loadFactor < 0.85 && ex.loadType != LoadType.cardio && ex.loadType != LoadType.bodyweight
          ? pe.sets.first.targetReps - 2
          : pe.sets.first.targetReps;
      final cur = progress.putIfAbsent(
        pe.exerciseId,
        () => ExerciseProgress(
          exerciseId: pe.exerciseId,
          workingWeight: baseline,
          targetReps: baseReps,
        ),
      );
      if (cur.workingWeight == 0 && baseline > 0) {
        cur.workingWeight = baseline;
      }
      final r = Progression.apply(pe, cur, now, loadFactor: plan.loadFactor, rpe: rpe);
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

  // ───────── 파트너 (계정 연동) ─────────

  List<PartnerLink> get partners => _data.partners;
  List<InboxItem> inbox = const [];

  Future<void> _publishPublic() async {
    final u = currentUser;
    if (u == null || !cloudSignedIn) return;
    await CloudSync.instance.publishPublic(PartnerProfile.build(
      uid: CloudSync.instance.user!.uid,
      me: u,
      available: availableEquipment,
      progress: progress,
      plans: myPlans,
      handle: myHandle,
    ));
  }

  Future<void> refreshInbox() async {
    if (!cloudSignedIn) return;
    try {
      final items = await CloudSync.instance.readInbox();
      // 수락/거절 답장은 자동 처리하고 지운다. 요청·루틴은 화면에 남겨 사용자가 결정.
      final keep = <InboxItem>[];
      var changed = false;
      for (final it in items) {
        if (it.type == InboxType.partnerAccept) {
          final i = _data.partners.indexWhere((p) => p.uid == it.fromUid);
          if (i >= 0) {
            _data.partners[i].pending = false;
            _data.partners[i].name = it.fromName;
          } else {
            _data.partners.add(PartnerLink(uid: it.fromUid, name: it.fromName, handle: it.fromHandle));
          }
          changed = true;
          lastPartnerNotice = '${it.fromName} 님이 파트너 요청을 수락했어요.';
          try {
            await CloudSync.instance.deleteInbox(it.id);
          } catch (_) {}
        } else if (it.type == InboxType.partnerDecline) {
          _data.partners.removeWhere((p) => p.uid == it.fromUid);
          changed = true;
          lastPartnerNotice = '${it.fromName} 님이 파트너 요청을 거절했어요.';
          try {
            await CloudSync.instance.deleteInbox(it.id);
          } catch (_) {}
        } else if (it.type == InboxType.jointAccepted) {
          final d = it.date;
          lastPartnerNotice = d == null
              ? '${it.fromName} 님이 파트너 루틴을 수락했어요.'
              : '${it.fromName} 님이 ${d.month}/${d.day} 파트너 루틴을 수락했어요. 둘 다 같은 루틴으로 뜹니다.';
          try {
            await CloudSync.instance.deleteInbox(it.id);
          } catch (_) {}
          notifyListeners();
        } else if (it.type == InboxType.joint && it.date != null && it.code != null) {
          // 이미 그 파트너와 잡아둔 날이고 아직 시작 전이면 자동으로 맞춘다(루틴 동기화).
          final existing = planOn(it.date!);
          final started = existing != null && (existing.isFinished || existing.exercises.any((e) => e.anyCompleted));
          if (existing != null && existing.partnerName == it.fromName && !started) {
            await _applyJointSilently(it);
            lastPartnerNotice = '${it.fromName} 님이 ${it.date!.month}/${it.date!.day} 루틴을 바꿔서 내 것도 맞췄어요.';
            changed = true;
          } else {
            keep.add(it);
          }
        } else {
          keep.add(it);
        }
      }
      inbox = keep;
      try {
        await _refreshPartnerConditions();
      } catch (_) {}
      if (changed) {
        await _save();
      } else {
        notifyListeners();
      }
    } catch (_) {}
  }

  /// 마지막 파트너 관련 알림(수락/거절). 화면에서 한 번 보여주고 지운다.
  String? lastPartnerNotice;

  /// 파트너 운동일(dateKey) → 파트너가 입력한 컨디션. 받은편지함 갱신 때 같이 가져온다.
  Map<String, PartnerCondition> partnerConditions = {};

  PartnerCondition? partnerConditionOn(DateTime d) => partnerConditions[dateKey(d)];

  Future<void> _refreshPartnerConditions() async {
    final today = dateOnly(DateTime.now());
    final days = myPlans.where((p) =>
        p.partnerName != null && !p.isFinished && !p.date.isBefore(today) && p.date.difference(today).inDays <= 7);
    final cache = <String, PartnerProfile?>{};
    final next = <String, PartnerCondition>{};
    for (final p in days) {
      final link = _data.partners.where((l) => l.name == p.partnerName && !l.pending).firstOrNull;
      if (link == null) continue;
      final pp = cache[link.uid] ??= await CloudSync.instance.fetchPartner(link.uid);
      final key = dateKey(p.date);
      final c = pp?.dayCondition[key];
      if (c != null) next[key] = PartnerCondition(name: pp!.name, condition: c, load: pp.dayLoad[key] ?? 1.0);
    }
    partnerConditions = next;
  }

  /// 내 공개 ID (닉네임#1234). 로그인 전이면 null.
  String? get myHandle {
    if (!cloudSignedIn) return null;
    return makeHandle(currentUser?.name ?? '', CloudSync.instance.user!.uid);
  }

  /// 공개 ID(닉네임#1234) 또는 이메일로 파트너 요청. 상대가 수락해야 양쪽에 등록된다.
  Future<String> addPartner(String query) async {
    if (!cloudSignedIn) return '계정에 로그인해야 파트너를 추가할 수 있어요.';
    final link = await CloudSync.instance.lookup(query);
    if (link == null) return '"$query" 를 찾지 못했어요. 상대의 ID(닉네임#1234)를 정확히 입력하고, 상대가 앱에 로그인한 적이 있어야 합니다.';
    if (link.uid == CloudSync.instance.user!.uid) return '본인이에요.';
    final existing = _data.partners.where((p) => p.uid == link.uid).firstOrNull;
    if (existing != null && !existing.pending) return '이미 등록된 파트너예요.';
    try {
      await CloudSync.instance.sendPartnerRequest(link.uid, currentUser?.name ?? '');
    } catch (e) {
      return '요청을 보내지 못했어요: $e';
    }
    if (existing == null) _data.partners.add(link..pending = true);
    await _save();
    return '${link.display} 님에게 파트너 요청을 보냈어요. 상대가 수락하면 등록됩니다.';
  }

  /// 받은 파트너 요청에 답한다.
  Future<String> answerPartnerRequest(InboxItem item, {required bool accept}) async {
    if (!cloudSignedIn) return '로그인이 필요해요.';
    try {
      await CloudSync.instance.sendPartnerAnswer(item.fromUid, currentUser?.name ?? '', accept: accept);
      await CloudSync.instance.deleteInbox(item.id);
    } catch (e) {
      return '답장을 보내지 못했어요: $e';
    }
    inbox = inbox.where((i) => i.id != item.id).toList();
    if (accept) {
      final i = _data.partners.indexWhere((p) => p.uid == item.fromUid);
      if (i >= 0) {
        _data.partners[i].pending = false;
        _data.partners[i].name = item.fromName;
      } else {
        _data.partners.add(PartnerLink(uid: item.fromUid, name: item.fromName, handle: item.fromHandle));
      }
      await _save();
      return '${item.fromName} 님과 파트너가 됐어요.';
    }
    notifyListeners();
    return '${item.fromName} 님의 요청을 거절했어요.';
  }

  Future<void> removePartner(String uid) async {
    _data.partners.removeWhere((p) => p.uid == uid);
    await _save();
  }

  /// 파트너와 같이 할 루틴 생성 (요구: 두 사람의 부위·기구를 맞추고 무게는 각자).
  ///
  /// - 부위: 그날 두 사람 계획의 교집합. 없으면 내 부위(파트너는 따라옴).
  /// - 기구: 두 헬스장의 교집합(파트너 기구 정보가 있을 때).
  /// - 무게: 내 것은 내 이력, 파트너 것은 파트너 작업 중량 또는 파트너 스펙으로 추정.
  /// - 파트너 앱의 받은편지함에 같은 루틴을 보낸다(파트너는 자기 무게로 받음).
  Future<String> generateJointSession(DateTime date, PartnerLink partner) async {
    final u = currentUser;
    if (u == null || !cloudSignedIn) return '계정 로그인이 필요해요.';
    final pp = await CloudSync.instance.fetchPartner(partner.uid);
    if (pp == null) return '${partner.name} 님의 정보를 아직 받을 수 없어요. 상대가 앱을 한 번 열면 됩니다.';
    partner.name = pp.name;

    final d = dateOnly(date);
    final key = dateKey(d);
    if (partner.pending) return '${partner.display} 님이 아직 요청을 수락하지 않았어요.';
    final mine = planOn(d);
    if (mine != null && mine.isFinished) return '그날 운동은 이미 완료했어요.';
    final myFocus = (mine != null && !mine.isRest) ? mine.focus : (await regenerateDay(d))?.focus ?? const <MuscleGroup>[];
    final theirs = pp.planFocus[key] ?? const <MuscleGroup>[];
    var groups = myFocus.where(theirs.contains).toList();
    String note;
    if (groups.isEmpty) {
      groups = List.of(myFocus);
      note = theirs.isEmpty ? '${pp.name} 님은 오늘 계획이 없어 내 부위로 맞췄어요.' : '겹치는 부위가 없어 내 부위(${myFocus.map((g) => g.label).join('·')})로 맞췄어요.';
    } else {
      note = '공통 부위 ${groups.map((g) => g.label).join('·')}로 맞췄어요.';
    }
    final available = pp.available.isEmpty
        ? availableEquipment
        : availableEquipment.where(pp.available.contains).toSet()..add(EquipmentType.bodyweight);

    final minutes = min(u.sessionMinutes, pp.profile.sessionMinutes);
    final exercises = SessionGenerator(SessionRequest(
      groups: groups,
      available: available,
      progress: progress,
      profile: u,
      minutesBudget: minutes,
      now: d,
      equipmentMax: equipmentMax,
      equipmentStep: equipmentStep,
      seed: d.millisecondsSinceEpoch ~/ 86400000 + 7,
      extraInjuries: pp.profile.injuries, // 상대 부상 부위도 제외
      cardioOverride: u.includeCardio && pp.profile.includeCardio, // 둘 다 원할 때만 유산소
    )).generate();
    if (exercises.isEmpty) return '두 헬스장에 공통으로 있는 기구로 만들 수 있는 운동이 없어요.';

    // 파트너 무게
    final est = LoadEstimator(pp.profile);
    final pw = <String, double>{};
    for (final pe in exercises) {
      final ex = exerciseById(pe.exerciseId)!;
      final w = pp.workingWeights[ex.id] ?? est.initialWeight(ex, pe.sets.first.targetReps);
      pw[ex.id] = w;
    }
    final title = '${mine?.title ?? groups.map((g) => g.label).join('·')} · ${pp.name}와 함께';
    final plan = DayPlan(
      id: mine?.id ?? newId(),
      userId: u.id,
      date: d,
      kind: DayKind.workout,
      focus: groups,
      exercises: exercises,
      estimatedMinutes: SessionGenerator.estimateMinutes(exercises),
      intensityFactor: mine?.intensityFactor ?? 1.0,
      title: title,
      partnerName: pp.name,
      partnerWeights: pw,
    );
    final focusChanged = mine == null || !_sameGroups(mine.focus, groups);
    if (mine != null) _data.plans.remove(mine);
    _data.plans.add(plan);
    await _save();
    if (focusChanged) await rebalanceAfter(d);

    try {
      await CloudSync.instance.sendJointRoutine(
        toUid: partner.uid,
        date: d,
        code: encodeRoutine(plan, from: u.name),
        title: title,
        fromName: u.name,
      );
    } catch (_) {
      return '$note 파트너에게 보내기는 실패했어요(네트워크).';
    }
    return '$note ${pp.name} 님 앱에도 같은 루틴을 보냈어요.';
  }

  /// 루틴 가져오기 + 파트너 무게 붙이기 (알림·수락 전송 없음). 자동 동기화에 쓴다.
  Future<DayPlan?> _applyJointSilently(InboxItem item) async {
    final before = planOn(dateOnly(item.date!));
    final beforeFocus = before == null || before.isRest ? const <MuscleGroup>[] : before.focus;
    final plan = await importRoutine(item.code!, item.date!);
    if (plan == null) return null;
    plan.partnerName = item.fromName;
    if (!_sameGroups(beforeFocus, plan.focus)) await rebalanceAfter(plan.date);
    try {
      final pp = await CloudSync.instance.fetchPartner(item.fromUid);
      if (pp != null) {
        final est = LoadEstimator(pp.profile);
        for (final pe in plan.exercises) {
          final ex = exerciseById(pe.exerciseId)!;
          plan.partnerWeights[ex.id] = pp.workingWeights[ex.id] ?? est.initialWeight(ex, pe.sets.first.targetReps);
        }
      }
    } catch (_) {}
    await _save();
    try {
      await CloudSync.instance.deleteInbox(item.id);
    } catch (_) {}
    return plan;
  }

  /// 받은편지함의 루틴을 내 계획으로 적용(무게는 내 기준, 파트너 무게는 보낸 사람 기준).
  /// 적용하면 보낸 사람에게 "수락됨"이 전달된다.
  Future<String> applyInbox(InboxItem item) async {
    if (item.code == null || item.date == null) return '루틴 정보가 없어요.';
    final plan = await _applyJointSilently(item);
    if (plan != null) {
      try {
        await CloudSync.instance.sendJointAccepted(item.fromUid, item.date!, currentUser?.name ?? '');
      } catch (_) {}
    }
    try {
      await CloudSync.instance.deleteInbox(item.id);
    } catch (_) {}
    inbox = inbox.where((i) => i.id != item.id).toList();
    notifyListeners();
    return plan == null ? '루틴을 읽지 못했어요.' : '${item.date!.month}/${item.date!.day} ${item.fromName} 님과의 루틴을 넣었어요.';
  }

  static bool _sameGroups(List<MuscleGroup> a, List<MuscleGroup> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  /// 파트너 운동일의 루틴이 바뀌면(운동 교체·부위 변경·AI 적용 등) 파트너에게 다시 보낸다.
  /// 상대 앱은 아직 시작 전이면 자동으로 같은 루틴으로 맞춘다.
  Future<void> resyncPartnerDay(DayPlan plan) async {
    if (plan.partnerName == null || !cloudSignedIn) return;
    final link = _data.partners.where((p) => p.name == plan.partnerName && !p.pending).firstOrNull;
    if (link == null) return;
    try {
      await CloudSync.instance.sendJointRoutine(
        toUid: link.uid,
        date: plan.date,
        code: encodeRoutine(plan, from: currentUser?.name),
        title: plan.title ?? '파트너 루틴',
        fromName: currentUser?.name ?? '',
      );
    } catch (_) {}
  }

  /// 날짜의 계획을 삭제한다(과거·완료 포함). 완료 기록도 함께 사라진다.
  Future<void> deletePlan(DateTime date) async {
    final p = planOn(date);
    if (p == null) return;
    _data.plans.remove(p);
    await _save();
  }

  /// 파트너 운동일 해제: 그날을 혼자 하는 루틴으로 되돌린다.
  Future<void> clearPartnerDay(DateTime date) async {
    final p = planOn(date);
    if (p == null || p.isFinished) return;
    _data.plans.remove(p);
    await regenerateDay(date);
  }

  Future<void> dismissInbox(InboxItem item) async {
    try {
      await CloudSync.instance.deleteInbox(item.id);
    } catch (_) {}
    inbox = inbox.where((i) => i.id != item.id).toList();
    notifyListeners();
  }

  // ───────── 루틴 공유 (코드) ─────────

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
