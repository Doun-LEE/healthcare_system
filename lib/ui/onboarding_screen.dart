import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/level_assessor.dart';
import '../engine/splits.dart';
import '../models/models.dart';
import '../state/app_state.dart';

/// 처음 계정을 만들었을 때 홈 전에 보여주는 초기 설정.
/// 기본 정보 → 인바디·3대 기록 → 목표·루틴. 모든 항목은 건너뛸 수 있고 나중에 내 정보에서 바꿀 수 있다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;

  // 1단계
  Sex _sex = Sex.male;
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _age = TextEditingController();
  // 2단계
  final _smm = TextEditingController();
  final _fat = TextEditingController();
  final _squat = TextEditingController();
  final _bench = TextEditingController();
  final _dead = TextEditingController();
  final _ohp = TextEditingController();
  // 3단계
  TrainingGoal _goal = TrainingGoal.hypertrophy;
  int _split = 3;
  double _minutes = 90;
  bool _cardio = true;
  final _injuries = <InjuryArea>{};

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().currentUser;
    if (u != null) {
      _sex = u.sex;
      _goal = u.goal;
      _split = u.splitDays;
      _minutes = u.sessionMinutes.toDouble().clamp(30, 150);
      _cardio = u.includeCardio;
      _injuries.addAll(u.injuries);
    }
  }

  @override
  void dispose() {
    for (final c in [_height, _weight, _age, _smm, _fat, _squat, _bench, _dead, _ohp]) {
      c.dispose();
    }
    _page.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null || v <= 0 ? null : v;
  }

  Future<void> _finish({bool skipped = false}) async {
    final state = context.read<AppState>();
    await state.updateProfile((p) {
      if (!skipped) {
        p.sex = _sex;
        p.heightCm = _num(_height) ?? p.heightCm;
        p.weightKg = _num(_weight) ?? p.weightKg;
        p.age = _num(_age)?.round() ?? p.age;
        p.skeletalMuscleKg = _num(_smm) ?? p.skeletalMuscleKg;
        p.bodyFatPct = _num(_fat) ?? p.bodyFatPct;
        p.squat1rm = _num(_squat) ?? p.squat1rm;
        p.bench1rm = _num(_bench) ?? p.bench1rm;
        p.deadlift1rm = _num(_dead) ?? p.deadlift1rm;
        p.ohp1rm = _num(_ohp) ?? p.ohp1rm;
        p.goal = _goal;
        p.splitDays = _split;
        p.sessionMinutes = _minutes.round();
        p.includeCardio = _cardio;
        p.injuries
          ..clear()
          ..addAll(_injuries);
      }
      p.onboarded = true;
    });
  }

  void _next() {
    if (_step >= 2) {
      _finish();
      return;
    }
    FocusScope.of(context).unfocus();
    _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = context.watch<AppState>().currentUser?.name ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text('시작하기 ${_step + 1}/3'),
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              ),
        actions: [
          TextButton(onPressed: () => _finish(skipped: true), child: const Text('전체 건너뛰기')),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          LinearProgressIndicator(value: (_step + 1) / 3),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                _Page(
                  title: '$name님, 반가워요',
                  subtitle: '무게·세트·횟수를 몸에 맞게 짜려고 물어봐요. 모르면 비워두고 다음으로 가도 돼요.',
                  children: [
                    SegmentedButton<Sex>(
                      segments: Sex.values.map((s) => ButtonSegment(value: s, label: Text(s.label))).toList(),
                      selected: {_sex},
                      onSelectionChanged: (s) => setState(() => _sex = s.first),
                    ),
                    const SizedBox(height: 12),
                    _Num(controller: _height, label: '키 (cm)', hint: '예: 175'),
                    _Num(controller: _weight, label: '체중 (kg)', hint: '예: 72'),
                    _Num(controller: _age, label: '나이', hint: '예: 28', integer: true),
                  ],
                ),
                _Page(
                  title: '인바디·3대 기록',
                  subtitle: '있으면 추정 대신 이 값으로 무게를 잡고 레벨을 판정해요. 모르는 칸은 비워두세요.',
                  children: [
                    Row(children: [
                      Expanded(child: _Num(controller: _smm, label: '골격근량 (kg)')),
                      const SizedBox(width: 8),
                      Expanded(child: _Num(controller: _fat, label: '체지방률 (%)')),
                    ]),
                    const SizedBox(height: 8),
                    Text('3대 기록 (1RM 또는 최고 중량)', style: text.labelLarge),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: _Num(controller: _squat, label: '스쿼트')),
                      const SizedBox(width: 8),
                      Expanded(child: _Num(controller: _bench, label: '벤치')),
                    ]),
                    Row(children: [
                      Expanded(child: _Num(controller: _dead, label: '데드리프트')),
                      const SizedBox(width: 8),
                      Expanded(child: _Num(controller: _ohp, label: 'OHP')),
                    ]),
                    Builder(builder: (c) {
                      final preview = UserProfile(
                        id: 'p',
                        name: '',
                        sex: _sex,
                        weightKg: _num(_weight) ?? 70,
                        age: _num(_age)?.round() ?? 28,
                        skeletalMuscleKg: _num(_smm),
                        bodyFatPct: _num(_fat),
                        squat1rm: _num(_squat),
                        bench1rm: _num(_bench),
                        deadlift1rm: _num(_dead),
                        ohp1rm: _num(_ohp),
                      );
                      final a = LevelAssessor.assess(preview);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          a.hasData ? '예상 레벨: ${a.grade!.label} (${a.score!.round()}점)' : '입력하면 예상 레벨이 여기 보여요.',
                          style: text.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                        ),
                      );
                    }),
                  ],
                ),
                _Page(
                  title: '목표와 루틴',
                  subtitle: '나중에 내 정보에서 언제든 바꿀 수 있어요.',
                  children: [
                    Text('운동 목표', style: text.labelLarge),
                    const SizedBox(height: 4),
                    SegmentedButton<TrainingGoal>(
                      segments: TrainingGoal.values.map((g) => ButtonSegment(value: g, label: Text(g.label))).toList(),
                      selected: {_goal},
                      onSelectionChanged: (s) => setState(() => _goal = s.first),
                    ),
                    Text(_goal.description, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Text('분할', style: text.labelLarge),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final t in splitTemplates)
                        ChoiceChip(label: Text(t.name), selected: _split == t.days, onSelected: (_) => setState(() => _split = t.days)),
                    ]),
                    Text(splitTemplates.firstWhere((t) => t.days == _split).description,
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Text('하루 운동 시간: ${_minutes.round()}분', style: text.labelLarge),
                    Slider(value: _minutes, min: 30, max: 150, divisions: 12, label: '${_minutes.round()}분', onChanged: (v) => setState(() => _minutes = v)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _cardio,
                      title: const Text('유산소 포함'),
                      onChanged: (v) => setState(() => _cardio = v),
                    ),
                    Text('부상·주의 부위 (해당 운동 제외)', style: text.labelLarge),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final i in InjuryArea.values)
                        FilterChip(
                          label: Text(i.label),
                          selected: _injuries.contains(i),
                          onSelected: (v) => setState(() => v ? _injuries.add(i) : _injuries.remove(i)),
                        ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              TextButton(onPressed: _next, child: Text(_step == 2 ? '건너뛰고 시작' : '건너뛰기')),
              const Spacer(),
              FilledButton.icon(
                onPressed: _next,
                icon: Icon(_step == 2 ? Icons.check : Icons.arrow_forward),
                label: Text(_step == 2 ? '시작하기' : '다음'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.subtitle, required this.children});
  final String title, subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(subtitle, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        ...children,
      ],
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({required this.controller, required this.label, this.hint, this.integer = false});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool integer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !integer),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
        ),
      );
}
