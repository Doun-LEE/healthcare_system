/// 수행 결과 기반 점진적 과부하 (요구사항 12).
///
/// 세션을 완료하면 운동별로 실제 수행(횟수·무게)을 평가해
/// [ExerciseProgress.workingWeight]와 목표 횟수를 갱신한다.
///
/// 규칙(더블 프로그레션):
/// - 모든 세트를 목표 횟수 이상 성공 → 다음엔 무게 +1단위 (여유 있게 더 당겼으면 +2단위)
/// - 사용자가 처방보다 무거운 무게로 성공했으면 그 무게를 기준으로 채택
/// - 절반 이상 세트 실패가 2회 연속 → 무게 -1단위(10% 디로드)
/// - 맨몸 운동은 무게 대신 목표 횟수를 ±2 조정
/// - 유산소는 분(min)을 +2 (상한 40분)
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/models.dart';
import 'load_estimator.dart';

class ProgressionResult {
  ProgressionResult(this.progress, this.message);
  final ExerciseProgress progress;

  /// 사용자에게 보여줄 한 줄 설명(예: "모든 세트 성공 → 다음 +2.5kg").
  final String message;
}

class Progression {
  /// [loadFactor]: 그날 처방 무게 배율(컨디션). 1.0 미만이면 "가벼운 날"로 보고
  /// 성공해도 작업 중량을 올리지 않는다(평소 무게를 든 게 아니므로).
  /// [rpe]: 운동 후 체감 강도 1~10. 낮으면 더 과감히, 높으면 보수적으로 올린다.
  static ProgressionResult apply(
    PlannedExercise planned,
    ExerciseProgress current,
    DateTime performedAt, {
    double loadFactor = 1.0,
    int? rpe,
  }) {
    final ex = exerciseById(planned.exerciseId);
    if (ex == null) return ProgressionResult(current, '');

    final done = planned.sets.where((s) => s.completed).toList();
    current.lastPerformed = performedAt;
    current.timesPerformed += 1;
    final lightDay = loadFactor < 0.95;

    if (done.isEmpty) {
      // 아무 세트도 안 했으면 무게 유지. 실패 카운트만 올린다.
      current.consecutiveFail += 1;
      current.consecutiveSuccess = 0;
      return ProgressionResult(current, '수행 기록 없음 → 유지');
    }

    final step = ex.loadType.increment;
    final targetReps = planned.sets.first.targetReps;
    final allHit = done.length == planned.sets.length &&
        done.every((s) => s.effectiveReps >= targetReps);
    final overReps = done.every((s) => s.effectiveReps >= targetReps + 2);
    final maxDoneWeight =
        done.map((s) => s.effectiveWeight).fold<double>(0, max);
    final failedHalf =
        done.where((s) => s.effectiveReps < targetReps).length * 2 >
                planned.sets.length ||
            done.length * 2 < planned.sets.length;

    // ── 유산소: 분 → 레벨 순으로 올린다 ──
    if (ex.loadType == LoadType.cardio) {
      final spec = cardioLevels[ex.id];
      final doneLevel = done.first.effectiveLevel;
      if (doneLevel != null) current.level = doneLevel; // 사용자가 바꾼 레벨이 새 기준
      if (allHit) {
        current.consecutiveSuccess += 1;
        current.consecutiveFail = 0;
        final easy = rpe != null && rpe <= 4;
        if (spec != null && current.level != null && (current.targetReps >= 30 || easy) && current.level! < spec.max) {
          current.level = current.level! + 1;
          return ProgressionResult(current, '완주 → 다음 ${spec.format(current.level!)} (${current.targetReps}분)');
        }
        current.targetReps = min(40, current.targetReps + 2);
        return ProgressionResult(current, '완주 → 다음 ${current.targetReps}분${spec != null && current.level != null ? ' · ${spec.format(current.level!)}' : ''}');
      }
      current.consecutiveFail += 1;
      if (spec != null && current.level != null && current.consecutiveFail >= 2 && current.level! > spec.min) {
        current.level = current.level! - 1;
        current.consecutiveFail = 0;
        return ProgressionResult(current, '2회 못 채움 → ${spec.format(current.level!)}로 낮춤');
      }
      return ProgressionResult(current, '유지 ${current.targetReps}분');
    }

    // ── 맨몸: 횟수 조정 ──
    if (ex.loadType == LoadType.bodyweight) {
      if (lightDay && allHit) {
        current.consecutiveFail = 0;
        return ProgressionResult(current, '가벼운 날 완수 → 목표 ${current.targetReps}회 유지');
      }
      if (overReps || (allHit && rpe != null && rpe <= 3)) {
        current.targetReps += 3;
      } else if (allHit && rpe != null && rpe >= 9) {
        // 유지
      } else if (allHit) {
        current.targetReps += 2;
      } else if (failedHalf) {
        current.targetReps = max(ex.repRange[0] ~/ 2, current.targetReps - 2);
      }
      if (allHit) {
        current.consecutiveSuccess += 1;
        current.consecutiveFail = 0;
        return ProgressionResult(current, '성공 → 다음 목표 ${current.targetReps}회');
      }
      current.consecutiveFail += 1;
      current.consecutiveSuccess = 0;
      return ProgressionResult(current, '목표 ${current.targetReps}회로 조정');
    }

    // ── 중량 운동 ──
    var newWeight = current.workingWeight;
    String msg;

    // 사용자가 더 무겁게 들었으면 그 무게를 새 기준으로.
    if (maxDoneWeight > newWeight && !failedHalf) {
      newWeight = maxDoneWeight;
    }
    // 사용자가 처방보다 낮춰서 했으면(컨디션 조정이 아닌 수동), 낮춘 무게가 새 기준.
    final plannedWeight = planned.sets.first.targetWeight;
    final lowered = !lightDay && maxDoneWeight > 0 && maxDoneWeight < plannedWeight;
    if (lowered) newWeight = maxDoneWeight;

    if (lowered && allHit) {
      current.consecutiveSuccess = 0;
      current.consecutiveFail = 0;
      if (overReps) {
        newWeight += step;
        msg = '무게를 낮춰 여유 있게 성공 → 기준 ${_fmt(newWeight)}kg';
      } else {
        msg = '무게를 낮춰 수행 → 기준을 ${_fmt(newWeight)}kg로 조정';
      }
    } else if (lightDay && allHit && maxDoneWeight < current.workingWeight) {
      // 컨디션 조절로 가볍게 한 날: 성공해도 기준 무게는 유지.
      current.consecutiveFail = 0;
      msg = '가벼운 날(${(loadFactor * 100).round()}%) 완수 → 기준 ${_fmt(newWeight)}kg 유지';
    } else if (allHit) {
      var bump = overReps ? step * 2 : step;
      if (rpe != null && rpe <= 3) bump = step * 2; // 너무 쉬웠으면 과감히
      if (rpe != null && rpe >= 9) bump = 0; // 전력투구였으면 같은 무게로 한 번 더
      newWeight += bump;
      current.consecutiveSuccess += 1;
      current.consecutiveFail = 0;
      msg = bump == 0
          ? '성공했지만 강도 $rpe/10 → 같은 무게로 한 번 더 (${_fmt(newWeight)}kg)'
          : overReps || (rpe != null && rpe <= 3)
              ? '여유 있게 성공 → 다음 +${_fmt(bump)}kg (${_fmt(newWeight)}kg)'
              : '모든 세트 성공 → 다음 +${_fmt(bump)}kg (${_fmt(newWeight)}kg)';
    } else if (failedHalf) {
      current.consecutiveFail += 1;
      current.consecutiveSuccess = 0;
      if (current.consecutiveFail >= 2) {
        newWeight = LoadEstimator.roundTo(newWeight * 0.9, step);
        current.consecutiveFail = 0;
        msg = '2회 연속 실패 → 10% 디로드 (${_fmt(newWeight)}kg)';
      } else {
        msg = '일부 실패 → 같은 무게 재도전 (${_fmt(newWeight)}kg)';
      }
    } else {
      current.consecutiveSuccess = 0;
      msg = '거의 성공 → 같은 무게 유지 (${_fmt(newWeight)}kg)';
    }

    current.workingWeight = max(step, newWeight);
    return ProgressionResult(current, msg);
  }

  static String _fmt(double w) =>
      w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}
