/// 외부 에셋 없이 Dart로 그리는 저폴리 3D 기구 뷰어 (요구사항 11).
///
/// 기구를 상자/원기둥 프리미티브로 조립하고, 회전(드래그)·원근 투영·
/// 화가 알고리즘(깊이 정렬)·단순 램버트 셰이딩으로 렌더링한다.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/equipment_models.dart';
import '../../models/models.dart';

class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 scale(double s) => V3(x * s, y * s, z * s);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) =>
      V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l == 0 ? this : V3(x / l, y / l, z / l);
  }

  V3 rotateY(double a) =>
      V3(x * cos(a) + z * sin(a), y, -x * sin(a) + z * cos(a));
  V3 rotateX(double a) =>
      V3(x, y * cos(a) - z * sin(a), y * sin(a) + z * cos(a));
}

class Face {
  const Face(this.pts, this.color);
  final List<V3> pts;
  final Color color;
}

abstract class Prim {
  List<Face> faces();
}

/// 축 정렬 상자. [size]는 전체 길이(가로, 세로, 깊이).
class Box implements Prim {
  const Box(this.center, this.size, this.color);
  final V3 center, size;
  final Color color;

  @override
  List<Face> faces() {
    final hx = size.x / 2, hy = size.y / 2, hz = size.z / 2;
    V3 p(double sx, double sy, double sz) =>
        V3(center.x + sx * hx, center.y + sy * hy, center.z + sz * hz);
    return [
      Face([p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1)], color), // front
      Face([p(1, -1, -1), p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1)], color), // back
      Face([p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1), p(-1, 1, -1)], color), // top
      Face([p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1)], color), // bottom
      Face([p(1, -1, 1), p(1, -1, -1), p(1, 1, -1), p(1, 1, 1)], color), // right
      Face([p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1)], color), // left
    ];
  }
}

/// 원기둥. [axis]는 'x' | 'y' | 'z'.
class Cyl implements Prim {
  const Cyl(this.center, this.radius, this.height, this.axis, this.color,
      {this.segments = 14});
  final V3 center;
  final double radius, height;
  final String axis;
  final Color color;
  final int segments;

  V3 _pt(double a, double h) {
    final c = radius * cos(a), s = radius * sin(a);
    return switch (axis) {
      'x' => V3(center.x + h, center.y + c, center.z + s),
      'z' => V3(center.x + c, center.y + s, center.z + h),
      _ => V3(center.x + c, center.y + h, center.z + s),
    };
  }

  @override
  List<Face> faces() {
    final out = <Face>[];
    final hh = height / 2;
    final top = <V3>[], bottom = <V3>[];
    for (var i = 0; i < segments; i++) {
      final a0 = 2 * pi * i / segments, a1 = 2 * pi * (i + 1) / segments;
      out.add(Face([_pt(a0, -hh), _pt(a1, -hh), _pt(a1, hh), _pt(a0, hh)], color));
      top.add(_pt(a0, hh));
      bottom.add(_pt(a0, -hh));
    }
    out.add(Face(top, color));
    out.add(Face(bottom.reversed.toList(), color));
    return out;
  }
}

class Equipment3DView extends StatelessWidget {
  const Equipment3DView({
    super.key,
    required this.type,
    this.height = 220,
    this.autoRotate = true,
  });

  final EquipmentType type;
  final double height;
  final bool autoRotate;

  /// 기구 모델을 면 리스트로 전개. 테스트에서도 사용한다.
  static List<Face> buildFaces(EquipmentType t) =>
      [for (final p in equipmentModel(t)) ...p.faces()];

  @override
  Widget build(BuildContext context) => Scene3DView(
        faces: buildFaces(type),
        height: height,
        autoRotate: autoRotate,
      );
}

/// 면 리스트를 받아 회전·투영해 그리는 범용 3D 뷰. 기구/인체 모델이 공유한다.
class Scene3DView extends StatefulWidget {
  const Scene3DView({
    super.key,
    required this.faces,
    this.height = 220,
    this.autoRotate = true,
    this.initialYaw = -0.6,
    this.initialPitch = 0.35,
    this.hint = '드래그해서 회전',
    this.overlay,
  });

  final List<Face> faces;
  final double height;
  final bool autoRotate;
  final double initialYaw;
  final double initialPitch;
  final String hint;

  /// 범례 등 장면 위에 얹을 위젯(왼쪽 아래).
  final Widget? overlay;

  @override
  State<Scene3DView> createState() => _Scene3DViewState();
}

class _Scene3DViewState extends State<Scene3DView>
    with SingleTickerProviderStateMixin {
  late double _yaw = widget.initialYaw;
  late double _pitch = widget.initialPitch;
  late final AnimationController _ctrl;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..addListener(() {
        if (!_dragging && widget.autoRotate) {
          setState(() => _yaw += 0.006);
        }
      });
    if (widget.autoRotate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant Scene3DView old) {
    super.didUpdateWidget(old);
    if (old.initialYaw != widget.initialYaw && !_dragging) _yaw = widget.initialYaw;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanStart: (_) => setState(() => _dragging = true),
      onPanEnd: (_) => setState(() => _dragging = false),
      onPanUpdate: (d) => setState(() {
        _yaw += d.delta.dx * 0.012;
        _pitch = (_pitch + d.delta.dy * 0.012).clamp(-1.2, 1.2);
      }),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.surfaceContainerHigh, cs.surfaceContainerLowest],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ScenePainter(widget.faces, _yaw, _pitch, cs.outlineVariant),
              ),
            ),
            if (widget.overlay != null)
              Positioned(left: 10, bottom: 8, child: widget.overlay!),
            if (widget.height >= 120)
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(widget.hint,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.faces, this.yaw, this.pitch, this.floorColor);
  final List<Face> faces;
  final double yaw, pitch;
  final Color floorColor;

  static const _light = V3(0.4, 0.8, 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    // 바운딩 박스로 중심/스케일 결정
    var minV = const V3(1e9, 1e9, 1e9), maxV = const V3(-1e9, -1e9, -1e9);
    for (final f in faces) {
      for (final p in f.pts) {
        minV = V3(min(minV.x, p.x), min(minV.y, p.y), min(minV.z, p.z));
        maxV = V3(max(maxV.x, p.x), max(maxV.y, p.y), max(maxV.z, p.z));
      }
    }
    final center = (minV + maxV).scale(0.5);
    final radius = max((maxV - minV).length / 2, 0.01);
    final scale = min(size.width, size.height) * 0.42 / radius;
    final camDist = radius * 4.0;
    final light = _light.normalized;

    // 바닥 그리드
    _drawFloor(canvas, size, center, minV.y, scale, camDist, radius);

    final projected = <(double, Path, Color)>[];
    for (final f in faces) {
      final rot = f.pts.map((p) => (p - center).rotateY(yaw).rotateX(pitch)).toList();
      final n = (rot[1] - rot[0]).cross(rot[2] - rot[0]).normalized;
      // 뒷면 제거: 카메라(+z 방향에서 바라봄) 쪽을 보지 않는 면은 생략
      final toCam = V3(0, 0, camDist) - rot[0];
      if (n.dot(toCam) <= 0) continue;
      final shade = (0.45 + 0.55 * max(0, n.dot(light))).clamp(0.3, 1.0);
      final color = Color.fromARGB(
        f.color.a.toInt() == 0 ? 255 : (f.color.a * 255).round(),
        (f.color.r * 255 * shade).round().clamp(0, 255),
        (f.color.g * 255 * shade).round().clamp(0, 255),
        (f.color.b * 255 * shade).round().clamp(0, 255),
      );
      final path = Path();
      var depth = 0.0;
      for (var i = 0; i < rot.length; i++) {
        final o = _project(rot[i], size, scale, camDist);
        depth += rot[i].z;
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      path.close();
      projected.add((depth / rot.length, path, color));
    }
    projected.sort((a, b) => a.$1.compareTo(b.$1)); // 먼 것부터
    final fill = Paint()..style = PaintingStyle.fill;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0x33000000);
    for (final (_, path, color) in projected) {
      fill.color = color;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
  }

  Offset _project(V3 p, Size size, double scale, double camDist) {
    final persp = camDist / (camDist - p.z);
    return Offset(size.width / 2 + p.x * scale * persp,
        size.height / 2 - p.y * scale * persp + size.height * 0.08);
  }

  void _drawFloor(Canvas canvas, Size size, V3 center, double floorY,
      double scale, double camDist, double radius) {
    final paint = Paint()
      ..color = floorColor.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    final n = 6;
    final step = radius * 2.2 / n;
    for (var i = -n ~/ 2; i <= n ~/ 2; i++) {
      final a = V3(i * step, floorY - center.y, -radius * 1.1).rotateY(yaw).rotateX(pitch);
      final b = V3(i * step, floorY - center.y, radius * 1.1).rotateY(yaw).rotateX(pitch);
      canvas.drawLine(_project(a, size, scale, camDist), _project(b, size, scale, camDist), paint);
      final c = V3(-radius * 1.1, floorY - center.y, i * step).rotateY(yaw).rotateX(pitch);
      final d = V3(radius * 1.1, floorY - center.y, i * step).rotateY(yaw).rotateX(pitch);
      canvas.drawLine(_project(c, size, scale, camDist), _project(d, size, scale, camDist), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.yaw != yaw || old.pitch != pitch || old.faces != faces;
}
