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
import '../engine/substitute.dart';
import '../models/models.dart';
import '../core/photo_store.dart' as photos;
import '../engine/level_assessor.dart';
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

  /// 그 날 가는 헬스장(날짜별로 바꿨으면 그것, 아니면 기본 헬스장).
  Gym? gymOf(DayPlan p) => _data.gyms.where((g) => g.id == p.gymId).firstOrNull ?? activeGym;

  Gym? gymById(String? id) => id == null ? null : _data.gyms.where((g) => g.id == id).firstOrNull;

  /// 그 날 헬스장에서 이 운동에 쓰는 실제 기구(등록한 이름·사진). 파트너 헬스장이거나 못 찾으면 null.
  /// 같은 종류가 여러 대면 사진 있는 것 → 브랜드 지정한 것 → 먼저 등록한 것 순.
  GymEquipment? equipmentFor(DayPlan plan, EquipmentType type) {
    if (plan.atOtherGym || type == EquipmentType.bodyweight) return null;
    final list = gymOf(plan)?.equipment ?? const <GymEquipment>[];
    final exact = list.where((e) => e.type == type).toList();
    final pool = exact.isNotEmpty ? exact : list.where((e) => e.allTypes.contains(type)).toList();
    if (pool.isEmpty) return null;
    return pool.firstWhere((e) => e.hasPhoto, orElse: () => pool.firstWhere((e) => e.brand != null, orElse: () => pool.first));
  }

  /// 화면 무게 배율(기구별 '한쪽/양쪽' 기준). 표시 = 내부 × 배율.
  double weightFactor(DayPlan plan, EquipmentType type) => equipmentFor(plan, type)?.displayFactor ?? 1;
  String weightBasisLabel(DayPlan plan, EquipmentType type) => equipmentFor(plan, type)?.basisLabel ?? '';

  /// 앞으로 할 날의 처방(목표 무게·횟수)을 직접 바꾼다. 그 운동의 모든 세트에 적용.
  Future<void> setTarget(DayPlan plan, PlannedExercise pe, {int? reps, double? weight, int? level}) async {
    for (var i = 0; i < pe.sets.length; i++) {
      final s0 = pe.sets[i];
      pe.sets[i] = SetEntry(
        targetReps: reps ?? s0.targetReps,
        targetWeight: weight ?? s0.targetWeight,
        level: level ?? s0.level,
        extra: s0.extra,
      );
    }
    plan.custom = true;
    await _save();
    await resyncPartnerDay(plan);
  }

  /// 운동 시작 시각을 직접 정한다(늦게 누른 경우).
  Future<void> setWorkoutStart(DayPlan plan, DateTime at) async {
    plan.startedAt = at;
    await _save();
  }

  /// 같은 헬스장 안에 똑같은(종류·이름·방식 같음) 기구가 여러 개 있으면 하나만 남긴다.
  void _dedupeEquipment() {
    for (final g in _data.gyms) {
      final seen = <String>{};
      g.equipment.removeWhere((e) {
        final k = '${e.type.name}|${e.displayName}|${e.mechanism.name}|${e.extraTypes.map((t) => t.name).join(',')}';
        if (seen.contains(k) && !e.hasPhoto) return true;
        seen.add(k);
        return false;
      });
    }
  }

  /// 루틴에 보여줄 기구 이름: 등록 이름(브랜드 모델명·별칭) 또는 종류 이름.
  String equipmentLabelFor(DayPlan plan, EquipmentType type) {
    if (type == EquipmentType.bodyweight) return '맨몸';
    return equipmentFor(plan, type)?.displayName ?? type.label;
  }

  /// 그 날 운동할 수 있는 기구: 파트너 헬스장이면 그곳 기구, 아니면 그 날 헬스장 기구.
  Set<EquipmentType> availableFor(DayPlan? p) {
    if (p != null && p.atOtherGym) return {EquipmentType.bodyweight, ...p.venueTypes};
    return (p == null ? activeGym : gymOf(p))?.availableTypes ?? {EquipmentType.bodyweight};
  }

  Map<EquipmentType, double> maxForGym(Gym? g) {
    final m = <EquipmentType, double>{};
    for (final e in g?.equipment ?? const <GymEquipment>[]) {
      if (e.maxWeightKg != null) {
        for (final t in e.allTypes) {
          m[t] = max(m[t] ?? 0, e.maxWeightKg!);
        }
      }
    }
    return m;
  }

  Map<EquipmentType, double> stepForGym(Gym? g) {
    final m = <EquipmentType, double>{};
    for (final e in g?.equipment ?? const <GymEquipment>[]) {
      final st = e.effectiveStep;
      if (st > 0) {
        for (final t in e.allTypes) {
          m[t] = st;
        }
      }
    }
    return m;
  }

  Map<EquipmentType, double> maxForPlan(DayPlan? p) =>
      p != null && p.atOtherGym ? const {} : maxForGym(p == null ? activeGym : gymOf(p));
  Map<EquipmentType, double> stepForPlan(DayPlan? p) =>
      p != null && p.atOtherGym ? const {} : stepForGym(p == null ? activeGym : gymOf(p));

  /// 계획을 새로 만들 때 이전 계획의 장소(헬스장·파트너 헬스장)를 그대로 옮긴다.
  void _copyVenue(DayPlan from, DayPlan to) {
    to.gymId = from.gymId;
    to.venueOwner = from.venueOwner;
    to.venueGymId = from.venueGymId;
    to.venueName = from.venueName;
    to.venueTypes = List.of(from.venueTypes);
  }

  /// 파트너에게 보낼 장소 정보.
  SharedVenue? venueOf(DayPlan p) {
    if (p.venueOwner == null || p.venueGymId == null) return null;
    return SharedVenue(
      owner: p.venueOwner!,
      gymId: p.venueGymId!,
      name: p.venueName ?? '',
      types: p.atOtherGym ? p.venueTypes : (gymById(p.venueGymId)?.availableTypes.toList() ?? const []),
    );
  }

  /// 장소를 계획에 적용(내 헬스장이면 gymId, 파트너 헬스장이면 그 기구 목록).
  void _applyVenue(DayPlan plan, SharedVenue v) {
    final myUid = cloudSignedIn ? CloudSync.instance.user!.uid : null;
    plan.venueOwner = v.owner;
    plan.venueGymId = v.gymId;
    plan.venueName = v.name;
    if (v.owner == myUid && gymById(v.gymId) != null) {
      plan.gymId = v.gymId;
      plan.venueTypes = [];
    } else {
      plan.venueTypes = List.of(v.types);
    }
  }

  /// 다른 헬스장으로 바꾸고, 같은 부위로 그 헬스장 기구에 맞춰 루틴을 새로 짠다
  /// (그 헬스장에만 있는 머신도 후보가 된다). 파트너 날이면 파트너에게도 다시 보낸다.
  Future<void> rebuildDayAtGym(DayPlan plan, String gymId) async {
    final gym = gymById(gymId);
    if (gym == null || plan.isFinished) return;
    plan.gymId = gymId;
    if (plan.partnerName != null && cloudSignedIn) {
      plan.venueOwner = CloudSync.instance.user!.uid;
      plan.venueGymId = gymId;
      plan.venueName = gym.name;
    } else {
      plan.venueOwner = null;
      plan.venueGymId = null;
      plan.venueName = null;
    }
    plan.venueTypes = [];
    final base = (plan.title ?? '').split(' · ').first.replaceAll(' ✨', '');
    // changeDayFocus가 파트너 날이면 파트너에게도 다시 보낸다.
    await changeDayFocus(plan.date, plan.focus, title: base.isEmpty ? null : base, shiftFollowing: false);
  }

  /// 다른 헬스장으로 바꾸고, 거기 없는 기구의 운동을 비슷한 운동으로 대체한다.
  /// 운동 구성(세트 수·횟수 틀)은 최대한 유지. 바뀐 내용을 문장으로 돌려준다.
  Future<List<String>> switchDayGym(DayPlan plan, String gymId) async {
    _markCustom(plan);
    final u = currentUser;
    final gym = _data.gyms.where((g) => g.id == gymId).firstOrNull;
    if (u == null || gym == null || plan.isFinished) return const [];
    final avail = gym.availableTypes;
    final msgs = <String>[];
    final used = plan.exercises.map((e) => e.exerciseId).toSet();
    for (var i = 0; i < plan.exercises.length; i++) {
      final pe = plan.exercises[i];
      final ex = exerciseById(pe.exerciseId);
      if (ex == null) continue;
      if (ex.canDoWith(avail)) {
        if (!avail.contains(pe.equipmentType)) {
          final eq = ex.pickEquipment(avail);
          plan.exercises[i] = PlannedExercise(
            exerciseId: pe.exerciseId,
            equipmentType: eq,
            restSeconds: pe.restSeconds,
            sets: pe.sets,
            note: '${gym.name}: ${pe.equipmentType.label} 대신 ${eq.label}',
            personal: pe.personal,
          );
          msgs.add('${ex.name}: ${pe.equipmentType.label} → ${eq.label}');
        }
        continue;
      }
      final alt = substituteFor(ex, avail, exclude: used);
      if (alt == null) {
        msgs.add('${ex.name}: ${gym.name}에 할 수 있는 기구가 없어 제외');
        plan.exercises.removeAt(i);
        i--;
        continue;
      }
      used.add(alt.id);
      final base = _planSingle(alt, u);
      final eq = alt.pickEquipment(avail);
      plan.exercises[i] = PlannedExercise(
        exerciseId: alt.id,
        equipmentType: eq,
        restSeconds: pe.restSeconds,
        sets: List.generate(
          pe.sets.length,
          (_) => SetEntry(targetReps: base.sets.first.targetReps, targetWeight: base.sets.first.targetWeight, level: base.sets.first.level),
        ),
        note: '${gym.name}에 ${pe.equipmentType.label} 없음 → ${ex.name} 대체',
        personal: pe.personal,
      );
      msgs.add('${ex.name} → ${alt.name} (${eq.label})');
    }
    plan.gymId = gymId;
    if (plan.partnerName != null && cloudSignedIn) {
      plan.venueOwner = CloudSync.instance.user!.uid;
      plan.venueGymId = gymId;
      plan.venueName = gym.name;
    } else {
      plan.venueOwner = null;
      plan.venueGymId = null;
      plan.venueName = null;
    }
    plan.venueTypes = [];
    plan.estimatedMinutes = SessionGenerator.estimateMinutes(plan.exercises);
    await _save();
    await resyncPartnerDay(plan);
    return msgs;
  }

  Map<EquipmentType, double> get equipmentMax => maxForGym(activeGym);

  /// 기구 종류별 무게 한 칸(핀 5 / 원판 2.5 / 사용자 지정).
  Map<EquipmentType, double> get equipmentStep => stepForGym(activeGym);

  Map<String, ExerciseProgress> get progress =>
      _data.progress.putIfAbsent(currentUser?.id ?? '_', () => {});

  /// 앱을 연 뒤 클라우드에서 최신 기록을 한 번 받아왔는지(받기 전엔 자동 처리를 하지 않는다).
  bool _initialSyncDone = false;

  Future<void> load() async {
    _data = await _store.load();
    _dedupeEquipment();
    _loaded = true;
    if (!cloudSignedIn) _initialSyncDone = true;
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
      _initialSyncDone = true;
      await refreshInbox();
      await catchUpMissed();
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
        onboarded: false,
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
    // 날짜별로 '운동한 기록'이 있는 쪽을 지킨다. 한쪽 기기에서 운동을 기록했는데 다른 기기가
    // 그걸 모른 채 휴식 처리해 올린 경우에도 기록이 사라지지 않게 한다.
    final rescued = _keepRecordedPlans(from: _data, into: data);
    if (data.updatedAt.isAfter(_data.updatedAt) || rescued > 0) {
      final local = _data;
      _data = data;
      if (rescued > 0) {
        _mergeProgress(local);
        _data.updatedAt = DateTime.now();
      }
      await _store.save(_data);
      lastSyncedAt = DateTime.now();
      notifyListeners();
      if (rescued > 0 && cloudSignedIn) _pushDebounce(_pushNow);
      return true;
    }
    // 내 쪽이 더 최신이어도, 클라우드에만 있는 운동 기록은 가져온다.
    final pulledBack = _keepRecordedPlans(from: data, into: _data);
    if (pulledBack > 0) {
      _mergeProgress(data);
      await _save();
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
  /// 운동 진행 정도: 완료 > 세트 체크/시작 > 손 안 댐 > 휴식 처리.
  static int _progressRank(DayPlan p) {
    if (p.isFinished) return 3;
    if (p.startedAt != null || p.exercises.any((e) => e.anyCompleted)) return 2;
    if (p.skipped || p.isRest) return 0;
    return 1;
  }

  /// [from]에만 있거나 [from] 쪽이 더 진행된(운동 기록이 있는) 날의 계획을 [into]로 옮긴다. 옮긴 수.
  int _keepRecordedPlans({required AppData from, required AppData into}) {
    var n = 0;
    for (final p in from.plans) {
      if (_progressRank(p) < 2) continue;
      final i = into.plans.indexWhere((x) => x.userId == p.userId && dateKey(x.date) == dateKey(p.date));
      if (i < 0) {
        into.plans.add(p);
        n++;
      } else if (_progressRank(into.plans[i]) < _progressRank(p)) {
        into.plans[i] = p;
        n++;
      }
    }
    return n;
  }

  /// 운동별 진행(작업 무게)은 더 최근에 한 쪽을 남긴다.
  void _mergeProgress(AppData other) {
    for (final e in other.progress.entries) {
      final target = _data.progress.putIfAbsent(e.key, () => {});
      for (final p in e.value.entries) {
        final cur = target[p.key];
        final a = cur?.lastPerformed, b = p.value.lastPerformed;
        if (cur == null || (b != null && (a == null || b.isAfter(a)))) target[p.key] = p.value;
      }
    }
  }

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
    final p = UserProfile(id: newId(), name: name.trim(), onboarded: false);
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
    if (u.levelAuto) {
      final a = LevelAssessor.assess(u);
      if (a.hasData) u.level = a.level;
    }
    // 슬라이더 드래그처럼 연속 입력은 화면만 바로 갱신하고 저장은 잠깐 모아서 한 번에.
    _data.updatedAt = DateTime.now();
    notifyListeners();
    _profileSaveDebounce(() => _save());
  }

  final _profileSaveDebounce = Debouncer(const Duration(milliseconds: 400));

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
      {String? name, double? maxWeight, String? note, LoadMechanism? mechanism, double? stepKg, List<EquipmentType>? extraTypes, String? brand, String? weightBasis}) async {
    final g = _data.gyms.where((g) => g.id == gymId).firstOrNull;
    if (g == null) return;
    // 같은 종류·같은 이름 기구가 이미 있으면 또 넣지 않는다(중복 방지).
    final label = (name == null || name.trim().isEmpty) ? type.label : name.trim();
    if (g.equipment.any((e) => e.type == type && e.displayName == label)) return;
    g.equipment.add(GymEquipment(
        id: newId(), type: type, customName: name, maxWeightKg: maxWeight, note: note, mechanism: mechanism, stepKg: stepKg,
        extraTypes: extraTypes, brand: brand, weightBasis: weightBasis));
    await _save();
  }

  Future<void> updateEquipment(String gymId, GymEquipment eq) async {
    final g = _data.gyms.where((g) => g.id == gymId).firstOrNull;
    if (g == null) return;
    final i = g.equipment.indexWhere((e) => e.id == eq.id);
    if (i >= 0) g.equipment[i] = eq;
    await _save();
  }

  /// 기구를 추가하고 새 기구 id를 돌려준다(운동 추가 화면의 '기구 추가 / 취소' 토글용).
  Future<String?> addEquipmentReturningId(String gymId, EquipmentType type) async {
    final g = gymById(gymId);
    if (g == null) return null;
    final dup = g.equipment.where((e) => e.type == type && e.customName == null).firstOrNull;
    if (dup != null) return null;
    final e = GymEquipment(id: newId(), type: type);
    g.equipment.add(e);
    await _save();
    return e.id;
  }

  /// 기구 실물 사진 저장/삭제(이 기기에만 저장).
  Future<void> setEquipmentPhoto(String gymId, String equipmentId, Uint8List? bytes) async {
    final e = _data.gyms.where((g) => g.id == gymId).firstOrNull?.equipment.where((e) => e.id == equipmentId).firstOrNull;
    if (e == null) return;
    if (bytes == null) {
      await photos.deletePhoto(equipmentId);
      e.hasPhoto = false;
    } else {
      await photos.savePhoto(equipmentId, bytes);
      e.hasPhoto = true;
    }
    await _save();
  }

  /// 기구 3D 색상·커버 변경.
  Future<void> setEquipmentLook(String gymId, String equipmentId, {int? frame, int? pad, bool? shroud, bool reset = false}) async {
    final e = _data.gyms.where((g) => g.id == gymId).firstOrNull?.equipment.where((e) => e.id == equipmentId).firstOrNull;
    if (e == null) return;
    if (reset) {
      e.frameColor = null;
      e.padColor = null;
      e.shroud = null;
    } else {
      if (frame != null) e.frameColor = frame;
      if (pad != null) e.padColor = pad;
      if (shroud != null) e.shroud = shroud;
    }
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

  /// '오늘'로 볼 날짜.
  /// 1) 시작했지만 아직 끝내지 않은 운동이 있으면(시작 후 8시간 안) 그 운동의 날짜.
  ///    밤 11시에 시작해 새벽 1시까지 해도 시작한 날의 운동으로 남는다.
  /// 2) 아니면 하루 시작 시각(기본 새벽 4시) 전은 전날로 본다. 낮밤이 바뀐 사람은 내 정보에서 바꿀 수 있다.
  DateTime get today {
    final now = DateTime.now();
    DayPlan? active;
    for (final p in myPlans) {
      final s = p.startedAt;
      if (s == null || p.isFinished || now.difference(s).inHours >= 8) continue;
      if (active == null || s.isAfter(active.startedAt!)) active = p;
    }
    if (active != null) return dateOnly(active.date);
    return dateOnly(now.subtract(Duration(hours: (currentUser?.dayStartHour ?? 4).clamp(0, 12))));
  }

  DayPlan? get todayPlan => planOn(today);

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
    // 완료한 날과 파트너 운동일은 그대로 둔다(파트너와 같은 루틴이어야 하므로).
    final fixed = <String, DayPlan>{
      for (final p in myPlans)
        if ((p.isFinished || p.partnerName != null || p.custom || p.skipped) && !p.date.isBefore(f) && !p.date.isAfter(t)) dateKey(p.date): p,
    };
    final keep = fixed.keys.toSet();

    // 날짜별로 다른 헬스장을 지정해 둔 날은 그 헬스장 기구로 다시 짠다.
    final dayAvailable = <String, Set<EquipmentType>>{};
    final dayGym = <String, String>{};
    for (final p in myPlans) {
      final k = dateKey(p.date);
      if (p.date.isBefore(f) || p.date.isAfter(t) || keep.contains(k)) continue;
      final g = gymById(p.gymId);
      if (g != null) {
        dayAvailable[k] = g.availableTypes;
        dayGym[k] = g.id;
      }
    }

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
      fixed: fixed,
      dayAvailable: dayAvailable,
      dayGym: dayGym,
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
    // 쉬기로 했던 운동일 → 다시 운동하기
    if (existing != null && existing.skipped) {
      existing.skipped = false;
      await _save();
      if (u.restMode == 'shift') await rebalanceAround(dateOnly(date));
      return;
    }
    // 운동일을 쉬는 날로: 설정에 따라 루틴 유지(그 날만 휴식 표시) 또는 뒤로 밀기
    if (existing != null && !existing.isRest) {
      existing.skipped = true;
      await _save();
      if (u.restMode == 'shift') await rebalanceAround(dateOnly(date));
      return;
    }
    if (existing != null && existing.isRest) {
      // 휴식 → 그날 하루만 운동으로 재생성하고 앞뒤를 다시 맞춘다
      _data.plans.remove(existing);
      await regenerateDay(date);
      await rebalanceAround(dateOnly(date));
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
    // 쉬는 날이 생겼으니 그 부위가 빠지지 않게 이후(와 오늘 이후 앞쪽) 날짜를 다시 맞춘다.
    await rebalanceAround(dateOnly(date));
  }

  /// 그날의 부위를 바꾸고 루틴을 다시 뽑는다. [shiftFollowing]이면 이후 미완료 날짜를
  /// 이 날 기준으로 다시 배치한다(플래너가 이 날의 제목을 보고 분할 순서를 이어감).
  Future<void> changeDayFocus(
    DateTime date,
    List<MuscleGroup> groups, {
    String? title,
    bool shiftFollowing = true,
  }) async {
    final u = currentUser;
    if (u == null || groups.isEmpty) return;
    final d = dateOnly(date);
    final existing = planOn(d);
    if (existing != null && existing.isFinished) return;
    final exercises = SessionGenerator(SessionRequest(
      groups: groups,
      available: availableFor(existing),
      progress: progress,
      profile: u,
      minutesBudget: (u.sessionMinutes * u.volumeBias).round(),
      now: d,
      equipmentMax: maxForPlan(existing),
      equipmentStep: stepForPlan(existing),
      seed: d.millisecondsSinceEpoch ~/ 86400000 + groups.length,
      pinned: [for (final e in existing?.exercises ?? const <PlannedExercise>[]) if (e.pinned) e],
      avoidIds: _neighborIds(d),
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
    if (existing != null) _copyVenue(existing, plan);
    plan.custom = true;
    if (existing != null) _data.plans.remove(existing);
    _data.plans.add(plan);
    await _save();
    await resyncPartnerDay(plan);

    if (shiftFollowing && !_sameGroups(existing?.focus ?? const [], groups)) await rebalanceAround(d);
  }

  /// [d] 이후의 미완료 날짜를 다시 짠다. 플래너가 [d]까지의 계획을 이력으로 보고
  /// 분할 순서와 부위별 회복 시간을 이어가므로, 중간에 끼워 넣은 파트너 운동이나
  /// 바뀐 부위 뒤에서도 같은 부위가 연달아 오거나 빠지는 일이 없다.
  /// 파트너 운동일처럼 중간에 고정된 날이 생겼을 때, 그 앞뒤의 아직 하지 않은 날짜를
  /// 모두 다시 짠다. 오늘 이미 시작한 운동과 완료한 날, 파트너 날은 그대로 둔다.
  Future<void> rebalanceAround(DateTime d) async {
    final today = this.today;
    final todayPlan = planOn(today);
    final todayStarted = todayPlan != null && (todayPlan.isFinished || todayPlan.exercises.any((e) => e.anyCompleted));
    final from = todayStarted ? today.add(const Duration(days: 1)) : today;
    final open = myPlans.where((p) => !p.isFinished && !p.date.isBefore(from)).toList();
    if (open.isEmpty) return;
    final last = open.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final to = last.isAfter(d) ? last : d;
    await generatePlans(from: from, to: to, restDays: manualRestDays);
  }

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
      available: availableFor(existing),
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
    if (existing != null) _copyVenue(existing, plan);
    plan.custom = true;
    if (existing != null) _data.plans.remove(existing);
    _data.plans.add(plan);
    await _save();
    await resyncPartnerDay(plan);
    await _rebalanceIfFocusChanged(plan, existing?.isRest == false ? existing!.focus : const []);
    return plan;
  }

  /// 하루만 다시 생성(기구 변경 등 반영).
  /// 하루 루틴 다시 짜기. 파트너 운동일이면 파트너와 다시 맞춘 루틴으로(파트너 유지),
  /// 아니면 그 날 헬스장([gymId] 또는 기존 지정) 기구로 짠다.
  Future<DayPlan?> regenerateDay(DateTime date, {String? gymId}) async {
    final u = currentUser;
    if (u == null) return null;
    final d = dateOnly(date);
    final existing = planOn(d);
    if (existing != null && existing.isFinished) return existing;
    if (existing != null && existing.partnerName != null) {
      final link = _data.partners.where((p) => p.name == existing.partnerName && !p.pending).firstOrNull;
      if (link != null && cloudSignedIn) {
        await generateJointSession(d, link, venue: venueOf(existing));
        return planOn(d);
      }
      // 파트너 정보를 지금 못 쓰면(오프라인 등) 파트너 날은 그대로 두고 같은 부위로만 다시 짠다.
      await changeDayFocus(d, existing.focus, title: (existing.title ?? '').split(' · ').first, shiftFollowing: false);
      return planOn(d);
    }
    final gym = gymById(gymId ?? existing?.gymId);
    final pinned = [for (final e in existing?.exercises ?? const <PlannedExercise>[]) if (e.pinned) e];
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
      equipmentMax: maxForGym(gym ?? activeGym),
      equipmentStep: stepForGym(gym ?? activeGym),
      dayAvailable: {if (gym != null) dateKey(d): gym.availableTypes},
      dayGym: {if (gym != null) dateKey(d): gym.id},
      dayPinned: {if (pinned.isNotEmpty) dateKey(d): pinned},
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
    // 파트너와 약속한 날은 지우지 않는다(파트너 해제는 그 날에서 따로).
    _data.plans.removeWhere(
        (p) => p.userId == u.id && !p.date.isBefore(f) && !p.isFinished && p.partnerName == null);
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
    if (completed == true && plan.startedAt == null) plan.startedAt = DateTime.now();
    await _save();
  }

  /// '운동 시작': 시작 시각을 기록한다(이미 시작했으면 유지).
  Future<void> startWorkout(DayPlan plan) async {
    if (plan.isFinished) return;
    plan.startedAt ??= DateTime.now();
    await _save();
  }

  /// 잘못 눌렀을 때: 시작 취소(세트 체크 전) 또는 시작 시각을 지금으로 재설정.
  Future<void> cancelWorkoutStart(DayPlan plan, {bool resetToNow = false}) async {
    if (plan.isFinished) return;
    plan.startedAt = resetToNow ? DateTime.now() : null;
    plan.endedAt = null;
    await _save();
  }

  Future<void> addSet(DayPlan plan, PlannedExercise ex) async {
    _markCustom(plan);
    final last = ex.sets.last;
    ex.sets.add(SetEntry(
        targetReps: last.targetReps, targetWeight: last.targetWeight, level: last.level, extra: true));
    await _save();
    await resyncPartnerDay(plan);
  }

  /// 마지막 세트를 뺀다(최소 1세트).
  Future<void> removeSet(DayPlan plan, PlannedExercise ex) async {
    _markCustom(plan);
    if (ex.sets.length <= 1) return;
    ex.sets.removeLast();
    await _save();
    await resyncPartnerDay(plan);
  }

  Future<void> removeExercise(DayPlan plan, PlannedExercise ex) async {
    _markCustom(plan);
    plan.exercises.remove(ex);
    await _save();
    await resyncPartnerDay(plan);
  }

  /// 운동을 하루 계획에 추가. 파트너 날에 [personal]이면 나만 하고 파트너에게 보내지 않는다.
  Future<PlannedExercise?> addExercise(DayPlan plan, Exercise ex, {bool personal = false}) async {
    final u = currentUser;
    if (u == null || plan.isFinished) return null;
    final base = _planSingle(ex, u, plan);
    _markCustom(plan);
    final planned = PlannedExercise(
      exerciseId: base.exerciseId,
      equipmentType: base.equipmentType,
      restSeconds: base.restSeconds,
      sets: base.sets,
      note: personal ? '개인 추가 · 파트너에게 안 보냄' : '직접 추가',
      personal: personal,
    );
    // 같은 구역(웨이트/복근/유산소)의 마지막 뒤에 넣는다.
    final sec = SessionGenerator.sectionOf(planned);
    final idx = plan.exercises.lastIndexWhere((p) => SessionGenerator.sectionOf(p) == sec);
    plan.exercises.insert(idx < 0 ? plan.exercises.length : idx + 1, planned);
    plan.estimatedMinutes = SessionGenerator.estimateMinutes(plan.exercises);
    await _save();
    if (!personal) await resyncPartnerDay(plan);
    return planned;
  }

  /// 운동 순서를 [delta]만큼 이동(-1 위로, +1 아래로).
  Future<void> moveExercise(DayPlan plan, PlannedExercise ex, int delta) async {
    _markCustom(plan);
    final i = plan.exercises.indexOf(ex);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= plan.exercises.length) return;
    plan.exercises.removeAt(i);
    plan.exercises.insert(j, ex);
    _learnOrder(plan);
    await _save();
    await resyncPartnerDay(plan);
  }

  /// 드래그로 순서 변경(onReorderItem: newIndex는 제거 후 기준).
  Future<void> reorderExercise(DayPlan plan, int oldIndex, int newIndex) async {
    _markCustom(plan);
    if (oldIndex < 0 || oldIndex >= plan.exercises.length) return;
    final ex = plan.exercises.removeAt(oldIndex);
    plan.exercises.insert(newIndex.clamp(0, plan.exercises.length), ex);
    _learnOrder(plan);
    await _save();
    await resyncPartnerDay(plan);
  }

  /// 사용자가 직접 바꾼 순서를 학습: 웨이트 구역(상체/하체) 안에서 각 운동의 상대 위치(0~1)와
  /// 부위별 평균 위치를 저장한다. 생성기가 다음 루틴을 짤 때 이 순위를 우선한다.
  void _learnOrder(DayPlan plan) {
    final u = currentUser;
    if (u == null) return;
    for (final sec in ['upper', 'lower']) {
      final list = plan.exercises.where((e) => SessionGenerator.sectionOf(e) == sec).toList();
      if (list.length < 2) continue;
      final byGroup = <String, List<double>>{};
      for (var i = 0; i < list.length; i++) {
        final r = i / (list.length - 1);
        u.exerciseRank[list[i].exerciseId] = r;
        final g = exerciseById(list[i].exerciseId)?.group.name ?? '';
        (byGroup[g] ??= []).add(r);
      }
      for (final e in byGroup.entries) {
        u.groupRank[e.key] = e.value.reduce((a, b) => a + b) / e.value.length;
      }
    }
  }

  /// 오늘 이전인데 손도 안 댄 운동일은 '휴식'(쉬기로 한 날)로 표시한다.
  /// 설정이 '뒤로 밀기'면 그만큼 이후 루틴을 다시 맞춘다. 앱을 열 때·돌아올 때 확인.
  Future<void> catchUpMissed() async {
    final u = currentUser;
    if (u == null) return;
    // 클라우드 기록을 받기 전엔 하지 않는다(다른 기기에서 한 운동을 '안 함'으로 오해하지 않게).
    if (!_initialSyncDone) return;
    final t = today;
    // 하루 여유: 어제 운동은 오늘 늦게 기록할 수도 있으니 그저께 이전만 '휴식'으로 본다.
    final cutoff = t.subtract(const Duration(days: 1));
    var changed = false;
    for (final p in myPlans) {
      if (!p.date.isBefore(cutoff) || p.isRest || p.isFinished || p.skipped) continue;
      if (p.startedAt != null || p.exercises.any((e) => e.anyCompleted)) continue;
      p.skipped = true;
      changed = true;
    }
    if (!changed) return;
    await _save();
    if (u.restMode == 'shift') await rebalanceAround(t);
  }

  /// 전날·다음날 운동 id(같은 운동이 연일 겹치지 않게).
  Set<String> _neighborIds(DateTime d) => {
        for (final off in [-2, -1, 1])
          for (final e in planOn(d.add(Duration(days: off)))?.exercises ?? const <PlannedExercise>[])
            if (!e.warmup) e.exerciseId,
      };

  /// 📌 고정 / 해제. 고정한 운동은 루틴을 다시 짜도 남는다.
  Future<void> togglePin(DayPlan plan, PlannedExercise pe) async {
    pe.pinned = !pe.pinned;
    if (pe.pinned) plan.custom = true;
    await _save();
  }

  /// 파트너 날에 나만 이 운동을 빼거나 다시 넣는다(파트너 루틴은 그대로).
  Future<void> toggleSkipMine(DayPlan plan, PlannedExercise pe) async {
    pe.skipMine = !pe.skipMine;
    plan.custom = true;
    await _save();
  }

  /// 운동을 이미 시작했는지(시작 버튼 또는 세트 체크).
  bool isStarted(DayPlan? p) => p != null && (p.isStarted || p.exercises.any((e) => e.anyCompleted));

  /// 직접 손본 날로 표시(이후 자동 재배치 때 그대로 두고 기준으로 삼는다).
  void _markCustom(DayPlan plan) {
    plan.custom = true;
  }

  /// 부위가 바뀐 날이 있으면 앞뒤 미완료 날짜를 바로 다시 맞춘다.
  Future<void> _rebalanceIfFocusChanged(DayPlan plan, List<MuscleGroup> before) async {
    if (!_sameGroups(before, plan.focus)) await rebalanceAround(plan.date);
  }

  /// 학습한 정렬 초기화(다시 기본 효율 순서로).
  Future<void> resetOrderLearning() async {
    final u = currentUser;
    if (u == null) return;
    u.exerciseRank.clear();
    u.groupRank.clear();
    await _save();
  }

  /// 운동 하나를 다른 운동으로 교체(같은 부위, 보유 기구로 가능한 것 중 선택).
  Future<void> swapExercise(DayPlan plan, PlannedExercise old, Exercise to) async {
    _markCustom(plan);
    final i = plan.exercises.indexOf(old);
    if (i < 0) return;
    final u = currentUser!;
    final gen = SessionGenerator(SessionRequest(
      groups: [to.group],
      available: {...availableFor(plan), ...to.equipment},
      progress: progress,
      profile: u,
      minutesBudget: 30,
      equipmentMax: maxForPlan(plan),
      equipmentStep: stepForPlan(plan),
    ));
    // 요청한 운동을 정확히 처방한다(예전엔 생성기가 고른 다른 운동이 들어가는 버그가 있었음).
    plan.exercises[i] = gen.planExercise(to);
    await _save();
    await resyncPartnerDay(plan);
  }

  PlannedExercise _planSingle(Exercise ex, UserProfile u, [DayPlan? plan]) {
    final gen = SessionGenerator(SessionRequest(
      groups: [ex.group],
      available: {...availableFor(plan), ...ex.equipment},
      progress: progress,
      profile: u,
      minutesBudget: 120,
      equipmentMax: maxForPlan(plan),
      equipmentStep: stepForPlan(plan),
    ));
    return gen.planExercise(ex);
  }

  /// 자세에 따라 타깃이 바뀌는 운동의 부위를 바꾼다(덤벨 풀오버: 등 → 가슴).
  Future<void> setExerciseTarget(DayPlan plan, PlannedExercise pe, MuscleGroup? group) async {
    _markCustom(plan);
    pe.groupOverride = group;
    await _save();
    await resyncPartnerDay(plan);
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
        available: availableFor(existing),
        progress: progress,
        profile: u,
        minutesBudget: minutes,
        intensityFactor: existing.intensityFactor,
        loadFactor: loadFactor,
        now: dateOnly(date),
        equipmentMax: maxForPlan(existing),
        equipmentStep: stepForPlan(existing),
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
    _copyVenue(existing, plan);
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
      if (!pe.anyCompleted || pe.warmup || pe.skipMine) continue;
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
    if (plan.startedAt != null) plan.endedAt = now;

    // 계획 대비 실제 수행 → 다음 루틴 볼륨 보정.
    final u = currentUser;
    if (u != null && plan.exercises.isNotEmpty) {
      final planned = plan.estimatedMinutes;
      final actual = plan.actualMinutes;
      final ratio = plan.completionRatio;
      final extra = plan.extraSetsDone;
      var delta = 0.0;
      final why = <String>[];
      if (ratio >= 0.9 && extra >= 3) {
        delta += 0.05;
        why.add('추가 세트 $extra개');
      }
      if (ratio >= 0.95 && actual != null && planned > 0 && actual >= 15 && actual < planned * 0.7) {
        delta += 0.05;
        why.add('계획 $planned분보다 빨리($actual분) 끝냄');
      }
      if (ratio < 0.7) {
        delta -= 0.05;
        why.add('수행 ${(ratio * 100).round()}%');
      } else if (actual != null && planned > 0 && actual > planned * 1.4 && (rpe ?? 0) >= 8) {
        delta -= 0.05;
        why.add('계획 $planned분보다 많이 걸림($actual분)');
      }
      if (delta != 0) {
        u.volumeBias = (u.volumeBias + delta).clamp(0.8, 1.3);
        msgs.add('⏱ ${why.join(' · ')} → 다음 루틴 볼륨 ${delta > 0 ? '+' : ''}${(delta * 100).round()}% (현재 ${(u.volumeBias * 100).round()}%)');
      } else if (actual != null) {
        msgs.add('⏱ 실제 $actual분 / 계획 $planned분 · 볼륨 유지');
      }
    }
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
      gyms: gyms,
    ));
  }

  Future<void> refreshInbox() async {
    if (!cloudSignedIn) return;
    try {
      final raw = await CloudSync.instance.readInbox();
      // 같은 파트너가 같은 날짜로 여러 번 보낸 루틴(수정할 때마다 전송)은 가장 최근 것 하나만 남긴다.
      final newestJoint = <String, InboxItem>{};
      DateTime atOf(InboxItem i) => (i.code == null ? null : decodeRoutine(i.code!)?.at) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final items = <InboxItem>[];
      for (final it in raw) {
        if (it.type != InboxType.joint || it.date == null) {
          items.add(it);
          continue;
        }
        final k = '${it.fromUid}|${dateKey(it.date!)}';
        final prev = newestJoint[k];
        if (prev == null || atOf(it).isAfter(atOf(prev))) {
          if (prev != null) unawaited(CloudSync.instance.deleteInbox(prev.id).catchError((_) {}));
          newestJoint[k] = it;
        } else {
          unawaited(CloudSync.instance.deleteInbox(it.id).catchError((_) {}));
        }
      }
      items.addAll(newestJoint.values);
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
          // 이미 그 파트너와 잡아둔 날이면 받은편지함에 쌓지 않고 바로 맞춘다.
          // 두 사람이 엇갈려 보냈으면(서로 공유) 더 최근에 바뀐 루틴 하나만 남긴다.
          final existing = planOn(it.date!);
          final started = existing != null && (existing.isFinished || existing.exercises.any((e) => e.anyCompleted));
          if (existing != null && existing.partnerName == it.fromName) {
            final incomingAt = decodeRoutine(it.code!)?.at;
            final newer = existing.jointAt == null || incomingAt == null || incomingAt.isAfter(existing.jointAt!);
            if (started) {
              // 이미 운동을 시작한 날은 바꾸지 않는다.
              try {
                await CloudSync.instance.deleteInbox(it.id);
              } catch (_) {}
            } else if (newer) {
              await _applyJointSilently(it);
              lastPartnerNotice = '${it.fromName} 님이 ${it.date!.month}/${it.date!.day} 루틴을 바꿔서 내 것도 맞췄어요.';
              changed = true;
            } else {
              // 내 쪽이 더 최근: 상대 앱이 내 루틴을 받아 맞춘다. 옛 것은 버린다.
              try {
                await CloudSync.instance.deleteInbox(it.id);
              } catch (_) {}
            }
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
    final today = this.today;
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
  /// [venue]: 운동 장소(내 헬스장 또는 파트너 헬스장). null이면 두 사람 헬스장의 공통 기구로.
  /// [prefetched]: 장소 고를 때 이미 받아온 파트너 정보(다시 받지 않는다).
  /// [onStep]: 진행 단계 문구(화면 표시용).
  Future<String> generateJointSession(
    DateTime date,
    PartnerLink partner, {
    SharedVenue? venue,
    PartnerProfile? prefetched,
    void Function(String step)? onStep,
  }) async {
    final u = currentUser;
    if (u == null || !cloudSignedIn) return '계정 로그인이 필요해요.';
    onStep?.call('파트너 정보 받는 중…');
    PartnerProfile? pp = prefetched;
    if (pp == null) {
      try {
        pp = await CloudSync.instance.fetchPartner(partner.uid);
      } on TimeoutException {
        return '연결이 느려서 ${partner.name} 님 정보를 받지 못했어요. 잠시 뒤 다시 해주세요.';
      }
    }
    if (pp == null) return '${partner.name} 님의 정보를 아직 받을 수 없어요. 상대가 앱을 한 번 열면 됩니다.';
    partner.name = pp.name;
    onStep?.call('두 사람 일정·기구로 루틴 맞추는 중…');

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
    final myUid = CloudSync.instance.user!.uid;
    final Set<EquipmentType> available;
    if (venue != null && venue.owner == myUid && gymById(venue.gymId) != null) {
      available = {EquipmentType.bodyweight, ...gymById(venue.gymId)!.availableTypes};
    } else if (venue != null) {
      available = {EquipmentType.bodyweight, ...venue.types};
    } else {
      final mineAvail = availableFor(planOn(d));
      available = pp.available.isEmpty
          ? mineAvail
          : (mineAvail.where(pp.available.contains).toSet()..add(EquipmentType.bodyweight));
    }

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
    if (venue != null) {
      _applyVenue(plan, venue);
    } else if (mine != null) {
      _copyVenue(mine, plan);
    }
    plan.jointAt = DateTime.now().toUtc();
    final focusChanged = mine == null || !_sameGroups(mine.focus, groups);
    if (mine != null) _data.plans.remove(mine);
    _data.plans.add(plan);
    await _save();
    onStep?.call('${pp.name} 님에게 보내는 중…');
    final where = venue == null ? '' : ' · 장소: ${venue.name}';
    var sent = '$note$where ${pp.name} 님 앱에도 같은 루틴을 보냈어요.';
    try {
      // 서버 확인을 오래 기다리지 않는다. 시간이 넘어도 전송은 뒤에서 계속돼 연결되면 도착한다.
      await CloudSync.instance
          .sendJointRoutine(
            toUid: partner.uid,
            date: d,
            code: encodeRoutine(plan, from: u.name, venue: venueOf(plan), at: plan.jointAt),
            title: title,
            fromName: u.name,
          )
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      sent = '$note$where 연결이 느려 전송이 조금 늦어요. 잠시 뒤 ${pp.name} 님 앱에 도착해요.';
    } catch (_) {
      return '$note 파트너에게 보내기는 실패했어요(네트워크).';
    }
    // 이후 날짜 재배치는 화면을 붙잡지 않고 뒤에서 한다.
    if (focusChanged) unawaited(rebalanceAround(d));
    return sent;
  }

  /// 루틴 가져오기 + 파트너 무게 붙이기 (알림·수락 전송 없음). 자동 동기화에 쓴다.
  Future<DayPlan?> _applyJointSilently(InboxItem item) async {
    final before = planOn(dateOnly(item.date!));
    final beforeFocus = before == null || before.isRest ? const <MuscleGroup>[] : before.focus;
    final plan = await importRoutine(item.code!, item.date!);
    if (plan == null) return null;
    plan.partnerName = item.fromName;
    plan.jointAt = decodeRoutine(item.code!)?.at ?? DateTime.now().toUtc();
    if (!_sameGroups(beforeFocus, plan.focus)) await rebalanceAround(plan.date);
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
    plan.jointAt = DateTime.now().toUtc();
    await _save();
    try {
      await CloudSync.instance.sendJointRoutine(
        toUid: link.uid,
        date: plan.date,
        code: encodeRoutine(plan, from: currentUser?.name, venue: venueOf(plan), at: plan.jointAt),
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
    // 파트너 날이 빠졌으니 앞뒤 날짜도 다시 맞춘다.
    await rebalanceAround(date);
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
    final myUid = cloudSignedIn ? CloudSync.instance.user!.uid : null;
    final v = shared.venue;
    final available = v == null
        ? availableFor(existing)
        : (v.owner == myUid && gymById(v.gymId) != null)
            ? gymById(v.gymId)!.availableTypes
            : {EquipmentType.bodyweight, ...v.types};
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
    if (v != null) {
      _applyVenue(plan, v);
    } else if (existing != null) {
      _copyVenue(existing, plan);
    }
    if (shared.at != null) plan.jointAt = shared.at;
    // 파트너 날 동기화: 내가 따로 넣은 개인 운동은 유지한다.
    if (existing != null && existing.partnerName != null) {
      plan.exercises.addAll(existing.exercises.where((e) => e.personal));
      // 파트너가 루틴을 바꿔 보내와도 내가 '나만 빼기'·'고정'한 표시는 유지한다.
      for (final e in plan.exercises) {
        final old = existing.exercises.where((x) => x.exerciseId == e.exerciseId).firstOrNull;
        if (old == null) continue;
        e.skipMine = old.skipMine;
        e.pinned = old.pinned;
      }
    }
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
    final today = this.today;
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
    var cursor = today;
    while (true) {
      final start = cursor.subtract(Duration(days: cursor.weekday % 7)); // 일요일 시작
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
