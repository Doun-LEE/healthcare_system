import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../engine/load_estimator.dart';
import '../engine/splits.dart';
import '../engine/session_generator.dart';
import '../models/models.dart';
import 'widgets/level_card.dart';
import '../state/app_state.dart';
import 'widgets/account_sheet.dart';
import 'widgets/partner_widgets.dart';
import 'widgets/version_section.dart';

/// 신체 스펙·인바디 스캔·분할/시간 설정·API 키·접근 코드·로그아웃.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final u = state.currentUser!;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final est = LoadEstimator(u);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.myHandle == null ? u.name : '${u.name}  ·  ${state.myHandle}'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: state.logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 통계
          Row(children: [
            _Stat(label: '완료 세션', value: '${state.completedSessions}'),
            _Stat(label: '연속 주', value: '${state.currentStreakWeeks}주'),
            _Stat(label: '숙련도', value: u.level.label),
          ]),
          const SizedBox(height: 16),

          // 신체 스펙
          _Section(title: '신체 스펙', children: [
            SegmentedButton<Sex>(
              segments: Sex.values.map((s) => ButtonSegment(value: s, label: Text(s.label))).toList(),
              selected: {u.sex},
              onSelectionChanged: (s) => _edit(state, (p) => p.sex = s.first),
            ),
            const SizedBox(height: 8),
            _NumField(label: '키 (cm)', value: u.heightCm, onChanged: (v) => _edit(state, (p) => p.heightCm = v)),
            _NumField(label: '체중 (kg)', value: u.weightKg, onChanged: (v) => _edit(state, (p) => p.weightKg = v)),
            _NumField(label: '나이', value: u.age.toDouble(), integer: true, onChanged: (v) => _edit(state, (p) => p.age = v.round())),
            _NumField(label: '골격근량 (kg, 인바디)', value: u.skeletalMuscleKg, onChanged: (v) => _edit(state, (p) => p.skeletalMuscleKg = v)),
            _NumField(label: '체지방률 (%, 인바디)', value: u.bodyFatPct, onChanged: (v) => _edit(state, (p) => p.bodyFatPct = v)),
            const SizedBox(height: 14),
            Text('3대 기록 (kg, 1RM 또는 최고 중량 · 선택)', style: text.labelLarge),
            Text('입력하면 추정 대신 이 값으로 무게를 계산하고, 레벨 판정에도 쓰입니다. 비우면 신체 스펙으로 추정.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _NumField(label: '스쿼트', value: u.squat1rm, onChanged: (v) => _edit(state, (p) => p.squat1rm = v > 0 ? v : null))),
              const SizedBox(width: 8),
              Expanded(child: _NumField(label: '벤치', value: u.bench1rm, onChanged: (v) => _edit(state, (p) => p.bench1rm = v > 0 ? v : null))),
            ]),
            Row(children: [
              Expanded(child: _NumField(label: '데드리프트', value: u.deadlift1rm, onChanged: (v) => _edit(state, (p) => p.deadlift1rm = v > 0 ? v : null))),
              const SizedBox(width: 8),
              Expanded(child: _NumField(label: 'OHP', value: u.ohp1rm, onChanged: (v) => _edit(state, (p) => p.ohp1rm = v > 0 ? v : null))),
            ]),
            if (u.squat1rm != null || u.bench1rm != null || u.deadlift1rm != null)
              Text('3대 합계: ${((u.squat1rm ?? 0) + (u.bench1rm ?? 0) + (u.deadlift1rm ?? 0)).round()}kg',
                  style: text.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Text('레벨 판정', style: text.labelLarge),
            Text('키·체중·나이·성별·골격근·체지방·3대 기록으로 리프트별·체성분별 등급을 매기고 종합 레벨을 정합니다.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            LevelCard(profile: u),
            SwitchListTile(
              value: u.levelAuto,
              contentPadding: EdgeInsets.zero,
              title: const Text('숙련도 자동 판정'),
              subtitle: Text(u.levelAuto ? '판정 결과에 따라 루틴 강도(세트·횟수·무게)를 적용합니다.' : '아래에서 직접 고른 숙련도를 씁니다.'),
              onChanged: (v) => _edit(state, (p) => p.levelAuto = v),
            ),
            if (!u.levelAuto)
              SegmentedButton<TrainingLevel>(
                segments: TrainingLevel.values.map((l) => ButtonSegment(value: l, label: Text(l.label))).toList(),
                selected: {u.level},
                onSelectionChanged: (s) => _edit(state, (p) => p.level = s.first),
              ),
            const SizedBox(height: 14),
            Text('운동 목표', style: text.labelLarge),
            SegmentedButton<TrainingGoal>(
              segments: TrainingGoal.values.map((g) => ButtonSegment(value: g, label: Text(g.label))).toList(),
              selected: {u.goal},
              onSelectionChanged: (s) => _edit(state, (p) => p.goal = s.first),
            ),
            Text(u.goal.description, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Text('부상 · 주의 부위', style: text.labelLarge),
            Text('체크한 부위에 부담 가는 운동은 루틴에서 자동으로 뺍니다.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in InjuryArea.values)
                  FilterChip(
                    label: Text(a.label),
                    selected: u.injuries.contains(a),
                    onSelected: (on) => _edit(state, (p) => on ? p.injuries.add(a) : p.injuries.remove(a)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('무게 계산 기준 1RM', style: text.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    '스쿼트 ${est.oneRepMax(RefLift.squat).round()}kg${u.squat1rm != null ? '(실제)' : ''} · 벤치 ${est.oneRepMax(RefLift.bench).round()}kg${u.bench1rm != null ? '(실제)' : ''} · 데드 ${est.oneRepMax(RefLift.deadlift).round()}kg${u.deadlift1rm != null ? '(실제)' : ''} · OHP ${est.oneRepMax(RefLift.ohp).round()}kg${u.ohp1rm != null ? '(실제)' : ''}',
                    style: text.bodyMedium,
                  ),
                  Text('근육 보정 ×${est.muscleFactor.toStringAsFixed(2)} · 체지방 보정 ×${est.fatFactor.toStringAsFixed(2)}. 실제 수행 결과로 매 세션 자동 보정됩니다.',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await state.recalibrateFuture();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('미래 계획의 무게를 다시 추정했어요.')));
                }
              },
              icon: const Icon(Icons.tune),
              label: const Text('스펙 변경을 미래 루틴에 반영'),
            ),
          ]),

          // 루틴 설정
          _Section(title: '루틴 설정', children: [
            Text('분할', style: text.labelLarge),
            const SizedBox(height: 4),
            RadioGroup<int>(
              groupValue: u.splitDays,
              onChanged: (v) => _edit(state, (p) => p.splitDays = v ?? p.splitDays),
              child: Column(
                children: [
                  for (final t in splitTemplates)
                    RadioListTile<int>(
                      value: t.days,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.name),
                      subtitle: Text(t.description),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('하루 운동 시간: ${u.sessionMinutes}분${u.volumeBias != 1.0 ? ' · 볼륨 보정 ${(u.volumeBias * 100).round()}%' : ''}', style: text.labelLarge),
            if (u.volumeBias != 1.0)
              Row(children: [
                Expanded(
                  child: Text(
                    '운동 완료 때 계획보다 ${u.volumeBias > 1 ? '더' : '덜'} 수행해서 루틴 볼륨을 ${u.volumeBias > 1 ? '늘려' : '줄여'} 짭니다.',
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                TextButton(onPressed: () => _edit(state, (p) => p.volumeBias = 1.0), child: const Text('초기화')),
              ]),
            Slider(
              value: u.sessionMinutes.toDouble(),
              min: 30,
              max: 150,
              divisions: 12,
              label: '${u.sessionMinutes}분',
              onChanged: (v) => _edit(state, (p) => p.sessionMinutes = v.round()),
            ),
            SwitchListTile(
              value: u.includeCardio,
              contentPadding: EdgeInsets.zero,
              title: const Text('유산소 포함'),
              subtitle: const Text('하체 날을 제외하고 세션에 10~20분 추가'),
              onChanged: (v) => _edit(state, (p) => p.includeCardio = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('하루 시작 시각', style: text.labelLarge),
                  Text('이 시각 전에 하는 운동은 전날 운동으로 봐요. 밤샘·야간 근무면 늦게 잡으세요. 시작한 운동은 끝낼 때까지 그 날 운동으로 남아요.',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: u.dayStartHour.clamp(0, 12),
                items: [
                  for (var h = 0; h <= 12; h++)
                    DropdownMenuItem(value: h, child: Text(h == 0 ? '자정' : (h < 12 ? '새벽·오전 $h시' : '정오'))),
                ],
                onChanged: (v) => _edit(state, (p) => p.dayStartHour = v ?? p.dayStartHour),
              ),
            ]),
            const SizedBox(height: 12),
            Text('갑자기 쉬게 되면', style: text.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'shift', label: Text('루틴 뒤로 밀기')),
                ButtonSegment(value: 'keep', label: Text('루틴 그대로')),
              ],
              selected: {u.restMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _edit(state, (p) => p.restMode = s.first),
            ),
            Text(
              u.restMode == 'keep'
                  ? '쉬거나 못 간 날은 그 날만 "휴식"으로 표시하고, 날짜별로 정해진 루틴(예: 금요일 하체)은 그대로 둡니다.'
                  : '쉬거나 못 간 날의 부위가 빠지지 않게, 이후 루틴을 하루씩 뒤로 밀어 다시 맞춥니다.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text('운동 구역 순서', style: text.labelLarge),
            Text('손잡이를 끌어 하루 루틴에서 어떤 구역을 먼저 할지 정합니다.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (o, n) => _edit(state, (p) {
                final list = List.of(p.sectionOrder);
                final item = list.removeAt(o);
                list.insert(n, item);
                p.sectionOrder = list;
              }),
              children: [
                for (var i = 0; i < u.sectionOrder.length; i++)
                  ListTile(
                    key: ValueKey(u.sectionOrder[i]),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                    title: Text(SessionGenerator.sectionLabel(u.sectionOrder[i])),
                    trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '웨이트 구역 안은 처음엔 복합운동(고중량) → 고립운동 순서로 짜고, 루틴에서 직접 순서를 바꾸면 그 순서를 기억해 다음 루틴에도 반영합니다.'
              '${u.exerciseRank.isNotEmpty ? ' 현재 ${u.exerciseRank.length}개 운동의 순서를 학습했어요.' : ''}',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (u.exerciseRank.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => state.resetOrderLearning(), child: const Text('학습한 순서 초기화')),
              ),
          ]),

          // 계정
          const _Section(title: '계정 · 동기화', children: [AccountSection()]),

          // 파트너
          const _Section(title: '운동 파트너', children: [PartnerSection()]),

          // 앱 정보 / 업데이트
          const _Section(title: '앱 정보', children: [VersionSection()]),

          // 보안/연동
          _Section(title: '보안 · 연동', children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock),
              title: const Text('접근 코드 변경'),
              subtitle: const Text('로그인 시 입력하는 숫자 코드'),
              onTap: () async {
                final v = await _promptText(context, '새 접근 코드 (4자 이상)', '', obscure: true);
                if (v != null && v.trim().length >= 4) await state.setAccessCode(v);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_forever, color: cs.error),
              title: Text('이 프로필 삭제', style: TextStyle(color: cs.error)),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('프로필을 삭제할까요?'),
                    content: const Text('계획과 기록이 모두 삭제되며 복구할 수 없습니다.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
                    ],
                  ),
                );
                if (ok == true) await state.deleteProfile(u.id);
              },
            ),
          ]),
        ],
      ),
    );
  }

  void _edit(AppState state, void Function(UserProfile) f) => state.updateProfile(f);
}

Future<String?> _promptText(BuildContext context, String title, String hint, {bool obscure = false}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, obscureText: obscure, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('저장')),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        color: cs.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

/// 포커스를 잃을 때 저장하는 숫자 입력.
class _NumField extends StatefulWidget {
  const _NumField({required this.label, required this.value, required this.onChanged, this.integer = false});
  final String label;
  final double? value;
  final bool integer;
  final void Function(double) onChanged;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _c;
  final _focus = FocusNode();

  String _fmt(double? v) => v == null ? '' : (widget.integer ? v.round().toString() : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1)));

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _fmt(widget.value));
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _c.text = _fmt(widget.value);
  }

  void _commit() {
    final v = double.tryParse(_c.text);
    if (v != null && v != widget.value) widget.onChanged(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: _c,
          focusNode: _focus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: widget.label, isDense: true),
          onSubmitted: (_) => _commit(),
        ),
      );
}
