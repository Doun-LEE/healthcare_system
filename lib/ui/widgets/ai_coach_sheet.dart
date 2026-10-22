import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/catalog.dart';
import '../../models/models.dart';
import '../../services/ai_coach.dart';
import '../../state/app_state.dart';
import 'app_sheet.dart';

/// AI 코치: 요청 입력 → 생성 → 미리보기(근거·운동 목록) → 적용.
Future<void> showAiCoach(BuildContext context, DateTime date) async {
  final state = context.read<AppState>();
  if (!state.cloudAvailable) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 플랫폼에선 AI 코치를 쓸 수 없어요.')));
    return;
  }
  final reqCtrl = TextEditingController();
  final go = await showAppSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome, color: Theme.of(c).colorScheme.primary),
            const SizedBox(width: 8),
            Text('AI 코치에게 ${date.month}/${date.day} 루틴 맡기기', style: Theme.of(c).textTheme.titleLarge),
          ]),
          const SizedBox(height: 6),
          Text(
            '내 스펙·3대·목표·부상·보유 기구·오늘 부위·컨디션·최근 2주 이력·4주 밸런스·파트너를 모두 보고 짭니다. 결과는 미리보기 후 적용합니다.',
            style: Theme.of(c).textTheme.bodySmall?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reqCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '요청 (선택)',
              hintText: '예: 어깨가 뻐근해서 프레스는 빼줘 / 오늘은 60분만 / 등 위주로',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('루틴 생성'),
          ),
        ],
      ),
    ),
  );
  if (go != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('AI 코치가 루틴을 짜는 중… (10~20초)')),
      ]),
    ),
  );
  AiPlan? plan;
  String? error;
  try {
    plan = await state.aiPlanFor(date, request: reqCtrl.text);
  } on AiCoachException catch (e) {
    error = e.message;
  } catch (e) {
    error = '오류: $e';
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), duration: const Duration(seconds: 6)));
    return;
  }
  final ai = plan!;
  final apply = await showAppSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => _AiPreview(ai: ai),
  );
  if (apply == true && context.mounted) {
    await state.applyAiPlan(date, ai);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI 루틴 "${ai.title}" 을 ${date.month}/${date.day}에 적용했어요.')));
    }
  }
}

class _AiPreview extends StatelessWidget {
  const _AiPreview({required this.ai});
  final AiPlan ai;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (c, ctrl) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ai.title, style: text.titleLarge)),
                ]),
                Wrap(spacing: 6, children: [for (final g in ai.focus) Chip(label: Text(g.label), visualDensity: VisualDensity.compact)]),
                const SizedBox(height: 8),
                if (ai.rationale.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                    child: Text(ai.rationale, style: text.bodyMedium),
                  ),
                for (final w in ai.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 16, color: cs.tertiary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(w, style: text.bodySmall?.copyWith(color: cs.tertiary))),
                    ]),
                  ),
                const SizedBox(height: 12),
                for (var i = 0; i < ai.exercises.length; i++) _row(context, i, ai.exercises[i]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.check), label: const Text('이 루틴 적용'))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i, PlannedExercise pe) {
    final ex = exerciseById(pe.exerciseId)!;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = pe.sets.first;
    final isCardio = ex.loadType == LoadType.cardio;
    final w = s.targetWeight;
    final spec = isCardio
        ? '${s.targetReps}분'
        : '${pe.sets.length}세트 × ${s.targetReps}회${w > 0 ? ' · ${w == w.roundToDouble() ? w.toInt() : w}kg' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, backgroundColor: cs.primaryContainer, child: Text('${i + 1}', style: text.labelSmall)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ex.name}  ·  $spec', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (pe.note != null) Text(pe.note!, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
