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
      // 프리웨이트
      EquipmentType.barbell => _barbell(),
      EquipmentType.dumbbell => _dumbbells(),
      EquipmentType.kettlebell => _kettlebell(),
      EquipmentType.ezBar => _barbell(length: 1.2, plate: 0.14, bent: true),
      EquipmentType.trapBar => _trapBar(),
      EquipmentType.safetySquatBar => _barbell(length: 2.2, plate: 0.2, pads: true),
      EquipmentType.fixedBarbell => _barbell(length: 1.1, plate: 0.1),
      EquipmentType.medicineBall => _ball(),
      // 벤치·랙
      EquipmentType.flatBench => _bench(incline: 0),
      EquipmentType.inclineBench => _bench(incline: 1),
      EquipmentType.declineBench => _bench(incline: -1),
      EquipmentType.squatRack => _rack(),
      EquipmentType.halfRack => _rack(half: true),
      EquipmentType.smithMachine => _smith(),
      EquipmentType.preacherBench => _preacher(),
      EquipmentType.pullUpBar => _pullUpBar(),
      EquipmentType.dipStation => _dipStation(),
      EquipmentType.assistedPullUp => _assistedPullUp(),
      EquipmentType.ghd => _ghd(),
      EquipmentType.multiStation => _cable(),
      // 가슴
      EquipmentType.chestPress => _pressMachine(arms: true),
      EquipmentType.inclineChestPress => _pressMachine(arms: true, tall: true),
      EquipmentType.declineChestPress => _pressMachine(arms: true),
      EquipmentType.chestPressPlateLoaded => _pressMachine(arms: true, plateLoaded: true),
      EquipmentType.pecDeck => _pecDeck(),
      EquipmentType.cableMachine => _cable(),
      EquipmentType.functionalTrainer => _cable(),
      // 등
      EquipmentType.latPulldown => _latPulldown(),
      EquipmentType.latPulldownPlateLoaded => _latPulldown(),
      EquipmentType.seatedRow => _seatedRow(),
      EquipmentType.chestSupportedRow => _seatedRow(),
      EquipmentType.highRow => _pressMachine(arms: true, tall: true, plateLoaded: true),
      EquipmentType.lowRow => _seatedRow(plateLoaded: true),
      EquipmentType.tBarRow => _seatedRow(plateLoaded: true),
      EquipmentType.pulloverMachine => _pulloverMachine(),
      EquipmentType.shrugMachine => _shrugMachine(),
      EquipmentType.backExtensionMachine => _backExtMachine(),
      EquipmentType.romanChair => _romanChair(),
      EquipmentType.reverseHyper => _reverseHyper(),
      // 어깨
      EquipmentType.shoulderPress => _pressMachine(arms: true, tall: true),
      EquipmentType.shoulderPressPlateLoaded => _pressMachine(arms: true, tall: true, plateLoaded: true),
      EquipmentType.lateralRaiseMachine => _lateralRaiseMachine(),
      EquipmentType.rearDeltMachine => _pecDeck(),
      // 팔
      EquipmentType.bicepCurlMachine => _armMachine(curl: true),
      EquipmentType.preacherCurlMachine => _armMachine(curl: true),
      EquipmentType.tricepExtensionMachine => _armMachine(curl: false),
      EquipmentType.dipMachine => _dipMachine(),
      // 하체
      EquipmentType.legPress => _legPress(),
      EquipmentType.horizontalLegPress => _legMachine(curl: false),
      EquipmentType.hackSquat => _hackSquat(),
      EquipmentType.pendulumSquat => _hackSquat(),
      EquipmentType.vSquat => _hackSquat(),
      EquipmentType.beltSquat => _beltSquat(),
      EquipmentType.legExtension => _legMachine(curl: false),
      EquipmentType.legCurl => _legMachine(curl: true),
      EquipmentType.lyingLegCurl => _lyingLegCurl(),
      EquipmentType.standingLegCurl => _standingLegCurl(),
      EquipmentType.multiHip => _multiHip(),
      EquipmentType.hipAbductor => _hipAbAd(out: true),
      EquipmentType.hipAdductor => _hipAbAd(out: false),
      EquipmentType.hipThrust => _hipThrust(),
      EquipmentType.gluteKickback => _gluteKickback(),
      EquipmentType.calfRaise => _calfRaise(),
      EquipmentType.seatedCalfRaise => _seatedCalf(),
      EquipmentType.sissySquat => _sissySquat(),
      EquipmentType.nordicBench => _nordicBench(),
      // 복근·코어
      EquipmentType.abCrunchMachine => _abCrunchMachine(),
      EquipmentType.torsoRotation => _torsoRotation(),
      EquipmentType.captainsChair => _captainsChair(),
      EquipmentType.declineAbBench => _bench(incline: -1),
      EquipmentType.abWheel => _abWheel(),
      EquipmentType.abCoaster => _abCoaster(),
      EquipmentType.monsterGlute => _monsterGlute(),
      // 유산소
      EquipmentType.treadmill => _treadmill(),
      EquipmentType.curvedTreadmill => _curvedTreadmill(),
      EquipmentType.bike => _bike(),
      EquipmentType.spinBike => _bike(),
      EquipmentType.recumbentBike => _recumbentBike(),
      EquipmentType.assaultBike => _assaultBike(),
      EquipmentType.rower => _rower(),
      EquipmentType.skiErg => _skiErg(),
      EquipmentType.stairClimber => _stairs(),
      EquipmentType.elliptical => _elliptical(),
      EquipmentType.jacobsLadder => _jacobsLadder(),
      EquipmentType.versaClimber => _versaClimber(),
      EquipmentType.jumpRope => _jumpRope(),
      EquipmentType.outdoor => _outdoor(),
      EquipmentType.pool => _pool(),
      // 기능성·기타
      EquipmentType.landmine => _landmine(),
      EquipmentType.sled => _sled(),
      EquipmentType.battleRope => _battleRope(),
      EquipmentType.plyoBox => _plyoBox(),
      EquipmentType.trx => _trx(),
      EquipmentType.resistanceBand => _band(),
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

List<Prim> _barbell({double length = 2.2, double plate = 0.22, bool bent = false, bool pads = false}) {
  final y = plate;
  final sleeve = length / 2 - 0.3;
  return [
    if (bent) ...[
      Cyl(V3(0, y, 0), 0.015, length * 0.45, 'x', _chrome),
      for (final s in [-1, 1]) ...[
        Box(V3(0.28 * s, y + 0.03, 0), const V3(0.12, 0.03, 0.03), _chrome),
        Cyl(V3((length * 0.225 + 0.2) * s, y, 0), 0.015, 0.4, 'x', _chrome),
      ],
    ] else
      Cyl(V3(0, y, 0), 0.015, length, 'x', _chrome),
    if (pads) ...[
      Box(V3(0, y + 0.06, 0), const V3(0.5, 0.1, 0.14), _padDark), // 어깨 패드
      for (final s in [-1, 1]) Box(V3(0.18 * s, y - 0.1, 0.15), const V3(0.05, 0.25, 0.05), _steel), // 핸들
    ],
    for (final s in [-1, 1]) ...[
      Cyl(V3((sleeve + 0.02) * s, y, 0), plate, 0.03, 'x', _plate),
      Cyl(V3((sleeve + 0.06) * s, y, 0), plate, 0.03, 'x', _plate),
      Cyl(V3((sleeve + 0.10) * s, y, 0), plate * 0.75, 0.025, 'x', _rubber),
      Cyl(V3((sleeve - 0.02) * s, y, 0), 0.03, 0.02, 'x', _steel), // 조임쇠
    ],
  ];
}

List<Prim> _trapBar() => [
      for (final z in [-0.3, 0.3]) Cyl(V3(0, 0.22, z), 0.014, 1.2, 'x', _chrome),
      for (final x in [-0.6, 0.6]) Cyl(V3(x, 0.22, 0), 0.014, 0.6, 'z', _chrome),
      for (final x in [-0.3, 0.3]) ...[
        Box(V3(x, 0.3, 0.3), const V3(0.03, 0.16, 0.03), _steel),
        Box(V3(x, 0.3, -0.3), const V3(0.03, 0.16, 0.03), _steel),
        Cyl(V3(x, 0.38, 0), 0.016, 0.6, 'z', _chrome), // 손잡이
      ],
      for (final s in [-1, 1]) ...[
        Cyl(V3(0.85 * s, 0.22, 0), 0.22, 0.03, 'x', _plate),
        Cyl(V3(0.89 * s, 0.22, 0), 0.22, 0.03, 'x', _plate),
      ],
    ];

List<Prim> _ball() => [
      Cyl(const V3(0, 0.18, 0), 0.18, 0.2, 'y', _rubber, segments: 18),
      Cyl(const V3(0, 0.3, 0), 0.11, 0.05, 'y', _rubber, segments: 18),
      Cyl(const V3(0, 0.06, 0), 0.11, 0.05, 'y', _rubber, segments: 18),
      Cyl(const V3(0.45, 0.14, 0.1), 0.14, 0.16, 'y', _padDark, segments: 16),
      Cyl(const V3(0.45, 0.23, 0.1), 0.08, 0.04, 'y', _padDark),
    ];

List<Prim> _assistedPullUp() => [
      Box(const V3(0, 0.04, 0), const V3(1.1, 0.08, 1.2), _dark),
      for (final x in [-0.5, 0.5]) Box(V3(x, 1.15, -0.3), const V3(0.08, 2.3, 0.08), _dark),
      Box(const V3(0, 2.3, -0.3), const V3(1.1, 0.08, 0.08), _dark),
      Cyl(const V3(0, 2.3, 0.1), 0.016, 1.0, 'x', _chrome), // 풀업 바
      for (final x in [-0.35, 0.35]) Cyl(V3(x, 1.4, 0.15), 0.02, 0.5, 'z', _chrome), // 딥 손잡이
      Box(const V3(0, 0.7, 0.1), const V3(0.4, 0.08, 0.35), _pad), // 무릎 패드
      Box(const V3(0, 0.35, 0.1), const V3(0.08, 0.7, 0.08), _steel),
      ..._weightStack(const V3(0, 0.08, -0.5), h: 0.9),
      for (final x in [-0.45, 0.45]) Box(V3(x, 0.4, 0.4), const V3(0.15, 0.05, 0.3), _padDark), // 발판
    ];

List<Prim> _ghd() => [
      Box(const V3(0, 0.04, 0), const V3(0.7, 0.08, 1.6), _dark),
      Box(const V3(0, 0.45, 0.3), const V3(0.1, 0.9, 0.1), _steel),
      for (final x in [-0.15, 0.15]) Cyl(V3(x, 0.85, 0.35), 0.13, 0.22, 'x', _pad, segments: 16), // 둥근 허벅지 패드
      Box(const V3(0, 0.35, -0.5), const V3(0.1, 0.7, 0.1), _steel),
      for (final x in [-0.15, 0.15]) ...[
        Cyl(V3(x, 0.72, -0.55), 0.05, 0.16, 'x', _padDark), // 발목 롤러
        Cyl(V3(x, 0.52, -0.55), 0.05, 0.16, 'x', _padDark),
      ],
      Box(const V3(0, 0.45, -0.6), const V3(0.5, 0.08, 0.3), _dark), // 발판
    ];

List<Prim> _beltSquat() => [
      Box(const V3(0, 0.08, 0), const V3(1.2, 0.16, 1.0), _dark), // 플랫폼
      Box(const V3(0, 0.6, -0.6), const V3(0.3, 1.2, 0.2), _dark),
      Box(const V3(0, 1.0, -0.2), const V3(0.08, 0.08, 0.7), _steel), // 레버 암
      Cyl(const V3(0, 0.8, 0.15), 0.012, 0.6, 'y', _chrome), // 벨트 체인
      Box(const V3(0, 1.1, 0.15), const V3(0.35, 0.08, 0.2), _padDark), // 벨트
      for (final s in [-1, 1]) Cyl(V3(0.25 * s, 1.0, -0.55), 0.18, 0.03, 'x', _plate),
    ];

List<Prim> _lyingLegCurl() => [
      Box(const V3(0, 0.04, 0), const V3(0.8, 0.08, 1.6), _dark),
      ..._legs(0.25, 0.6, 0.6),
      Box(const V3(0, 0.62, 0.3), const V3(0.4, 0.08, 0.7), _pad), // 상체 패드
      for (var i = 0; i < 3; i++) Box(V3(0, 0.66 + i * 0.06, -0.15 - i * 0.12), const V3(0.4, 0.08, 0.14), _padDark), // 꺾인 허벅지 패드
      Cyl(const V3(0, 0.5, -0.65), 0.06, 0.4, 'x', _padDark), // 발목 롤러
      Box(const V3(0.25, 0.45, -0.4), const V3(0.04, 0.04, 0.5), _steel),
      ..._weightStack(const V3(0, 0.08, 0.75), h: 0.7),
    ];

List<Prim> _captainsChair() => [
      Box(const V3(0, 0.04, 0), const V3(1.0, 0.08, 0.9), _dark),
      for (final x in [-0.4, 0.4]) Box(V3(x, 0.9, -0.3), const V3(0.08, 1.8, 0.08), _dark),
      Box(const V3(0, 1.3, -0.3), const V3(0.7, 0.6, 0.06), _pad), // 등판
      for (final x in [-0.4, 0.4]) ...[
        Box(V3(x, 1.5, 0.0), const V3(0.12, 0.08, 0.5), _padDark), // 팔꿈치 패드
        Cyl(V3(x, 1.55, 0.3), 0.018, 0.2, 'y', _chrome), // 손잡이
      ],
      for (final x in [-0.4, 0.4]) Box(V3(x, 0.3, 0.2), const V3(0.15, 0.04, 0.3), _dark), // 발판
    ];

List<Prim> _abWheel() => [
      Cyl(const V3(0, 0.12, 0), 0.12, 0.08, 'x', _rubber, segments: 18),
      Cyl(const V3(0, 0.12, 0), 0.012, 0.5, 'x', _chrome),
      for (final s in [-1, 1]) Cyl(V3(0.18 * s, 0.12, 0), 0.02, 0.14, 'x', _padDark), // 손잡이
      Box(const V3(0, 0.01, 0), const V3(0.6, 0.02, 1.2), _pad), // 매트
    ];

List<Prim> _skiErg() => [
      Box(const V3(0, 0.04, 0), const V3(0.6, 0.08, 0.8), _dark),
      Box(const V3(0, 1.1, -0.3), const V3(0.12, 2.2, 0.12), _dark),
      Cyl(const V3(0, 1.9, -0.3), 0.25, 0.16, 'z', _rubber, segments: 18), // 팬
      Box(const V3(0, 1.5, -0.2), const V3(0.2, 0.15, 0.03), _screen),
      for (final x in [-0.2, 0.2]) ...[
        Cyl(V3(x, 1.6, 0.0), 0.008, 0.7, 'y', _chrome), // 줄
        Box(V3(x, 1.25, 0.0), const V3(0.04, 0.12, 0.04), _padDark), // 손잡이
      ],
    ];

List<Prim> _landmine() => [
      Box(const V3(0, 0.03, 0.5), const V3(0.4, 0.06, 0.4), _dark), // 베이스
      Cyl(const V3(0, 0.12, 0.5), 0.05, 0.12, 'y', _steel), // 피벗
      Box(const V3(0, 0.55, 0.0), const V3(0.03, 0.03, 1.5), _chrome), // 바(기울어진 근사)
      Box(const V3(0, 0.85, -0.6), const V3(0.03, 0.6, 0.03), _chrome),
      for (final s in [-1, 1]) Cyl(V3(0.05 * s, 1.1, -0.65), 0.18, 0.03, 'x', _plate),
    ];

List<Prim> _sled() => [
      Box(const V3(0, 0.05, 0), const V3(0.7, 0.04, 1.0), _dark),
      for (final x in [-0.3, 0.3]) Box(V3(x, 0.03, 0), const V3(0.06, 0.06, 1.1), _steel), // 스키
      Cyl(const V3(0, 0.3, 0), 0.04, 0.5, 'y', _steel), // 중앙 기둥
      for (final x in [-0.3, 0.3]) Box(V3(x, 0.6, 0.4), const V3(0.05, 1.1, 0.05), _steel), // 푸시 핸들
      Cyl(const V3(0, 0.45, 0), 0.22, 0.04, 'y', _plate),
      Cyl(const V3(0, 0.5, 0), 0.22, 0.04, 'y', _plate),
    ];

List<Prim> _plyoBox() => [
      Box(const V3(0, 0.3, 0), const V3(0.6, 0.6, 0.75), _dark),
      Box(const V3(0, 0.6, 0), const V3(0.62, 0.02, 0.77), _padDark),
      Box(const V3(0.9, 0.2, 0), const V3(0.5, 0.4, 0.6), _steel),
    ];

List<Prim> _trx() => [
      Box(const V3(0, 2.3, 0), const V3(1.6, 0.08, 0.08), _dark),
      Cyl(const V3(0, 1.85, 0), 0.012, 0.9, 'y', _rubber), // 메인 스트랩
      for (final x in [-0.25, 0.25]) ...[
        Box(V3(x, 1.2, 0), const V3(0.03, 0.9, 0.01), _pad), // 갈라진 스트랩
        Cyl(V3(x, 0.72, 0), 0.02, 0.14, 'x', _padDark), // 손잡이
      ],
      Box(const V3(0, 0.01, 0.2), const V3(0.8, 0.02, 1.2), _dark),
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
  } else if (incline < 0) {
    // 디클라인: 발 쪽이 높고 머리 쪽이 낮다 + 발목 롤러
    for (var i = 0; i < 6; i++) {
      parts.add(Box(V3(0, 0.3 + i * 0.05, -0.5 + i * 0.2), const V3(0.3, 0.08, 0.22), _pad));
    }
    parts.add(Cyl(const V3(0, 0.75, 0.62), 0.06, 0.4, 'x', _padDark));
    parts.add(Cyl(const V3(0, 0.5, 0.62), 0.06, 0.4, 'x', _padDark));
    parts.add(Box(const V3(0, 0.45, 0.6), const V3(0.06, 0.6, 0.06), _steel));
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

List<Prim> _rack({bool half = false}) => [
      for (final x in [-0.55, 0.55])
        for (final z in half ? [0.6] : [-0.6, 0.6]) Box(V3(x, 1.1, z), const V3(0.08, 2.2, 0.08), _dark),
      if (!half) for (final x in [-0.55, 0.55]) Box(V3(x, 2.18, 0), const V3(0.08, 0.08, 1.28), _dark),
      for (final z in half ? [0.6] : [-0.6, 0.6]) Box(V3(0, 2.18, z), const V3(1.18, 0.08, 0.08), _dark),
      for (final z in [-0.6, 0.6]) Box(V3(0, 0.04, z), const V3(1.2, 0.08, 0.1), _dark),
      if (half) for (final x in [-0.55, 0.55]) Box(V3(x, 0.04, 0), const V3(0.1, 0.08, 1.2), _dark),
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

List<Prim> _seatedRow({bool plateLoaded = false}) => [
      Box(const V3(0, 0.04, 0), const V3(0.8, 0.08, 1.8), _dark),
      if (plateLoaded) ...[
        for (final x in [-0.35, 0.35]) ...[
          Box(V3(x, 0.7, -0.8), const V3(0.05, 1.3, 0.05), _steel),
          Cyl(V3(x, 1.1, -0.85), 0.18, 0.03, 'x', _plate),
        ],
      ] else
        ..._weightStack(const V3(0, 0.08, -0.75), h: 0.8),
      Box(const V3(0, 0.75, -0.55), const V3(0.3, 0.3, 0.1), _pad), // 가슴 패드
      Box(const V3(0, 0.45, -0.55), const V3(0.08, 0.6, 0.08), _steel),
      for (final x in [-0.2, 0.2]) Box(V3(x, 0.85, -0.3), const V3(0.04, 0.04, 0.4), _chrome), // 핸들
      ..._seatBase(seatH: 0.42, z: 0.25),
      Box(const V3(0, 0.3, 0.6), const V3(0.4, 0.1, 0.15), _padDark), // 발판
    ];

List<Prim> _pressMachine({required bool arms, bool tall = false, bool plateLoaded = false}) {
  final h = tall ? 1.9 : 1.6;
  return [
    Box(const V3(0, 0.04, 0), const V3(1.1, 0.08, 1.2), _dark),
    Box(V3(0, h / 2, -0.4), V3(0.12, h, 0.12), _dark),
    if (plateLoaded) ...[
      for (final x in [-0.5, 0.5]) ...[
        Box(V3(x, h * 0.55, -0.3), V3(0.05, 0.05, 0.7), _steel), // 레버 암
        Cyl(V3(x, h * 0.55, -0.55), 0.18, 0.03, 'x', _plate),
        Cyl(V3(x, h * 0.55, -0.6), 0.18, 0.03, 'x', _plate),
      ],
    ] else
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

List<Prim> _outdoor() => [
      // 산(삼각 근사)과 길
      for (var i = 0; i < 6; i++)
        Box(V3(-0.3, 0.1 + i * 0.2, 0), V3(1.4 - i * 0.22, 0.2, 1.0 - i * 0.15), const Color(0xFF4E7D3A)),
      Box(const V3(0.9, 0.03, 0.2), const V3(0.8, 0.06, 0.5), const Color(0xFF8A7B6A)), // 흙길
      Cyl(const V3(0.9, 0.35, -0.2), 0.03, 0.5, 'y', const Color(0xFF6B4F2A)), // 나무
      Cyl(const V3(0.9, 0.7, -0.2), 0.22, 0.3, 'y', const Color(0xFF3F8F3A), segments: 10),
    ];

List<Prim> _pool() => [
      Box(const V3(0, 0.15, 0), const V3(2.0, 0.3, 1.0), const Color(0xFFCFD6DD)), // 풀 테두리
      Box(const V3(0, 0.28, 0), const V3(1.8, 0.06, 0.8), const Color(0xFF3FA7E0)), // 물
      for (final z in [-0.2, 0.2]) Box(V3(0, 0.32, z), const V3(1.8, 0.02, 0.03), const Color(0xFFE53935)), // 레인
      Box(const V3(1.05, 0.5, 0.3), const V3(0.1, 0.4, 0.1), const Color(0xFF9AA3AD)), // 사다리
    ];

List<Prim> _mat() => [
      Box(const V3(0, 0.01, 0), const V3(0.6, 0.02, 1.8), _pad),
      Cyl(const V3(0.5, 0.08, -0.6), 0.08, 0.6, 'z', _padDark), // 폼롤러
    ];

// ── 전용 모델 (실제 기구 형태에 가깝게) ──

/// 몬스터 글루트: 가슴 패드에 상체를 기대고 양발 발판을 뒤로 밀며 고관절을 편다. 원판 로딩.
List<Prim> _monsterGlute() => [
      // 베이스 레일
      Box(const V3(0, 0.04, 0), const V3(0.3, 0.08, 1.5), _dark),
      Box(const V3(-0.55, 0.04, 0.1), const V3(0.08, 0.08, 1.2), _dark),
      Box(const V3(0.55, 0.04, 0.1), const V3(0.08, 0.08, 1.2), _dark),
      Box(const V3(0, 0.04, -0.6), const V3(1.2, 0.08, 0.1), _dark),
      // 뒤 기둥 + 가슴 패드 + 헤드 패드
      Box(const V3(0, 0.75, -0.55), const V3(0.12, 1.5, 0.12), _dark),
      Box(const V3(0, 1.1, -0.4), const V3(0.42, 0.6, 0.12), _pad),
      Box(const V3(0, 1.55, -0.42), const V3(0.24, 0.26, 0.1), _padDark),
      // 손잡이
      for (final x in [-0.32, 0.32]) ...[
        Box(V3(x, 1.0, -0.3), const V3(0.05, 0.05, 0.4), _steel),
        Cyl(V3(x, 1.0, -0.05), 0.02, 0.16, 'z', _chrome),
      ],
      // 중심 피벗 축과 양쪽 레버 암 + 발판
      Cyl(const V3(0, 0.32, -0.15), 0.03, 1.0, 'x', _steel),
      for (final x in [-0.32, 0.32]) ...[
        Box(V3(x, 0.32, 0.15), const V3(0.06, 0.06, 0.6), _steel),
        Box(V3(x, 0.5, 0.42), const V3(0.32, 0.36, 0.08), _padDark), // 발판(앞쪽, 세워진)
        Box(V3(x, 0.33, 0.42), const V3(0.32, 0.04, 0.16), _padDark), // 발판 바닥
      ],
      // 옆 프레임 + 원판 거치 암
      for (final s in [-1, 1]) ...[
        Box(V3(0.55 * s, 0.4, -0.2), const V3(0.06, 0.8, 0.06), _dark),
        Cyl(V3(0.72 * s, 0.55, -0.3), 0.022, 0.3, 'x', _chrome),
        Cyl(V3(0.8 * s, 0.55, -0.3), 0.2, 0.04, 'x', _plate),
      ],
    ];

/// 멀티 힙: 플랫폼에 서서 허벅지에 롤러 패드를 걸고 앞/뒤/옆으로 다리를 민다.
List<Prim> _multiHip() => [
      Box(const V3(0, 0.1, 0.25), const V3(0.6, 0.2, 0.6), _dark), // 플랫폼
      Box(const V3(0, 1.0, -0.4), const V3(0.12, 2.0, 0.12), _dark),
      ..._weightStack(const V3(0, 0.08, -0.65), h: 0.9),
      Cyl(const V3(0, 1.1, -0.3), 0.03, 0.4, 'z', _steel), // 피벗
      Box(const V3(0.0, 0.8, -0.05), const V3(0.06, 0.6, 0.06), _steel), // 스윙 암
      Cyl(const V3(0, 0.55, -0.05), 0.07, 0.3, 'x', _pad), // 롤러 패드
      Box(const V3(0.35, 1.2, -0.2), const V3(0.05, 0.05, 0.5), _chrome), // 손잡이
      Box(const V3(-0.35, 1.2, -0.2), const V3(0.05, 0.05, 0.5), _chrome),
    ];

/// 글루트 킥백 머신: 가슴 패드에 기대고 한 발을 발판에 올려 뒤로 민다.
List<Prim> _gluteKickback() => [
      Box(const V3(0, 0.04, 0), const V3(0.8, 0.08, 1.4), _dark),
      Box(const V3(0, 0.6, -0.3), const V3(0.1, 1.2, 0.1), _dark),
      Box(const V3(0, 1.05, -0.2), const V3(0.4, 0.5, 0.1), _pad), // 가슴 패드
      Box(const V3(0, 0.5, 0.2), const V3(0.3, 0.06, 0.35), _padDark), // 무릎 받침
      for (final x in [-0.3, 0.3]) Box(V3(x, 0.95, 0.0), const V3(0.04, 0.04, 0.4), _chrome),
      Cyl(const V3(0, 0.35, -0.2), 0.03, 0.6, 'x', _steel), // 피벗
      Box(const V3(0.0, 0.25, 0.25), const V3(0.06, 0.06, 0.8), _steel), // 레버
      Box(const V3(0.0, 0.3, 0.65), const V3(0.28, 0.2, 0.06), _padDark), // 발판
      ..._weightStack(const V3(0, 0.08, -0.6), h: 0.8),
    ];

/// 앱 코스터: 곡선 레일 위 무릎 패드 캐리지를 당겨 올린다.
List<Prim> _abCoaster() => [
      Box(const V3(0, 0.04, 0), const V3(0.7, 0.08, 1.6), _dark),
      Box(const V3(0, 0.9, 0.55), const V3(0.12, 1.8, 0.12), _dark), // 앞 기둥
      Box(const V3(0, 1.75, 0.45), const V3(0.6, 0.06, 0.3), _steel), // 상단 손잡이 대
      for (final x in [-0.25, 0.25]) Box(V3(x, 1.6, 0.4), const V3(0.05, 0.3, 0.05), _chrome),
      // 곡선 레일(짧은 상자들을 호로)
      for (var i = 0; i < 7; i++)
        Box(V3(0, 0.25 + i * i * 0.02, -0.5 + i * 0.16), const V3(0.12, 0.05, 0.2), _steel),
      Box(const V3(0, 0.4, -0.2), const V3(0.36, 0.1, 0.3), _pad), // 무릎 패드 캐리지
      Box(const V3(0, 0.3, -0.2), const V3(0.3, 0.1, 0.2), _dark),
    ];

/// 스탠딩 레그 컬: 서서 허벅지 패드에 기대고 발목 롤러를 들어 올린다.
List<Prim> _standingLegCurl() => [
      Box(const V3(0, 0.04, 0), const V3(0.8, 0.08, 1.2), _dark),
      Box(const V3(0, 0.15, 0.15), const V3(0.4, 0.14, 0.3), _padDark), // 발판
      Box(const V3(0, 0.8, -0.3), const V3(0.12, 1.6, 0.12), _dark),
      Box(const V3(0, 0.95, -0.15), const V3(0.36, 0.3, 0.1), _pad), // 허벅지 패드
      Box(const V3(0, 1.3, -0.15), const V3(0.36, 0.3, 0.1), _pad), // 가슴 패드
      for (final x in [-0.28, 0.28]) Box(V3(x, 1.15, 0.0), const V3(0.04, 0.04, 0.3), _chrome),
      Cyl(const V3(0, 0.5, -0.25), 0.03, 0.5, 'x', _steel),
      Box(const V3(0.18, 0.3, -0.05), const V3(0.05, 0.05, 0.5), _steel), // 레버
      Cyl(const V3(0.18, 0.2, 0.2), 0.06, 0.22, 'x', _pad), // 발목 롤러
      ..._weightStack(const V3(0, 0.08, -0.55), h: 0.8),
    ];

/// 마운틴 클라이머 머신(버사클라이머): 세로 레일에 손잡이·발판이 번갈아 오르내린다.
List<Prim> _versaClimber() => [
      Box(const V3(0, 0.04, 0.1), const V3(0.7, 0.08, 1.0), _dark),
      Box(const V3(0, 1.2, -0.2), const V3(0.16, 2.4, 0.16), _dark), // 메인 레일
      Box(const V3(0, 0.3, -0.5), const V3(0.1, 0.1, 0.6), _dark), // 뒤 지지
      Box(const V3(0, 1.3, -0.1), const V3(0.22, 0.14, 0.04), _screen),
      for (final (x, h) in [(-0.22, 1.9), (0.22, 1.6)]) ...[
        Box(V3(x, h, -0.05), const V3(0.05, 0.3, 0.05), _steel),
        Cyl(V3(x, h + 0.15, 0.05), 0.02, 0.2, 'z', _chrome), // 손잡이
      ],
      for (final (x, h) in [(-0.18, 0.45), (0.18, 0.75)]) ...[
        Box(V3(x, h, -0.05), const V3(0.05, 0.3, 0.05), _steel),
        Box(V3(x, h - 0.15, 0.1), const V3(0.14, 0.04, 0.3), _padDark), // 발판
      ],
    ];

/// 제이콥스 래더: 기울어진 사다리가 돌아간다.
List<Prim> _jacobsLadder() => [
      Box(const V3(0, 0.04, 0), const V3(0.9, 0.08, 1.4), _dark),
      for (final s in [-1, 1]) ...[
        Box(V3(0.35 * s, 0.3, 0.5), const V3(0.06, 0.6, 0.06), _dark),
        Box(V3(0.35 * s, 1.2, -0.5), const V3(0.06, 2.4, 0.06), _dark),
      ],
      // 기울어진 가로대
      for (var i = 0; i < 9; i++) Cyl(V3(0, 0.35 + i * 0.22, 0.55 - i * 0.13), 0.025, 0.74, 'x', _chrome),
      Box(const V3(0, 0.9, 0.75), const V3(0.6, 0.04, 0.3), _padDark), // 발 디딤 받침
      Box(const V3(0, 2.3, -0.6), const V3(0.3, 0.14, 0.05), _screen),
    ];

/// 힙 어브덕터/어덕터: 앉아서 무릎 패드를 벌리거나 모은다.
List<Prim> _hipAbAd({required bool out}) {
  final d = out ? 0.22 : 0.38;
  return [
    ..._seatBase(seatH: 0.45),
    Box(const V3(0, 0.85, -0.22), const V3(0.4, 0.7, 0.08), _pad), // 등받이
    for (final s in [-1, 1]) ...[
      Box(V3(d * s, 0.5, 0.35), const V3(0.05, 0.3, 0.05), _steel),
      Box(V3(d * s, 0.62, 0.35), const V3(0.1, 0.26, 0.26), _pad), // 무릎 패드
    ],
    Box(const V3(0, 0.08, 0.5), const V3(0.6, 0.06, 0.3), _padDark), // 발판
    ..._weightStack(const V3(0, 0.08, -0.6), h: 0.9),
  ];
}

/// 시시 스쿼트: 발을 고정하고 종아리 패드에 기대 뒤로 눕듯 앉는다.
List<Prim> _sissySquat() => [
      Box(const V3(0, 0.04, 0), const V3(0.6, 0.08, 1.0), _dark),
      Box(const V3(0, 0.1, 0.2), const V3(0.5, 0.06, 0.35), _padDark), // 발판
      Cyl(const V3(0, 0.22, 0.0), 0.06, 0.5, 'x', _pad), // 발목 롤러
      Box(const V3(0, 0.45, -0.25), const V3(0.5, 0.14, 0.14), _pad), // 종아리 패드
      Box(const V3(0, 0.3, -0.25), const V3(0.08, 0.5, 0.08), _steel),
    ];

/// 노르딕 컬 벤치: 무릎 패드 + 발목 고정 롤러.
List<Prim> _nordicBench() => [
      Box(const V3(0, 0.04, 0), const V3(0.6, 0.08, 1.2), _dark),
      Box(const V3(0, 0.3, 0.2), const V3(0.5, 0.12, 0.6), _pad), // 무릎 패드
      Box(const V3(0, 0.15, 0.2), const V3(0.1, 0.2, 0.1), _steel),
      Box(const V3(0, 0.35, -0.45), const V3(0.08, 0.6, 0.08), _steel),
      Cyl(const V3(0, 0.6, -0.45), 0.06, 0.5, 'x', _padDark), // 발목 롤러
    ];

/// 시티드 딥 머신: 앉아서 손잡이를 아래로 민다.
List<Prim> _dipMachine() => [
      ..._seatBase(seatH: 0.45),
      Box(const V3(0, 0.85, -0.22), const V3(0.4, 0.7, 0.08), _pad),
      Cyl(const V3(0, 1.1, -0.1), 0.03, 0.8, 'x', _steel), // 피벗
      for (final s in [-1, 1]) ...[
        Box(V3(0.35 * s, 0.9, 0.05), const V3(0.05, 0.4, 0.05), _steel),
        Cyl(V3(0.35 * s, 0.7, 0.1), 0.02, 0.24, 'z', _chrome), // 손잡이
      ],
      ..._weightStack(const V3(0, 0.08, -0.6), h: 0.9),
    ];

/// 토르소 로테이션: 가슴 패드에 기대고 회전판을 돌린다.
List<Prim> _torsoRotation() => [
      Box(const V3(0, 0.04, 0), const V3(0.7, 0.08, 0.9), _dark),
      Cyl(const V3(0, 0.12, 0.1), 0.3, 0.08, 'y', _padDark, segments: 20), // 회전판
      Cyl(const V3(0, 0.45, 0.1), 0.06, 0.6, 'y', _steel),
      Box(const V3(0, 0.78, 0.1), const V3(0.36, 0.08, 0.36), _pad), // 시트
      Box(const V3(0, 1.0, -0.3), const V3(0.12, 2.0, 0.12), _dark),
      Box(const V3(0, 1.3, -0.1), const V3(0.3, 0.3, 0.1), _pad), // 가슴 패드
      for (final x in [-0.25, 0.25]) Box(V3(x, 1.3, 0.05), const V3(0.04, 0.04, 0.3), _chrome),
      ..._weightStack(const V3(0, 0.08, -0.55), h: 0.9),
    ];

/// 풀오버 머신: 앉아서 머리 위 암을 앞으로 당겨 내린다.
List<Prim> _pulloverMachine() => [
      ..._seatBase(seatH: 0.45),
      Box(const V3(0, 0.85, -0.22), const V3(0.4, 0.7, 0.08), _pad),
      Cyl(const V3(0, 1.3, 0.0), 0.03, 0.9, 'x', _steel), // 피벗
      for (final s in [-1, 1]) Box(V3(0.4 * s, 1.5, 0.1), const V3(0.05, 0.5, 0.05), _steel),
      Box(const V3(0, 1.75, 0.2), const V3(0.9, 0.08, 0.14), _pad), // 팔꿈치 패드 암
      Cyl(const V3(0, 1.75, 0.3), 0.02, 0.8, 'x', _chrome), // 바
      ..._weightStack(const V3(0, 0.08, -0.6), h: 0.9),
    ];

/// 리버스 하이퍼: 높은 패드 위에 엎드려 다리를 뒤로 들어 올린다.
List<Prim> _reverseHyper() => [
      Box(const V3(0, 0.04, 0), const V3(0.8, 0.08, 1.4), _dark),
      ..._legs(0.3, 0.4, 0.85, w: 0.06),
      Box(const V3(0, 0.95, 0), const V3(0.7, 0.14, 1.0), _pad), // 상판 패드
      for (final x in [-0.3, 0.3]) Box(V3(x, 1.1, 0.4), const V3(0.04, 0.04, 0.4), _chrome), // 손잡이
      Cyl(const V3(0, 0.8, -0.45), 0.03, 0.6, 'x', _steel), // 진자 피벗
      Box(const V3(0, 0.45, -0.55), const V3(0.06, 0.7, 0.06), _steel), // 진자 암
      Cyl(const V3(0, 0.12, -0.55), 0.06, 0.5, 'x', _padDark), // 발목 롤러
      Cyl(const V3(0, 0.2, -0.75), 0.16, 0.04, 'z', _plate),
    ];

/// 슈러그 머신: 서서 양옆 손잡이를 들어 올린다.
List<Prim> _shrugMachine() => [
      Box(const V3(0, 0.04, 0), const V3(1.0, 0.08, 1.0), _dark),
      Box(const V3(0, 0.1, 0.1), const V3(0.5, 0.04, 0.4), _padDark),
      Box(const V3(0, 0.8, -0.4), const V3(0.12, 1.6, 0.12), _dark),
      Cyl(const V3(0, 0.5, -0.3), 0.03, 1.0, 'x', _steel),
      for (final s in [-1, 1]) ...[
        Box(V3(0.45 * s, 0.6, 0.0), const V3(0.05, 0.05, 0.6), _steel),
        Cyl(V3(0.45 * s, 0.75, 0.15), 0.02, 0.3, 'y', _chrome), // 손잡이
        Cyl(V3(0.45 * s, 0.6, -0.5), 0.18, 0.04, 'x', _plate),
      ],
    ];

/// 시티드 카프 레이즈: 앉아서 무릎 위 패드를 종아리로 들어 올린다.
List<Prim> _seatedCalf() => [
      Box(const V3(0, 0.04, 0), const V3(0.7, 0.08, 1.1), _dark),
      Box(const V3(0, 0.25, -0.2), const V3(0.1, 0.45, 0.1), _steel),
      Box(const V3(0, 0.5, -0.2), const V3(0.4, 0.08, 0.4), _pad), // 시트
      Box(const V3(0, 0.2, 0.3), const V3(0.45, 0.04, 0.25), _padDark), // 발판(앞 끝)
      Cyl(const V3(0, 0.3, 0.35), 0.03, 0.6, 'x', _steel),
      Box(const V3(0, 0.75, 0.25), const V3(0.5, 0.12, 0.2), _pad), // 무릎 패드
      for (final s in [-1, 1]) Box(V3(0.25 * s, 0.6, 0.3), const V3(0.05, 0.3, 0.05), _steel),
      Cyl(const V3(0, 0.75, 0.55), 0.16, 0.04, 'z', _plate),
    ];

/// 백 익스텐션 머신: 앉아서 등 패드를 뒤로 민다.
List<Prim> _backExtMachine() => [
      ..._seatBase(seatH: 0.45),
      Box(const V3(0, 0.25, 0.3), const V3(0.4, 0.06, 0.3), _padDark), // 발판
      Cyl(const V3(0, 0.5, -0.3), 0.03, 0.6, 'x', _steel),
      Box(const V3(0, 0.75, -0.3), const V3(0.06, 0.5, 0.06), _steel),
      Box(const V3(0, 0.95, -0.25), const V3(0.4, 0.2, 0.1), _pad), // 등 패드
      ..._weightStack(const V3(0, 0.08, -0.65), h: 0.9),
    ];

/// 복근 크런치 머신: 앉아서 가슴 패드를 앞으로 말아 내린다.
List<Prim> _abCrunchMachine() => [
      ..._seatBase(seatH: 0.45),
      Box(const V3(0, 0.85, -0.22), const V3(0.4, 0.7, 0.08), _pad),
      Cyl(const V3(0, 1.15, -0.2), 0.03, 0.6, 'x', _steel),
      for (final s in [-1, 1]) Box(V3(0.22 * s, 1.0, 0.05), const V3(0.05, 0.35, 0.05), _steel),
      Box(const V3(0, 1.0, 0.1), const V3(0.44, 0.14, 0.1), _pad), // 가슴 패드
      Cyl(const V3(0, 0.25, 0.3), 0.05, 0.4, 'x', _padDark), // 발 고정 롤러
      ..._weightStack(const V3(0, 0.08, -0.6), h: 0.9),
    ];

/// 팔 머신(바이셉 컬 / 트라이셉 익스텐션): 패드에 팔을 올리고 레버를 당기거나 민다.
List<Prim> _armMachine({required bool curl}) => [
      ..._seatBase(seatH: 0.45),
      Box(const V3(0, 0.85, -0.22), const V3(0.4, 0.7, 0.08), _pad),
      Box(const V3(0, 0.85, 0.25), const V3(0.5, 0.08, 0.3), _pad), // 팔 패드
      Box(const V3(0, 0.65, 0.3), const V3(0.08, 0.4, 0.08), _steel),
      Cyl(const V3(0, 0.9, 0.4), 0.03, 0.6, 'x', _steel), // 피벗
      Box(V3(0, curl ? 1.05 : 0.8, 0.5), const V3(0.06, 0.3, 0.06), _steel),
      Cyl(V3(0, curl ? 1.2 : 0.65, 0.5), 0.02, 0.5, 'x', _chrome), // 손잡이
      ..._weightStack(const V3(0, 0.08, -0.6), h: 0.9),
    ];

/// 레터럴 레이즈 머신: 팔꿈치 패드를 옆으로 들어 올린다.
List<Prim> _lateralRaiseMachine() => [
      ..._seatBase(seatH: 0.45),
      Box(const V3(0, 0.85, -0.22), const V3(0.4, 0.7, 0.08), _pad),
      Cyl(const V3(0, 1.1, -0.1), 0.03, 0.9, 'x', _steel),
      for (final s in [-1, 1]) ...[
        Box(V3(0.35 * s, 0.85, 0.0), const V3(0.05, 0.5, 0.05), _steel),
        Box(V3(0.4 * s, 0.75, 0.05), const V3(0.14, 0.1, 0.3), _pad), // 팔꿈치 패드
      ],
      ..._weightStack(const V3(0, 0.08, -0.6), h: 0.9),
    ];

/// 커브드 트레드밀: 오목한 벨트, 모터 없음.
List<Prim> _curvedTreadmill() => [
      for (var i = 0; i < 9; i++)
        Box(V3(0, 0.12 + (i - 4) * (i - 4) * 0.012, -0.8 + i * 0.2), const V3(0.7, 0.06, 0.22), _rubber),
      for (final s in [-1, 1]) ...[
        Box(V3(0.42 * s, 0.1, 0), const V3(0.08, 0.2, 1.9), _dark),
        Box(V3(0.42 * s, 0.7, -0.6), const V3(0.05, 1.2, 0.05), _dark),
      ],
      Box(const V3(0, 1.3, -0.6), const V3(0.9, 0.05, 0.05), _chrome), // 손잡이
      Box(const V3(0, 1.2, -0.65), const V3(0.25, 0.12, 0.03), _screen),
    ];

/// 에어 바이크(어썰트): 큰 팬 + 움직이는 팔 손잡이.
List<Prim> _assaultBike() => [
      Box(const V3(0, 0.04, 0), const V3(0.6, 0.08, 1.3), _dark),
      Cyl(const V3(0, 0.6, -0.35), 0.5, 0.12, 'x', _rubber, segments: 20), // 팬
      Box(const V3(0, 0.6, -0.35), const V3(0.16, 1.0, 0.04), _steel),
      Box(const V3(0, 0.5, 0.2), const V3(0.08, 0.9, 0.08), _dark),
      Box(const V3(0, 0.95, 0.2), const V3(0.28, 0.06, 0.24), _pad), // 안장
      for (final s in [-1, 1]) ...[
        Box(V3(0.25 * s, 1.0, -0.1), const V3(0.04, 0.9, 0.04), _steel), // 팔 레버
        Cyl(V3(0.25 * s, 1.45, -0.1), 0.02, 0.2, 'x', _chrome),
        Box(V3(0.2 * s, 0.35, 0.05 + 0.1 * s), const V3(0.12, 0.04, 0.2), _padDark), // 페달
      ],
      Box(const V3(0, 1.3, -0.5), const V3(0.22, 0.14, 0.03), _screen),
    ];

/// 리컴번트 바이크: 등받이가 있는 좌식 자전거.
List<Prim> _recumbentBike() => [
      Box(const V3(0, 0.04, 0), const V3(0.6, 0.08, 1.6), _dark),
      Box(const V3(0, 0.3, -0.35), const V3(0.1, 0.5, 0.1), _dark),
      Box(const V3(0, 0.55, -0.35), const V3(0.42, 0.08, 0.42), _pad), // 시트
      Box(const V3(0, 0.85, -0.6), const V3(0.42, 0.6, 0.08), _pad), // 등받이
      for (final s in [-1, 1]) Box(V3(0.25 * s, 0.6, -0.4), const V3(0.04, 0.04, 0.3), _chrome),
      Cyl(const V3(0, 0.4, 0.35), 0.22, 0.08, 'x', _steel, segments: 18), // 크랭크 하우징
      for (final s in [-1, 1]) Box(V3(0.16 * s, 0.4 + 0.15 * s, 0.35), const V3(0.12, 0.04, 0.2), _padDark),
      Box(const V3(0, 0.75, 0.55), const V3(0.08, 0.7, 0.08), _dark),
      Box(const V3(0, 1.1, 0.55), const V3(0.3, 0.18, 0.03), _screen),
    ];

List<Prim> _battleRope() => [
      Box(const V3(0, 0.03, 0), const V3(2.0, 0.06, 1.4), _rubber),
      Box(const V3(0, 0.15, -0.6), const V3(0.3, 0.3, 0.3), _dark), // 앵커
      for (final s in [-1, 1])
        for (var i = 0; i < 8; i++) Cyl(V3(0.15 * s + (i.isEven ? 0.05 : -0.05) * s, 0.05, -0.4 + i * 0.14), 0.025, 0.14, 'z', _padDark),
    ];

List<Prim> _band() => [
      Box(const V3(0, 0.03, 0), const V3(1.2, 0.06, 1.2), _rubber),
      Box(const V3(0, 0.06, 0), const V3(0.9, 0.03, 0.08), _pad),
      Box(const V3(0, 0.06, 0.15), const V3(0.7, 0.03, 0.06), _screen),
      Box(const V3(0, 0.06, -0.15), const V3(0.5, 0.03, 0.05), _steel),
    ];

List<Prim> _jumpRope() => [
      Box(const V3(0, 0.03, 0), const V3(1.2, 0.06, 1.2), _rubber),
      for (final s in [-1, 1]) Cyl(V3(0.3 * s, 0.06, 0.3), 0.02, 0.25, 'z', _padDark), // 손잡이
      for (var i = 0; i < 10; i++) Cyl(V3(-0.3 + i * 0.066, 0.06, 0.15 - (i - 4.5) * (i - 4.5) * 0.02), 0.006, 0.08, 'x', _chrome),
    ];
