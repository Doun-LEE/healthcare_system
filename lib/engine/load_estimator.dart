/// 신체 스펙으로 초기 작업 중량을 추정한다 (요구사항 13).
///
/// 1) 성별·체중·숙련도로 대표 리프트(스쿼트/벤치/데드/OHP/로우) 1RM을 추정
/// 2) 인바디 골격근량(SMM)이 있으면 평균 대비 비율로 보정
/// 3) 운동별 [Exercise.ratio]로 해당 운동 1RM → Epley 공식으로 목표 횟수 중량
/// 4) 기구 단위(LoadType.increment)로 반올림
///
/// 추정은 출발점일 뿐이며 이후 [Progression]이 실제 수행 결과로 보정한다.
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/models.dart';

class LoadEstimator {
  LoadEstimator(this.profile);

  final UserProfile profile;

  /// 체중 대비 1RM 비율(초급 기준). 숙련도 계수를 곱해 사용.
  static const Map<RefLift, double> _maleBase = {
    RefLift.squat: 0.9,
    RefLift.bench: 0.65,
    RefLift.deadlift: 1.1,
    RefLift.ohp: 0.42,
    RefLift.row: 0.6,
  };
  static const Map<RefLift, double> _femaleBase = {
    RefLift.squat: 0.7,
    RefLift.bench: 0.4,
    RefLift.deadlift: 0.85,
    RefLift.ohp: 0.28,
    RefLift.row: 0.42,
  };

  /// 체중 대비 평균 골격근량 비율(인바디 기준 대략치).
  static double _avgSmmRatio(Sex s) => s == Sex.male ? 0.44 : 0.36;

  /// 인바디 보정 계수. SMM 비율이 평균보다 10% 높으면 약 +8%.
  double get muscleFactor {
    final smm = profile.skeletalMuscleKg;
    if (smm == null || profile.weightKg <= 0) return 1.0;
    final ratio = smm / profile.weightKg;
    final rel = ratio / _avgSmmRatio(profile.sex);
    return (0.2 + 0.8 * rel).clamp(0.7, 1.4);
  }

  /// 체지방률 보정. 체지방이 높을수록 체중 기준 추정이 과대평가되므로 낮춘다.
  double get fatFactor {
    final bf = profile.bodyFatPct;
    if (bf == null) return 1.0;
    final norm = profile.sex == Sex.male ? 18.0 : 26.0;
    final diff = bf - norm;
    return (1.0 - diff * 0.012).clamp(0.75, 1.1);
  }

  /// 나이 보정. 40세 이후 10년마다 약 -7%.
  double get ageFactor {
    if (profile.age <= 40) return 1.0;
    return (1.0 - (profile.age - 40) * 0.007).clamp(0.7, 1.0);
  }

  double oneRepMax(RefLift lift) {
    if (lift == RefLift.bodyweight) return profile.weightKg;
    final base = (profile.sex == Sex.male ? _maleBase : _femaleBase)[lift]!;
    return profile.weightKg *
        base *
        profile.level.strengthFactor *
        muscleFactor *
        fatFactor *
        ageFactor;
  }

  /// Epley: 1RM = w(1 + r/30)  →  w = 1RM / (1 + r/30)
  static double weightForReps(double oneRm, int reps) =>
      oneRm / (1 + reps / 30.0);

  static double roundTo(double w, double step) {
    if (step <= 0) return 0;
    return (w / step).round() * step;
  }

  /// 운동의 초기 작업 중량(kg). 맨몸/유산소는 0.
  double initialWeight(Exercise ex, int reps, {double? maxWeightKg}) {
    if (ex.loadType == LoadType.bodyweight || ex.loadType == LoadType.cardio) {
      return 0;
    }
    final rm = oneRepMax(ex.refLift) * ex.ratio;
    var w = weightForReps(rm, reps);
    // 첫 세션은 보수적으로 90%에서 시작해 폼을 잡는다.
    w *= 0.9;
    if (maxWeightKg != null) w = min(w, maxWeightKg);
    final step = ex.loadType.increment;
    final minW = _minimumWeight(ex.loadType);
    return max(minW, roundTo(w, step));
  }

  static double _minimumWeight(LoadType t) => switch (t) {
        LoadType.barbell => 20, // 빈 바
        LoadType.dumbbell => 2,
        LoadType.machine => 5,
        LoadType.cable => 2.5,
        _ => 0,
      };

  /// 횟수 범위 안에서 숙련도에 맞는 목표 횟수.
  static int targetReps(Exercise ex, TrainingLevel level) {
    final lo = ex.repRange[0];
    final hi = ex.repRange[1];
    return switch (level) {
      TrainingLevel.beginner => hi,
      TrainingLevel.intermediate => ((lo + hi) / 2).round(),
      TrainingLevel.advanced => lo,
    };
  }

  /// 운동당 세트 수. 핵심 복합운동은 4, 보조 고립은 3. 유산소는 1.
  static int setsFor(Exercise ex, TrainingLevel level) {
    if (ex.group == MuscleGroup.cardio) return 1;
    var s = ex.compound ? 4 : 3;
    if (level == TrainingLevel.beginner && ex.compound) s = 3;
    if (level == TrainingLevel.advanced && ex.priority == 3) s = 4;
    return s;
  }
}
