import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/catalog.dart';
import '../../models/models.dart';
import '../../services/ai_coach.dart';
import '../../services/workout_photo.dart';
import '../../services/workout_text_parser.dart';
import '../../state/app_state.dart';
import 'app_sheet.dart';

/// 워치·러닝 앱 기록 캡처를 골라 읽고, 확인 뒤 그날 유산소 기록으로 넣는 시트.
/// [target]이 있으면 그 운동(이미 루틴에 있는 축구 등)에 기록을 채우고, 없으면 새 운동으로 추가한다.
class WorkoutPhotoSheet {
  static Future<void> show(BuildContext context, DayPlan plan, {PlannedExercise? target}) async {
    final picker = ImagePicker();
    List<XFile> files;
    try {
      files = await picker.pickMultiImage(maxWidth: 1800, maxHeight: 1800, imageQuality: 88, limit: 4);
    } catch (_) {
      final one = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1800, maxHeight: 1800, imageQuality: 88);
      files = one == null ? [] : [one];
    }
    if (files.isEmpty || !context.mounted) return;
    final images = <WorkoutImage>[];
    for (final f in files.take(4)) {
      final b = await f.readAsBytes();
      final name = f.name.toLowerCase();
      images.add(WorkoutImage(b, name.endsWith('.png') ? 'image/png' : name.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
    }
    if (!context.mounted) return;
    await showAppSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => _Body(plan: plan, target: target, images: images),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.plan, required this.target, required this.images});
  final DayPlan plan;
  final PlannedExercise? target;
  final List<WorkoutImage> images;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  String _step = '사진 읽는 중…';
  String? _error;
  PhotoWorkout? _result;
  late String _exerciseId;
  late final TextEditingController _minutes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _exerciseId = widget.target?.exerciseId ?? 'outdoor_run';
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _result = null;
    });
    try {
      final r = await WorkoutPhotoReader.read(widget.images, onStep: (s) {
        if (mounted) setState(() => _step = s);
      });
      if (!mounted) return;
      setState(() {
        _result = r;
        if (widget.target == null) _exerciseId = r.exerciseId;
        _minutes.text = r.minutes == 0 ? '' : '${r.minutes}';
      });
    } on AiCoachException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '읽는 중 오류: $e');
    }
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = _result;
    final choices = WorkoutTextParser.choices;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('운동 기록 사진 읽기', style: text.titleLarge),
          Text('워치·러닝 앱 화면 캡처 ${widget.images.length}장', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (r == null && _error == null) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 10),
            Text(_step, textAlign: TextAlign.center, style: text.bodyMedium),
          ],
          if (_error != null) ...[
            Card(
              color: cs.errorContainer,
              child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: cs.onErrorContainer))),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
              const Spacer(),
              FilledButton.icon(onPressed: _run, icon: const Icon(Icons.refresh), label: const Text('다시 시도')),
            ]),
          ],
          if (r != null) ...[
            Row(children: [
              Icon(Icons.check_circle, color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${r.method ?? '인식'} · ${r.title ?? exerciseById(r.exerciseId)?.name ?? ''}'
                  '${r.date != null ? ' · ${r.date!.month}/${r.date!.day}' : ''}',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ]),
            if (r.date != null && !_sameDay(r.date!, widget.plan.date))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '사진 날짜(${r.date!.month}/${r.date!.day})와 이 날(${widget.plan.date.month}/${widget.plan.date.day})이 달라요. 그래도 이 날에 넣어요.',
                  style: text.bodySmall?.copyWith(color: cs.tertiary),
                ),
              ),
            const SizedBox(height: 10),
            if (widget.target == null)
              DropdownButtonFormField<String>(
                initialValue: choices.any((e) => e.id == _exerciseId) ? _exerciseId : choices.first.id,
                decoration: const InputDecoration(labelText: '운동', border: OutlineInputBorder(), isDense: true),
                items: [for (final e in choices) DropdownMenuItem(value: e.id, child: Text(e.name))],
                onChanged: (v) => setState(() => _exerciseId = v ?? _exerciseId),
              )
            else
              Text(exerciseById(widget.target!.exerciseId)?.name ?? '', style: text.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '운동 시간(분)', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 10),
            if (r.stats.isEmpty)
              Text('세부 수치를 찾지 못했어요. 시간만 넣거나 다른 캡처로 다시 시도하세요.', style: text.bodySmall?.copyWith(color: cs.error))
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [for (final c in cardioStatChips(r.stats)) Chip(label: Text(c), visualDensity: VisualDensity.compact)],
              ),
            if (r.stats.splits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('스플릿 ${r.stats.splits.length}개', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            const SizedBox(height: 12),
            Row(children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: Text(widget.target == null ? '이 날에 추가' : '기록 채우기'),
                onPressed: () async {
                  final state = context.read<AppState>();
                  final ex = exerciseById(_exerciseId);
                  if (ex == null) return;
                  final min = int.tryParse(_minutes.text.trim()) ?? 0;
                  final nav = Navigator.of(context);
                  final msg = ScaffoldMessenger.of(context);
                  await state.recordCardio(widget.plan, ex, min, r.stats, target: widget.target);
                  nav.pop();
                  msg.showSnackBar(SnackBar(content: Text('${ex.name} 기록을 넣었어요${min > 0 ? ' · $min분' : ''}.')));
                },
              ),
            ]),
          ],
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
