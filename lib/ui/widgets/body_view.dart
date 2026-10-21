import 'package:flutter/material.dart';

import '../../data/body_model.dart';
import 'equipment_3d.dart';

/// 자극 근육을 빨강(주동)·주황(보조)으로 칠한 3D 인체. 드래그로 돌려볼 수 있다.
class BodyMuscleView extends StatelessWidget {
  const BodyMuscleView({super.key, required this.map, this.height = 260});
  final MuscleMap map;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Scene3DView(
          faces: bodyFaces(map),
          height: height,
          autoRotate: false,
          initialYaw: bodyInitialYaw(map),
          initialPitch: 0.12,
          hint: '드래그해서 앞·뒤 보기',
          overlay: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _Legend(color: Color(0xFFE53935), label: '주동근'),
              SizedBox(width: 10),
              _Legend(color: Color(0xFFFFA726), label: '보조근'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in map.primary)
              Chip(
                label: Text(m.label),
                visualDensity: VisualDensity.compact,
                backgroundColor: cs.errorContainer,
                labelStyle: TextStyle(color: cs.onErrorContainer),
                side: BorderSide.none,
              ),
            for (final m in map.secondary)
              Chip(
                label: Text(m.label),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: cs.outlineVariant),
              ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}
