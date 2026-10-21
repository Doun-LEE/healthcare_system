import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/catalog.dart';

/// 실제 수행 무게·횟수를 위아래로 돌려서 고르는 휠 입력.
/// 무게는 기구 단위(바벨 2.5 / 덤벨 2 / 머신 5kg)로, 횟수는 1씩 움직인다.
class SetEditorSheet extends StatefulWidget {
  const SetEditorSheet({
    super.key,
    required this.title,
    required this.targetReps,
    required this.targetWeight,
    required this.initialReps,
    required this.initialWeight,
    required this.weightStep,
    required this.unit,
    required this.showWeight,
    this.levelSpec,
    this.initialLevel,
  });

  final String title;
  final CardioLevelSpec? levelSpec;
  final int? initialLevel;
  final int targetReps;
  final double targetWeight;
  final int initialReps;
  final double initialWeight;
  final double weightStep;
  final String unit;
  final bool showWeight;

  /// 저장하면 (reps, weight, level), 취소하면 null.
  static Future<(int, double, int?)?> show(
    BuildContext context, {
    required String title,
    required int targetReps,
    required double targetWeight,
    required int initialReps,
    required double initialWeight,
    required double weightStep,
    required String unit,
    required bool showWeight,
    CardioLevelSpec? levelSpec,
    int? initialLevel,
  }) =>
      showModalBottomSheet<(int, double, int?)>(
        context: context,
        showDragHandle: true,
        builder: (_) => SetEditorSheet(
          title: title,
          targetReps: targetReps,
          targetWeight: targetWeight,
          initialReps: initialReps,
          initialWeight: initialWeight,
          weightStep: weightStep,
          unit: unit,
          showWeight: showWeight,
          levelSpec: levelSpec,
          initialLevel: initialLevel,
        ),
      );

  @override
  State<SetEditorSheet> createState() => _SetEditorSheetState();
}

class _SetEditorSheetState extends State<SetEditorSheet> {
  static const int _maxReps = 60;
  late int _reps;
  late int _weightIdx; // weight = idx * step
  late final int _maxWeightIdx;
  late final FixedExtentScrollController _repsCtrl;
  late final FixedExtentScrollController _weightCtrl;
  late int _level;
  late final FixedExtentScrollController _levelCtrl;
  CardioLevelSpec? get _spec => widget.levelSpec;

  double get _step => widget.weightStep > 0 ? widget.weightStep : 2.5;

  @override
  void initState() {
    super.initState();
    _maxWeightIdx = (400 / _step).round();
    _reps = widget.initialReps.clamp(0, _maxReps);
    _weightIdx = (widget.initialWeight / _step).round().clamp(0, _maxWeightIdx);
    _repsCtrl = FixedExtentScrollController(initialItem: _reps);
    _weightCtrl = FixedExtentScrollController(initialItem: _weightIdx);
    final sp = _spec;
    _level = sp == null ? 0 : (widget.initialLevel ?? sp.min).clamp(sp.min, sp.max);
    _levelCtrl = FixedExtentScrollController(initialItem: sp == null ? 0 : _level - sp.min);
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _levelCtrl.dispose();
    super.dispose();
  }

  double get _weight => _weightIdx * _step;

  String _fmt(double w) =>
      w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final upW = _weight > widget.targetWeight;
    final upR = _reps > widget.targetReps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: text.titleMedium),
          Text(
            '처방: ${widget.showWeight ? '${_fmt(widget.targetWeight)}kg × ' : ''}${widget.targetReps}${widget.unit}',
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                if (widget.showWeight)
                  Expanded(
                    child: _Wheel(
                      label: 'kg',
                      controller: _weightCtrl,
                      count: _maxWeightIdx + 1,
                      selected: _weightIdx,
                      highlight: upW ? cs.primary : null,
                      itemText: (i) => _fmt(i * _step),
                      onChanged: (i) => setState(() => _weightIdx = i),
                    ),
                  ),
                if (widget.showWeight)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×', style: text.headlineSmall),
                  ),
                Expanded(
                  child: _Wheel(
                    label: widget.unit,
                    controller: _repsCtrl,
                    count: _maxReps + 1,
                    selected: _reps,
                    highlight: upR ? cs.primary : null,
                    itemText: (i) => '$i',
                    onChanged: (i) => setState(() => _reps = i),
                  ),
                ),
                if (_spec != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('·', style: text.headlineSmall),
                  ),
                  Expanded(
                    child: _Wheel(
                      label: _spec!.label,
                      controller: _levelCtrl,
                      count: _spec!.max - _spec!.min + 1,
                      selected: _level - _spec!.min,
                      highlight: widget.initialLevel != null && _level > widget.initialLevel! ? cs.primary : null,
                      itemText: (i) => '${i + _spec!.min}${_spec!.unit}',
                      onChanged: (i) => setState(() => _level = i + _spec!.min),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.showWeight) ...[
                _Nudge(label: '-${_fmt(_step)}', onTap: () => _jumpW(_weightIdx - 1)),
                const SizedBox(width: 6),
                _Nudge(label: '+${_fmt(_step)}', onTap: () => _jumpW(_weightIdx + 1)),
                const Spacer(),
              ],
              _Nudge(label: '-1', onTap: () => _jumpR(_reps - 1)),
              const SizedBox(width: 6),
              _Nudge(label: '+1', onTap: () => _jumpR(_reps + 1)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  _jumpR(widget.targetReps);
                  if (widget.showWeight) _jumpW((widget.targetWeight / _step).round());
                },
                child: const Text('처방대로'),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, (_reps, widget.showWeight ? _weight : 0.0, _spec == null ? null : _level)),
                icon: const Icon(Icons.check),
                label: const Text('저장 + 완료'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _jumpW(int i) {
    final v = i.clamp(0, _maxWeightIdx);
    _weightCtrl.animateToItem(v, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    setState(() => _weightIdx = v);
  }

  void _jumpR(int i) {
    final v = i.clamp(0, _maxReps);
    _repsCtrl.animateToItem(v, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    setState(() => _reps = v);
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.label,
    required this.controller,
    required this.count,
    required this.selected,
    required this.itemText,
    required this.onChanged,
    this.highlight,
  });

  final String label;
  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final String Function(int) itemText;
  final void Function(int) onChanged;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: (highlight ?? cs.primary).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        CupertinoPicker(
          scrollController: controller,
          itemExtent: 44,
          magnification: 1.1,
          useMagnifier: true,
          squeeze: 1.1,
          selectionOverlay: const SizedBox.shrink(),
          onSelectedItemChanged: onChanged,
          children: [
            for (var i = 0; i < count; i++)
              Center(
                child: Text(
                  itemText(i),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: i == selected ? FontWeight.bold : FontWeight.normal,
                    color: i == selected ? (highlight ?? cs.onSurface) : cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          right: 8,
          child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ),
      ],
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label),
      );
}
