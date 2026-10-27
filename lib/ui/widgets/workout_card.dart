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

/// 운동 완료 카드. 이미지로 캡처해 공유한다(인스타·카톡).
class WorkoutSummaryCard extends StatelessWidget {
  const WorkoutSummaryCard({super.key, required this.plan, required this.userName, this.equipmentLabel, this.showAll = false});

  /// 운동을 전부 펼쳐 보여줄지(기본은 8개까지).
  final bool showAll;
  final DayPlan plan;
  final String userName;

  /// 운동에 쓴 기구 이름(내 헬스장 등록 이름). 없으면 표시 안 함.
  final String Function(PlannedExercise)? equipmentLabel;

  static const _bg = Color(0xFF16201A);
  static const _bg2 = Color(0xFF2E4231);
  static const _fg = Colors.white;
  static const _accent = Color(0xFFC5E383);

  @override
  Widget build(BuildContext context) {
    final d = plan.date;
    final done = plan.exercises.where((e) => e.anyCompleted).toList();
    var sets = 0, volume = 0.0, cardioMin = 0;
    double bestW = 0;
    int bestR = 0;
    String? bestName;
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
            bestName = ex?.name;
          }
        }
      }
    }
    final shown = showAll ? done : done.take(8).toList();
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return Container(
      width: 340,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_bg, _bg2]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(children: [
        // 은은한 빛
        Positioned(
          right: -60,
          top: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_accent.withValues(alpha: 0.22), _accent.withValues(alpha: 0)]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                _Pill(
                  color: _accent,
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.fitness_center, color: _bg, size: 13),
                    SizedBox(width: 4),
                    Text('FitRoutine', style: TextStyle(color: _bg, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.3)),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} (${wd[d.weekday - 1]})',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ]),
              const SizedBox(height: 16),
              Text(plan.title ?? '운동 완료', style: const TextStyle(color: _fg, fontSize: 25, fontWeight: FontWeight.w800, height: 1.15)),
              const SizedBox(height: 4),
              Text(
                [
                  userName,
                  '${(plan.completionRatio * 100).round()}% 수행',
                  if (plan.actualMinutes != null) '${plan.actualMinutes}분',
                  if (plan.rpe != null) '체감 ${plan.rpe}/10',
                  if (plan.partnerName != null) '${plan.partnerName}와 함께',
                ].join(' · '),
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _Stat(label: '운동', value: '${done.length}'),
                const SizedBox(width: 6),
                _Stat(label: '세트', value: '$sets'),
                const SizedBox(width: 6),
                _Stat(label: '볼륨', value: volume >= 1000 ? '${(volume / 1000).toStringAsFixed(1)}t' : '${volume.round()}kg'),
                if (cardioMin > 0) ...[const SizedBox(width: 6), _Stat(label: '유산소', value: '$cardioMin분')],
              ]),
              if (bestName != null && bestW > 0) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Text('🏆', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        children: [
                          const TextSpan(text: '오늘의 최고  '),
                          TextSpan(text: bestName, style: const TextStyle(color: _fg, fontWeight: FontWeight.w600)),
                          TextSpan(text: '  ${_kg(bestW)}kg × $bestR', style: const TextStyle(color: _accent, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 12),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 8),
              for (var i = 0; i < shown.length; i++) _ExerciseLine(index: i + 1, e: shown[i], equipment: equipmentLabel?.call(shown[i]), setsText: _setsText(shown[i])),
              if (!showAll && done.length > 8)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 30),
                  child: Text('외 ${done.length - 8}개 더', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  static String _kg(double w) => w % 1 == 0 ? w.toInt().toString() : w.toString();

  /// 세트별 실제 수행을 그대로. 같은 세트가 이어지면 "50kg×15 ×2"처럼 묶는다.
  String _setsText(PlannedExercise e) {
    final ex = exerciseById(e.exerciseId);
    final doneSets = e.sets.where((s) => s.completed).toList();
    if (doneSets.isEmpty) return '';
    if (ex?.loadType == LoadType.cardio) {
      final m = doneSets.first.doneReps ?? doneSets.first.targetReps;
      final lv = doneSets.first.effectiveLevel;
      final spec = cardioLevels[e.exerciseId];
      return '$m분${lv != null && spec != null ? ' · ${spec.format(lv)}' : ''}';
    }
    final parts = <String>[];
    for (final s in doneSets) {
      final w = s.doneWeight ?? s.targetWeight;
      final r = s.doneReps ?? s.targetReps;
      parts.add(w > 0 ? '${_kg(w)}kg×$r' : '$r회');
    }
    final out = <String>[];
    var k = 0;
    while (k < parts.length) {
      var n = 1;
      while (k + n < parts.length && parts[k + n] == parts[k]) {
        n++;
      }
      out.add(n > 1 ? '${parts[k]} ×$n' : parts[k]);
      k += n;
    }
    return out.join(' · ');
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.color});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: child,
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
          ]),
        ),
      );
}

/// 운동 한 줄: 번호 · 이름(한 줄) / 기구 · 세트(줄바꿈 허용) — 이름이 잘리지 않게 세트는 아래 줄에.
class _ExerciseLine extends StatelessWidget {
  const _ExerciseLine({required this.index, required this.e, required this.equipment, required this.setsText});
  final int index;
  final PlannedExercise e;
  final String? equipment;
  final String setsText;

  @override
  Widget build(BuildContext context) {
    final name = exerciseById(e.exerciseId)?.name ?? '';
    final eq = (equipment ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: WorkoutSummaryCard._accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(7)),
          child: Text('$index', style: const TextStyle(color: WorkoutSummaryCard._accent, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WorkoutSummaryCard._fg, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.2)),
            const SizedBox(height: 1),
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                children: [
                  if (eq.isNotEmpty) TextSpan(text: '$eq  ', style: const TextStyle(color: Colors.white38)),
                  TextSpan(text: setsText),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// 완료 카드를 보여주고 이미지로 공유/저장한다.
Future<void> shareWorkoutImage(BuildContext context, DayPlan plan, String userName) async {
  final key = GlobalKey();
  var showAll = false;
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
              showAll: showAll,
              equipmentLabel: (e) => context.read<AppState>().equipmentLabelFor(plan, e.equipmentType),
            ),
          ),
          if (plan.exercises.where((e) => e.anyCompleted).length > 8)
            TextButton.icon(
              onPressed: () => setDialog(() => showAll = !showAll),
              icon: Icon(showAll ? Icons.unfold_less : Icons.unfold_more, color: Colors.white),
              label: Text(showAll ? '접기' : '전부 펼치기', style: const TextStyle(color: Colors.white)),
            ),
          const SizedBox(height: 12),
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
              style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
        ]),
      ),
    ),
  ));
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
      text: '[FitRoutine] ${plan.title ?? '운동'} 완료 · ${(plan.completionRatio * 100).round()}% 수행',
    ));
    return result.status == ShareResultStatus.unavailable ? '이 기기에서는 이미지 공유를 지원하지 않아요.' : null;
  } catch (e) {
    return '공유 실패: $e';
  }
}
