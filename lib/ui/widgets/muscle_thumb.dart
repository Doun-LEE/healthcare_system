import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/body_model.dart';
import 'equipment_3d.dart';

/// 근육 하나를 빨갛게 칠하고 그 부위를 확대한 작은 인체 썸네일(앞/뒤 자동).
/// 상용 앱의 해부도 사진 대신 우리 3D 모델을 그대로 잘라 쓴다.
class MuscleThumb extends StatelessWidget {
  const MuscleThumb({super.key, required this.muscle, this.size = 56, this.heat});
  final Muscle muscle;
  final double size;

  /// 0~1. 없으면 주동근 빨강.
  final double? heat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final map = MuscleMap(primary: {muscle}, secondary: const {});
    final faces = bodyFaces(map, heat: heat == null ? null : {muscle: heat!});
    final (focusY, zoom) = _focus(muscle);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: cs.surfaceContainerHighest,
        child: CustomPaint(painter: _ThumbPainter(faces, yaw: muscle.back ? pi : 0, focusY: focusY, zoom: zoom)),
      ),
    );
  }

  /// 근육의 세로 위치(모델 좌표)와 확대 배율.
  static (double, double) _focus(Muscle m) => switch (m) {
        Muscle.chestUpper || Muscle.chestMid || Muscle.chestLower => (1.35, 2.3),
        Muscle.deltFront || Muscle.deltSide || Muscle.deltRear || Muscle.trapsUpper => (1.45, 2.3),
        Muscle.biceps || Muscle.triceps => (1.3, 2.2),
        Muscle.forearm => (1.0, 2.2),
        Muscle.absUpper || Muscle.absLower || Muscle.obliques => (1.13, 2.3),
        Muscle.upperBack => (1.38, 2.3),
        Muscle.lats => (1.22, 2.2),
        Muscle.lowerBack => (1.05, 2.3),
        Muscle.glutes || Muscle.hipFlexors => (0.88, 2.3),
        Muscle.quads || Muscle.hamstrings || Muscle.adductors => (0.6, 1.9),
        Muscle.calves => (0.22, 2.0),
      };
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.faces, {required this.yaw, required this.focusY, required this.zoom});
  final List<Face> faces;
  final double yaw, focusY, zoom;

  static const _light = V3(0.4, 0.8, 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;
    var minV = const V3(1e9, 1e9, 1e9), maxV = const V3(-1e9, -1e9, -1e9);
    for (final f in faces) {
      for (final p in f.pts) {
        minV = V3(min(minV.x, p.x), min(minV.y, p.y), min(minV.z, p.z));
        maxV = V3(max(maxV.x, p.x), max(maxV.y, p.y), max(maxV.z, p.z));
      }
    }
    final center = V3((minV.x + maxV.x) / 2, focusY, (minV.z + maxV.z) / 2);
    final radius = max((maxV - minV).length / 2, 0.01);
    final scale = min(size.width, size.height) * 0.42 / radius * zoom;
    final camDist = radius * 4.0;
    final light = _light.normalized;

    final projected = <(double, Path, Color)>[];
    for (final f in faces) {
      final rot = f.pts.map((p) => (p - center).rotateY(yaw)).toList();
      final n = (rot[1] - rot[0]).cross(rot[2] - rot[0]).normalized;
      final toCam = V3(0, 0, camDist) - rot[0];
      if (n.dot(toCam) <= 0) continue;
      final shade = (0.45 + 0.55 * max(0, n.dot(light))).clamp(0.3, 1.0);
      final color = Color.fromARGB(
        255,
        (f.color.r * 255 * shade).round().clamp(0, 255),
        (f.color.g * 255 * shade).round().clamp(0, 255),
        (f.color.b * 255 * shade).round().clamp(0, 255),
      );
      final path = Path();
      var depth = 0.0;
      for (var i = 0; i < rot.length; i++) {
        final persp = camDist / (camDist - rot[i].z);
        final o = Offset(size.width / 2 + rot[i].x * scale * persp, size.height / 2 - rot[i].y * scale * persp);
        depth += rot[i].z;
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      path.close();
      projected.add((depth / rot.length, path, color));
    }
    projected.sort((a, b) => a.$1.compareTo(b.$1));
    final fill = Paint()..style = PaintingStyle.fill;
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (final (_, path, color) in projected) {
      fill.color = color;
      seam.color = color;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, seam);
    }
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.faces != faces || old.yaw != yaw || old.focusY != focusY || old.zoom != zoom;
}
