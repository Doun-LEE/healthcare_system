import 'package:flutter/material.dart';

import '../../data/body_model.dart';
import '../../data/catalog.dart';
import '../../data/how_to.dart';
import '../../models/models.dart';
import 'body_view.dart';
import 'equipment_3d.dart';
import 'app_sheet.dart';

/// 운동 상세: 설명, 세부 타깃, 사용 기구의 3D 모델과 기구 특징.
class ExerciseSheet extends StatelessWidget {
  const ExerciseSheet({super.key, required this.exercise, required this.equipment});
  final Exercise exercise;
  final EquipmentType equipment;

  static Future<void> show(BuildContext context, Exercise ex, EquipmentType eq) =>
      showAppSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ExerciseSheet(exercise: ex, equipment: eq),
      );

  @override
  Widget build(BuildContext context) {
    final info = equipmentInfo(equipment);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final muscles = musclesFor(exercise);
    final steps = howToFor(exercise);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(exercise.name, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${exercise.group.label} · ${exercise.compound ? '복합운동' : '고립운동'} · ${exercise.repRange[0]}~${exercise.repRange[1]}${exercise.group == MuscleGroup.cardio ? '분' : '회'}',
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: exercise.emphasis
                .map((e) => Chip(
                      label: Text(e),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cs.primaryContainer,
                      labelStyle: TextStyle(color: cs.onPrimaryContainer),
                    ))
                .toList(),
          ),
          if (exercise.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(exercise.description, style: text.bodyLarge),
          ],
          const SizedBox(height: 20),
          Text('자극 부위', style: text.titleMedium),
          const SizedBox(height: 8),
          BodyMuscleView(map: muscles),
          const SizedBox(height: 20),
          Text('하는 방법', style: text.titleMedium),
          const SizedBox(height: 6),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: cs.primaryContainer,
                    child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[i], style: text.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text('사용 기구 · ${equipment.label}', style: text.titleMedium),
          const SizedBox(height: 8),
          Equipment3DView(type: equipment, height: 230),
          const SizedBox(height: 12),
          Text(info.summary, style: text.bodyMedium),
          const SizedBox(height: 8),
          ...info.strengths.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(Icons.check_circle, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s)),
                ]),
              )),
          if (exercise.equipment.length > 1) ...[
            const SizedBox(height: 16),
            Text('대체 가능 기구', style: text.titleSmall),
            const SizedBox(height: 4),
            Text(exercise.equipment.map((e) => e.label).join(', '),
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
