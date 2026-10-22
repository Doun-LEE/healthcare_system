import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/body_model.dart';
import '../data/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'widgets/body_view.dart';
import 'widgets/equipment_3d.dart';
import 'widgets/exercise_sheet.dart';
import 'widgets/app_sheet.dart';

/// 헬스장별 보유 기구 추가/수정/삭제 (요구사항 3) + 기구 3D/특징 보기.
class GymScreen extends StatelessWidget {
  const GymScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final gym = state.activeGym;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: gym == null
            ? const Text('헬스장')
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: gym.id,
                  items: state.gyms
                      .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, style: text.titleLarge)))
                      .toList(),
                  onChanged: (v) => v == null ? null : state.setActiveGym(v),
                ),
              ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _gymMenu(context, state, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'add', child: Text('헬스장 추가')),
              if (gym != null) const PopupMenuItem(value: 'rename', child: Text('이름 변경')),
              if (gym != null) const PopupMenuItem(value: 'standard', child: Text('대중적인 기본 기구 일괄 추가')),
              if (gym != null) const PopupMenuItem(value: 'delete', child: Text('이 헬스장 삭제')),
            ],
          ),
        ],
      ),
      floatingActionButton: gym == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addEquipment(context, state, gym),
              icon: const Icon(Icons.add),
              label: const Text('기구 추가'),
            ),
      body: gym == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_mall_directory_outlined, size: 72, color: cs.primary),
                  const SizedBox(height: 12),
                  Text('등록된 헬스장이 없어요', style: text.titleLarge),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _gymMenu(context, state, 'add'),
                    icon: const Icon(Icons.add),
                    label: const Text('헬스장 추가'),
                  ),
                ],
              ),
            )
          : gym.equipment.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('보유 기구를 추가하세요', style: text.titleLarge),
                        const SizedBox(height: 8),
                        Text('기구를 등록하면 그 기구로 할 수 있는 운동만 루틴에 들어갑니다.',
                            textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => state.addStandardEquipment(gym.id),
                          child: const Text('대중적인 기본 기구 16종 일괄 추가'),
                        ),
                      ],
                    ),
                  ),
                )
              : _EquipmentList(gym: gym),
    );
  }

  Future<void> _gymMenu(BuildContext context, AppState state, String v) async {
    final gym = state.activeGym;
    switch (v) {
      case 'add':
        final name = await _prompt(context, '헬스장 이름', '예: 집 앞 피트니스');
        if (name != null) await state.addGym(name);
      case 'rename':
        if (gym == null) return;
        final name = await _prompt(context, '헬스장 이름', gym.name, initial: gym.name);
        if (name != null && name.trim().isNotEmpty) await state.renameGym(gym.id, name.trim());
      case 'standard':
        if (gym != null) await state.addStandardEquipment(gym.id);
      case 'delete':
        if (gym == null) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('${gym.name} 삭제'),
            content: const Text('기구 목록이 함께 삭제됩니다.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
            ],
          ),
        );
        if (ok == true) await state.deleteGym(gym.id);
    }
  }

  Future<void> _addEquipment(BuildContext context, AppState state, Gym gym) async {
    final result = await showAppSheet<PickerResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => _EquipmentPicker(have: gym.equipment.map((e) => e.type).toSet()),
    );
    if (result == null || !context.mounted) return;
    if (result.customBase != null && result.customName != null) {
      await state.addEquipment(gym.id, result.customBase!, name: result.customName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('"${result.customName}" 추가 (운동은 ${result.customBase!.label} 기준으로 짭니다)')));
      }
      return;
    }
    // 보유 해제한 기구 삭제
    for (final t in result.remove) {
      for (final e in gym.equipment.where((e) => e.type == t).toList()) {
        await state.removeEquipment(gym.id, e.id);
      }
    }
    final chosen = result.add;
    if (chosen.isEmpty) {
      if (result.remove.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.remove.length}개 기구를 보유 목록에서 뺐어요.')));
      }
      return;
    }
    if (chosen.length == 1 && result.remove.isEmpty) {
      if (!context.mounted) return;
      final detail = await _EquipmentEditor.show(context, chosen.first);
      if (detail == null) return;
      await state.addEquipment(gym.id, chosen.first,
          name: detail.customName, maxWeight: detail.maxWeightKg, note: detail.note,
          mechanism: detail.mechanism, stepKg: detail.stepKg);
      return;
    }
    for (final t in chosen) {
      await state.addEquipment(gym.id, t);
    }
    if (context.mounted) {
      final removed = result.remove.isEmpty ? '' : ', ${result.remove.length}개 제거';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${chosen.length}개 기구를 추가$removed했어요. 길게 눌러 별칭/최대중량을 넣을 수 있어요.')));
    }
  }
}

/// 기구 선택기 결과: 새로 추가할 기구와 보유 해제한 기구.
class PickerResult {
  const PickerResult({required this.add, required this.remove, this.customName, this.customBase});
  final List<EquipmentType> add;
  final List<EquipmentType> remove;

  /// 목록에 없는 기구를 이름 그대로 추가할 때: 표시 이름과 운동 매핑에 쓸 비슷한 기구.
  final String? customName;
  final EquipmentType? customBase;
}

/// 기구 종류별로 할 수 있는 운동 이름(검색용).
final Map<EquipmentType, List<String>> _exerciseNamesByType = () {
  final m = <EquipmentType, List<String>>{};
  for (final ex in exerciseCatalog) {
    for (final t in ex.equipment) {
      (m[t] ??= []).add(ex.name);
    }
  }
  return m;
}();

/// 카탈로그 전체(80여 종)에서 검색·분류로 골라 여러 개를 한 번에 추가하는 선택기.
class _EquipmentPicker extends StatefulWidget {
  const _EquipmentPicker({required this.have});
  final Set<EquipmentType> have;

  @override
  State<_EquipmentPicker> createState() => _EquipmentPickerState();
}

/// 직접 추가할 기구와 가장 비슷한 기구 고르기.
Future<EquipmentType?> _pickBaseType(BuildContext context) {
  return showDialog<EquipmentType>(
    context: context,
    builder: (c) {
      var query = '';
      return StatefulBuilder(builder: (c, setState) {
        final list = equipmentCatalog.where((i) => i.type.matches(query)).toList();
        return AlertDialog(
          title: const Text('가장 비슷한 기구는?'),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: Column(children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '예: 로우, 프레스, 케이블'),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(children: [
                  for (final i in list)
                    ListTile(
                      dense: true,
                      title: Text(i.type.label),
                      subtitle: Text(i.strengths.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(c, i.type),
                    ),
                ]),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소'))],
        );
      });
    },
  );
}

class _EquipmentPickerState extends State<_EquipmentPicker> {
  String _query = '';
  EquipmentCategory? _category;
  final _selected = <EquipmentType>{};
  final _removed = <EquipmentType>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = equipmentCatalog
        .where((i) => i.type != EquipmentType.bodyweight)
        .where((i) => _category == null || i.type.category == _category)
        .where((i) =>
            i.type.matches(_query) ||
            i.strengths.any((s) => s.toLowerCase().contains(_query.toLowerCase())) ||
            (_exerciseNamesByType[i.type] ?? const []).any((n) => n.toLowerCase().contains(_query.toLowerCase())))
        .toList();
    final q = _query.trim();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (c, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(child: Text('기구 선택', style: text.titleMedium)),
                Text('${equipmentCatalog.length - 1}종 · 이미 ${widget.have.length}개 보유',
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '검색: 해머, 레그프레스, cable, 둔근 …',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _query = '')),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: const Text('전체'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                ),
                for (final cat in EquipmentCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat.label),
                      selected: _category == cat,
                      onSelected: (_) => setState(() => _category = _category == cat ? null : cat),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: items.length + (q.isEmpty ? 0 : 1),
              itemBuilder: (c, i) {
                if (i == items.length) {
                  return ListTile(
                    leading: Icon(Icons.add_circle_outline, color: cs.tertiary),
                    title: Text('"$q" 이름 그대로 추가'),
                    subtitle: Text(items.isEmpty ? '목록에 없는 기구예요. 비슷한 기구를 골라주면 그 기준으로 운동을 짭니다.' : '위에 없으면 비슷한 기구를 골라 직접 추가'),
                    onTap: () async {
                      final base = await _pickBaseType(context);
                      if (base != null && context.mounted) {
                        Navigator.pop(context, PickerResult(add: const [], remove: const [], customName: q, customBase: base));
                      }
                    },
                  );
                }
                final info = items[i];
                final has = widget.have.contains(info.type);
                final rem = _removed.contains(info.type);
                final sel = has ? !rem : _selected.contains(info.type);
                return CheckboxListTile(
                  value: sel,
                  onChanged: (_) => setState(() {
                    if (has) {
                      rem ? _removed.remove(info.type) : _removed.add(info.type);
                    } else {
                      sel ? _selected.remove(info.type) : _selected.add(info.type);
                    }
                  }),
                  secondary: has
                      ? Icon(rem ? Icons.remove_circle_outline : Icons.check_circle, color: rem ? cs.error : cs.primary)
                      : null,
                  title: Text(info.type.label,
                      style: rem ? TextStyle(decoration: TextDecoration.lineThrough, color: cs.onSurfaceVariant) : null),
                  subtitle: Text(
                    has ? (rem ? '체크 해제됨 · 적용하면 보유 목록에서 빠져요' : '이미 보유 · 체크를 풀면 제거') : info.strengths.take(3).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dense: true,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selected.isEmpty && _removed.isEmpty
                        ? '체크해서 추가 · 보유 기구는 체크를 풀어 제거'
                        : [
                            if (_selected.isNotEmpty) '${_selected.length}개 추가',
                            if (_removed.isNotEmpty) '${_removed.length}개 제거',
                          ].join(' · '),
                    style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _selected.isEmpty && _removed.isEmpty
                      ? null
                      : () => Navigator.pop(context, PickerResult(add: _selected.toList(), remove: _removed.toList())),
                  icon: Icon(_selected.isEmpty && _removed.isNotEmpty ? Icons.check : Icons.add),
                  label: Text(_selected.isEmpty && _removed.isNotEmpty ? '적용' : '추가'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _prompt(BuildContext context, String title, String hint, {String? initial}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('확인')),
      ],
    ),
  );
}

class _EquipmentList extends StatelessWidget {
  const _EquipmentList({required this.gym});
  final Gym gym;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // 부위별로 묶어서 보여준다.
    final byGroup = <MuscleGroup, List<GymEquipment>>{};
    for (final e in gym.equipment) {
      final groups = equipmentInfo(e.type).groups;
      final g = groups.isEmpty ? MuscleGroup.cardio : groups.first;
      byGroup.putIfAbsent(g, () => []).add(e);
    }
    final order = [
      MuscleGroup.chest, MuscleGroup.back, MuscleGroup.legs, MuscleGroup.shoulder,
      MuscleGroup.arms, MuscleGroup.abs, MuscleGroup.cardio,
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('${gym.equipment.length}개 기구 · 탭하면 3D와 특징, 길게 누르면 수정',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
        for (final g in order)
          if (byGroup[g] != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(g.label, style: text.labelLarge?.copyWith(color: cs.primary)),
            ),
            for (final e in byGroup[g]!)
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: cs.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete, color: cs.onErrorContainer),
                ),
                onDismissed: (_) => state.removeEquipment(gym.id, e.id),
                child: ListTile(
                  leading: SizedBox(
                    width: 56,
                    height: 56,
                    child: Equipment3DView(type: e.type, height: 56, autoRotate: false),
                  ),
                  title: Text(e.displayName),
                  subtitle: Text(
                    [
                      if (e.customName != null && e.customName!.isNotEmpty) e.type.label,
                      equipmentInfo(e.type).strengths.take(2).join(' · '),
                      if (e.mechanism != LoadMechanism.none) '${e.mechanism.label.split(' ').first} ${e.effectiveStep}kg',
                      if (e.maxWeightKg != null) '최대 ${e.maxWeightKg!.toInt()}kg',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _EquipmentDetail.show(context, e),
                  onLongPress: () async {
                    final edited = await _EquipmentEditor.show(context, e.type, existing: e);
                    if (edited != null) await state.updateEquipment(gym.id, edited);
                  },
                ),
              ),
          ],
      ],
    );
  }
}

class _EquipmentDetail extends StatelessWidget {
  const _EquipmentDetail({required this.eq});
  final GymEquipment eq;

  static Future<void> show(BuildContext context, GymEquipment eq) => showAppSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _EquipmentDetail(eq: eq),
      );

  @override
  Widget build(BuildContext context) {
    final info = equipmentInfo(eq.type);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final exercises = exerciseCatalog.where((x) => x.equipment.contains(eq.type)).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (c, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(eq.displayName, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (eq.displayName != eq.type.label)
            Text(eq.type.label, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Equipment3DView(type: eq.type, height: 240),
          const SizedBox(height: 12),
          Text(info.summary, style: text.bodyLarge),
          const SizedBox(height: 8),
          Text('이 기구가 잘 먹는 포인트', style: text.titleSmall),
          ...info.strengths.map((s) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bolt, color: cs.primary, size: 20),
                title: Text(s),
              )),
          if (eq.note != null && eq.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('메모', style: text.titleSmall),
            Text(eq.note!),
          ],
          const SizedBox(height: 12),
          Text('이 기구로 자극하는 부위', style: text.titleSmall),
          const SizedBox(height: 8),
          BodyMuscleView(map: musclesForEquipment(eq.type), height: 240),
          const SizedBox(height: 16),
          Text('이 기구로 하는 운동 ${exercises.length}개 · 눌러서 방법 보기', style: text.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: exercises
                .map((x) => ActionChip(
                      label: Text(x.name),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ExerciseSheet.show(context, x, eq.type),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EquipmentEditor extends StatefulWidget {
  const _EquipmentEditor({required this.type, this.existing});
  final EquipmentType type;
  final GymEquipment? existing;

  static Future<GymEquipment?> show(BuildContext context, EquipmentType type, {GymEquipment? existing}) =>
      showDialog<GymEquipment>(
        context: context,
        builder: (_) => _EquipmentEditor(type: type, existing: existing),
      );

  @override
  State<_EquipmentEditor> createState() => _EquipmentEditorState();
}

class _EquipmentEditorState extends State<_EquipmentEditor> {
  late final TextEditingController _name;
  late final TextEditingController _max;
  late final TextEditingController _note;
  late final TextEditingController _step;
  late LoadMechanism _mech;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.customName ?? '');
    _max = TextEditingController(text: widget.existing?.maxWeightKg?.toInt().toString() ?? '');
    _note = TextEditingController(text: widget.existing?.note ?? '');
    _mech = widget.existing?.mechanism ?? LoadMechanism.defaultFor(widget.type);
    _step = TextEditingController(text: widget.existing?.stepKg == null ? '' : _fmt(widget.existing!.stepKg!));
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _max.dispose();
    _note.dispose();
    _step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMachine = ![
      EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.flatBench, EquipmentType.inclineBench,
      EquipmentType.pullUpBar, EquipmentType.dipStation, EquipmentType.romanChair, EquipmentType.kettlebell,
      EquipmentType.treadmill, EquipmentType.bike, EquipmentType.rower, EquipmentType.stairClimber,
      EquipmentType.elliptical, EquipmentType.bodyweight,
    ].contains(widget.type);
    return AlertDialog(
      title: Text(widget.existing == null ? '${widget.type.label} 추가' : '${widget.type.label} 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '별칭 (선택)', hintText: '예: 해머 체스트프레스'),
          ),
          if (isMachine) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: Text('중량 방식', style: Theme.of(context).textTheme.labelLarge)),
            const SizedBox(height: 4),
            SegmentedButton<LoadMechanism>(
              segments: const [
                ButtonSegment(value: LoadMechanism.pin, label: Text('핀'), icon: Icon(Icons.push_pin_outlined)),
                ButtonSegment(value: LoadMechanism.plate, label: Text('원판'), icon: Icon(Icons.album_outlined)),
                ButtonSegment(value: LoadMechanism.free, label: Text('프리')),
              ],
              selected: {_mech == LoadMechanism.none ? LoadMechanism.pin : _mech},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _mech = v.first),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _step,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: '무게 한 칸 kg', hintText: '기본 ${_fmt(_mech.defaultStepKg)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _max,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '최대 kg (선택)'),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _mech == LoadMechanism.pin
                    ? '핀 머신: 스택 한 칸 무게(보통 5kg, 수입 머신은 4.5kg)로 처방 무게가 떨어집니다.'
                    : _mech == LoadMechanism.plate
                        ? '원판 머신: 끼우는 원판 단위(보통 2.5kg)로 처방됩니다.'
                        : '프리웨이트: 2.5kg 단위.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: '메모 (선택)', hintText: '예: 2층 창가, 시트 높이 4'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            GymEquipment(
              id: widget.existing?.id ?? 'new',
              type: widget.type,
              customName: _name.text.trim().isEmpty ? null : _name.text.trim(),
              maxWeightKg: double.tryParse(_max.text),
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              mechanism: isMachine ? _mech : LoadMechanism.defaultFor(widget.type),
              stepKg: double.tryParse(_step.text),
            ),
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
