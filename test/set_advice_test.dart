import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/set_advice.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ex = exerciseById('bb_bench')!;
  SetEntry s(int reps, double w, {int? done, double? doneW}) => SetEntry(targetReps: reps, targetWeight: w, doneReps: done, doneWeight: doneW, completed: true);

  test('목표보다 3회 이상 더 하면 무게 한 칸 올리고 횟수는 원래대로', () {
    final a = adviseNextSet(ex, s(10, 40, done: 13), SetEntry(targetReps: 9, targetWeight: 40), step: 2.5)!;
    expect(a.weight, 42.5);
    expect(a.reps, 9);
    expect(a.up, isTrue);
  });

  test('1~2회 더 하면 무게 그대로 횟수만', () {
    final a = adviseNextSet(ex, s(10, 40, done: 11), SetEntry(targetReps: 9, targetWeight: 40), step: 2.5)!;
    expect(a.weight, 40);
    expect(a.reps, 11);
  });

  test('2회 이상 모자라면 한 횟수로 추정한 힘에 맞춰 내림, 목표대로면 추천 없음', () {
    final a = adviseNextSet(ex, s(10, 40, done: 7), SetEntry(targetReps: 9, targetWeight: 40), step: 2.5)!;
    expect(a.weight, 35);
    // 140kg 8회 목표에 5회 → 한 칸(137.5)이 아니라 8회 할 수 있는 무게로
    final b = adviseNextSet(ex, s(8, 140, done: 5), SetEntry(targetReps: 8, targetWeight: 140), step: 2.5)!;
    expect(b.weight, inInclusiveRange(120, 130));
    expect(a.up, isFalse);
    expect(adviseNextSet(ex, s(10, 40), SetEntry(targetReps: 9, targetWeight: 40), step: 2.5), isNull);
  });

  test('한쪽 기준 표시 배율이 문구에 반영', () {
    final a = adviseNextSet(ex, s(10, 80, done: 13), SetEntry(targetReps: 10, targetWeight: 80), step: 5, factor: 0.5)!;
    expect(a.message, contains('42.5kg'));
  });
}
