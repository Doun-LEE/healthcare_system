/// AI 코치 — Firebase AI Logic(Gemini)으로 하루 루틴을 짠다.
///
/// 흐름: 앱이 모든 변수(스펙·목표·부상·기구·오늘 부위·컨디션·최근 이력·밸런스·파트너)를
/// 글로 정리해 보내고, 모델은 **카탈로그의 운동 ID만** 골라 세트·횟수·무게 배율을
/// JSON으로 돌려준다. 돌아온 JSON은 [AiCoach.validate]가 검증해 [DayPlan]으로 만든다.
/// 규칙 엔진은 네트워크/한도 문제 시 그대로 백업이 된다.
library;

import 'dart:convert';
import 'dart:math';

import 'package:firebase_ai/firebase_ai.dart';

import '../data/catalog.dart';
import '../engine/load_estimator.dart';
import '../engine/session_generator.dart';
import '../engine/stats.dart';
import '../models/models.dart';
import 'partner.dart';

class AiCoachException implements Exception {
  AiCoachException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 모델에 넘길 입력.
class AiContext {
  AiContext({
    required this.profile,
    required this.date,
    required this.focus,
    required this.available,
    required this.progress,
    required this.recent,
    required this.stats,
    this.condition,
    this.loadFactor = 1.0,
    this.minutes,
    this.partner,
    this.request,
  });

  final UserProfile profile;
  final DateTime date;
  final List<MuscleGroup> focus;
  final Set<EquipmentType> available;
  final Map<String, ExerciseProgress> progress;

  /// 최근 완료 세션(최신순, 최대 8개).
  final List<DayPlan> recent;
  final StatsSummary stats;
  final int? condition;
  final double loadFactor;
  final int? minutes;
  final PartnerProfile? partner;

  /// 사용자가 자유롭게 적은 요청 ("오늘 어깨 아파서 가볍게" 등).
  final String? request;
}

/// 모델이 돌려준 루틴(검증 후).
class AiPlan {
  AiPlan({required this.title, required this.focus, required this.rationale, required this.exercises, required this.warnings});
  final String title;
  final List<MuscleGroup> focus;
  final String rationale;
  final List<PlannedExercise> exercises;

  /// 검증 중 고친 것들(사용자에게 보여준다).
  final List<String> warnings;
}

class AiCoach {
  /// 순서대로 시도한다. (3.8-flash는 응답이 60초 넘게 걸려 제외)
  static const models = ['gemini-3.5-flash', 'gemini-3.5-flash-lite'];

  static final _schema = Schema.object(
    properties: {
      'title': Schema.string(description: '루틴 제목 (한국어, 짧게)'),
      'focus': Schema.array(items: Schema.string(description: 'MuscleGroup 이름: shoulder|chest|arms|abs|legs|back|cardio')),
      'rationale': Schema.string(description: '왜 이렇게 짰는지 한국어 3~5문장. 사용자에게 그대로 보여줌.'),
      'exercises': Schema.array(
        minItems: 3,
        maxItems: 10,
        items: Schema.object(
          properties: {
            'id': Schema.string(description: '후보 목록에 있는 exercise id'),
            'sets': Schema.integer(minimum: 1, maximum: 6),
            'reps': Schema.integer(minimum: 3, maximum: 40, description: '횟수. 유산소는 분, 플랭크는 초'),
            'weightFactor': Schema.number(minimum: 0.5, maximum: 1.2, description: '기준 무게 대비 배율. 1.0 = 기준 그대로'),
            'note': Schema.string(description: '이 운동을 고른 이유 한 줄 (한국어)'),
          },
          optionalProperties: ['note'],
        ),
      ),
    },
    propertyOrdering: ['title', 'focus', 'rationale', 'exercises'],
  );

  static const _system = '''
당신은 경험 많은 퍼스널 트레이너다. 아래 정보를 바탕으로 **오늘 하루** 운동 루틴을 짠다.
원칙:
- 후보 목록(candidates)에 있는 exercise id만 사용한다. 다른 id는 절대 쓰지 않는다.
- 큰 복합운동 → 보조/고립 순서. 같은 세부 타깃(예: 가슴 중앙부)만 반복하지 않는다.
- 최근 이력에서 오래 안 한 운동을 우선하고, 어제 한 부위의 피로를 고려한다.
- 밸런스에서 부족한 부위가 오늘 부위에 포함되면 세트를 조금 더 준다.
- 부상 부위 관련 운동은 후보에 이미 없지만, 그 부위에 부담 가는 각도도 피한다.
- 컨디션/무게 배율이 주어지면 weightFactor를 그에 맞춰 낮추고 횟수를 조금 늘린다.
- 총 시간이 time_budget_min 안에 들어가야 한다 (세트당 약 1~3분, 운동 전환 2분).
- 파트너가 있으면 두 사람 모두 할 수 있는 운동을 고르고 파트너 부상도 피한다.
- 사용자 요청(request)이 있으면 최우선으로 반영한다.
- weightFactor는 사용자의 기준 무게(baseline_kg) 대비 배율이다. 보통 0.9~1.05.
출력은 JSON만.
''';

  /// 모델 호출. 네트워크/한도/설정 문제는 [AiCoachException]으로.
  static Future<AiPlan> generate(AiContext ctx) async {
    final prompt = buildPrompt(ctx);
    String? text;
    Object? lastError;
    for (final m in models) {
      try {
        final gm = FirebaseAI.googleAI().generativeModel(
          model: m,
          systemInstruction: Content.system(_system),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: _schema,
          ),
        );
        final res = await gm.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 45));
        text = res.text;
        if (text != null && text.trim().isNotEmpty) break;
      } catch (e) {
        lastError = e;
        final msg = e.toString();
        if (msg.contains('403') || msg.contains('PERMISSION_DENIED') || msg.contains('not enabled') || msg.contains('API has not been used')) {
          throw AiCoachException('Firebase 콘솔에서 AI Logic(Gemini)을 아직 켜지 않았습니다. (빌드 → AI Logic → 시작하기)');
        }
        if (msg.contains('429') || msg.contains('RESOURCE_EXHAUSTED') || msg.contains('quota')) {
          throw AiCoachException('오늘 AI 무료 한도를 다 썼어요. 규칙 기반 루틴을 사용하세요.');
        }
        // 그 외(타임아웃, 모델 없음 등)는 다음 모델로.
      }
    }
    if (text == null || text.trim().isEmpty) {
      throw AiCoachException('AI 응답을 받지 못했어요. 잠시 후 다시 시도하세요.${lastError == null ? '' : ' ($lastError)'}');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw AiCoachException('AI 응답을 읽지 못했어요. 다시 시도하세요.');
    }
    return validate(json, ctx);
  }

  /// 후보 운동: 보유 기구로 가능하고 부상에 걸리지 않는 것.
  static List<Exercise> candidates(AiContext ctx) {
    final injuries = {...ctx.profile.injuries, ...?ctx.partner?.profile.injuries};
    final available = ctx.partner != null && ctx.partner!.available.isNotEmpty
        ? ctx.available.where(ctx.partner!.available.contains).toSet()
        : ctx.available;
    available.add(EquipmentType.bodyweight);
    return exerciseCatalog
        .where((e) => !e.activity && !e.warmupOnly && e.canDoWith(available) && !excludedByInjury(e, injuries))
        .toList();
  }

  static String buildPrompt(AiContext ctx) {
    final p = ctx.profile;
    final est = LoadEstimator(p);
    final cands = candidates(ctx);
    final now = ctx.date;
    String g(MuscleGroup m) => m.name;

    final sb = StringBuffer();
    sb.writeln('## 사용자');
    sb.writeln('성별 ${p.sex.label}, ${p.age}세, ${p.heightCm.round()}cm, ${p.weightKg.round()}kg, 숙련도 ${p.level.label}, 목표 ${p.goal.label}');
    if (p.skeletalMuscleKg != null) sb.writeln('골격근량 ${p.skeletalMuscleKg}kg');
    if (p.bodyFatPct != null) sb.writeln('체지방률 ${p.bodyFatPct}%');
    sb.writeln('1RM(실제 또는 추정): 스쿼트 ${est.oneRepMax(RefLift.squat).round()}, 벤치 ${est.oneRepMax(RefLift.bench).round()}, 데드 ${est.oneRepMax(RefLift.deadlift).round()}, OHP ${est.oneRepMax(RefLift.ohp).round()}');
    if (p.injuries.isNotEmpty) sb.writeln('부상(해당 운동 제외됨): ${p.injuries.map((i) => i.label).join(', ')}');
    if (p.cautions.isNotEmpty) {
      sb.writeln('주의 부위(넣어도 되지만 무게 60% 이하·고반복으로 재활 느낌): ${p.cautions.map((i) => i.label).join(', ')}');
    }
    sb.writeln('분할: ${p.splitDays}분할, 유산소 ${p.includeCardio ? '포함' : '제외'}');
    sb.writeln();
    sb.writeln('## 오늘 (${dateKey(now)})');
    sb.writeln('focus: ${ctx.focus.map(g).join(', ')}');
    sb.writeln('time_budget_min: ${ctx.minutes ?? p.sessionMinutes}');
    if (ctx.condition != null) sb.writeln('condition: ${ctx.condition}/10, 요청 무게 배율 ${ctx.loadFactor}');
    if (ctx.request != null && ctx.request!.trim().isNotEmpty) sb.writeln('request: ${ctx.request!.trim()}');
    if (ctx.partner != null) {
      final pp = ctx.partner!;
      sb.writeln('partner: ${pp.name} (${pp.profile.level.label}, ${pp.profile.weightKg.round()}kg)'
          '${pp.profile.injuries.isNotEmpty ? ', 부상 ${pp.profile.injuries.map((i) => i.label).join(',')}' : ''}');
    }
    sb.writeln();
    sb.writeln('## 최근 완료 세션 (최신순)');
    if (ctx.recent.isEmpty) sb.writeln('없음 (첫 세션)');
    for (final r in ctx.recent) {
      final done = r.exercises.where((e) => e.anyCompleted).map((e) {
        final ex = exerciseById(e.exerciseId);
        final best = e.sets.where((s) => s.completed).map((s) => s.effectiveWeight).fold<double>(0, max);
        return '${ex?.id ?? e.exerciseId}${best > 0 ? '@${_fmt(best)}kg' : ''}';
      }).join(', ');
      sb.writeln('- ${dateKey(r.date)} [${r.focus.map(g).join(',')}]${r.rpe != null ? ' RPE ${r.rpe}' : ''}: $done');
    }
    sb.writeln();
    sb.writeln('## 최근 4주 밸런스 (완료 세트)');
    sb.writeln(ctx.stats.groups.where((x) => x.group != MuscleGroup.cardio).map((x) => '${x.group.name} ${x.sets}').join(', '));
    if (ctx.stats.underTrained.isNotEmpty) sb.writeln('부족: ${ctx.stats.underTrained.map(g).join(', ')}');
    sb.writeln();
    sb.writeln('## candidates (id | name | group | compound | emphasis | rep_range | baseline_kg | last_done)');
    for (final e in cands) {
      final prog = ctx.progress[e.id];
      final reps = prog?.targetReps ?? LoadEstimator.targetReps(e, p.level, p.goal);
      final base = (prog != null && prog.workingWeight > 0) ? prog.workingWeight : est.initialWeight(e, reps);
      final last = prog?.lastPerformed == null ? '-' : '${now.difference(prog!.lastPerformed!).inDays}d';
      sb.writeln('${e.id} | ${e.name} | ${e.group.name} | ${e.compound ? 'C' : 'I'} | ${e.emphasis.join('/')} | ${e.repRange[0]}-${e.repRange[1]} | ${_fmt(base)} | $last');
    }
    return sb.toString();
  }

  /// JSON → DayPlan 재료. 없는 id·과한 값은 고치거나 버리고 warnings에 남긴다.
  static AiPlan validate(Map<String, dynamic> json, AiContext ctx) {
    final warnings = <String>[];
    final p = ctx.profile;
    final est = LoadEstimator(p);
    final candIds = {for (final e in candidates(ctx)) e.id};
    final rule = restRules;

    final focus = <MuscleGroup>[];
    for (final f in (json['focus'] as List? ?? const [])) {
      try {
        focus.add(MuscleGroup.parse(f as String));
      } catch (_) {}
    }
    final exercises = <PlannedExercise>[];
    final seen = <String>{};
    for (final raw in (json['exercises'] as List? ?? const [])) {
      final m = (raw as Map).cast<String, dynamic>();
      final id = m['id'] as String? ?? '';
      final ex = exerciseById(id);
      if (ex == null || !candIds.contains(id)) {
        warnings.add('"$id" 는 할 수 없는 운동이라 뺐어요.');
        continue;
      }
      if (!seen.add(id)) continue;
      var sets = (m['sets'] as num?)?.toInt() ?? 3;
      var reps = (m['reps'] as num?)?.toInt() ?? ex.repRange[1];
      var factor = (m['weightFactor'] as num?)?.toDouble() ?? 1.0;
      sets = sets.clamp(1, 6);
      if (ex.loadType == LoadType.cardio) {
        sets = 1;
        reps = reps.clamp(5, 60);
      } else {
        reps = reps.clamp(max(3, ex.repRange[0] - 3), ex.repRange[1] + 6);
      }
      if (factor < 0.5 || factor > 1.2) {
        warnings.add('${ex.name} 무게 배율 $factor → 범위 밖이라 1.0으로.');
        factor = 1.0;
      }
      factor *= ctx.loadFactor == 1.0 ? 1.0 : 1.0; // 컨디션 배율은 프롬프트로 이미 반영 (중복 적용 안 함)
      final prog = ctx.progress[id];
      final base = (prog != null && prog.workingWeight > 0) ? prog.workingWeight : est.initialWeight(ex, reps);
      double weight = 0;
      if (ex.loadType != LoadType.bodyweight && ex.loadType != LoadType.cardio) {
        weight = max(ex.loadType.increment, LoadEstimator.roundTo(base * factor, ex.loadType.increment));
      }
      final rest = ((ex.compound ? rule[ex.group]!.compoundRestSec : rule[ex.group]!.isolationRestSec) *
              LoadEstimator.restFactor(p.goal))
          .round();
      final note = (m['note'] as String?)?.trim();
      exercises.add(PlannedExercise(
        exerciseId: id,
        equipmentType: ex.pickEquipment(ctx.available),
        restSeconds: ex.loadType == LoadType.cardio ? 0 : rest,
        sets: List.generate(sets, (_) => SetEntry(targetReps: reps, targetWeight: weight)),
        note: 'AI · ${note == null || note.isEmpty ? ex.emphasis.join(', ') : note}',
      ));
    }
    if (exercises.isEmpty) throw AiCoachException('AI가 유효한 운동을 하나도 고르지 못했어요. 다시 시도하세요.');

    // 시간 초과면 뒤에서부터 세트를 줄인다.
    final budget = ctx.minutes ?? p.sessionMinutes;
    var guard = 0;
    while (SessionGenerator.estimateMinutes(exercises) > budget + 10 && guard++ < 30) {
      final victim = exercises.lastWhere((e) => e.sets.length > 2, orElse: () => exercises.last);
      if (victim.sets.length > 2) {
        victim.sets.removeLast();
      } else if (exercises.length > 3) {
        exercises.remove(victim);
      } else {
        break;
      }
      if (guard == 1) warnings.add('시간 예산($budget분)에 맞춰 세트를 줄였어요.');
    }

    return AiPlan(
      title: (json['title'] as String?)?.trim().isNotEmpty == true ? (json['title'] as String).trim() : 'AI 코치 루틴',
      focus: focus.isEmpty ? ctx.focus : focus,
      rationale: (json['rationale'] as String?)?.trim() ?? '',
      exercises: exercises,
      warnings: warnings,
    );
  }

  static String _fmt(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}
