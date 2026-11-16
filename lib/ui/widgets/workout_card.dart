import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/save_file.dart';
import '../../data/catalog.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../app_theme.dart';
import 'marine_hero.dart';
import 'marine_mascot.dart';
import 'mascot.dart';

/// 공유 카드의 색·장식. 앱 테마(기본·귀여운·상남자·해병대)를 따른다.
class CardLook {
  const CardLook({
    required this.bg1,
    required this.bg2,
    required this.accent,
    required this.fg,
    required this.muted,
    required this.tile,
    required this.glow,
    this.dark = true,
    this.mascot,
    this.badge,
    this.tagline = '#FitRoutine',
  });
  final Color bg1, bg2, accent, fg, muted, tile, glow;
  final bool dark;

  /// 오른쪽 위 캐릭터(귀여운·해병대).
  final Widget? mascot;

  /// 제목 옆 작은 뱃지(해병대).
  final Widget? badge;
  final String tagline;

  Color get faint => fg.withValues(alpha: dark ? 0.55 : 0.6);
  Color get line => fg.withValues(alpha: dark ? 0.14 : 0.12);

  static CardLook of(AppThemeStyle s) => switch (s) {
        AppThemeStyle.basic => const CardLook(
            bg1: Color(0xFF16201A),
            bg2: Color(0xFF2E4231),
            accent: Color(0xFFC5E383),
            fg: Colors.white,
            muted: Colors.white70,
            tile: Color(0x17FFFFFF),
            glow: Color(0xFFC5E383),
          ),
        AppThemeStyle.cute => const CardLook(
            bg1: Color(0xFFFFE1EA),
            bg2: Color(0xFFFFF7F2),
            accent: Color(0xFFD9567F),
            fg: Color(0xFF3F1A2A),
            muted: Color(0xFF8A5A6A),
            tile: Color(0x99FFFFFF),
            glow: Color(0xFFFFB1C8),
            dark: false,
            mascot: Mascot(mood: MascotMood.cheer, size: 64, bob: false),
            tagline: '#FitRoutine · 헬창애옹과 함께 🐱',
          ),
        AppThemeStyle.tough => const CardLook(
            bg1: Color(0xFF0B0A09),
            bg2: Color(0xFF2A211C),
            accent: Color(0xFFFF6A2B),
            fg: Color(0xFFF3EEE9),
            muted: Color(0xFFBFB3A9),
            tile: Color(0x1AFFFFFF),
            glow: Color(0xFFFF6A2B),
            tagline: '#FitRoutine · 쇠는 핑계를 안 듣는다',
          ),
        AppThemeStyle.marine => const CardLook(
            bg1: Color(0xFF0B1020),
            bg2: Color(0xFF24304F),
            accent: Color(0xFFFFD24D),
            fg: Colors.white,
            muted: Color(0xFFC2BFB4),
            tile: Color(0x1AFFFFFF),
            glow: Color(0xFFFF5A6B),
            mascot: MarineHero(size: 78),
            badge: MarineEmblem(size: 26),
            tagline: '#FitRoutine · 악! 임무 완수! 필승!',
          ),
      };
}

/// 운동 완료 카드. 이미지로 캡처해 공유한다(인스타·카톡).
class WorkoutSummaryCard extends StatelessWidget {
  const WorkoutSummaryCard({
    super.key,
    required this.plan,
    required this.userName,
    this.equipmentLabel,
    this.style = AppThemeStyle.basic,
  });

  final DayPlan plan;
  final String userName;
  final AppThemeStyle style;

  /// 운동에 쓴 기구 이름(내 헬스장 등록 이름). 없으면 표시 안 함.
  final String Function(PlannedExercise)? equipmentLabel;

  @override
  Widget build(BuildContext context) {
    final look = CardLook.of(style);
    final d = plan.date;
    final done = plan.exercises.where((e) => e.anyCompleted).toList();
    var sets = 0, volume = 0.0, cardioMin = 0;
    double bestW = 0;
    int bestR = 0;
    String? bestId;
    for (final e in plan.exercises) {
      final ex = exerciseById(e.exerciseId);
      for (final s in e.sets) {
        if (!s.completed) continue;
        if (ex?.loadType == LoadType.cardio) {
          cardioMin += s.doneReps ?? s.targetReps;
        } else {
          sets++;
          final w = s.doneWeight ?? s.targetWeight;
          final r = s.doneReps ?? s.targetReps;
          volume += w * r;
          if (w > bestW || (w == bestW && w > 0 && r > bestR)) {
            bestW = w;
            bestR = r;
            bestId = e.exerciseId;
          }
        }
      }
    }
    final groupSets = <MuscleGroup, int>{};
    for (final e in done) {
      if (exerciseById(e.exerciseId)?.loadType == LoadType.cardio) continue;
      groupSets[e.effectiveGroup] = (groupSets[e.effectiveGroup] ?? 0) + e.sets.where((x) => x.completed).length;
    }
    const sectionOrder = [MuscleGroup.cardio, MuscleGroup.legs, MuscleGroup.back, MuscleGroup.chest, MuscleGroup.shoulder, MuscleGroup.arms, MuscleGroup.abs];
    final splitOrder = groupSets.keys.toList()..sort((a, b) => groupSets[b]!.compareTo(groupSets[a]!));
    // 한 화면(9:16)에 다 들어가게: 부위 순서로 줄 세우고, 7개 이상이면 2열 타일.
    final ordered = [...done]..sort((a, b) => sectionOrder.indexOf(a.effectiveGroup).compareTo(sectionOrder.indexOf(b.effectiveGroup)));
    final twoCol = ordered.length > 6;
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final percent = (plan.completionRatio * 100).round();
    final radius = style.radius.clamp(10.0, 26.0);

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [look.bg1, look.bg2]),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(children: [
          // 상남자·해병대: 가공한 실사 사진을 위쪽에 깔고 아래로 갈수록 배경색으로 녹인다.
          if (style.photo != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 230,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x55000000), Color(0x00000000)],
                  stops: [0.0, 0.55, 1.0],
                ).createShader(r),
                child: Image.asset(style.photo!, fit: BoxFit.cover, alignment: Alignment.centerRight),
              ),
            ),
          // 은은한 빛
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [look.glow.withValues(alpha: look.dark ? 0.22 : 0.45), look.glow.withValues(alpha: 0)]),
              ),
            ),
          ),
          if (look.mascot != null) Positioned(right: 14, top: 44, child: look.mascot!),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: look.accent, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.fitness_center, color: look.bg1, size: 13),
                      const SizedBox(width: 4),
                      Text('FitRoutine', style: TextStyle(color: look.bg1, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.3)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} (${wd[d.weekday - 1]})',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: look.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (look.badge != null) ...[look.badge!, const SizedBox(width: 6)],
                        Expanded(
                          child: Text(plan.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: look.fg, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        [
                          userName,
                          if (plan.actualMinutes != null) '${plan.actualMinutes}분',
                          if (plan.rpe != null) '체감 ${plan.rpe}/10',
                          if (plan.partnerName != null) '${plan.partnerName}와 함께',
                        ].join(' · '),
                        style: TextStyle(color: look.muted, fontSize: 12.5),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  // 수행률 링
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CustomPaint(
                      painter: _RingPainter(plan.completionRatio, look.accent, look.line),
                      child: Center(
                        child: Text('$percent%', style: TextStyle(color: look.fg, fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  if (look.mascot != null) SizedBox(width: look.mascot is MarineHero ? 66 : 54),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _Stat(look: look, label: '운동', value: '${done.length}'),
                  const SizedBox(width: 6),
                  _Stat(look: look, label: '세트', value: '$sets'),
                  const SizedBox(width: 6),
                  _Stat(look: look, label: '볼륨', value: volume >= 1000 ? '${(volume / 1000).toStringAsFixed(1)}t' : '${volume.round()}kg'),
                  if (cardioMin > 0) ...[const SizedBox(width: 6), _Stat(look: look, label: '유산소', value: '$cardioMin분')],
                ]),
                if (splitOrder.length > 1) ...[
                  const SizedBox(height: 8),
                  _SplitBar(look: look, order: splitOrder, sets: groupSets),
                ],
                const SizedBox(height: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: cardWidth - 40,
                        child: _ExerciseGrid(
                          look: look,
                          items: ordered,
                          twoCol: twoCol,
                          equipment: equipmentLabel,
                          bestId: bestW > 0 ? bestId : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: look.line),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(look.tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: look.faint, fontSize: 11))),
                  const SizedBox(width: 8),
                  Text('${plan.exercises.length}개 계획 · $percent% 완료', style: TextStyle(color: look.faint, fontSize: 11)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// 인스타 스토리·폰 화면 비율(9:16). 스크롤 없이 한 장에 다 보이게 고정.
  static const cardWidth = 340.0;
  static const cardHeight = cardWidth * 16 / 9;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ratio, this.color, this.track);
  final double ratio;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = 6);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * ratio.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.ratio != ratio || old.color != color;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.look, required this.label, required this.value});
  final CardLook look;
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(color: look.tile, borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: look.fg, fontSize: 16, fontWeight: FontWeight.w800, height: 1.1)))),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: look.faint, fontSize: 10.5)),
          ]),
        ),
      );
}

String _kgText(double w) => w % 1 == 0 ? w.toInt().toString() : w.toString();

/// 세트 칩 하나(같은 세트가 이어지면 "×2"로 묶는다).
class _Chip {
  _Chip(this.label, this.top);
  final String label;
  final bool top;
}

/// 운동 하나의 세트를 칩으로. 근력은 '무게kg×횟수', 맨몸은 '횟수회', 유산소는 '분 · 레벨' 구간별.
List<_Chip> _chipsFor(PlannedExercise e) {
  final ex = exerciseById(e.exerciseId);
  final done = e.sets.where((s) => s.completed).toList();
  if (done.isEmpty) return const [];
  if (ex?.loadType == LoadType.cardio) {
    final spec = cardioLevels[e.exerciseId];
    return [
      for (final s in done)
        _Chip('${s.doneReps ?? s.targetReps}분${spec != null && s.effectiveLevel != null ? ' · ${spec.format(s.effectiveLevel!)}' : ''}', false),
    ];
  }
  final maxW = done.map((s) => s.doneWeight ?? s.targetWeight).fold<double>(0, math.max);
  final raw = <(String, bool)>[
    for (final s in done)
      () {
        final w = s.doneWeight ?? s.targetWeight;
        final r = s.doneReps ?? s.targetReps;
        return (w > 0 ? '${_kgText(w)}kg×$r' : '$r회', w > 0 && w == maxW);
      }(),
  ];
  final out = <_Chip>[];
  var k = 0;
  var topMarked = false;
  while (k < raw.length) {
    var n = 1;
    while (k + n < raw.length && raw[k + n].$1 == raw[k].$1) {
      n++;
    }
    final top = raw[k].$2 && !topMarked && raw.any((x) => x.$1 != raw[k].$1);
    if (top) topMarked = true;
    out.add(_Chip(n > 1 ? '${raw[k].$1} ×$n' : raw[k].$1, top));
    k += n;
  }
  return out;
}

/// 운동 오른쪽에 크게 보여줄 값: 최고 무게 / 총 횟수 / 총 시간.
String _headline(PlannedExercise e) {
  final ex = exerciseById(e.exerciseId);
  final done = e.sets.where((s) => s.completed).toList();
  if (done.isEmpty) return '';
  if (ex?.loadType == LoadType.cardio) return '${done.fold<int>(0, (a, s) => a + (s.doneReps ?? s.targetReps))}분';
  final maxW = done.map((s) => s.doneWeight ?? s.targetWeight).fold<double>(0, math.max);
  if (maxW > 0) return '${_kgText(maxW)}kg';
  return '${done.fold<int>(0, (a, s) => a + (s.doneReps ?? s.targetReps))}회';
}

/// 부위별 세트 비중 막대 + 범례.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.look, required this.order, required this.sets});
  final CardLook look;
  final List<MuscleGroup> order;
  final Map<MuscleGroup, int> sets;

  Color _shade(int i) => look.accent.withValues(alpha: (1.0 - i * 0.16).clamp(0.3, 1.0));

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 7,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < order.length; i++) ...[
              if (i > 0) SizedBox(width: 2, child: ColoredBox(color: look.bg1)),
              Expanded(flex: sets[order[i]]!, child: ColoredBox(color: _shade(i))),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 5),
      Wrap(spacing: 10, runSpacing: 2, children: [
        for (var i = 0; i < order.length; i++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: _shade(i), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text('${order[i].label} ${sets[order[i]]}', style: TextStyle(color: look.muted, fontSize: 10.5)),
          ]),
      ]),
    ]);
  }
}

/// 운동 목록. 6개 이하는 한 줄에 하나(넓은 타일), 7개 이상은 2열 타일.
class _ExerciseGrid extends StatelessWidget {
  const _ExerciseGrid({required this.look, required this.items, required this.twoCol, this.equipment, this.bestId});
  final CardLook look;
  final List<PlannedExercise> items;
  final bool twoCol;
  final String Function(PlannedExercise)? equipment;
  final String? bestId;

  Widget _tile(PlannedExercise e) => _ExerciseTile(
        look: look,
        e: e,
        equipment: equipment?.call(e),
        best: e.exerciseId == bestId,
        wide: !twoCol,
      );

  @override
  Widget build(BuildContext context) {
    if (!twoCol) {
      return Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          _tile(items[i]),
        ],
      ]);
    }
    return Column(children: [
      for (var i = 0; i < items.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 5),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _tile(items[i])),
            const SizedBox(width: 6),
            Expanded(child: i + 1 < items.length ? _tile(items[i + 1]) : const SizedBox()),
          ]),
        ),
      ],
    ]);
  }
}

/// 운동 하나: 이름(+최고 무게) / 부위·기구 / 세트("80×12 · 120×8", 최고 세트 강조).
class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.look, required this.e, required this.equipment, this.best = false, this.wide = false});
  final CardLook look;
  final PlannedExercise e;
  final String? equipment;
  final bool best;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final name = exerciseById(e.exerciseId)?.name ?? '';
    final eq = (equipment ?? '').trim();
    final chips = _chipsFor(e);
    final nameStyle = TextStyle(color: look.fg, fontSize: 13, fontWeight: FontWeight.w700, height: 1.2);
    final sets = Text.rich(
      TextSpan(children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) TextSpan(text: wide ? ' · ' : ' ', style: TextStyle(color: look.faint)),
          TextSpan(
            text: chips[i].label.replaceAll('kg×', '×'),
            style: chips[i].top ? TextStyle(color: look.accent, fontWeight: FontWeight.w800) : null,
          ),
        ],
      ]),
      maxLines: 1,
      softWrap: false,
      textAlign: wide ? TextAlign.right : TextAlign.left,
      style: TextStyle(color: look.muted, fontSize: 11, height: 1.25, fontFeatures: const [FontFeature.tabularFigures()]),
    );
    final sub = Text.rich(
      TextSpan(children: [
        TextSpan(text: e.effectiveGroup.label, style: TextStyle(color: look.accent, fontWeight: FontWeight.w700)),
        if (eq.isNotEmpty) TextSpan(text: ' · $eq'),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: look.faint, fontSize: 9.5, height: 1.3),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
      decoration: BoxDecoration(
        color: best ? look.accent.withValues(alpha: look.dark ? 0.14 : 0.18) : look.tile,
        borderRadius: BorderRadius.circular(10),
        border: best ? Border.all(color: look.accent.withValues(alpha: 0.6)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (best) const Padding(padding: EdgeInsets.only(right: 3), child: Text('🏆', style: TextStyle(fontSize: 10))),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle)),
          if (wide) ...[
            const SizedBox(width: 4),
            Text(_headline(e), style: TextStyle(color: best ? look.accent : look.fg, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ],
        ]),
        const SizedBox(height: 2),
        if (wide)
          Row(children: [
            Expanded(child: sub),
            const SizedBox(width: 8),
            Flexible(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: sets)),
          ])
        else ...[
          sub,
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: sets),
        ],
      ]),
    );
  }
}

/// 완료 카드를 보여주고 이미지로 공유/저장한다. 카드 스타일은 앱 테마가 기본, 공유 전에 바꿀 수 있다.
Future<void> shareWorkoutImage(BuildContext context, DayPlan plan, String userName) async {
  final key = GlobalKey();
  var style = themeStyleOf(context);
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setDialog) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
            key: key,
            child: WorkoutSummaryCard(
              plan: plan,
              userName: userName,
              style: style,
              equipmentLabel: (e) => context.read<AppState>().equipmentLabelFor(plan, e.equipmentType, pe: e),
            ),
          ),
          const SizedBox(height: 8),
          // 카드 스타일 고르기
          Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
            for (final s in AppThemeStyle.values)
              ChoiceChip(
                label: Text(s.label),
                selected: style == s,
                avatar: CircleAvatar(backgroundColor: CardLook.of(s).accent, radius: 7),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setDialog(() => style = s),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('닫기', style: TextStyle(color: Colors.white))),
            if (kIsWeb)
              FilledButton.tonalIcon(
                onPressed: () async {
                  final msg = await _capture(key, plan, copy: true);
                  if (c.mounted && msg != null) {
                    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('복사 (카톡에 붙여넣기)'),
              ),
            FilledButton.tonalIcon(
              onPressed: () async {
                final msg = await _capture(key, plan, save: true);
                if (c.mounted && msg != null) {
                  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('이미지 저장'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final msg = await _capture(key, plan);
                if (c.mounted && msg != null) {
                  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('공유 (카톡·인스타)'),
            ),
          ]),
          const SizedBox(height: 6),
          Text(kIsWeb ? 'PC 공유 창에는 카카오톡이 안 뜹니다(윈도우 제한). "복사" 후 카톡 대화창에 Ctrl+V 하세요. 폰에서는 공유 창에 카카오톡·인스타그램이 보여요.' : '공유 창에서 카카오톡·인스타그램·갤러리를 고르세요.',
              style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
        ]),
      ),
    )),
  );
}

Future<String?> _capture(GlobalKey key, DayPlan plan, {bool save = false, bool copy = false}) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return '카드를 찾지 못했어요.';
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return '이미지 변환 실패';
    final d = plan.date;
    final name = 'fitroutine_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.png';
    if (copy) {
      final ok = await copyImageToClipboard(bytes.buffer.asUint8List(), 'image/png');
      return ok ? '이미지를 복사했어요. 카톡 대화창에서 Ctrl+V 하세요.' : '이 브라우저는 이미지 복사를 지원하지 않아요. "이미지 저장"을 쓰세요.';
    }
    if (save) return await saveBytesToDevice(bytes.buffer.asUint8List(), name, 'image/png');
    final file = XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: name);
    final result = await SharePlus.instance.share(ShareParams(
      files: [file],
      text: '[FitRoutine] ${plan.displayTitle} 완료 · ${(plan.completionRatio * 100).round()}% 수행',
    ));
    return result.status == ShareResultStatus.unavailable ? '이 기기에서는 이미지 공유를 지원하지 않아요.' : null;
  } catch (e) {
    return '공유 실패: $e';
  }
}
