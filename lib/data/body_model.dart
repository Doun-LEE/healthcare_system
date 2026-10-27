/// 저폴리 3D 인체 모델과 운동 → 자극 근육 매핑.
///
/// 운동의 부위/세부 타깃(emphasis) 문자열에서 근육 영역을 뽑아
/// 주동근(빨강)·보조근(주황)으로 칠한 인체를 만든다. 단위 m, y축 위, +z가 정면.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../ui/widgets/equipment_3d.dart';
import 'catalog.dart';

enum Muscle {
  chestUpper('윗가슴', MuscleGroup.chest, back: false),
  chestMid('가슴 중앙', MuscleGroup.chest, back: false),
  chestLower('아랫가슴', MuscleGroup.chest, back: false),
  deltFront('전면 어깨', MuscleGroup.shoulder, back: false),
  deltSide('측면 어깨', MuscleGroup.shoulder, back: false),
  deltRear('후면 어깨', MuscleGroup.shoulder, back: true),
  biceps('이두', MuscleGroup.arms, back: false),
  triceps('삼두', MuscleGroup.arms, back: true),
  forearm('전완', MuscleGroup.arms, back: false),
  absUpper('상복부', MuscleGroup.abs, back: false),
  absLower('하복부', MuscleGroup.abs, back: false),
  obliques('복사근', MuscleGroup.abs, back: false),
  trapsUpper('승모', MuscleGroup.back, back: true),
  upperBack('등 상부', MuscleGroup.back, back: true),
  lats('광배', MuscleGroup.back, back: true),
  lowerBack('등 하부', MuscleGroup.back, back: true),
  glutes('둔근', MuscleGroup.legs, back: true),
  quads('대퇴사두', MuscleGroup.legs, back: false),
  hamstrings('햄스트링', MuscleGroup.legs, back: true),
  adductors('내전근', MuscleGroup.legs, back: false),
  hipFlexors('고관절 굴곡근', MuscleGroup.legs, back: false),
  calves('종아리', MuscleGroup.legs, back: true);

  const Muscle(this.label, this.group, {required this.back});
  final String label;
  final MuscleGroup group;

  /// 뒤쪽에서 보이는 근육이면 true(초기 시점 결정에 사용).
  final bool back;
}

class MuscleMap {
  const MuscleMap({required this.primary, required this.secondary});
  final Set<Muscle> primary;
  final Set<Muscle> secondary;

  bool get isEmpty => primary.isEmpty && secondary.isEmpty;

  /// 주동근이 대부분 뒤쪽이면 뒤에서 보는 시점이 낫다.
  bool get preferBack {
    if (primary.isEmpty) return false;
    final b = primary.where((m) => m.back).length;
    return b * 2 > primary.length;
  }

  MuscleMap merge(MuscleMap o) => MuscleMap(
        primary: {...primary, ...o.primary},
        secondary: {...secondary, ...o.secondary}..removeAll({...primary, ...o.primary}),
      );
}

/// 세부 타깃 문자열 → 근육. 앞에 있는 키워드가 먼저 매치된다.
const _keywords = <String, List<Muscle>>{
  '윗가슴': [Muscle.chestUpper],
  '아랫가슴': [Muscle.chestLower],
  '가슴': [Muscle.chestMid],
  '전면 어깨': [Muscle.deltFront],
  '측면 어깨': [Muscle.deltSide],
  '후면 어깨': [Muscle.deltRear],
  '회전근개': [Muscle.deltRear],
  '어깨': [Muscle.deltSide, Muscle.deltFront],
  '상완근': [Muscle.biceps, Muscle.forearm],
  '이두': [Muscle.biceps],
  '삼두': [Muscle.triceps],
  '전완': [Muscle.forearm],
  '악력': [Muscle.forearm],
  '손목': [Muscle.forearm],
  '상복부': [Muscle.absUpper],
  '하복부': [Muscle.absLower],
  '고관절 굴곡근': [Muscle.hipFlexors, Muscle.absLower],
  '복직근': [Muscle.absUpper, Muscle.absLower],
  '복사근': [Muscle.obliques],
  '회전 코어': [Muscle.obliques],
  '복횡근': [Muscle.absLower, Muscle.obliques],
  '코어': [Muscle.absUpper, Muscle.absLower, Muscle.obliques],
  '광배': [Muscle.lats],
  '대원근': [Muscle.lats],
  '승모 상부': [Muscle.trapsUpper],
  '승모 중부': [Muscle.upperBack],
  '승모': [Muscle.trapsUpper],
  '능형근': [Muscle.upperBack],
  '등 상부': [Muscle.upperBack],
  '상부 등': [Muscle.upperBack],
  '등 두께': [Muscle.upperBack],
  '등 보조': [Muscle.upperBack, Muscle.lats],
  '등 하부': [Muscle.lowerBack],
  '척추기립근': [Muscle.lowerBack],
  '허리': [Muscle.lowerBack],
  '후면 사슬': [Muscle.lowerBack, Muscle.glutes, Muscle.hamstrings],
  '중둔근': [Muscle.glutes],
  '둔근': [Muscle.glutes],
  '대퇴사두': [Muscle.quads],
  '대퇴직근': [Muscle.quads],
  '내측광근': [Muscle.quads],
  '사두': [Muscle.quads],
  '햄스트링': [Muscle.hamstrings],
  '내전근': [Muscle.adductors],
  '가자미근': [Muscle.calves],
  '종아리': [Muscle.calves],
  '하체': [Muscle.quads, Muscle.glutes],
  '상체': [Muscle.lats, Muscle.deltFront, Muscle.triceps, Muscle.chestMid],
  '전신': [Muscle.quads, Muscle.glutes, Muscle.lats, Muscle.deltSide, Muscle.absUpper],
  '심폐': [Muscle.quads, Muscle.calves],
  '지방': [Muscle.quads, Muscle.glutes],
  '칼로리': [Muscle.quads, Muscle.glutes],
  '폭발력': [Muscle.quads, Muscle.glutes, Muscle.calves],
  '점프': [Muscle.quads, Muscle.calves],
  '회복': [Muscle.quads, Muscle.calves],
};

Set<Muscle> _fromText(String text) {
  final out = <Muscle>{};
  var rest = text;
  for (final e in _keywords.entries) {
    if (rest.contains(e.key)) {
      out.addAll(e.value);
      rest = rest.replaceAll(e.key, ' ');
    }
  }
  return out;
}

/// 운동별 자극 근육. 세부 타깃에서 같은 부위 근육은 주동근, 다른 부위는 보조근.
/// 복합운동은 id 규칙으로 보조근을 더 붙인다.
MuscleMap musclesFor(Exercise ex) {
  final primary = <Muscle>{};
  final secondary = <Muscle>{};
  for (final e in ex.emphasis) {
    for (final m in _fromText(e)) {
      if (ex.group == MuscleGroup.cardio || m.group == ex.group) {
        primary.add(m);
      } else {
        secondary.add(m);
      }
    }
  }
  if (primary.isEmpty) primary.addAll(_groupDefault(ex));

  final id = ex.id;
  bool has(String s) => id.contains(s);
  if (ex.group == MuscleGroup.chest) {
    secondary.addAll([Muscle.triceps, Muscle.deltFront]);
  }
  if (has('deadlift') || has('rack_pull') || has('rdl')) {
    secondary.addAll([Muscle.hamstrings, Muscle.glutes, Muscle.trapsUpper, Muscle.forearm, Muscle.lowerBack]);
  }
  if (has('row') || has('pull') || has('chin')) {
    if (ex.group == MuscleGroup.back) secondary.addAll([Muscle.biceps, Muscle.forearm, Muscle.deltRear]);
  }
  if (has('squat') || has('leg_press') || has('lunge') || has('bulgarian') || has('step_up') || has('sled')) {
    secondary.addAll([Muscle.hamstrings, Muscle.adductors, Muscle.glutes]);
    if (has('bb_squat') || has('front_squat') || has('goblet')) secondary.addAll([Muscle.lowerBack, Muscle.absUpper]);
  }
  if (has('hip_thrust') || has('ghr') || has('nordic')) secondary.addAll([Muscle.hamstrings, Muscle.lowerBack]);
  if (has('ohp') || has('shoulder_press') || has('landmine_press')) secondary.addAll([Muscle.triceps, Muscle.trapsUpper]);
  if (has('upright') || has('shrug')) secondary.add(Muscle.trapsUpper);
  if (has('dip')) secondary.addAll([Muscle.chestLower, Muscle.triceps, Muscle.deltFront]);
  if (has('curl') && ex.group == MuscleGroup.arms) secondary.add(Muscle.forearm);
  if (has('pushup') || has('cgbp') || has('bench')) secondary.add(Muscle.absUpper);
  if (has('kb_swing') || has('burpee') || has('slam')) secondary.addAll([Muscle.lowerBack, Muscle.deltFront, Muscle.absUpper]);
  if (has('rowing') || has('ski')) secondary.addAll([Muscle.lats, Muscle.upperBack, Muscle.biceps]);
  if (has('plank') || has('wheel')) secondary.addAll([Muscle.deltFront, Muscle.quads]);
  if (ex.group == MuscleGroup.cardio) secondary.addAll([Muscle.calves, Muscle.quads, Muscle.glutes]);

  secondary.removeAll(primary);
  return MuscleMap(primary: primary, secondary: secondary);
}

Set<Muscle> _groupDefault(Exercise ex) => switch (ex.group) {
      MuscleGroup.chest => {Muscle.chestMid},
      MuscleGroup.back => {Muscle.lats, Muscle.upperBack},
      MuscleGroup.legs => {Muscle.quads, Muscle.glutes},
      MuscleGroup.shoulder => {Muscle.deltSide, Muscle.deltFront},
      MuscleGroup.arms => ex.id.contains('curl') ? {Muscle.biceps} : {Muscle.triceps},
      MuscleGroup.abs => {Muscle.absUpper, Muscle.absLower},
      MuscleGroup.cardio => {Muscle.quads, Muscle.calves, Muscle.glutes},
    };

/// 기구 하나로 할 수 있는 모든 운동의 근육을 합친 지도.
MuscleMap musclesForEquipment(EquipmentType t) {
  var map = const MuscleMap(primary: {}, secondary: {});
  for (final ex in exerciseCatalog.where((x) => x.equipment.contains(t))) {
    map = map.merge(musclesFor(ex));
  }
  return map;
}

// ---------------------------------------------------------------------------
// 인체 모델 (타원체·테이퍼 원기둥으로 둥글게)

const _skin = Color(0xFFD9B79A);
const _skinDark = Color(0xFFC79E80);
const _muscleIdle = Color(0xFFCFA98B);
const _primaryColor = Color(0xFFE53935);
const _secondaryColor = Color(0xFFFFA726);
const _short = Color(0xFF3E4A5C);
const _hair = Color(0xFF2E2622);

/// 인체 전체 프리미티브. [primary]는 빨강, [secondary]는 주황, 나머지 근육은 살색 음영.
/// [heat]를 주면(근육 → 0~1) 주동/보조 색 대신 살색→주황→빨강 열지도로 칠한다.
List<Prim> bodyModel(MuscleMap map, {Map<Muscle, double>? heat}) {
  Color c(Muscle m) {
    if (heat != null) return heatColor(heat[m] ?? 0);
    return map.primary.contains(m)
        ? _primaryColor
        : map.secondary.contains(m)
            ? _secondaryColor
            : _muscleIdle;
  }

  final prims = <Prim>[
    // 머리·목
    const Ellipsoid(V3(0, 1.64, 0), V3(0.1, 0.12, 0.11), _skin),
    const Ellipsoid(V3(0, 1.69, -0.015), V3(0.105, 0.085, 0.115), _hair, segments: 14, rings: 6),
    const Taper(V3(0, 1.51, 0), 0.055, 0.05, 0.08, _skin, segments: 12),
    // 몸통(어깨→가슴→허리→골반)
    const Taper(V3(0, 1.36, 0), 0.165, 0.21, 0.24, _skin, segments: 20, scaleZ: 0.55),
    const Taper(V3(0, 1.13, 0), 0.15, 0.165, 0.22, _skin, segments: 20, scaleZ: 0.6),
    const Taper(V3(0, 0.93, 0), 0.17, 0.15, 0.18, _short, segments: 20, scaleZ: 0.65),
    // 팔
    const Taper(V3(-0.26, 1.3, 0), 0.045, 0.055, 0.28, _skin, segments: 12),
    const Taper(V3(0.26, 1.3, 0), 0.045, 0.055, 0.28, _skin, segments: 12),
    const Taper(V3(-0.275, 0.99, 0.02), 0.035, 0.047, 0.28, _skin, segments: 12),
    const Taper(V3(0.275, 0.99, 0.02), 0.035, 0.047, 0.28, _skin, segments: 12),
    const Ellipsoid(V3(-0.28, 0.8, 0.03), V3(0.035, 0.05, 0.025), _skinDark, segments: 10, rings: 6),
    const Ellipsoid(V3(0.28, 0.8, 0.03), V3(0.035, 0.05, 0.025), _skinDark, segments: 10, rings: 6),
    // 다리
    const Taper(V3(-0.1, 0.6, 0), 0.065, 0.09, 0.42, _skin, segments: 14),
    const Taper(V3(0.1, 0.6, 0), 0.065, 0.09, 0.42, _skin, segments: 14),
    const Taper(V3(-0.1, 0.2, 0), 0.04, 0.06, 0.38, _skin, segments: 12),
    const Taper(V3(0.1, 0.2, 0), 0.04, 0.06, 0.38, _skin, segments: 12),
    const Ellipsoid(V3(-0.1, 0.03, 0.05), V3(0.05, 0.03, 0.12), _short, segments: 10, rings: 5),
    const Ellipsoid(V3(0.1, 0.03, 0.05), V3(0.05, 0.03, 0.12), _short, segments: 10, rings: 5),
  ];

  void both(Prim Function(double side) f) {
    prims.add(f(-1));
    prims.add(f(1));
  }

  Ellipsoid m(Muscle mu, double x, double y, double z, double rx, double ry, double rz) =>
      Ellipsoid(V3(x, y, z), V3(rx, ry, rz), c(mu), segments: 12, rings: 7);

  // --- 앞면
  both((s) => m(Muscle.chestUpper, s * 0.085, 1.41, 0.105, 0.08, 0.035, 0.03));
  both((s) => m(Muscle.chestMid, s * 0.09, 1.345, 0.11, 0.085, 0.04, 0.035));
  both((s) => m(Muscle.chestLower, s * 0.075, 1.285, 0.105, 0.07, 0.03, 0.03));
  prims.add(m(Muscle.absUpper, 0, 1.19, 0.1, 0.07, 0.055, 0.03));
  prims.add(m(Muscle.absLower, 0, 1.07, 0.1, 0.06, 0.055, 0.03));
  both((s) => m(Muscle.obliques, s * 0.13, 1.12, 0.07, 0.03, 0.11, 0.05));
  both((s) => m(Muscle.hipFlexors, s * 0.07, 0.92, 0.1, 0.04, 0.045, 0.025));
  // 어깨
  both((s) => m(Muscle.deltFront, s * 0.23, 1.455, 0.055, 0.05, 0.045, 0.04));
  both((s) => m(Muscle.deltSide, s * 0.255, 1.455, 0, 0.045, 0.055, 0.06));
  both((s) => m(Muscle.deltRear, s * 0.23, 1.455, -0.055, 0.05, 0.045, 0.04));
  // 팔
  both((s) => m(Muscle.biceps, s * 0.258, 1.3, 0.04, 0.038, 0.1, 0.03));
  both((s) => m(Muscle.triceps, s * 0.258, 1.3, -0.04, 0.038, 0.11, 0.03));
  both((s) => m(Muscle.forearm, s * 0.275, 1.0, 0.02, 0.046, 0.12, 0.04));
  // --- 뒷면
  prims.add(m(Muscle.trapsUpper, 0, 1.5, -0.04, 0.16, 0.035, 0.06));
  both((s) => m(Muscle.upperBack, s * 0.085, 1.38, -0.095, 0.08, 0.07, 0.03));
  both((s) => m(Muscle.lats, s * 0.12, 1.22, -0.08, 0.065, 0.12, 0.045));
  both((s) => m(Muscle.lowerBack, s * 0.035, 1.05, -0.09, 0.035, 0.08, 0.025));
  both((s) => m(Muscle.glutes, s * 0.085, 0.86, -0.1, 0.08, 0.075, 0.04));
  // 다리
  both((s) => m(Muscle.quads, s * 0.1, 0.6, 0.045, 0.06, 0.19, 0.045));
  both((s) => m(Muscle.hamstrings, s * 0.1, 0.6, -0.045, 0.058, 0.18, 0.045));
  prims.add(m(Muscle.adductors, 0, 0.63, 0.02, 0.03, 0.15, 0.06));
  both((s) => m(Muscle.calves, s * 0.1, 0.22, -0.03, 0.045, 0.14, 0.04));
  return prims;
}

List<Face> bodyFaces(MuscleMap map, {Map<Muscle, double>? heat}) => [for (final p in bodyModel(map, heat: heat)) ...p.faces()];

/// 열지도 색: 0 = 쉬는 근육(살색), 0.5 = 주황, 1 = 빨강.
Color heatColor(double v) {
  final t = v.clamp(0.0, 1.0);
  if (t == 0) return _muscleIdle;
  if (t < 0.5) return Color.lerp(_muscleIdle, _secondaryColor, t * 2)!;
  return Color.lerp(_secondaryColor, _primaryColor, (t - 0.5) * 2)!;
}

/// 주동근 위치에 따라 앞/뒤 초기 시점.
double bodyInitialYaw(MuscleMap map) => map.preferBack ? pi : 0;
