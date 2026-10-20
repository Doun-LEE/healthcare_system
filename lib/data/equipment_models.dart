/// 기구별 저폴리 3D 모델 정의. 단위는 m, y축이 위.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../ui/widgets/equipment_3d.dart';

const _steel = Color(0xFF9AA3AD);
const _dark = Color(0xFF3A3F47);
const _pad = Color(0xFFC62828);
const _padDark = Color(0xFF8E1B1B);
const _plate = Color(0xFF2B2F36);
const _rubber = Color(0xFF17191C);
const _chrome = Color(0xFFCFD6DD);
const _screen = Color(0xFF2E7DFF);

List<Prim> equipmentModel(EquipmentType t) => switch (t) {
      EquipmentType.barbell => _barbell(),
      EquipmentType.dumbbell => _dumbbells(),
      EquipmentType.flatBench => _bench(incline: 0),
      EquipmentType.inclineBench => _bench(incline: 1),
      EquipmentType.squatRack => _rack(),
      EquipmentType.smithMachine => _smith(),
      EquipmentType.cableMachine => _cable(),
      EquipmentType.latPulldown => _latPulldown(),
      EquipmentType.seatedRow => _seatedRow(),
      EquipmentType.chestPress => _pressMachine(arms: true),
      EquipmentType.pecDeck => _pecDeck(),
      EquipmentType.shoulderPress => _pressMachine(arms: true, tall: true),
      EquipmentType.legPress => _legPress(),
      EquipmentType.legExtension => _legMachine(curl: false),
      EquipmentType.legCurl => _legMachine(curl: true),
      EquipmentType.hipThrust => _hipThrust(),
      EquipmentType.calfRaise => _calfRaise(),
      EquipmentType.hackSquat => _hackSquat(),
      EquipmentType.pullUpBar => _pullUpBar(),
      EquipmentType.dipStation => _dipStation(),
      EquipmentType.preacherBench => _preacher(),
      EquipmentType.abCrunchMachine => _pressMachine(arms: false),
      EquipmentType.romanChair => _romanChair(),
      EquipmentType.kettlebell => _kettlebell(),
      EquipmentType.treadmill => _treadmill(),
      EquipmentType.bike => _bike(),
      EquipmentType.rower => _rower(),
      EquipmentType.stairClimber => _stairs(),
      EquipmentType.elliptical => _elliptical(),
      EquipmentType.bodyweight => _mat(),
    };

// ── 공용 파츠 ──

List<Prim> _legs(double x, double z, double h, {double w = 0.05}) => [
      Box(V3(-x, h / 2, -z), V3(w, h, w), _dark),
      Box(V3(x, h / 2, -z), V3(w, h, w), _dark),
      Box(V3(-x, h / 2, z), V3(w, h, w), _dark),
      Box(V3(x, h / 2, z), V3(w, h, w), _dark),
    ];

List<Prim> _weightStack(V3 at, {double h = 0.9}) => [
      Box(at + V3(0, h / 2, 0), V3(0.26, h, 0.18), _plate),
      Box(at + V3(0, h + 0.3, 0), V3(0.3, 0.6, 0.04), _steel), // 가이드 프레임
      Cyl(at + V3(0, h + 0.05, 0), 0.012, h + 0.1, 'y', _chrome),
    ];

List<Prim> _seatBase({double seatH = 0.45, double z = 0}) => [
      Box(V3(0, 0.03, z), V3(0.5, 0.06, 0.6), _dark),
      Box(V3(0, seatH / 2, z), V3(0.08, seatH, 0.08), _steel),
      Box(V3(0, seatH + 0.04, z), V3(0.38, 0.08, 0.38), _pad),
    ];

// ── 모델 ──

List<Prim> _barbell() => [
      Cyl(const V3(0, 0.22, 0), 0.015, 2.2, 'x', _chrome),
      for (final s in [-1, 1]) ...[
        Cyl(V3(0.72 * s, 0.22, 0), 0.22, 0.03, 'x', _plate),
        Cyl(V3(0.76 * s, 0.22, 0), 0.22, 0.03, 'x', _plate),
        Cyl(V3(0.80 * s, 0.22, 0), 0.16, 0.025, 'x', _rubber),
        Cyl(V3(0.68 * s, 0.22, 0), 0.03, 0.02, 'x', _steel), // 조임쇠
      ],
    ];

List<Prim> _dumbbells() => [
      for (final (dz, r) in [(-0.22, 0.08), (0.0, 0.1), (0.22, 0.12)]) ...[
        Cyl(V3(0, r, dz), 0.016, 0.26, 'x', _chrome),
        Cyl(V3(-0.1, r, dz), r, 0.07, 'x', _rubber),
        Cyl(V3(0.1, r, dz), r, 0.07, 'x', _rubber),
      ],
      Box(const V3(0, 0.02, 0), const V3(0.5, 0.04, 0.7), _dark), // 거치대 바닥
    ];

List<Prim> _bench({required int incline}) {
  final parts = <Prim>[
    ..._legs(0.0, 0.5, 0.42, w: 0.06),
    Box(const V3(0, 0.1, 0), const V3(0.12, 0.06, 1.2), _dark),
  ];
  if (incline == 0) {
    parts.add(Box(const V3(0, 0.46, 0), const V3(0.3, 0.08, 1.25), _pad));
  } else {
    parts.add(Box(const V3(0, 0.44, 0.3), const V3(0.3, 0.08, 0.55), _pad)); // 시트
    // 등판: 기울어진 판을 작은 계단 상자로 근사
    for (var i = 0; i < 6; i++) {
      parts.add(Box(V3(0, 0.46 + i * 0.09, -0.05 - i * 0.075), const V3(0.32, 0.1, 0.1), _padDark));
    }
    parts.add(Box(const V3(0, 0.45, -0.45), const V3(0.08, 0.5, 0.06), _steel));
  }
  return parts;
}

List<Prim> _rack() => [
      for (final x in [-0.55, 0.55])
        for (final z in [-0.6, 0.6]) Box(V3(x, 1.1, z), const V3(0.08, 2.2, 0.08), _dark),
      for (final x in [-0.55, 0.55]) Box(V3(x, 2.18, 0), const V3(0.08, 0.08, 1.28), _dark),
      for (final z in [-0.6, 0.6]) Box(V3(0, 2.18, z), const V3(1.18, 0.08, 0.08), _dark),
      for (final z in [-0.6, 0.6]) Box(V3(0, 0.04, z), const V3(1.2, 0.08, 0.1), _dark),
      // J-hook + 바벨
      for (final x in [-0.5, 0.5]) Box(V3(x, 1.45, 0.62), const V3(0.1, 0.12, 0.1), _steel),
      Cyl(const V3(0, 1.52, 0.62), 0.015, 2.1, 'x', _chrome),
      for (final s in [-1, 1]) Cyl(V3(0.85 * s, 1.52, 0.62), 0.2, 0.03, 'x', _plate),
      // 세이프티 바
      for (final x in [-0.55, 0.55]) Box(V3(x, 0.75, 0), const V3(0.05, 0.05, 1.2), _steel),
    ];

List<Prim> _smith() => [
      for (final x in [-0.9, 0.9]) Box(V3(x, 1.1, 0), const V3(0.1, 2.2, 0.3), _dark),
      Box(const V3(0, 2.2, 0), const V3(1.9, 0.1, 0.3), _dark),
      for (final x in [-0.75, 0.75]) Cyl(V3(x, 1.1, 0.12), 0.02, 2.0, 'y', _chrome),
      Cyl(const V3(0, 1.3, 0.12), 0.016, 1.9, 'x', _chrome),
      for (final x in [-0.75, 0.75]) Box(V3(x, 1.3, 0.12), const V3(0.12, 0.14, 0.12), _steel),
      for (final s in [-1, 1]) Cyl(V3(0.84 * s, 1.3, 0.12), 0.18, 0.03, 'x', _plate),
      Box(const V3(0, 0.04, 0.4), const V3(1.9, 0.08, 1.0), _dark),
    ];

List<Prim> _cable() => [
      Box(const V3(0, 0.04, 0), const V3(2.2, 0.08, 0.7), _dark),
      for (final x in [-1.0, 1.0]) ...[
        Box(V3(x, 1.1, 0), const V3(0.12, 2.2, 0.3), _dark),
        ..._weightStack(V3(x, 0.08, 0), h: 0.7),
        Box(V3(x * 0.78, 1.3, 0.05), const V3(0.3, 0.12, 0.1), _steel), // 풀리 캐리지
        Cyl(V3(x * 0.78, 1.3, 0.12), 0.06, 0.04, 'z', _chrome),
      ],
      Box(const V3(0, 2.18, 0), const V3(2.1, 0.1, 0.25), _dark),
      Cyl(const V3(0, 2.0, 0.15), 0.014, 1.0, 'x', _chrome), // 상단 바
    ];

List<Prim> _latPulldown() => [
      Box(const V3(0, 0.04, 0.2), const V3(0.9, 0.08, 1.3), _dark),
      Box(const V3(0, 1.15, -0.4), const V3(0.12, 2.3, 0.12), _dark),
      ..._weightStack(const V3(0.3, 0.08, -0.4), h: 0.8),
      Box(const V3(0, 2.25, 0.05), const V3(0.12, 0.1, 0.9), _dark),
      Cyl(const V3(0, 2.2, 0.45), 0.05, 0.05, 'x', _chrome), // 풀리
      Cyl(const V3(0, 1.75, 0.45), 0.008, 0.9, 'y', _chrome), // 케이블
      Box(const V3(0, 1.3, 0.45), const V3(1.1, 0.04, 0.04), _steel), // 랫바
      ..._seatBase(seatH: 0.45, z: 0.4),
      Box(const V3(0, 0.82, 0.25), const V3(0.36, 0.08, 0.14), _padDark), // 허벅지 패드
      Box(const V3(0.22, 0.65, 0.25), const V3(0.04, 0.34, 0.04), _steel),
    ];

List<Prim> _seatedRow() => [
      Box(const V3(0, 0.04, 0), const V3(0.8, 0.08, 1.8), _dark),
      ..._weightStack(const V3(0, 0.08, -0.75), h: 0.8),
      Box(const V3(0, 0.75, -0.55), const V3(0.3, 0.3, 0.1), _pad), // 가슴 패드
      Box(const V3(0, 0.45, -0.55), const V3(0.08, 0.6, 0.08), _steel),
      for (final x in [-0.2, 0.2]) Box(V3(x, 0.85, -0.3), const V3(0.04, 0.04, 0.4), _chrome), // 핸들
      ..._seatBase(seatH: 0.42, z: 0.25),
      Box(const V3(0, 0.3, 0.6), const V3(0.4, 0.1, 0.15), _padDark), // 발판
    ];

List<Prim> _pressMachine({required bool arms, bool tall = false}) {
  final h = tall ? 1.9 : 1.6;
  return [
    Box(const V3(0, 0.04, 0), const V3(1.1, 0.08, 1.2), _dark),
    Box(V3(0, h / 2, -0.4), V3(0.12, h, 0.12), _dark),
    ..._weightStack(const V3(0.5, 0.08, -0.4), h: 0.8),
    ..._seatBase(seatH: 0.45, z: 0.15),
    Box(const V3(0, 0.95, -0.1), const V3(0.36, 0.7, 0.08), _pad), // 등판
    if (arms) ...[
      for (final x in [-0.3, 0.3]) ...[
        Box(V3(x, tall ? 1.5 : 1.15, -0.35), const V3(0.05, 0.05, 0.55), _steel),
        Cyl(V3(x, tall ? 1.5 : 1.15, -0.05), 0.02, 0.2, 'x', _chrome),
      ],
    ] else
      Box(const V3(0, 1.25, 0.1), const V3(0.4, 0.1, 0.1), _padDark), // 복근 패드
  ];
}

List<Prim> _pecDeck() => [
      Box(const V3(0, 0.04, 0), const V3(1.2, 0.08, 1.0), _dark),
      Box(const V3(0, 0.9, -0.35), const V3(0.12, 1.8, 0.12), _dark),
      ..._weightStack(const V3(0, 0.08, -0.6), h: 0.8),
      ..._seatBase(seatH: 0.45, z: 0.1),
      Box(const V3(0, 0.95, -0.15), const V3(0.36, 0.7, 0.08), _pad),
      Box(const V3(0, 1.6, -0.3), const V3(0.9, 0.06, 0.06), _steel),
      for (final x in [-0.42, 0.42]) ...[
        Box(V3(x, 1.25, -0.1), const V3(0.05, 0.7, 0.05), _steel),
        Box(V3(x, 1.0, 0.05), const V3(0.08, 0.35, 0.18), _padDark),
      ],
    ];

List<Prim> _legPress() => [
      Box(const V3(0, 0.04, 0), const V3(1.0, 0.08, 2.0), _dark),
      Box(const V3(0, 0.4, 0.5), const V3(0.5, 0.1, 0.7), _pad), // 시트
      for (var i = 0; i < 5; i++) Box(V3(0, 0.45 + i * 0.1, 0.9 + i * 0.07), const V3(0.5, 0.1, 0.1), _padDark),
      for (final x in [-0.4, 0.4]) Box(V3(x, 0.8, -0.3), const V3(0.08, 0.08, 1.4), _steel), // 레일
      Box(const V3(0, 1.2, -0.8), const V3(0.7, 0.6, 0.08), _dark), // 발판
      for (final x in [-0.5, 0.5]) Box(V3(x, 0.6, -0.9), const V3(0.08, 1.2, 0.08), _dark),
      for (final s in [-1, 1]) Cyl(V3(0.5 * s, 1.0, -0.6), 0.2, 0.03, 'x', _plate),
    ];

List<Prim> _legMachine({required bool curl}) => [
      Box(const V3(0, 0.04, 0), const V3(0.8, 0.08, 1.4), _dark),
      ..._weightStack(const V3(0, 0.08, -0.6), h: 0.7),
      ..._seatBase(seatH: 0.45, z: 0.1),
      Box(const V3(0, 0.95, -0.15), const V3(0.36, 0.7, 0.08), _pad),
      Box(const V3(0.25, 0.4, 0.35), const V3(0.05, 0.05, 0.5), _steel),
      Cyl(V3(0, curl ? 0.55 : 0.3, 0.6), 0.06, 0.4, 'x', _padDark), // 롤러 패드
      Cyl(const V3(0, 0.5, 0.3), 0.04, 0.42, 'x', _chrome), // 피벗
    ];

List<Prim> _hipThrust() => [
      Box(const V3(0, 0.04, 0), const V3(1.4, 0.08, 1.0), _dark),
      Box(const V3(0, 0.35, -0.35), const V3(0.8, 0.12, 0.35), _pad), // 등 받침
      Box(const V3(0, 0.1, 0.3), const V3(0.9, 0.06, 0.5), _padDark), // 발판
      Box(const V3(0, 0.7, -0.35), const V3(1.2, 0.08, 0.08), _steel), // 벨트 바
      for (final s in [-1, 1]) Cyl(V3(0.6 * s, 0.6, -0.3), 0.18, 0.04, 'x', _plate),
    ];

List<Prim> _calfRaise() => [
      Box(const V3(0, 0.04, 0), const V3(0.9, 0.08, 1.0), _dark),
      Box(const V3(0, 0.15, 0.1), const V3(0.5, 0.15, 0.3), _padDark), // 발판
      Box(const V3(0, 1.0, -0.3), const V3(0.12, 2.0, 0.12), _dark),
      ..._weightStack(const V3(0, 0.08, -0.5), h: 0.8),
      for (final x in [-0.22, 0.22]) ...[
        Box(V3(x, 1.4, -0.15), const V3(0.05, 0.9, 0.05), _steel),
        Box(V3(x, 1.5, 0.05), const V3(0.12, 0.1, 0.35), _pad), // 어깨 패드
      ],
    ];

List<Prim> _hackSquat() => [
      Box(const V3(0, 0.04, 0), const V3(1.1, 0.08, 1.8), _dark),
      for (var i = 0; i < 7; i++) Box(V3(0, 0.3 + i * 0.16, -0.1 - i * 0.12), const V3(0.6, 0.16, 0.14), _pad),
      Box(const V3(0, 0.12, 0.6), const V3(0.6, 0.1, 0.5), _padDark), // 발판
      for (final x in [-0.45, 0.45]) ...[
        Box(V3(x, 0.9, -0.5), const V3(0.08, 1.8, 0.08), _dark),
        Box(V3(x, 1.35, -0.2), const V3(0.1, 0.1, 0.4), _steel), // 어깨 패드
      ],
      for (final s in [-1, 1]) Cyl(V3(0.6 * s, 1.0, -0.6), 0.18, 0.03, 'x', _plate),
    ];

List<Prim> _pullUpBar() => [
      for (final x in [-0.6, 0.6]) Box(V3(x, 1.15, 0), const V3(0.08, 2.3, 0.08), _dark),
      Box(const V3(0, 0.04, 0), const V3(1.4, 0.08, 0.8), _dark),
      Cyl(const V3(0, 2.28, 0), 0.016, 1.3, 'x', _chrome),
      for (final x in [-0.3, 0.3]) ...[
        Box(V3(x, 2.28, -0.2), const V3(0.03, 0.03, 0.4), _chrome),
        Cyl(V3(x, 2.28, -0.4), 0.016, 0.3, 'z', _chrome),
      ],
    ];

List<Prim> _dipStation() => [
      for (final x in [-0.3, 0.3]) ...[
        Box(V3(x, 0.6, 0), const V3(0.06, 1.2, 0.06), _dark),
        Cyl(V3(x, 1.22, 0), 0.02, 0.6, 'z', _chrome), // 평행 손잡이
      ],
      Box(const V3(0, 0.04, 0), const V3(0.9, 0.08, 0.8), _dark),
      Box(const V3(0, 0.9, -0.35), const V3(0.6, 0.6, 0.06), _pad), // 등판(레그레이즈용)
    ];

List<Prim> _preacher() => [
      ..._seatBase(seatH: 0.5, z: 0.3),
      Box(const V3(0, 0.8, -0.15), const V3(0.1, 0.6, 0.08), _steel),
      for (var i = 0; i < 4; i++) Box(V3(0, 0.95 + i * 0.07, -0.05 - i * 0.06), const V3(0.5, 0.08, 0.1), _padDark),
      Cyl(const V3(0, 1.25, -0.45), 0.015, 1.0, 'x', _chrome), // EZ바
      for (final s in [-1, 1]) Cyl(V3(0.42 * s, 1.25, -0.45), 0.1, 0.03, 'x', _plate),
    ];

List<Prim> _romanChair() => [
      Box(const V3(0, 0.04, 0), const V3(0.7, 0.08, 1.3), _dark),
      Box(const V3(0, 0.5, -0.3), const V3(0.1, 1.0, 0.1), _steel),
      // 45도 패드
      for (var i = 0; i < 5; i++) Box(V3(0, 0.6 + i * 0.09, -0.1 + i * 0.09), const V3(0.45, 0.1, 0.12), _pad),
      Box(const V3(0, 0.35, 0.5), const V3(0.5, 0.08, 0.15), _padDark), // 발목 패드
      Box(const V3(0, 0.2, 0.55), const V3(0.5, 0.06, 0.2), _dark), // 발판
    ];

List<Prim> _kettlebell() => [
      Cyl(const V3(0, 0.14, 0), 0.14, 0.26, 'y', _rubber, segments: 16),
      Cyl(const V3(0, 0.26, 0), 0.1, 0.06, 'y', _rubber),
      Box(const V3(0, 0.37, 0), const V3(0.22, 0.04, 0.04), _steel),
      for (final x in [-0.09, 0.09]) Box(V3(x, 0.32, 0), const V3(0.04, 0.1, 0.04), _steel),
    ];

List<Prim> _treadmill() => [
      Box(const V3(0, 0.08, 0.2), const V3(0.75, 0.12, 1.7), _dark),
      Box(const V3(0, 0.15, 0.2), const V3(0.5, 0.02, 1.5), _rubber), // 벨트
      for (final x in [-0.38, 0.38]) ...[
        Box(V3(x, 0.7, -0.65), const V3(0.06, 1.3, 0.06), _steel),
        Box(V3(x, 1.0, -0.3), const V3(0.05, 0.05, 0.8), _steel), // 핸들
      ],
      Box(const V3(0, 1.35, -0.7), const V3(0.75, 0.3, 0.1), _dark), // 콘솔
      Box(const V3(0, 1.38, -0.64), const V3(0.45, 0.18, 0.02), _screen),
    ];

List<Prim> _bike() => [
      Box(const V3(0, 0.03, 0), const V3(0.5, 0.06, 1.0), _dark),
      Box(const V3(0, 0.45, -0.1), const V3(0.12, 0.9, 0.12), _dark), // 프레임
      Cyl(const V3(0, 0.45, 0.0), 0.2, 0.1, 'x', _rubber, segments: 18), // 플라이휠
      Box(const V3(0, 0.85, 0.3), const V3(0.06, 0.6, 0.06), _steel),
      Box(const V3(0, 1.0, 0.3), const V3(0.3, 0.06, 0.25), _pad), // 안장
      Box(const V3(0, 1.0, -0.4), const V3(0.06, 0.5, 0.06), _steel),
      Cyl(const V3(0, 1.25, -0.45), 0.02, 0.5, 'x', _chrome), // 핸들
      Box(const V3(0, 1.3, -0.4), const V3(0.25, 0.15, 0.03), _screen),
    ];

List<Prim> _rower() => [
      Box(const V3(0, 0.3, 0.3), const V3(0.14, 0.1, 1.9), _steel), // 레일
      for (final z in [-0.6, 1.2]) Box(V3(0, 0.15, z), const V3(0.5, 0.3, 0.1), _dark),
      Box(const V3(0, 0.38, 0.4), const V3(0.3, 0.06, 0.3), _pad), // 시트
      Cyl(const V3(0, 0.45, -0.75), 0.25, 0.14, 'z', _rubber, segments: 18), // 팬 케이스
      Box(const V3(0, 0.75, -0.75), const V3(0.2, 0.15, 0.03), _screen),
      for (final x in [-0.2, 0.2]) Box(V3(x, 0.2, -0.45), const V3(0.12, 0.25, 0.08), _padDark), // 발판
      Cyl(const V3(0, 0.55, -0.2), 0.015, 0.4, 'x', _chrome), // 핸들
    ];

List<Prim> _stairs() => [
      Box(const V3(0, 0.04, 0.1), const V3(0.8, 0.08, 1.2), _dark),
      Box(const V3(0, 1.0, -0.45), const V3(0.7, 2.0, 0.3), _dark),
      for (var i = 0; i < 4; i++) Box(V3(0, 0.3 + i * 0.2, 0.3 - i * 0.2), const V3(0.5, 0.06, 0.25), _rubber),
      for (final x in [-0.38, 0.38]) Box(V3(x, 1.2, 0.1), const V3(0.05, 0.05, 0.8), _steel),
      Box(const V3(0, 1.9, -0.28), const V3(0.4, 0.2, 0.03), _screen),
    ];

List<Prim> _elliptical() => [
      Box(const V3(0, 0.05, 0), const V3(0.6, 0.1, 1.6), _dark),
      Cyl(const V3(0, 0.4, -0.6), 0.28, 0.2, 'x', _dark, segments: 18),
      for (final x in [-0.2, 0.2]) ...[
        Box(V3(x, 0.3, 0.2), const V3(0.12, 0.04, 0.5), _padDark), // 페달
        Box(V3(x, 1.0, -0.2), const V3(0.04, 1.4, 0.04), _steel), // 무빙암
      ],
      Box(const V3(0, 0.8, -0.65), const V3(0.08, 1.6, 0.08), _steel),
      Box(const V3(0, 1.55, -0.6), const V3(0.35, 0.2, 0.03), _screen),
    ];

List<Prim> _mat() => [
      Box(const V3(0, 0.01, 0), const V3(0.6, 0.02, 1.8), _pad),
      Cyl(const V3(0.5, 0.08, -0.6), 0.08, 0.6, 'z', _padDark), // 폼롤러
    ];
