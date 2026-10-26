import 'package:flutter/material.dart';

import '../../models/models.dart';

/// 부위별 3단계: 없음 → 주의(가볍게 재활 느낌으로 넣음) → 부상(그 부위 부담 운동 빼기) → 없음.
class InjuryChips extends StatelessWidget {
  const InjuryChips({super.key, required this.injuries, required this.cautions, required this.onChanged});

  final Set<InjuryArea> injuries;
  final Set<InjuryArea> cautions;

  /// 새 (부상, 주의) 집합.
  final void Function(Set<InjuryArea> injuries, Set<InjuryArea> cautions) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final a in InjuryArea.values)
          _chip(cs, a),
      ]),
      const SizedBox(height: 4),
      Text('한 번 누르면 주의(무게 낮춰 재활 느낌으로 넣음), 한 번 더 누르면 부상(그 부위 부담 가는 운동은 뺌).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _chip(ColorScheme cs, InjuryArea a) {
    final hurt = injuries.contains(a);
    final careful = !hurt && cautions.contains(a);
    final label = hurt ? '${a.label} · 부상' : careful ? '${a.label} · 주의' : a.label;
    return ChoiceChip(
      avatar: hurt
          ? Icon(Icons.block, size: 16, color: cs.onErrorContainer)
          : careful
              ? Icon(Icons.healing, size: 16, color: cs.onTertiaryContainer)
              : null,
      label: Text(label),
      selected: hurt || careful,
      showCheckmark: false,
      selectedColor: hurt ? cs.errorContainer : cs.tertiaryContainer,
      labelStyle: TextStyle(color: hurt ? cs.onErrorContainer : careful ? cs.onTertiaryContainer : null),
      onSelected: (_) {
        final inj = {...injuries}, cau = {...cautions};
        if (hurt) {
          inj.remove(a);
          cau.remove(a);
        } else if (careful) {
          cau.remove(a);
          inj.add(a);
        } else {
          cau.add(a);
        }
        onChanged(inj, cau);
      },
    );
  }
}
