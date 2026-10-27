import 'package:flutter/material.dart';

import '../../data/body_model.dart';
import '../../engine/muscle_stats.dart';
import 'equipment_3d.dart';
import 'muscle_thumb.dart';

/// 기록 탭: 근육 22개 열지도 3D 인체 + 근육별 유효 세트(주동/보조/유산소) 표.
class MuscleHeatSection extends StatefulWidget {
  const MuscleHeatSection({super.key, required this.stats});
  final MuscleStats stats;

  @override
  State<MuscleHeatSection> createState() => _MuscleHeatSectionState();
}

class _MuscleHeatSectionState extends State<MuscleHeatSection> {
  bool _all = false;
  Muscle? _open;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final st = widget.stats;
    final ranked = st.ranked;
    final shown = _all ? ranked : ranked.take(8).toList();
    final low = [for (final m in Muscle.values) if (st.statusOf(m) == MuscleStatus.low || st.statusOf(m) == MuscleStatus.none) m];
    final high = [for (final m in Muscle.values) if (st.statusOf(m) == MuscleStatus.high) m];
    final maxScore = st.maxScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Scene3DView(
          faces: bodyFaces(const MuscleMap(primary: {}, secondary: {}), heat: st.heat),
          height: 300,
          autoRotate: false,
          edges: false,
          initialYaw: 0,
          initialPitch: 0.1,
          hint: '드래그해서 앞·뒤 보기 · 색이 진할수록 많이 자극',
          overlay: const _HeatLegend(),
        ),
        const SizedBox(height: 8),
        if (st.sessions >= 2) ...[
          if (low.isNotEmpty)
            _Line(icon: Icons.arrow_downward, color: cs.tertiary, text: '부족: ${low.map((m) => m.label).join('·')}'),
          if (high.isNotEmpty)
            _Line(icon: Icons.local_fire_department, color: cs.error, text: '많음(주 14세트 초과): ${high.map((m) => m.label).join('·')}'),
          if (low.isEmpty && high.isEmpty)
            _Line(icon: Icons.check_circle_outline, color: cs.primary, text: '근육별로 고르게 자극하고 있어요.'),
        ] else
          Text('세션이 2회 이상 쌓이면 근육별 부족·과다를 판단해요.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('근육별 유효 세트 (${st.days}일, ${st.weeks.toStringAsFixed(1)}주)', style: text.labelLarge)),
          Text('주당', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 4),
        for (final s in shown) _MuscleRow(
          score: s,
          max: maxScore,
          status: st.statusOf(s.muscle),
          weekly: st.weekly(s.muscle),
          open: _open == s.muscle,
          onTap: () => setState(() => _open = _open == s.muscle ? null : s.muscle),
        ),
        if (ranked.length > 8)
          TextButton.icon(
            onPressed: () => setState(() => _all = !_all),
            icon: Icon(_all ? Icons.unfold_less : Icons.unfold_more, size: 18),
            label: Text(_all ? '접기' : '나머지 ${ranked.length - 8}개 근육 보기'),
          ),
        Text(
          '유효 세트 = 주동근 세트×1.0 + 보조근 세트×0.4. 유산소는 20분 ≈ 1세트로 환산하고, 워치 평균 심박(또는 운동 강도)이 있으면 0.6~1.4배로 보정해요. '
          '근육 하나 기준 주당 4~14세트를 적정으로 봅니다(부위 합산이 아니라 근육 하나라 가이드보다 낮게 잡음).',
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
        ]),
      );
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('적게', style: t),
      const SizedBox(width: 4),
      Container(
        width: 70,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(colors: [heatColor(0), heatColor(0.5), heatColor(1)]),
        ),
      ),
      const SizedBox(width: 4),
      Text('많이', style: t),
    ]);
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({required this.score, required this.max, required this.status, required this.weekly, required this.open, required this.onTap});
  final MuscleScore score;
  final double max;
  final MuscleStatus status;
  final double weekly;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = switch (status) {
      MuscleStatus.low || MuscleStatus.none => cs.tertiary,
      MuscleStatus.high => cs.error,
      _ => cs.primary,
    };
    final top = score.byExercise.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 76,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(score.muscle.label, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(score.muscle.group.label, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            Expanded(
              child: LayoutBuilder(builder: (c, bc) {
                final w = max == 0 ? 0.0 : bc.maxWidth * score.score / max;
                final pw = max == 0 ? 0.0 : bc.maxWidth * score.primarySets / max;
                return Stack(children: [
                  Container(height: 16, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                  // 전체(보조·유산소 포함)는 연하게, 주동근 몫은 진하게
                  Container(height: 16, width: w.clamp(score.score > 0 ? 4.0 : 0.0, bc.maxWidth), decoration: BoxDecoration(color: heatColor(0.5), borderRadius: BorderRadius.circular(4))),
                  Container(height: 16, width: pw.clamp(0.0, bc.maxWidth), decoration: BoxDecoration(color: heatColor(1), borderRadius: BorderRadius.circular(4))),
                ]);
              }),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${_f(score.score)}세트', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (status != MuscleStatus.unknown)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(status.label, style: text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
                    ),
                  Text('주 ${_f(weekly)}', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ]),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 76, top: 2),
            child: Text(
              '주동 ${_f(score.primarySets)} · 보조 ${_f(score.secondarySets)}${score.cardioSets > 0 ? ' · 유산소 ${_f(score.cardioSets)}' : ''} · ${score.sessions}세션${score.tonnage > 0 ? ' · ${score.tonnage >= 1000 ? '${(score.tonnage / 1000).toStringAsFixed(1)}t' : '${score.tonnage.round()}kg'}' : ''}',
              style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(left: 76, top: 4, bottom: 4),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final e in top.take(5))
                  Chip(
                    label: Text('${e.key} ${_f(e.value)}'),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: cs.outlineVariant),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  static String _f(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// 워치·러닝 앱에서 읽어 들인 유산소 기록 합계.
class WatchSummaryCard extends StatelessWidget {
  const WatchSummaryCard({super.key, required this.watch});
  final WatchSummary watch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final h = watch.durationSec ~/ 3600, m = (watch.durationSec % 3600) ~/ 60;
    final tiles = <(String, String)>[
      ('기록', '${watch.sessions}회'),
      ('총 시간', h > 0 ? '$h시간 $m분' : '$m분'),
      if (watch.distanceKm > 0) ('거리', '${watch.distanceKm.toStringAsFixed(1)}km'),
      if (watch.activeKcal > 0) ('활동 kcal', '${watch.activeKcal}'),
      if (watch.avgHr != null) ('평균 심박', '${watch.avgHr}${watch.maxHr > 0 ? ' / 최대 ${watch.maxHr}' : ''}'),
      if (watch.avgEffort != null) ('평균 강도', '${watch.avgEffort!.toStringAsFixed(1)}/10'),
      if (watch.elevationM > 0) ('오른 고도', '${watch.elevationM}m'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (l, v) in tiles)
          Container(
            width: (MediaQuery.of(context).size.width - 32 - 32 - 16) / 3,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(l, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
      ]),
      const SizedBox(height: 6),
      Text(
        '평균 심박 ${watch.avgHr ?? '-'}bpm → 유산소 강도 보정 ×${((watch.avgHr ?? 140) / 140).clamp(0.6, 1.4).toStringAsFixed(2)}. 심박이 높을수록 다리 근육 자극을 더 쳐줘요.',
        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    ]);
  }
}

/// 근육별 회복 상태 목록: 썸네일 · 이름 · 마지막 운동 · 회복 %.
class MuscleRecoveryList extends StatefulWidget {
  const MuscleRecoveryList({super.key, required this.items});
  final List<MuscleRecovery> items;

  @override
  State<MuscleRecoveryList> createState() => _MuscleRecoveryListState();
}

class _MuscleRecoveryListState extends State<MuscleRecoveryList> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shown = _all ? widget.items : widget.items.take(8).toList();
    final tired = widget.items.where((r) => r.percent < 100).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        tired == 0 ? '모든 근육이 회복됐어요. 뭐든 들 수 있는 날!' : '회복 중인 근육 $tired개. 100%가 아닌 근육은 오늘 가볍게 가거나 다른 부위를 추천해요.',
        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 6),
      for (final r in shown)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            MuscleThumb(muscle: r.muscle, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.muscle.label, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  r.lastExercise != null && r.lastAt != null ? '${r.lastLabel} · ${r.lastExercise}' : r.lastLabel,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            _Pct(percent: r.percent),
          ]),
        ),
      if (widget.items.length > 8)
        TextButton.icon(
          onPressed: () => setState(() => _all = !_all),
          icon: Icon(_all ? Icons.unfold_less : Icons.unfold_more, size: 18),
          label: Text(_all ? '접기' : '나머지 ${widget.items.length - 8}개 보기'),
        ),
      Text('회복 % = 마지막 자극 후 지난 시간 ÷ 부위 권장 회복 시간(하체 72h · 가슴/등/어깨/팔 48h · 복근 24h). 보조근으로 쓰인 날은 절반만 쳐요.',
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }
}

class _Pct extends StatelessWidget {
  const _Pct({required this.percent});
  final int percent;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = percent >= 100
        ? cs.primary
        : percent >= 60
            ? const Color(0xFFF57C00)
            : cs.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
      child: Text('$percent%', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    );
  }
}
