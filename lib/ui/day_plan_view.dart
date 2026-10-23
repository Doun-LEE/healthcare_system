import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/catalog.dart';
import '../engine/load_estimator.dart';
import '../engine/session_generator.dart';
import '../engine/splits.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';
import 'widgets/condition_card.dart';
import 'widgets/equipment_3d.dart';
import 'widgets/equipment_look.dart';
import 'widgets/exercise_sheet.dart';
import 'widgets/rest_timer.dart';
import 'widgets/set_editor.dart';
import 'widgets/workout_card.dart';
import 'widgets/app_sheet.dart';

/// 공유 코드 붙여넣기 → 해당 날짜로 가져오기. 오늘/달력 화면에서 공용.
Future<void> importRoutineDialog(BuildContext context, DateTime date) async {
  final state = context.read<AppState>();
  final c = TextEditingController();
  final clip = await Clipboard.getData('text/plain');
  if (clip?.text != null && clip!.text!.contains('FR1:')) c.text = clip.text!;
  if (!context.mounted) return;
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('루틴 불러오기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('친구가 보낸 공유 코드(FR1:…)를 붙여넣으세요. 운동·세트·횟수는 그대로, 무게는 내 기준으로 바뀝니다.'),
          const SizedBox(height: 10),
          TextField(controller: c, maxLines: 4, autofocus: true, decoration: const InputDecoration(hintText: 'FR1:…')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('가져오기')),
      ],
    ),
  );
  if (code == null || code.trim().isEmpty || !context.mounted) return;
  final plan = await state.importRoutine(code, date);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(plan == null
        ? '코드를 읽지 못했어요. 전체를 그대로 붙여넣었는지 확인하세요.'
        : '${date.month}/${date.day}에 "${plan.title}" ${plan.exercises.length}개 운동을 넣었어요.'),
  ));
}

/// 그날의 부위를 바꾼다: 분할 템플릿의 다른 날을 고르거나 부위를 직접 선택.
/// "이후 날짜도 이어서 재배치"를 켜면 분할 순서가 그날부터 다시 이어진다.
Future<void> changeDayFocusDialog(BuildContext context, DayPlan plan) async {
  final state = context.read<AppState>();
  final user = state.currentUser;
  if (user == null) return;
  final cycle = splitCycles[user.splitDays.clamp(1, 6)]!;
  final custom = <MuscleGroup>{...plan.focus};
  var shift = true;

  final result = await showAppSheet<(List<MuscleGroup>, String?, bool)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${plan.date.month}/${plan.date.day} 부위 바꾸기', style: Theme.of(c).textTheme.titleLarge),
            Text('예: 오늘이 하체 날인데 가슴을 하고 싶으면 "밀기"를 고르세요.',
                style: Theme.of(c).textTheme.bodySmall?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Text('내 ${user.splitDays}분할의 날', style: Theme.of(c).textTheme.labelLarge),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final d in cycle)
                  ActionChip(
                    label: Text(d.title),
                    onPressed: () => Navigator.pop(c, (d.groups, d.title, shift)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('또는 부위 직접 선택', style: Theme.of(c).textTheme.labelLarge),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final g in MuscleGroup.values)
                  FilterChip(
                    label: Text(g.label),
                    selected: custom.contains(g),
                    onSelected: (v) => setSheet(() => v ? custom.add(g) : custom.remove(g)),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: shift,
              title: const Text('이후 날짜도 이어서 재배치'),
              subtitle: const Text('분할 순서가 이 날부터 다시 이어집니다 (완료한 날은 그대로)'),
              onChanged: (v) => setSheet(() => shift = v),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: custom.isEmpty ? null : () => Navigator.pop(c, (custom.toList(), null, shift)),
              child: const Text('선택한 부위로 다시 만들기'),
            ),
          ],
        ),
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  final (groups, title, doShift) = result;
  await state.changeDayFocus(plan.date, groups, title: title, shiftFollowing: doShift);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${plan.date.month}/${plan.date.day} 루틴을 ${title ?? groups.map((g) => g.label).join('·')}(으)로 바꿨어요${doShift ? ' · 이후 날짜 재배치됨' : ''}.'),
    ));
  }
}

Future<void> shareRoutine(BuildContext context, DayPlan plan) async {
  final state = context.read<AppState>();
  final code = state.shareCode(plan);
  final text = '[FitRoutine] ${plan.title ?? '루틴'} · ${plan.exercises.length}개 운동\n'
      '앱에서 "루틴 불러오기"에 아래 코드를 붙여넣으세요.\n$code';
  await Clipboard.setData(ClipboardData(text: text));
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: 'FitRoutine 루틴 공유'));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유 코드를 클립보드에 복사했어요.')));
    }
  }
}

/// 하루 계획 상세. 오늘 화면과 달력 상세에서 공용으로 쓴다.
/// 세트 체크, 횟수/무게 수정, 세트 추가, 운동 교체/삭제, 완료 처리.
class DayPlanView extends StatelessWidget {
  const DayPlanView({super.key, required this.plan, this.editable = true, bool? logging})
      : logging = logging ?? editable;
  final DayPlan plan;

  /// 운동 교체/제외/세트 추가/부위 바꾸기 허용.
  final bool editable;

  /// 세트 체크·실제 수행 입력·완료 허용 (오늘/과거만).
  final bool logging;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (plan.isRest) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement, size: 72, color: cs.tertiary),
            const SizedBox(height: 12),
            Text('휴식일', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(plan.title ?? '', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            const Text('잘 쉬는 것도 운동입니다. 스트레칭·수면·단백질.'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _Header(plan: plan),
        if (plan.skipped)
          Card(
            color: cs.tertiaryContainer,
            child: ListTile(
              leading: Icon(Icons.self_improvement, color: cs.onTertiaryContainer),
              title: Text('휴식한 날', style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.bold)),
              subtitle: Text(
                state.currentUser?.restMode == 'keep'
                    ? '계획한 루틴은 그대로 두고 이 날만 쉬었어요. 이후 루틴은 바뀌지 않아요.'
                    : '이 날을 쉬어서 이후 루틴을 뒤로 밀어 다시 맞췄어요.',
                style: TextStyle(color: cs.onTertiaryContainer),
              ),
              trailing: plan.isFinished
                  ? null
                  : TextButton(onPressed: () => state.toggleRestDay(plan.date), child: const Text('운동하기')),
            ),
          ),
        if (logging && !plan.isFinished && plan.exercises.isNotEmpty && !plan.exercises.any((e) => e.anyCompleted))
          ConditionCard(key: ValueKey('cond-${plan.id}-${plan.loadFactor}-${plan.estimatedMinutes}'), plan: plan),
        if (logging && !plan.isFinished && plan.exercises.isNotEmpty)
          _WorkoutClock(plan: plan, onStart: () => state.startWorkout(plan)),
        if (plan.partnerName != null && !plan.isFinished) _PartnerConditionLine(plan: plan),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: plan.exercises.length,
          onReorderItem: (o, n) => state.reorderExercise(plan, o, n),
          proxyDecorator: (child, i, anim) => Material(color: Colors.transparent, elevation: 6, child: child),
          itemBuilder: (c, i) {
            final pe = plan.exercises[i];
            final sectionStart = i == 0 || SessionGenerator.sectionOf(pe) != SessionGenerator.sectionOf(plan.exercises[i - 1]);
            return Column(
              key: ObjectKey(pe),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sectionStart) _SectionLabel(SessionGenerator.sectionLabel(SessionGenerator.sectionOf(pe))),
                _ExerciseCard(plan: plan, pe: pe, index: i, editable: editable && !plan.isFinished, logging: logging && !plan.isFinished),
              ],
            );
          },
        ),
        if (editable && !plan.isFinished && plan.exercises.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2),
            child: Text('≡ 손잡이를 끌어 순서를 바꾸면 다음 루틴에도 그 순서가 반영돼요.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        if (editable && !plan.isFinished)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => addExerciseDialog(context, plan),
              icon: const Icon(Icons.add),
              label: Text(plan.partnerName != null ? '운동 추가 (나만 또는 같이)' : '운동 추가'),
            ),
          ),
        if (plan.exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '보유 기구로 할 수 있는 운동이 없습니다. 헬스장 탭에서 기구를 추가하세요.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 16),
        if (logging && !plan.isFinished && plan.exercises.isNotEmpty)
          FilledButton.icon(
            onPressed: () => _finish(context, state),
            icon: const Icon(Icons.flag),
            label: Text('운동 완료 (${(plan.completionRatio * 100).round()}%)'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        if (plan.isFinished)
          Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: cs.primary),
              const SizedBox(width: 8),
              Text('완료됨 · ${(plan.completionRatio * 100).round()}% 수행', style: text.titleMedium),
            ]),
            if (plan.actualMinutes != null)
              Text('실제 ${plan.actualMinutes}분 / 계획 ${plan.estimatedMinutes}분${plan.extraSetsDone > 0 ? ' · 추가 세트 ${plan.extraSetsDone}개' : ''}',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            if (plan.rpe != null)
              Text('체감 강도 ${plan.rpe}/10 · ${rpeLabel(plan.rpe!)}',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              FilledButton.tonalIcon(
                onPressed: () => shareWorkoutImage(context, plan, state.currentUser?.name ?? ''),
                icon: const Icon(Icons.image_outlined),
                label: const Text('완료 카드 이미지 공유'),
              ),
              if (logging)
                TextButton(
                  onPressed: () => state.reopenDay(plan),
                  child: const Text('다시 열기'),
                ),
            ]),
          ]),
      ],
    );
  }

  Future<void> _finish(BuildContext context, AppState state) async {
    final ratio = plan.completionRatio;
    if (ratio < 1.0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('아직 체크하지 않은 세트가 있어요'),
          content: Text('${(ratio * 100).round()}%만 완료했습니다. 지금 끝낼까요? 안 한 세트는 실패로 기록돼 다음 강도 조절에 반영됩니다.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('계속 운동')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('끝내기')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!context.mounted) return;
    final rpe = await showRpePicker(context);
    if (!context.mounted) return;
    final msgs = await state.finishDay(plan, rpe: rpe);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('수고했어요! 다음 루틴 반영'),
        content: SizedBox(
          width: double.maxFinite,
          child: msgs.isEmpty
              ? const Text('수행한 세트가 없어 강도는 그대로 유지됩니다.')
              : ListView(
                  shrinkWrap: true,
                  children: msgs
                      .map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('• $m'),
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(c);
              shareWorkoutImage(context, plan, state.currentUser?.name ?? '');
            },
            icon: const Icon(Icons.image_outlined),
            label: const Text('완료 카드 공유'),
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('확인')),
        ],
      ),
    );
  }
}

/// 파트너 무게에 파트너가 입력한 컨디션 배율을 곱한 값(기구 단위로 반올림).
double _partnerWeight(BuildContext context, DayPlan plan, PlannedExercise pe) {
  final base = plan.partnerWeights[pe.exerciseId]!;
  final pc = context.read<AppState>().partnerConditionOn(plan.date);
  if (pc == null || pc.load == 1.0) return base;
  final inc = exerciseById(pe.exerciseId)!.loadType.increment;
  return max(inc, LoadEstimator.roundTo(base * pc.load, inc));
}

/// 파트너가 그날 입력한 컨디션을 보여준다. 아직 없으면 안내.
class _PartnerConditionLine extends StatelessWidget {
  const _PartnerConditionLine({required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pc = context.watch<AppState>().partnerConditionOn(plan.date);
    final msg = pc == null
        ? '${plan.partnerName} 님은 아직 이 날 컨디션을 입력하지 않았어요. 입력하면 여기와 파트너 무게에 반영돼요.'
        : '${pc.name} 님 컨디션 ${pc.condition}/10 · 무게 ${(pc.load * 100).round()}% 로 운동해요. 아래 파트너 무게에 반영됨.';
    final link = context.read<AppState>().partners.where((p) => p.name == plan.partnerName && !p.pending).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.group, size: 16, color: cs.secondary),
          const SizedBox(width: 6),
          Expanded(child: Text(msg, style: text.bodySmall?.copyWith(color: cs.secondary))),
          if (link != null)
            IconButton(
              tooltip: '${link.display}와 채팅',
              icon: Icon(Icons.chat_bubble_outline, size: 18, color: cs.secondary),
              visualDensity: VisualDensity.compact,
              onPressed: () => PartnerChatScreen.open(context, link),
            ),
        ],
      ),
    );
  }
}

/// 오늘 갈 헬스장 바꾸기: 없는 기구의 운동은 비슷한 운동으로 대체된다.
Future<void> switchGymDialog(BuildContext context, DayPlan plan) async {
  final state = context.read<AppState>();
  final current = state.gymOf(plan);
  if (state.gyms.length < 2 && !plan.atOtherGym) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('헬스장이 하나뿐이에요. 헬스장 탭에서 다른 헬스장을 추가하면 날짜마다 고를 수 있어요.')));
    return;
  }
  final picked = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('이 날 갈 헬스장'),
      children: [
        for (final g in state.gyms)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, g.id),
            child: Row(children: [
              Icon(g.id == current?.id ? Icons.radio_button_checked : Icons.radio_button_off, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('${g.name} · 기구 ${g.equipment.length}개')),
            ]),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Text('없는 기구의 운동은 같은 부위의 비슷한 운동으로 바뀝니다. 세트·횟수 틀은 유지돼요.', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  final mode = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('루틴은 어떻게 할까요?'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(c, 'rebuild'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.auto_awesome),
            title: Text('이 헬스장 기구로 새로 짜기'),
            subtitle: Text('같은 부위로, 그 헬스장에만 있는 머신까지 후보로 다시 구성'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(c, 'swap'),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.swap_horiz),
            title: Text('지금 루틴 유지, 없는 기구만 대체'),
            subtitle: Text('짜둔 운동은 그대로 두고 그 헬스장에 없는 기구의 운동만 비슷한 운동으로'),
          ),
        ),
      ],
    ),
  );
  if (mode == null || !context.mounted) return;
  if (mode == 'rebuild') {
    await state.rebuildDayAtGym(plan, picked);
    if (context.mounted) {
      final name = state.gyms.firstWhere((g) => g.id == picked).name;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 기구로 같은 부위 루틴을 새로 짰어요.')));
    }
    return;
  }
  final msgs = await state.switchDayGym(plan, picked);
  if (!context.mounted) return;
  final gymName = state.gyms.firstWhere((g) => g.id == picked).name;
  if (msgs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$gymName 기준으로 설정. 바꿀 운동이 없어요.')));
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('$gymName 기준으로 조정'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: [for (final m in msgs) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• $m'))]),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('확인'))],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = context.watch<AppState>();
    final gym = state.gymOf(plan);
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.title ?? '운동',
                      style: text.titleLarge?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                ),
                if (!plan.isFinished)
                  IconButton(
                    tooltip: '부위 바꾸기',
                    icon: Icon(Icons.swap_horiz, color: cs.onPrimaryContainer),
                    onPressed: () => changeDayFocusDialog(context, plan),
                  ),
                if (plan.exercises.isNotEmpty)
                  IconButton(
                    tooltip: '루틴 공유 (파트너와 같은 운동)',
                    icon: Icon(Icons.share, color: cs.onPrimaryContainer),
                    onPressed: () => shareRoutine(context, plan),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final g in plan.focus)
                  Chip(label: Text(g.label), visualDensity: VisualDensity.compact),
                if (plan.atOtherGym || gym != null)
                  ActionChip(
                    avatar: Icon(Icons.place_outlined, size: 16, color: cs.primary),
                    label: Text(plan.atOtherGym ? '${plan.venueName} (파트너 헬스장)' : gym!.name),
                    visualDensity: VisualDensity.compact,
                    onPressed: plan.isFinished ? null : () => switchGymDialog(context, plan),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule, size: 16, color: cs.onPrimaryContainer),
              const SizedBox(width: 4),
              Text('예상 ${plan.estimatedMinutes}분 · ${plan.exercises.length}개 운동',
                  style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer)),
              if (plan.intensityFactor < 1.0) ...[
                const SizedBox(width: 10),
                Icon(Icons.battery_3_bar, size: 16, color: cs.onPrimaryContainer),
                Text(' 피로 누적 → 볼륨 ${(plan.intensityFactor * 100).round()}%',
                    style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
              ],
            ]),
            if (plan.condition != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.monitor_heart_outlined, size: 16, color: cs.onPrimaryContainer),
                  const SizedBox(width: 4),
                  Text('컨디션 ${plan.condition}/10 · 무게 ${(plan.loadFactor * 100).round()}%',
                      style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// 운동 시작 버튼과 경과 시간. 시작 전엔 버튼, 시작 후엔 경과/예상 시간 표시(30초마다 갱신).
class _WorkoutClock extends StatefulWidget {
  const _WorkoutClock({required this.plan, required this.onStart});
  final DayPlan plan;
  final VoidCallback onStart;

  @override
  State<_WorkoutClock> createState() => _WorkoutClockState();
}

class _WorkoutClockState extends State<_WorkoutClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = widget.plan;
    if (!p.isStarted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FilledButton.tonalIcon(
          onPressed: widget.onStart,
          icon: const Icon(Icons.play_arrow),
          label: Text('운동 시작 (예상 ${p.estimatedMinutes}분)'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      );
    }
    final elapsed = p.actualMinutes ?? 0;
    final over = p.estimatedMinutes > 0 && elapsed > p.estimatedMinutes;
    final start = p.startedAt!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(Icons.timer_outlined, size: 18, color: over ? cs.error : cs.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '경과 $elapsed분 / 예상 ${p.estimatedMinutes}분 · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} 시작'
            '${p.extraSetsDone > 0 ? ' · 추가 세트 ${p.extraSetsDone}' : ''}',
            style: text.bodyMedium?.copyWith(color: over ? cs.error : cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '시작 시각',
          icon: Icon(Icons.more_horiz, size: 18, color: cs.onSurfaceVariant),
          onSelected: (v) => context.read<AppState>().cancelWorkoutStart(p, resetToNow: v == 'now'),
          itemBuilder: (_) => [
            if (!p.exercises.any((e) => e.anyCompleted)) const PopupMenuItem(value: 'cancel', child: Text('시작 취소 (잘못 눌렀어요)')),
            const PopupMenuItem(value: 'now', child: Text('시작 시각을 지금으로')),
          ],
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
      child: Row(children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ]),
    );
  }
}

/// 운동에 쓸 수 있는 기구가 여러 종류일 때 어떤 기구를 헬스장에 추가할지 고른다.
Future<EquipmentType?> _pickEquipmentType(BuildContext context, Exercise e) => showDialog<EquipmentType>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('${e.name} · 어떤 기구를 추가할까요?'),
        children: [
          for (final t in e.equipment)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, t), child: Text(t.label)),
        ],
      ),
    );

/// 운동 추가: 보유 기구로 가능한 운동을 부위별로 검색해서 고른다.
Future<void> addExerciseDialog(BuildContext context, DayPlan plan) async {
  final state = context.read<AppState>();
  // 이 다이얼로그에서 '기구 추가'로 넣은 기구(운동 id → 기구 id). 다시 누르면 취소.
  final addedEquip = <String, String>{};
  final dayGym = plan.atOtherGym ? null : state.gymOf(plan);
  var query = '';
  MuscleGroup? group;
  var personal = plan.partnerName != null;
  final picked = await showAppSheet<(Exercise, bool)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => StatefulBuilder(builder: (c, setState) {
      final available = state.availableFor(plan);
      final list = exerciseCatalog
          .where((e) => group == null || e.group == group)
          .where((e) => query.isEmpty || e.name.toLowerCase().contains(query.toLowerCase()) || e.emphasis.any((m) => m.contains(query)))
          .toList()
        ..sort((a, b) {
          final ca = a.canDoWith(available) ? 0 : 1, cb = b.canDoWith(available) ? 0 : 1;
          return ca != cb ? ca - cb : b.priority - a.priority;
        });
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (c, ctrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '운동 이름·부위 검색'),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: const Text('전체'), selected: group == null, onSelected: (_) => setState(() => group = null)),
              ),
              for (final g in MuscleGroup.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(g.label), selected: group == g, onSelected: (_) => setState(() => group = g)),
                ),
            ]),
          ),
          if (plan.partnerName != null)
            SwitchListTile(
              dense: true,
              value: personal,
              title: const Text('나만 하는 운동'),
              subtitle: Text(personal ? '${plan.partnerName}에게 보내지 않고 내 루틴에만 추가' : '${plan.partnerName}의 루틴에도 같이 추가'),
              onChanged: (v) => setState(() => personal = v),
            ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: list.length,
              itemBuilder: (c, i) {
                final e = list[i];
                final can = e.canDoWith(available);
                final added = addedEquip.containsKey(e.id);
                Widget? trailing = e.compound ? const Icon(Icons.fitness_center, size: 16) : null;
                if ((!can || added) && dayGym != null) {
                  trailing = added
                      ? FilledButton.tonalIcon(
                          onPressed: () async {
                            await state.removeEquipment(dayGym.id, addedEquip.remove(e.id)!);
                            setState(() {});
                          },
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('추가 취소'),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        )
                      : OutlinedButton.icon(
                          onPressed: () async {
                            final type = e.equipment.length == 1 ? e.equipment.first : await _pickEquipmentType(c, e);
                            if (type == null) return;
                            final id = await state.addEquipmentReturningId(dayGym.id, type);
                            if (id != null) setState(() => addedEquip[e.id] = id);
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('기구 추가'),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        );
                }
                return ListTile(
                  dense: true,
                  enabled: can,
                  title: Text(e.name, style: can ? null : TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
                  subtitle: Text(
                    '${e.group.label} · ${e.emphasis.take(2).join(' · ')}${can ? (added ? ' · ${dayGym?.name ?? ''}에 기구 추가됨' : '') : ' · 보유 기구 없음'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: trailing,
                  onTap: can ? () => Navigator.pop(c, (e, personal)) : null,
                );
              },
            ),
          ),
        ]),
      );
    }),
  );
  if (picked == null || !context.mounted) return;
  await state.addExercise(plan, picked.$1, personal: picked.$2);
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.plan, required this.pe, required this.index, required this.editable, required this.logging});
  final DayPlan plan;
  final PlannedExercise pe;
  final int index;
  final bool editable;
  final bool logging;

  @override
  Widget build(BuildContext context) {
    final ex = exerciseById(pe.exerciseId);
    if (ex == null) return const SizedBox.shrink();
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isCardio = ex.loadType == LoadType.cardio;
    final isBw = ex.loadType == LoadType.bodyweight;
    final unit = isCardio ? '분' : (ex.id == 'plank' ? '초' : '회');
    final myEq = state.equipmentFor(plan, pe.equipmentType);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => ExerciseSheet.show(context, ex, pe.equipmentType),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: myEq != null
                        ? EquipmentThumb(eq: myEq, size: 48)
                        : SizedBox(
                            width: 48,
                            height: 48,
                            child: Equipment3DView(type: pe.equipmentType, height: 48, autoRotate: false),
                          ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => ExerciseSheet.show(context, ex, pe.equipmentType),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Row(children: [
                          Icon(isBw ? Icons.accessibility_new : Icons.fitness_center, size: 14, color: cs.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              state.equipmentLabelFor(plan, pe.equipmentType),
                              style: text.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                        Text('${pe.effectiveGroup.label}${pe.groupOverride != null ? '(타깃 변경)' : ''}${pe.restSeconds > 0 ? ' · 휴식 ${pe.restSeconds}초' : ''}${myEq != null && myEq.displayName != pe.equipmentType.label ? ' · ${pe.equipmentType.label}' : ''}',
                            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        if (pe.note != null && pe.note!.isNotEmpty)
                          Text(pe.note!, style: text.bodySmall?.copyWith(color: pe.personal ? cs.secondary : cs.tertiary)),
                        if (plan.partnerName != null && plan.partnerWeights.containsKey(pe.exerciseId) && !isCardio)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(children: [
                              Icon(Icons.group, size: 14, color: cs.secondary),
                              const SizedBox(width: 4),
                              Text(
                                isBw
                                    ? '${plan.partnerName}: 같은 횟수'
                                    : '${plan.partnerName}: ${_fmt(_partnerWeight(context, plan, pe))}kg',
                                style: text.bodySmall?.copyWith(color: cs.secondary, fontWeight: FontWeight.w600),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
                if (editable)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
                    ),
                  ),
                if (editable)
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'swap':
                          await _swap(context, state, ex);
                        case 'add':
                          await state.addSet(plan, pe);
                        case 'removeSet':
                          await state.removeSet(plan, pe);
                        case 'remove':
                          await state.removeExercise(plan, pe);
                        case 'up':
                          await state.moveExercise(plan, pe, -1);
                        case 'down':
                          await state.moveExercise(plan, pe, 1);
                        default:
                          if (v.startsWith('target:')) {
                            final g = v.substring(7);
                            await state.setExerciseTarget(plan, pe, g == ex.group.name ? null : MuscleGroup.parse(g));
                          }
                      }
                    },
                    itemBuilder: (_) => [
                      if (ex.altGroups.isNotEmpty)
                        for (final g in [ex.group, ...ex.altGroups])
                          PopupMenuItem(
                            value: 'target:${g.name}',
                            child: Text('${pe.effectiveGroup == g ? '✓ ' : ''}타깃: ${g.label}'),
                          ),
                      const PopupMenuItem(value: 'up', child: Text('↑ 위로')),
                      const PopupMenuItem(value: 'down', child: Text('↓ 아래로')),
                      PopupMenuItem(value: 'swap', child: Text('다른 운동으로 교체')),
                      PopupMenuItem(value: 'remove', child: Text('이 운동 제외')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < pe.sets.length; i++)
              _SetRow(
                index: i,
                set: pe.sets[i],
                unit: unit,
                showWeight: !isCardio && !isBw,
                levelText: isCardio && pe.sets[i].effectiveLevel != null && cardioLevels[ex.id] != null
                    ? cardioLevels[ex.id]!.format(pe.sets[i].effectiveLevel!)
                    : null,
                editable: logging,
                onToggle: () async {
                  await state.toggleSet(plan, pe, i);
                  if (pe.sets[i].completed && pe.restSeconds > 0 && i < pe.sets.length - 1 && context.mounted) {
                    RestTimerSheet.show(context, pe.restSeconds);
                  }
                },
                onEdit: () => _editSet(context, state, i, unit, !isCardio && !isBw),
              ),
            if ((editable || logging) && !isCardio)
              Row(children: [
                TextButton.icon(
                  onPressed: pe.sets.length > 1 ? () => state.removeSet(plan, pe) : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('세트 빼기'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
                TextButton.icon(
                  onPressed: () => state.addSet(plan, pe),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('세트 추가'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Future<void> _editSet(BuildContext context, AppState state, int i, String unit, bool showWeight) async {
    final s = pe.sets[i];
    final ex = exerciseById(pe.exerciseId);
    final spec = ex == null ? null : cardioLevels[ex.id];
    final result = await SetEditorSheet.show(
      context,
      title: '${ex?.name ?? ''} ${i + 1}세트 실제 수행',
      targetReps: s.targetReps,
      targetWeight: s.targetWeight,
      initialReps: s.effectiveReps,
      initialWeight: s.effectiveWeight,
      weightStep: ex?.loadType.increment ?? 2.5,
      unit: unit,
      showWeight: showWeight,
      levelSpec: spec,
      initialLevel: s.effectiveLevel,
    );
    if (result != null) {
      await state.updateSet(plan, pe, i,
          reps: result.$1, weight: showWeight ? result.$2 : null, level: result.$3); // 완료 체크는 체크박스로만
    }
  }

  Future<void> _swap(BuildContext context, AppState state, Exercise ex) async {
    final options = exercisesOf(ex.group)
        .where((e) => e.id != ex.id && e.canDoWith(state.availableEquipment))
        .toList();
    final chosen = await showAppSheet<Exercise>(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${ex.group.label} 운동으로 교체', style: Theme.of(c).textTheme.titleMedium),
          ),
          for (final e in options)
            ListTile(
              title: Text(e.name),
              subtitle: Text(e.emphasis.join(' · ')),
              trailing: Text(e.pickEquipment(state.availableEquipment).label,
                  style: Theme.of(c).textTheme.bodySmall),
              onTap: () => Navigator.pop(c, e),
            ),
          if (options.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('교체 가능한 운동이 없습니다.')),
        ],
      ),
    );
    if (chosen != null) await state.swapExercise(plan, pe, chosen);
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.set,
    required this.unit,
    required this.showWeight,
    required this.editable,
    required this.onToggle,
    required this.onEdit,
    this.levelText,
  });

  final int index;
  final SetEntry set;
  final String unit;
  final bool showWeight;
  final bool editable;

  /// 유산소 강도 표시(예: '레벨 8').
  final String? levelText;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final changed = (set.doneReps != null && set.doneReps != set.targetReps) ||
        (set.doneWeight != null && set.doneWeight != set.targetWeight);
    final up = changed &&
        (set.effectiveReps > set.targetReps || set.effectiveWeight > set.targetWeight);

    return InkWell(
      onTap: editable ? onToggle : null,
      onLongPress: editable ? onEdit : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(value: set.completed, onChanged: editable ? (_) => onToggle() : null),
            Text('${index + 1}세트', style: text.bodyMedium),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${showWeight ? '${_fmt(set.effectiveWeight)}kg × ' : ''}${set.effectiveReps}$unit${levelText != null ? ' · $levelText' : ''}',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: set.completed ? TextDecoration.lineThrough : null,
                  color: set.completed ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
            ),
            if (changed)
              Icon(up ? Icons.trending_up : Icons.trending_down,
                  size: 18, color: up ? cs.primary : cs.error),
            if (editable)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: '실제 수행 입력',
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}

String _fmt(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

/// 오늘의 명언 배너.
class QuoteBanner extends StatelessWidget {
  const QuoteBanner({super.key, required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote, size: 18, color: cs.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(quote,
                style: text.bodyMedium?.copyWith(color: cs.onTertiaryContainer, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}
