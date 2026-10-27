/// Supabase(Postgres) 동기화 계층.
///
/// 지금 단계는 **이중 쓰기(shadow write)**: 읽기는 Firestore 가 기준이고, 바뀐 행만 Postgres 에 upsert 한다.
/// [supabasePrimary] 를 켜면 계획(plans)은 Postgres 에서 읽는다(전환 단계).
///
/// 인증: Firebase ID 토큰을 그대로 전달(third-party auth). Supabase 가 서명을 검증하고
/// RLS 는 `auth_uid()`(JWT sub) 로 본인 행만 허용한다.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../supabase_options.dart';
import 'supa_rows.dart';

/// 전환 단계에서 계획을 Postgres 에서 읽을지. 모든 기기가 새 버전이 된 뒤 켠다.
const supabasePrimary = false;

class SupaSnapshot {
  SupaSnapshot({this.user, required this.gyms, required this.plans, required this.progress, required this.partners});
  final Map<String, dynamic>? user;
  final List<Gym> gyms;
  final List<DayPlan> plans;
  final List<ExerciseProgress> progress;
  final List<Map<String, dynamic>> partners;
}

class SupaSync {
  SupaSync._();

  static SupaSync? _i;
  static bool get enabled => _i != null;
  static SupaSync get instance => _i!;
  static String? initError;

  /// 앱 시작 시(Firebase 초기화 뒤) 한 번. URL·키가 비어 있으면 아무것도 하지 않는다.
  static Future<void> init() async {
    if (!supabaseConfigured || _i != null) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
        accessToken: () async {
          final u = FirebaseAuth.instance.currentUser;
          if (u == null) return null;
          try {
            return await u.getIdToken();
          } catch (_) {
            return null;
          }
        },
      );
      _i = SupaSync._();
      initError = null;
    } catch (e) {
      initError = e.toString();
    }
  }

  SupabaseClient get _c => Supabase.instance.client;

  static const _chunk = 400;

  Future<void> _upsert(String table, List<Map<String, dynamic>> rows, {String? onConflict}) async {
    for (var i = 0; i < rows.length; i += _chunk) {
      final part = rows.sublist(i, i + _chunk > rows.length ? rows.length : i + _chunk);
      await _c.from(table).upsert(part, onConflict: onConflict).timeout(const Duration(seconds: 30));
    }
  }

  Future<void> _deleteIn(String table, String column, List<String> values) async {
    for (var i = 0; i < values.length; i += _chunk) {
      final part = values.sublist(i, i + _chunk > values.length ? values.length : i + _chunk);
      await _c.from(table).delete().inFilter(column, part).timeout(const Duration(seconds: 30));
    }
  }

  /// 계정에 Postgres 데이터가 있는지(첫 이전 판단).
  Future<bool> hasUser(String uid) async {
    final r = await _c.from('users').select('id').eq('id', uid).maybeSingle().timeout(const Duration(seconds: 15));
    return r != null;
  }

  /// 행 묶음을 올린다. 계획은 "그 계획의 운동·세트 행을 전부 바꿔치기"(빠진 세트가 남지 않게).
  Future<void> push(RowBundle b) async {
    if (b.user != null) await _upsert('users', [b.user!]);
    if (b.gyms.isNotEmpty) await _upsert('gyms', b.gyms);
    if (b.equipment.isNotEmpty) await _upsert('gym_equipment', b.equipment);
    if (b.plans.isNotEmpty) {
      final planIds = [for (final p in b.plans) p['id'] as String];
      await _upsert('plans', b.plans);
      // 옛 운동·세트 행 정리: 이 계획들의 행 중 이번에 안 올리는 것만 지운다.
      final peIds = {for (final e in b.planExercises) e['id'] as String};
      final setIds = {for (final s in b.sets) s['id'] as String};
      final oldPe = await _c.from('plan_exercises').select('id').inFilter('plan_id', planIds).timeout(const Duration(seconds: 30));
      final stalePe = [for (final r in oldPe) if (!peIds.contains(r['id'])) r['id'] as String];
      if (stalePe.isNotEmpty) await _deleteIn('plan_exercises', 'id', stalePe); // sets·cardio 는 cascade
      if (b.planExercises.isNotEmpty) await _upsert('plan_exercises', b.planExercises);
      if (peIds.isNotEmpty) {
        final oldSets = await _c.from('sets').select('id').inFilter('plan_exercise_id', peIds.toList()).timeout(const Duration(seconds: 30));
        final staleSets = [for (final r in (oldSets as List)) if (!setIds.contains(r['id'])) r['id'] as String];
        if (staleSets.isNotEmpty) await _deleteIn('sets', 'id', staleSets);
      }
      if (b.sets.isNotEmpty) await _upsert('sets', b.sets);
      if (b.cardio.isNotEmpty) await _upsert('cardio_stats', b.cardio, onConflict: 'plan_exercise_id');
    }
    if (b.progress.isNotEmpty) await _upsert('exercise_progress', b.progress, onConflict: 'user_id,exercise_id');
    if (b.partners.isNotEmpty) await _upsert('partners', b.partners, onConflict: 'user_id,partner_id');
  }

  /// 지운 계획 표시(소프트 삭제).
  Future<void> softDeletePlans(String uid, List<String> dateKeys) async {
    if (dateKeys.isEmpty) return;
    await _c
        .from('plans')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', uid)
        .inFilter('date', dateKeys)
        .timeout(const Duration(seconds: 30));
  }

  /// 프로필·헬스장·진행·파트너 전체와, [from] 이후 날짜의 계획을 읽는다.
  Future<SupaSnapshot> pull(String uid, {required String localUserId, DateTime? from}) async {
    final user = await _c.from('users').select().eq('id', uid).maybeSingle().timeout(const Duration(seconds: 20));
    final gymRows = await _c.from('gyms').select().eq('user_id', uid).isFilter('deleted_at', null).timeout(const Duration(seconds: 20));
    final gymIds = [for (final g in (gymRows as List)) g['id'] as String];
    final eqRows = gymIds.isEmpty
        ? const <dynamic>[]
        : await _c.from('gym_equipment').select().inFilter('gym_id', gymIds).isFilter('deleted_at', null).timeout(const Duration(seconds: 20));
    final gyms = [
      for (final g in gymRows)
        gymFromRows(Map<String, dynamic>.from(g as Map), [
          for (final e in eqRows)
            if (e['gym_id'] == g['id']) Map<String, dynamic>.from(e as Map),
        ]),
    ];

    final since = dateKey(from ?? DateTime.now().subtract(const Duration(days: 120)));
    final planRows = await _c.from('plans').select().eq('user_id', uid).gte('date', since).isFilter('deleted_at', null).timeout(const Duration(seconds: 30));
    final planIds = [for (final p in (planRows as List)) p['id'] as String];
    final peRows = <Map<String, dynamic>>[];
    final setRows = <Map<String, dynamic>>[];
    final cardioRows = <Map<String, dynamic>>[];
    for (var i = 0; i < planIds.length; i += 100) {
      final part = planIds.sublist(i, i + 100 > planIds.length ? planIds.length : i + 100);
      final pes = await _c.from('plan_exercises').select().inFilter('plan_id', part).isFilter('deleted_at', null).timeout(const Duration(seconds: 30));
      final ids = [for (final e in (pes as List)) e['id'] as String];
      peRows.addAll([for (final e in pes) Map<String, dynamic>.from(e as Map)]);
      if (ids.isNotEmpty) {
        final ss = await _c.from('sets').select().inFilter('plan_exercise_id', ids).timeout(const Duration(seconds: 30));
        setRows.addAll([for (final s in (ss as List)) Map<String, dynamic>.from(s as Map)]);
        final cs = await _c.from('cardio_stats').select().inFilter('plan_exercise_id', ids).timeout(const Duration(seconds: 30));
        cardioRows.addAll([for (final c in (cs as List)) Map<String, dynamic>.from(c as Map)]);
      }
    }
    final plans = <DayPlan>[];
    for (final p in planRows) {
      final pm = Map<String, dynamic>.from(p as Map);
      final id = pm['id'];
      try {
        plans.add(planFromRows(
          pm,
          [for (final e in peRows) if (e['plan_id'] == id) e],
          [for (final s in setRows) if ((s['plan_exercise_id'] as String).startsWith('$id:')) s],
          [for (final c in cardioRows) if ((c['plan_exercise_id'] as String).startsWith('$id:')) c],
          localUserId: localUserId,
        ));
      } catch (_) {
        // 깨진 행 하나 때문에 전체가 실패하지 않게 건너뛴다.
      }
    }
    final progRows = await _c.from('exercise_progress').select().eq('user_id', uid).timeout(const Duration(seconds: 20));
    final partnerRows = await _c.from('partners').select().eq('user_id', uid).timeout(const Duration(seconds: 20));
    return SupaSnapshot(
      user: user == null ? null : Map<String, dynamic>.from(user),
      gyms: gyms,
      plans: plans,
      progress: [for (final r in (progRows as List)) progressFromRow(Map<String, dynamic>.from(r as Map))],
      partners: [for (final r in (partnerRows as List)) Map<String, dynamic>.from(r as Map)],
    );
  }

  /// 공개 ID·이메일 키로 사용자 찾기(RPC, 테이블 나열 불가).
  Future<Map<String, dynamic>?> lookupUser(String q) async {
    final r = await _c.rpc('lookup_user', params: {'q': q}).timeout(const Duration(seconds: 15));
    final list = r as List?;
    if (list == null || list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }
}
