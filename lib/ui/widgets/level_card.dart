import 'package:flutter/material.dart';

import '../../engine/level_assessor.dart';
import '../../models/models.dart';

/// 레벨 판정 결과: 종합 등급 + 항목별 바.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.profile, this.compact = false, this.onTap, this.hideBody = false});
  final UserProfile profile;

  /// 친구가 신체 정보를 숨겼으면: '체중의 몇 배'처럼 체중을 거꾸로 알 수 있는 값과 골격근·체지방 수치는 숨기고 등급만.
  final bool hideBody;

  String _detail(LevelItem it) {
    if (!hideBody || it.missing) return it.detail;
    if (it.name == '골격근량' || it.name == '체지방률') return '비공개';
    return it.detail.split(' · ').first;
  }

  /// 홈 화면용 한 줄 요약.
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = LevelAssessor.assess(profile);
    final gradeText = a.grade?.label ?? profile.level.label;

    if (compact) {
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(Icons.military_tech_outlined, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('내 레벨 · $gradeText${a.score != null ? ' ${a.score!.round()}점' : ''}',
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    a.hasData ? a.items.where((i) => !i.missing).map((i) => '${i.name} ${i.grade.label}').join(' · ') : a.summary,
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ]),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.military_tech_outlined, color: cs.primary, size: 28),
        const SizedBox(width: 8),
        // 좁은 폰에서 넘치지 않게: 등급·점수는 남는 폭 안에서 줄바꿈.
        Expanded(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
            Text('종합 $gradeText', style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
            if (a.score != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${a.score!.round()}점 / 100', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ),
          ]),
        ),
        const SizedBox(width: 6),
        Chip(label: Text('엔진 ${a.level.label}'), visualDensity: VisualDensity.compact),
      ]),
      if (a.score != null) ...[
        const SizedBox(height: 6),
        _Bar(value: a.score! / 100, color: cs.primary, height: 8),
        const SizedBox(height: 2),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final g in Grade.values) Text(g.label, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ],
      const SizedBox(height: 10),
      for (final it in a.items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(
              width: 76,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(it.name, maxLines: 1, style: text.bodyMedium)),
              ),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Bar(value: it.missing ? 0 : it.score / 100, color: it.missing ? cs.outlineVariant : _gradeColor(it.grade, cs), height: 6),
                const SizedBox(height: 2),
                Text(_detail(it), style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text(it.missing ? '—' : it.grade.label,
                  textAlign: TextAlign.right,
                  style: text.labelLarge?.copyWith(color: it.missing ? cs.onSurfaceVariant : _gradeColor(it.grade, cs), fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      const SizedBox(height: 8),
      Text('적용 강도', style: text.labelLarge),
      Text(a.intensity, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }

  Color _gradeColor(Grade g, ColorScheme cs) => switch (g) {
        Grade.novice => cs.outline,
        Grade.beginner => cs.tertiary,
        Grade.intermediate => cs.primary,
        Grade.advanced => const Color(0xFF2E7D32),
        Grade.elite => const Color(0xFFEF6C00),
      };
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.height});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          color: color,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      );
}
