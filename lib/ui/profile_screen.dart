import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../engine/load_estimator.dart';
import '../engine/splits.dart';
import '../models/models.dart';
import '../services/inbody_scanner.dart';
import '../state/app_state.dart';
import 'widgets/account_sheet.dart';

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
        title: Text(u.name),
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

          // 인바디
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.document_scanner_outlined, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('인바디 결과지 스캔', style: text.titleMedium),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    u.inbodyScannedAt == null
                        ? '결과지 사진을 찍으면 체중·골격근량·체지방률을 읽어 무게/세트/횟수를 자동 설정합니다.'
                        : '마지막 스캔: ${u.inbodyScannedAt!.month}/${u.inbodyScannedAt!.day} · 골격근 ${u.skeletalMuscleKg?.toStringAsFixed(1) ?? '-'}kg · 체지방 ${u.bodyFatPct?.toStringAsFixed(1) ?? '-'}%',
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _scan(context, state, ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('카메라'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _scan(context, state, ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('앨범'),
                      ),
                    ),
                  ]),
                  if (state.data.apiKey.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('※ 아래 "Claude API 키"를 먼저 입력해야 사진 분석이 됩니다. 키가 없어도 수치를 직접 입력하면 동일하게 자동 설정됩니다.',
                          style: text.bodySmall?.copyWith(color: cs.error)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

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
            const SizedBox(height: 8),
            Text('숙련도', style: text.labelLarge),
            SegmentedButton<TrainingLevel>(
              segments: TrainingLevel.values.map((l) => ButtonSegment(value: l, label: Text(l.label))).toList(),
              selected: {u.level},
              onSelectionChanged: (s) => _edit(state, (p) => p.level = s.first),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('추정 1RM (출발점)', style: text.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    '스쿼트 ${est.oneRepMax(RefLift.squat).round()}kg · 벤치 ${est.oneRepMax(RefLift.bench).round()}kg · 데드 ${est.oneRepMax(RefLift.deadlift).round()}kg · OHP ${est.oneRepMax(RefLift.ohp).round()}kg',
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
            Text('하루 운동 시간: ${u.sessionMinutes}분', style: text.labelLarge),
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
              subtitle: const Text('하체 날을 제외하고 세션 끝에 10~20분 추가'),
              onChanged: (v) => _edit(state, (p) => p.includeCardio = v),
            ),
          ]),

          // 계정
          const _Section(title: '계정 · 동기화', children: [AccountSection()]),

          // 보안/연동
          _Section(title: '보안 · 연동', children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.key),
              title: const Text('Claude API 키'),
              subtitle: Text(state.data.apiKey.isEmpty ? '미설정 (인바디 사진 분석에 필요)' : '설정됨 ···${state.data.apiKey.characters.takeLast(4)}'),
              onTap: () async {
                final v = await _promptText(context, 'Claude API 키', 'sk-ant-...', obscure: true);
                if (v != null) await state.setApiKey(v);
              },
            ),
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

  Future<void> _scan(BuildContext context, AppState state, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사진을 불러오지 못했어요: $e')));
      }
      return;
    }
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('결과지를 분석하고 있어요…')),
        ]),
      ),
    );
    InBodyResult? result;
    String? error;
    try {
      result = await state.scanInBody(bytes);
    } on InBodyScanException catch (e) {
      error = e.message;
    } catch (e) {
      error = '알 수 없는 오류: $e';
    }
    if (!context.mounted) return;
    Navigator.pop(context);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final r = result!;
    final apply = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('인바디 결과 반영됨'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.weightKg != null) Text('체중 ${r.weightKg!.toStringAsFixed(1)}kg'),
            if (r.skeletalMuscleKg != null) Text('골격근량 ${r.skeletalMuscleKg!.toStringAsFixed(1)}kg'),
            if (r.bodyFatPct != null) Text('체지방률 ${r.bodyFatPct!.toStringAsFixed(1)}%'),
            if (r.heightCm != null) Text('신장 ${r.heightCm!.toStringAsFixed(1)}cm'),
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.notes, style: Theme.of(c).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            const Text('아직 하지 않은 미래 루틴의 무게를 새 스펙으로 다시 추정할까요?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('나중에')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('다시 추정')),
        ],
      ),
    );
    if (apply == true) await state.recalibrateFuture();
  }
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
