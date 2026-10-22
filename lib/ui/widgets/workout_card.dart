import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/save_file.dart';
import '../../data/catalog.dart';
import '../../models/models.dart';

/// 운동 완료 카드. 이미지로 캡처해 공유한다(인스타·카톡).
class WorkoutSummaryCard extends StatelessWidget {
  const WorkoutSummaryCard({super.key, required this.plan, required this.userName});
  final DayPlan plan;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final d = plan.date;
    final done = plan.exercises.where((e) => e.anyCompleted).toList();
    var sets = 0, volume = 0.0, cardioMin = 0;
    for (final e in plan.exercises) {
      final ex = exerciseById(e.exerciseId);
      for (final s in e.sets) {
        if (!s.completed) continue;
        if (ex?.loadType == LoadType.cardio) {
          cardioMin += s.doneReps ?? s.targetReps;
        } else {
          sets++;
          volume += (s.doneWeight ?? s.targetWeight) * (s.doneReps ?? s.targetReps);
        }
      }
    }
    const bg = Color(0xFF1F2A1E);
    const fg = Colors.white;
    const accent = Color(0xFFB7D77A);
    return Container(
      width: 340,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [bg, Color(0xFF3A4D33)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.fitness_center, color: accent, size: 20),
            const SizedBox(width: 6),
            const Text('FitRoutine', style: TextStyle(color: accent, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const Spacer(),
            Text('${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          Text(plan.title ?? '운동 완료', style: const TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.bold)),
          Text('$userName · ${(plan.completionRatio * 100).round()}% 수행${plan.rpe != null ? ' · 체감 ${plan.rpe}/10' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            _Stat(label: '운동', value: '${done.length}개'),
            _Stat(label: '세트', value: '$sets'),
            _Stat(label: '볼륨', value: volume >= 1000 ? '${(volume / 1000).toStringAsFixed(1)}t' : '${volume.round()}kg'),
            if (cardioMin > 0) _Stat(label: '유산소', value: '$cardioMin분'),
          ]),
          const SizedBox(height: 14),
          for (final e in done.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.check, color: accent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: Text(exerciseById(e.exerciseId)?.name ?? '', style: const TextStyle(color: fg, fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 6,
                  child: Text(_setsText(e), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ]),
            ),
          if (done.length > 8)
            Text('외 ${done.length - 8}개', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

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
      parts.add(w > 0 ? '${w % 1 == 0 ? w.toInt() : w}kg×$r' : '$r회');
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
    return out.join(', ');
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      );
}

/// 완료 카드를 보여주고 이미지로 공유/저장한다.
Future<void> shareWorkoutImage(BuildContext context, DayPlan plan, String userName) async {
  final key = GlobalKey();
  await showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(key: key, child: WorkoutSummaryCard(plan: plan, userName: userName)),
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
      text: '[FitRoutine] ${plan.title ?? '운동'} 완료 · ${(plan.completionRatio * 100).round()}% 수행',
    ));
    return result.status == ShareResultStatus.unavailable ? '이 기기에서는 이미지 공유를 지원하지 않아요.' : null;
  } catch (e) {
    return '공유 실패: $e';
  }
}
