import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/catalog.dart';
import '../../data/exercise_photos.dart';
import '../../models/models.dart';
import 'equipment_3d.dart';
import '../../data/equipment_models.dart';

/// 실제 사람이 운동하는 사진 두 장(시작 ↔ 끝 자세)을 번갈아 보여 동작을 보여 준다.
/// 사진: Free Exercise DB (퍼블릭 도메인). 인터넷이 없으면 숨긴다.
class ExerciseMotion extends StatefulWidget {
  const ExerciseMotion({super.key, required this.exerciseId, required this.name, this.height = 230});
  final String exerciseId;
  final String name;
  final double height;

  @override
  State<ExerciseMotion> createState() => _ExerciseMotionState();
}

class _ExerciseMotionState extends State<ExerciseMotion> {
  Timer? _timer;
  bool _end = false;
  bool _playing = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (_playing && mounted) setState(() => _end = !_end);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _img(String url) => Image.network(
        url,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        loadingBuilder: (c, child, p) => p == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (c, e, s) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_failed) setState(() => _failed = true);
          });
          return const SizedBox.shrink();
        },
      );

  @override
  Widget build(BuildContext context) {
    final urls = exercisePhotoUrls(widget.exerciseId);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final video = OutlinedButton.icon(
      icon: const Icon(Icons.play_circle_outline),
      label: const Text('영상으로 보기 (유튜브)'),
      onPressed: () => launchUrl(
        Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent('${widget.name} 자세')}'),
        mode: LaunchMode.externalApplication,
      ),
    );
    if (urls == null || _failed) {
      return Align(alignment: Alignment.centerLeft, child: video);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        onTap: () => setState(() => _playing = !_playing),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            _img(urls.$1),
            AnimatedOpacity(
              opacity: _end ? 1 : 0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut,
              child: _img(urls.$2),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  _playing ? (_end ? '끝 자세' : '시작 자세') : '멈춤 · 눌러서 재생',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: Text('실제 동작 사진 · Free Exercise DB(퍼블릭 도메인)',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
        video,
      ]),
    ]);
  }
}

/// 기구 종류의 실제 사진(사람이 쓰는 모습). 없거나 인터넷이 안 되면 3D로.
class EquipmentPhoto extends StatelessWidget {
  const EquipmentPhoto({super.key, required this.type, this.size = 56, this.height, this.style = ModelStyle.standard, this.rounded = 10});
  final EquipmentType type;
  final double size;
  final double? height;
  final ModelStyle style;
  final double rounded;

  @override
  Widget build(BuildContext context) {
    final h = height ?? size;
    final fallback = Equipment3DView(type: type, height: h, autoRotate: false, style: style);
    final url = equipmentPhotoUrl(type);
    if (url == null) return SizedBox(width: height == null ? size : null, height: h, child: fallback);
    return SizedBox(
      width: height == null ? size : null,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rounded),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (c, e, s) => fallback,
          loadingBuilder: (c, child, p) => p == null ? child : fallback,
        ),
      ),
    );
  }
}

/// 운동 썸네일: 그 운동의 실제 사진(시작 자세). 없으면 기구 사진/3D.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.exerciseId, required this.type, this.size = 48});
  final String exerciseId;
  final EquipmentType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final urls = exercisePhotoUrls(exerciseId);
    final ex = exerciseById(exerciseId);
    if (urls == null && ex != null && (ex.activity || ex.loadType == LoadType.cardio) && type == EquipmentType.bodyweight) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(10)),
        child: Icon(sportIcon(exerciseId), size: size * 0.55, color: cs.onTertiaryContainer),
      );
    }
    final fallback = EquipmentPhoto(type: type, size: size);
    if (urls == null) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          urls.$1,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (c, e, s) => fallback,
          loadingBuilder: (c, child, p) => p == null ? child : fallback,
        ),
      ),
    );
  }
}

/// 기구 사진을 크게 보여 주는 창(실제 사용 사진 + 3D + 설명). 기구를 고를 때 뭔지 확인용.
Future<void> showEquipmentPreview(BuildContext context, EquipmentType type, {String? title}) {
  final info = equipmentInfo(type);
  final hasPhoto = equipmentPhotoUrl(type) != null;
  return showDialog<void>(
    context: context,
    builder: (c) {
      final text = Theme.of(c).textTheme;
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title ?? type.label, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (title != null && title != type.label) Text(type.label, style: text.bodySmall),
            const SizedBox(height: 10),
            if (hasPhoto)
              InteractiveViewer(child: EquipmentPhoto(type: type, height: 280, rounded: 14)),
            const SizedBox(height: 8),
            Equipment3DView(type: type, height: hasPhoto ? 180 : 280),
            const SizedBox(height: 8),
            Text(info.summary, style: text.bodyMedium),
            if (info.strengths.isNotEmpty)
              Text(info.strengths.join(' · '), style: text.bodySmall),
            if (hasPhoto) Text('사진: Free Exercise DB(퍼블릭 도메인) 예시', style: text.labelSmall),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(c), child: const Text('닫기'))),
          ]),
        ),
      );
    },
  );
}


/// 스포츠·유산소 운동 아이콘(사진이 없는 운동용).
IconData sportIcon(String exerciseId) => switch (exerciseId) {
      'soccer' || 'futsal' => Icons.sports_soccer,
      'basketball' => Icons.sports_basketball,
      'swim' => Icons.pool,
      'badminton' || 'tennis' || 'table_tennis' || 'squash' => Icons.sports_tennis,
      'volleyball' => Icons.sports_volleyball,
      'baseball' => Icons.sports_baseball,
      'climbing' => Icons.terrain,
      'boxing' => Icons.sports_mma,
      'jiujitsu' => Icons.sports_kabaddi,
      'golf' => Icons.sports_golf,
      'ski' => Icons.downhill_skiing,
      'dance' => Icons.music_note,
      'hiking' || 'trail_run' => Icons.hiking,
      'outdoor_bike' || 'bike' || 'spin' || 'recumbent' => Icons.directions_bike,
      'outdoor_walk' || 'treadmill_walk' => Icons.directions_walk,
      'stairs' || 'stair_run' => Icons.stairs,
      'rowing' => Icons.rowing,
      'jump_rope' => Icons.cable,
      _ => Icons.directions_run,
    };
