import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/photo_store.dart' as photos;
import '../../data/brands.dart';
import '../../data/equipment_models.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'equipment_3d.dart';

/// 기구 썸네일: 실물 사진이 있으면 사진, 없으면 브랜드/사용자 스타일의 3D.
class EquipmentThumb extends StatelessWidget {
  const EquipmentThumb({super.key, required this.eq, this.size = 56});
  final GymEquipment eq;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Equipment3DView(type: eq.type, height: size, autoRotate: false, style: styleForEquipment(eq));
    if (!eq.hasPhoto) return SizedBox(width: size, height: size, child: fallback);
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<Uint8List?>(
        future: photos.loadPhoto(eq.id),
        builder: (c, snap) {
          final b = snap.data;
          if (b == null) return fallback;
          return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true));
        },
      ),
    );
  }
}

/// 기구 상세의 "모습" 섹션: 사진/3D 전환, 사진 등록·삭제, 3D 색상·스택 커버.
class EquipmentLookSection extends StatefulWidget {
  const EquipmentLookSection({super.key, required this.gymId, required this.equipmentId});
  final String gymId;
  final String equipmentId;

  @override
  State<EquipmentLookSection> createState() => _EquipmentLookSectionState();
}

class _EquipmentLookSectionState extends State<EquipmentLookSection> {
  bool _show3d = false;
  bool _busy = false;

  GymEquipment? _eq(AppState s) =>
      s.gyms.where((g) => g.id == widget.gymId).firstOrNull?.equipment.where((e) => e.id == widget.equipmentId).firstOrNull;

  Future<void> _pick(ImageSource src) async {
    setState(() => _busy = true);
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1024, maxHeight: 1024, imageQuality: 72);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      await context.read<AppState>().setEquipmentPhoto(widget.gymId, widget.equipmentId, bytes);
      if (mounted) setState(() => _show3d = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사진을 불러오지 못했어요: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final eq = _eq(state);
    if (eq == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final style = styleForEquipment(eq);
    final brand = brandByKey(eq.brand);
    final showPhoto = eq.hasPhoto && !_show3d;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (eq.hasPhoto)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('실물 사진'), icon: Icon(Icons.photo_outlined)),
              ButtonSegment(value: true, label: Text('3D'), icon: Icon(Icons.view_in_ar_outlined)),
            ],
            selected: {_show3d},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _show3d = s.first),
          ),
        ),
      if (showPhoto)
        FutureBuilder<Uint8List?>(
          future: photos.loadPhoto(eq.id),
          builder: (c, snap) => Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: snap.data == null
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer(child: Image.memory(snap.data!, fit: BoxFit.contain)),
          ),
        )
      else
        Equipment3DView(type: eq.type, height: 240, style: style),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: [
        FilledButton.tonalIcon(
          onPressed: _busy ? null : () => _pick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(eq.hasPhoto ? '다시 찍기' : '실물 사진 찍기'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('앨범에서'),
        ),
        if (eq.hasPhoto)
          TextButton.icon(
            onPressed: _busy ? null : () => state.setEquipmentPhoto(widget.gymId, widget.equipmentId, null),
            icon: const Icon(Icons.delete_outline),
            label: const Text('사진 삭제'),
          ),
      ]),
      Text('사진은 이 기기에만 저장돼요(계정 동기화 제외).', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 14),
      Row(children: [
        Text('3D 색상', style: text.titleSmall),
        const SizedBox(width: 8),
        if (brand != null)
          Expanded(
            child: Text('${brand.name} 기본 색상', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
          )
        else
          const Spacer(),
        if (eq.frameColor != null || eq.padColor != null || eq.shroud != null)
          TextButton(onPressed: () => state.setEquipmentLook(widget.gymId, widget.equipmentId, reset: true), child: const Text('기본으로')),
      ]),
      _ColorRow(
        label: '프레임',
        choices: frameColorChoices,
        selected: style.frame,
        onPick: (c) => state.setEquipmentLook(widget.gymId, widget.equipmentId, frame: c.toARGB32()),
      ),
      _ColorRow(
        label: '패드',
        choices: padColorChoices,
        selected: style.pad,
        onPick: (c) => state.setEquipmentLook(widget.gymId, widget.equipmentId, pad: c.toARGB32()),
      ),
      if (eq.mechanism == LoadMechanism.pin)
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: style.shroud,
          title: const Text('웨이트 스택 커버'),
          subtitle: const Text('스택이 덮개로 가려진 머신(라이프·테크노짐 등)'),
          onChanged: (v) => state.setEquipmentLook(widget.gymId, widget.equipmentId, shroud: v),
        ),
    ]);
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.label, required this.choices, required this.selected, required this.onPick});
  final String label;
  final Map<String, Color> choices;
  final Color selected;
  final void Function(Color) onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 48, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 6, children: [
            for (final e in choices.entries)
              Tooltip(
                message: e.key,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onPick(e.value),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: e.value.toARGB32() == selected.toARGB32() ? cs.primary : cs.outlineVariant,
                        width: e.value.toARGB32() == selected.toARGB32() ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
