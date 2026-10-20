import 'package:fit_routine/services/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version compare is numeric per segment', () {
    expect(AppUpdate.compare('0.1.10', '0.1.9'), greaterThan(0));
    expect(AppUpdate.compare('1.0.0', '0.9.9'), greaterThan(0));
    expect(AppUpdate.compare('0.1.1', '0.1.1'), 0);
    expect(AppUpdate.compare('0.1.1-dev', '0.1.1'), 0);
    expect(AppUpdate.compare('0.1.0', '0.1.1'), lessThan(0));
  });
}
