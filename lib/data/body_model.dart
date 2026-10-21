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
// 인체 모델

const _skin = Color(0xFFD8B597);
const _skinDark = Color(0xFFC49B7C);
const _muscleIdle = Color(0xFFC7A287);
const _primaryColor = Color(0xFFE53935);
const _secondaryColor = Color(0xFFFFA726);
const _short = Color(0xFF3E4A5C);
const _hair = Color(0xFF2E2622);

/// 인체 전체 프리미티브. [primary]는 빨강, [secondary]는 주황, 나머지 근육은 살색 음영.
List<Prim> bodyModel(MuscleMap map) {
  Color c(Muscle m) => map.primary.contains(m)
      ? _primaryColor
      : map.secondary.contains(m)
          ? _secondaryColor
          : _muscleIdle;

  final prims = <Prim>[
    // 머리·목
    const Cyl(V3(0, 1.66, 0), 0.1, 0.22, 'y', _skin, segments: 12),
    const Box(V3(0, 1.74, -0.02), V3(0.2, 0.1, 0.2), _hair),
    const Cyl(V3(0, 1.52, 0), 0.055, 0.08, 'y', _skin, segments: 10),
    // 몸통·골반
    const Box(V3(0, 1.21, 0), V3(0.38, 0.56, 0.22), _skin),
    const Box(V3(0, 0.86, 0), V3(0.36, 0.16, 0.23), _short),
    // 팔
    const Cyl(V3(-0.25, 1.31, 0), 0.055, 0.3, 'y', _skin, segments: 10),
    const Cyl(V3(0.25, 1.31, 0), 0.055, 0.3, 'y', _skin, segments: 10),
    const Cyl(V3(-0.27, 0.99, 0.02), 0.045, 0.3, 'y', _skin, segments: 10),
    const Cyl(V3(0.27, 0.99, 0.02), 0.045, 0.3, 'y', _skin, segments: 10),
    const Box(V3(-0.27, 0.79, 0.03), V3(0.07, 0.1, 0.05), _skinDark),
    const Box(V3(0.27, 0.79, 0.03), V3(0.07, 0.1, 0.05), _skinDark),
    // 다리
    const Cyl(V3(-0.1, 0.58, 0), 0.085, 0.42, 'y', _skin, segments: 12),
    const Cyl(V3(0.1, 0.58, 0), 0.085, 0.42, 'y', _skin, segments: 12),
    const Cyl(V3(-0.1, 0.2, 0), 0.06, 0.38, 'y', _skin, segments: 10),
    const Cyl(V3(0.1, 0.2, 0), 0.06, 0.38, 'y', _skin, segments: 10),
    const Box(V3(-0.1, 0.03, 0.05), V3(0.11, 0.06, 0.24), _short),
    const Box(V3(0.1, 0.03, 0.05), V3(0.11, 0.06, 0.24), _short),
  ];

  void both(Prim Function(double side) f) {
    prims.add(f(-1));
    prims.add(f(1));
  }

  // --- 앞면 근육 (z = +0.12 근처)
  both((s) => Box(V3(s * 0.09, 1.405, 0.115), const V3(0.16, 0.06, 0.02), c(Muscle.chestUpper)));
  both((s) => Box(V3(s * 0.09, 1.335, 0.12), const V3(0.17, 0.07, 0.03), c(Muscle.chestMid)));
  both((s) => Box(V3(s * 0.08, 1.27, 0.115), const V3(0.15, 0.05, 0.02), c(Muscle.chestLower)));
  prims.add(Box(const V3(0, 1.18, 0.115), const V3(0.15, 0.1, 0.02), c(Muscle.absUpper)));
  prims.add(Box(const V3(0, 1.06, 0.115), const V3(0.13, 0.1, 0.02), c(Muscle.absLower)));
  both((s) => Box(V3(s * 0.14, 1.11, 0.1), const V3(0.05, 0.22, 0.05), c(Muscle.obliques)));
  both((s) => Box(V3(s * 0.07, 0.905, 0.115), const V3(0.07, 0.07, 0.02), c(Muscle.hipFlexors)));
  // 어깨 (앞/옆/뒤 삼각근)
  both((s) => Box(V3(s * 0.235, 1.45, 0.07), const V3(0.1, 0.09, 0.07), c(Muscle.deltFront)));
  both((s) => Box(V3(s * 0.27, 1.45, 0), const V3(0.08, 0.1, 0.1), c(Muscle.deltSide)));
  both((s) => Box(V3(s * 0.235, 1.45, -0.07), const V3(0.1, 0.09, 0.07), c(Muscle.deltRear)));
  // 팔
  both((s) => Cyl(V3(s * 0.25, 1.3, 0.045), 0.04, 0.2, 'y', c(Muscle.biceps), segments: 8));
  both((s) => Cyl(V3(s * 0.25, 1.3, -0.045), 0.04, 0.2, 'y', c(Muscle.triceps), segments: 8));
  both((s) => Cyl(V3(s * 0.27, 1.0, 0.02), 0.05, 0.2, 'y', c(Muscle.forearm), segments: 8));
  // --- 뒷면 근육 (z = -0.12 근처)
  prims.add(Box(const V3(0, 1.49, -0.06), const V3(0.3, 0.06, 0.13), c(Muscle.trapsUpper)));
  both((s) => Box(V3(s * 0.08, 1.37, -0.115), const V3(0.15, 0.14, 0.02), c(Muscle.upperBack)));
  both((s) => Box(V3(s * 0.13, 1.2, -0.115), const V3(0.1, 0.22, 0.02), c(Muscle.lats)));
  both((s) => Box(V3(s * 0.195, 1.2, -0.04), const V3(0.02, 0.22, 0.13), c(Muscle.lats)));
  both((s) => Box(V3(s * 0.04, 1.03, -0.115), const V3(0.07, 0.16, 0.02), c(Muscle.lowerBack)));
  both((s) => Box(V3(s * 0.09, 0.85, -0.125), const V3(0.16, 0.15, 0.03), c(Muscle.glutes)));
  // 다리
  both((s) => Cyl(V3(s * 0.1, 0.6, 0.05), 0.06, 0.36, 'y', c(Muscle.quads), segments: 8));
  both((s) => Cyl(V3(s * 0.1, 0.6, -0.05), 0.06, 0.34, 'y', c(Muscle.hamstrings), segments: 8));
  prims.add(Box(const V3(0, 0.62, 0.02), const V3(0.05, 0.3, 0.12), c(Muscle.adductors)));
  both((s) => Cyl(V3(s * 0.1, 0.22, -0.035), 0.045, 0.28, 'y', c(Muscle.calves), segments: 8));
  return prims;
}

List<Face> bodyFaces(MuscleMap map) => [for (final p in bodyModel(map)) ...p.faces()];

/// 주동근 위치에 따라 앞/뒤 초기 시점.
double bodyInitialYaw(MuscleMap map) => map.preferBack ? pi : 0;
