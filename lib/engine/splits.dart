/// n분할 템플릿 (요구사항 5, 7).
///
/// 각 분할은 "하루에 어떤 부위를 묶는지"의 순환 리스트다.
/// 플래너가 운동일마다 다음 항목을 순서대로 배정한다.
library;

import '../models/models.dart';

class SplitDay {
  const SplitDay(this.title, this.groups);
  final String title;
  final List<MuscleGroup> groups;
}

class SplitTemplate {
  const SplitTemplate(this.days, this.name, this.description);
  final int days;
  final String name;
  final String description;

  List<SplitDay> get cycle => splitCycles[days]!;
}

const List<SplitTemplate> splitTemplates = [
  SplitTemplate(1, '무분할', '매 세션 전신. 주 2~3회 운동하는 사람에게 적합.'),
  SplitTemplate(2, '2분할', '상체 / 하체. 주 4회에 최적.'),
  SplitTemplate(3, '3분할', '밀기(가슴·어깨·삼두) / 당기기(등·이두) / 하체. 가장 대중적.'),
  SplitTemplate(4, '4분할', '가슴+삼두 / 등+이두 / 어깨+복근 / 하체.'),
  SplitTemplate(5, '5분할', '가슴 / 등 / 어깨 / 팔 / 하체. 부위별 고볼륨.'),
  SplitTemplate(6, '6분할', '밀기/당기기/하체 ×2. 주 6회 운동하는 상급자.'),
];

/// 세션 내 부위 순서는 큰 근육 → 작은 근육. 복근·유산소는 마지막.
const Map<int, List<SplitDay>> splitCycles = {
  1: [
    // 무분할은 매번 전신이지만, 먼저 하는 부위(가장 힘 있을 때 하는 부위)를 번갈아 바꾼다.
    SplitDay('전신 A (하체 먼저)', [MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.back, MuscleGroup.shoulder, MuscleGroup.arms, MuscleGroup.abs]),
    SplitDay('전신 B (등 먼저)', [MuscleGroup.back, MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.shoulder, MuscleGroup.arms, MuscleGroup.abs]),
  ],
  2: [
    SplitDay('상체', [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.shoulder, MuscleGroup.arms]),
    SplitDay('하체·복근', [MuscleGroup.legs, MuscleGroup.abs]),
  ],
  3: [
    SplitDay('밀기 (가슴·어깨·삼두)', [MuscleGroup.chest, MuscleGroup.shoulder, MuscleGroup.arms]),
    SplitDay('당기기 (등·이두)', [MuscleGroup.back, MuscleGroup.arms, MuscleGroup.abs]),
    SplitDay('하체', [MuscleGroup.legs, MuscleGroup.abs]),
  ],
  4: [
    SplitDay('가슴·삼두', [MuscleGroup.chest, MuscleGroup.arms]),
    SplitDay('등·이두', [MuscleGroup.back, MuscleGroup.arms]),
    SplitDay('어깨·복근', [MuscleGroup.shoulder, MuscleGroup.abs]),
    SplitDay('하체', [MuscleGroup.legs]),
  ],
  5: [
    SplitDay('가슴', [MuscleGroup.chest, MuscleGroup.abs]),
    SplitDay('등', [MuscleGroup.back]),
    SplitDay('어깨', [MuscleGroup.shoulder, MuscleGroup.abs]),
    SplitDay('팔', [MuscleGroup.arms]),
    SplitDay('하체', [MuscleGroup.legs]),
  ],
  6: [
    SplitDay('밀기 A', [MuscleGroup.chest, MuscleGroup.shoulder, MuscleGroup.arms]),
    SplitDay('당기기 A', [MuscleGroup.back, MuscleGroup.arms]),
    SplitDay('하체 A', [MuscleGroup.legs, MuscleGroup.abs]),
    SplitDay('밀기 B', [MuscleGroup.shoulder, MuscleGroup.chest, MuscleGroup.arms]),
    SplitDay('당기기 B', [MuscleGroup.back, MuscleGroup.arms, MuscleGroup.abs]),
    SplitDay('하체 B', [MuscleGroup.legs]),
  ],
};

/// 4·5분할의 '팔' 날은 이두/삼두를 함께 다루므로 세부 타깃 힌트를 준다.
/// 세션 생성기가 arms를 뽑을 때 밀기 날엔 삼두, 당기기 날엔 이두를 우선한다.
List<String> armsEmphasisFor(List<MuscleGroup> dayGroups) {
  if (dayGroups.contains(MuscleGroup.chest) ||
      dayGroups.contains(MuscleGroup.shoulder)) {
    return ['삼두'];
  }
  if (dayGroups.contains(MuscleGroup.back)) return ['이두', '상완근'];
  return [];
}
