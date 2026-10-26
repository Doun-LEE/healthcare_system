import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/body_model.dart';
import '../data/brands.dart';
import '../data/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'widgets/body_view.dart';
import 'widgets/equipment_look.dart';
import 'widgets/real_photos.dart';
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
    final custom = result.custom;
    if (custom != null) {
      await state.addEquipment(gym.id, custom.types.first,
          name: custom.name, mechanism: custom.mechanism, extraTypes: custom.types.skip(1).toList());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('"${custom.name}" 추가 · ${custom.types.map((t) => t.label).join(' + ')} 기준으로 운동을 짭니다')));
      }
      return;
    }
    for (final p in result.named) {
      await state.addEquipment(gym.id, p.model.type,
          name: p.model.name,
          mechanism: p.model.mechanism,
          brand: p.brandKey,
          extraTypes: p.model.extra.isEmpty ? null : List.of(p.model.extra),
          weightBasis: p.model.perSide ? 'perSide' : null);
    }
    if (result.named.isNotEmpty && result.add.isEmpty && result.remove.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('브랜드 기구 ${result.named.length}개를 추가했어요.')));
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
  const PickerResult({required this.add, required this.remove, this.named = const [], this.custom});
  final List<EquipmentType> add;
  final List<EquipmentType> remove;

  /// 브랜드 탭에서 고른 모델(이름·종류·방식·브랜드 그대로 등록).
  final List<BrandPick> named;

  /// 직접 추가(목록에 없는 기구·복합 머신).
  final CustomEquipment? custom;
}

class BrandPick {
  const BrandPick(this.model, this.brandKey);
  final BrandModel model;
  final String brandKey;
}

class CustomEquipment {
  const CustomEquipment({required this.name, required this.types, required this.mechanism});
  final String name;

  /// 첫 번째가 주 종류, 나머지는 복합 머신의 겸용 종류.
  final List<EquipmentType> types;
  final LoadMechanism mechanism;
}

/// 목록에 없는 기구 / 복합(짬뽕) 머신 직접 추가.
Future<CustomEquipment?> customEquipmentDialog(BuildContext context, {String initialName = ''}) {
  final nameCtrl = TextEditingController(text: initialName);
  final picked = <EquipmentType>[];
  var query = '';
  var mech = LoadMechanism.pin;
  return showDialog<CustomEquipment>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setState) {
      final list = equipmentCatalog.where((i) => i.type != EquipmentType.bodyweight && i.type.matches(query)).toList();
      final text = Theme.of(c).textTheme;
      return AlertDialog(
        title: const Text('기구 직접 추가'),
        content: SizedBox(
          width: double.maxFinite,
          height: 460,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '기구 이름 (예: 디랙스 레그 익스텐션/컬)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SegmentedButton<LoadMechanism>(
              segments: const [
                ButtonSegment(value: LoadMechanism.pin, label: Text('핀')),
                ButtonSegment(value: LoadMechanism.plate, label: Text('원판')),
                ButtonSegment(value: LoadMechanism.free, label: Text('프리')),
              ],
              selected: {mech},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => mech = s.first),
            ),
            const SizedBox(height: 8),
            Text('이 기구로 할 수 있는 운동 종류 (여러 개 = 복합 머신)', style: text.labelLarge),
            if (picked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final t in picked)
                    InputChip(label: Text(t.label), onDeleted: () => setState(() => picked.remove(t)), visualDensity: VisualDensity.compact),
                ]),
              ),
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '예: 레그 컬, 로우, 프레스', isDense: true),
              onChanged: (v) => setState(() => query = v),
            ),
            Expanded(
              child: ListView(children: [
                for (final i in list)
                  CheckboxListTile(
                    dense: true,
                    value: picked.contains(i.type),
                    title: Text(i.type.label),
                    subtitle: Text(i.strengths.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onChanged: (_) => setState(() => picked.contains(i.type) ? picked.remove(i.type) : picked.add(i.type)),
                  ),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
          FilledButton(
            onPressed: nameCtrl.text.trim().isEmpty && picked.isEmpty
                ? null
                : () {
                    if (picked.isEmpty) {
                      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('어떤 운동이 되는 기구인지 하나 이상 골라주세요.')));
                      return;
                    }
                    final name = nameCtrl.text.trim().isEmpty ? picked.map((t) => t.label).join(' + ') : nameCtrl.text.trim();
                    Navigator.pop(c, CustomEquipment(name: name, types: List.of(picked), mechanism: mech));
                  },
            child: const Text('추가'),
          ),
        ],
      );
    }),
  );
}

/// 기구 종류별로 할 수 있는 운동 이름(검색용).
final Map<EquipmentType, List<String>> _exerciseNamesByType = () {
  final m = <EquipmentType, List<String>>{};
  for (final t in EquipmentType.values) {
    m[t] = [for (final ex in exercisesForTypes({t, ...?impliedEquipment[t]})) ex.name];
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

class _EquipmentPickerState extends State<_EquipmentPicker> {
  String _query = '';
  EquipmentCategory? _category;
  final _selected = <EquipmentType>{};
  final _removed = <EquipmentType>{};

  /// 브랜드 탭
  bool _byBrand = false;
  final _brandPicked = <BrandModel, String>{};

  Future<void> _custom() async {
    final custom = await customEquipmentDialog(context, initialName: _query.trim());
    if (custom != null && mounted) {
      Navigator.pop(context, PickerResult(add: const [], remove: const [], custom: custom));
    }
  }

  Widget _brandList(ScrollController ctrl, ColorScheme cs, TextTheme text) {
    final q = _query.trim().toLowerCase();
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    // 여러 단어 검색: 단어마다 브랜드 이름/별칭 또는 모델 이름/종류 중 어딘가에 있으면 통과.
    bool hit(EquipmentBrand b, BrandModel m) => tokens.every((t) => b.matches(t) || m.name.toLowerCase().contains(t) || m.type.matches(t));
    final brands = equipmentBrands.where((b) => q.isEmpty || b.models.any((m) => hit(b, m))).toList();
    return ListView(
      controller: ctrl,
      children: [
        for (final b in brands)
          ExpansionTile(
            key: ValueKey('${b.key}-${q.isNotEmpty}'),
            initiallyExpanded: q.isNotEmpty,
            leading: BrandBadge(brand: b),
            title: Text(b.name),
            subtitle: Text(b.note.isEmpty ? '${b.models.length}개 모델' : '${b.models.length}개 모델 · ${b.note}', maxLines: 2, overflow: TextOverflow.ellipsis),
            children: [
              for (final m in b.models.where((m) => q.isEmpty || hit(b, m)))
                CheckboxListTile(
                  dense: true,
                  value: _brandPicked.containsKey(m),
                  secondary: EquipmentPhoto(type: m.type, size: 44),
                  title: Text(m.name),
                  subtitle: Text('${m.type.label} · ${m.mechanism.label}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onChanged: (_) => setState(() => _brandPicked.containsKey(m) ? _brandPicked.remove(m) : _brandPicked[m] = b.key),
                ),
            ],
          ),
        ListTile(
          leading: Icon(Icons.add_circle_outline, color: cs.tertiary),
          title: const Text('찾는 모델이 없나요? 직접 추가'),
          subtitle: const Text('이름을 그대로 쓰고, 복합 머신이면 되는 운동 종류를 여러 개 고르세요.'),
          onTap: _custom,
        ),
      ],
    );
  }

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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('종류별'), icon: Icon(Icons.category_outlined)),
                    ButtonSegment(value: true, label: Text('브랜드별'), icon: Icon(Icons.storefront_outlined)),
                  ],
                  selected: {_byBrand},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _byBrand = s.first),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: _custom, icon: const Icon(Icons.add), label: const Text('직접 추가')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: _byBrand ? '검색: 디랙스, 해머, 레그 컬 …' : '검색: 해머, 레그프레스, cable, 둔근 …',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _query = '')),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (!_byBrand)
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
          if (_byBrand) const SizedBox(height: 6),
          if (_byBrand)
            Expanded(child: _brandList(ctrl, cs, text))
          else
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
                      final custom = await customEquipmentDialog(context, initialName: q);
                      if (custom != null && context.mounted) {
                        Navigator.pop(context, PickerResult(add: const [], remove: const [], custom: custom));
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
                  secondary: SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(children: [
                      EquipmentPhoto(type: info.type, size: 52),
                      if (has)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                            child: Icon(rem ? Icons.remove_circle : Icons.check_circle, size: 18, color: rem ? cs.error : cs.primary),
                          ),
                        ),
                    ]),
                  ),
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
                    _selected.isEmpty && _removed.isEmpty && _brandPicked.isEmpty
                        ? (_byBrand ? '브랜드 모델을 체크해서 추가' : '체크해서 추가 · 보유 기구는 체크를 풀어 제거')
                        : [
                            if (_selected.isNotEmpty) '${_selected.length}개 추가',
                            if (_brandPicked.isNotEmpty) '브랜드 ${_brandPicked.length}개',
                            if (_removed.isNotEmpty) '${_removed.length}개 제거',
                          ].join(' · '),
                    style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _selected.isEmpty && _removed.isEmpty && _brandPicked.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          PickerResult(
                            add: _selected.toList(),
                            remove: _removed.toList(),
                            named: [for (final e in _brandPicked.entries) BrandPick(e.key, e.value)],
                          ),
                        ),
                  icon: Icon(_selected.isEmpty && _brandPicked.isEmpty && _removed.isNotEmpty ? Icons.check : Icons.add),
                  label: Text(_selected.isEmpty && _brandPicked.isEmpty && _removed.isNotEmpty ? '적용' : '추가'),
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
                  leading: EquipmentThumb(eq: e),
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
                  onTap: () => _EquipmentDetail.show(context, e, gym.id),
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
  const _EquipmentDetail({required this.eq, required this.gymId});
  final GymEquipment eq;
  final String gymId;

  static Future<void> show(BuildContext context, GymEquipment eq, String gymId) => showAppSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _EquipmentDetail(eq: eq, gymId: gymId),
      );

  @override
  Widget build(BuildContext context) {
    final info = equipmentInfo(eq.type);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final exercises = exercisesForTypes({
      for (final t in eq.allTypes) ...[t, ...?impliedEquipment[t]],
    });
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
          EquipmentLookSection(gymId: gymId, equipmentId: eq.id),
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
  String? _basis;
  late List<EquipmentType> _extra;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.customName ?? '');
    _max = TextEditingController(text: widget.existing?.maxWeightKg?.toInt().toString() ?? '');
    _note = TextEditingController(text: widget.existing?.note ?? '');
    _mech = widget.existing?.mechanism ?? LoadMechanism.defaultFor(widget.type);
    _basis = widget.existing?.weightBasis;
    _extra = List.of(widget.existing?.extraTypes ?? const <EquipmentType>[]);
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
      scrollable: true,
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
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: Text('무게 표시 기준', style: Theme.of(context).textTheme.labelLarge)),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'total', label: Text('양쪽 합계')),
              ButtonSegment(value: 'perSide', label: Text('한쪽 기준')),
            ],
            selected: {_basis ?? (GymEquipment.perSideByDefault(widget.type) ? 'perSide' : 'total')},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _basis = v.first),
          ),
          Text(
            GymEquipment.perSideByDefault(widget.type)
                ? '덤벨은 보통 한 손 무게로 봐요. 양손 합으로 보고 싶으면 바꾸세요.'
                : '좌우에 원판을 따로 거는 머신(해머 등)은 한쪽 기준이 편해요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: Text('이 기구로 하는 다른 운동(다기능 머신)', style: Theme.of(context).textTheme.labelLarge)),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final t in _extra)
              InputChip(label: Text(t.label), onDeleted: () => setState(() => _extra.remove(t)), visualDensity: VisualDensity.compact),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('추가'),
              onPressed: () async {
                final t = await _pickExtraType(context, {widget.type, ..._extra});
                if (t != null) setState(() => _extra.add(t));
              },
            ),
          ]),
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
              // 수정해도 브랜드·색·사진 정보는 그대로 둔다.
              extraTypes: List.of(_extra),
              brand: widget.existing?.brand,
              frameColor: widget.existing?.frameColor,
              padColor: widget.existing?.padColor,
              shroud: widget.existing?.shroud,
              hasPhoto: widget.existing?.hasPhoto ?? false,
              weightBasis: _basis,
            ),
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}


/// 다기능 머신에 더할 운동 종류 고르기.
Future<EquipmentType?> _pickExtraType(BuildContext context, Set<EquipmentType> exclude) {
  var query = '';
  return showDialog<EquipmentType>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setState) {
      final list = equipmentCatalog.where((i) => !exclude.contains(i.type) && i.type != EquipmentType.bodyweight && i.type.matches(query)).toList();
      return AlertDialog(
        title: const Text('어떤 운동도 되나요?'),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: Column(children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '예: 슈러그, 로우, 카프'),
              onChanged: (v) => setState(() => query = v),
            ),
            Expanded(
              child: ListView(children: [
                for (final i in list)
                  ListTile(dense: true, title: Text(i.type.label), onTap: () => Navigator.pop(c, i.type)),
              ]),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소'))],
      );
    }),
  );
}
