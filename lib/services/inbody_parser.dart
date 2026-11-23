/// 인바디 결과지 사진에서 읽은 글자 → 체중·골격근량·체지방률·측정일.
///
/// 결과지에는 그래프 눈금(70 85 100 …), 표준 범위(55.0~74.4) 같은 숫자가 많아서
/// 항목 이름이 있는 줄(없으면 바로 다음 줄)에서, 범위를 뺀 첫 숫자 중 소수점 있는 값을 먼저 고른다.
library;

class InbodyResult {
  InbodyResult({this.weightKg, this.skeletalMuscleKg, this.bodyFatPct, this.date});
  final double? weightKg;
  final double? skeletalMuscleKg;
  final double? bodyFatPct;
  final DateTime? date;

  bool get isEmpty => weightKg == null && skeletalMuscleKg == null && bodyFatPct == null;
}

final _num = RegExp(r'-?\d{1,3}(?:\.\d{1,2})?');
final _range = RegExp(r'\d{1,3}(?:\.\d)?\s*[~\-–]\s*\d{1,3}(?:\.\d)?');

/// 줄에서 [after] 위치 뒤 숫자 중 [lo]~[hi] 범위 값. 소수점 있는 값을 먼저.
double? _pick(String line, int after, double lo, double hi) {
  final rest = line.substring(after).replaceAll(_range, ' ');
  final all = [
    for (final m in _num.allMatches(rest))
      if (!m.group(0)!.startsWith('-')) m.group(0)!,
  ];
  double? firstAny;
  for (final s in all) {
    final v = double.tryParse(s);
    if (v == null || v < lo || v > hi) continue;
    if (s.contains('.')) return v;
    firstAny ??= v;
  }
  return firstAny;
}

double? _find(List<String> lines, List<String> keys, double lo, double hi, {List<String> not = const []}) {
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final low = raw.toLowerCase().replaceAll(' ', '');
    if (not.any((n) => low.contains(n.toLowerCase()))) continue;
    for (final k in keys) {
      // 글자 사이 띄어쓰기는 OCR마다 달라서 무시하고 찾는다(숫자 사이 띄어쓰기는 살려 둠).
      final re = RegExp(k.split('').where((ch) => ch != ' ').map(RegExp.escape).join(r'\s*'), caseSensitive: false);
      final m = re.firstMatch(raw);
      if (m == null) continue;
      final v = _pick(raw, m.end, lo, hi) ?? (i + 1 < lines.length ? _pick(lines[i + 1], 0, lo, hi) : null);
      if (v != null) return v;
    }
  }
  return null;
}

InbodyResult parseInbody(String text) {
  final lines = text.replaceAll(',', '.').split('\n').where((l) => l.trim().isNotEmpty).toList();
  final weight = _find(lines, ['체중', 'weight'], 25, 250, not: ['적정', '목표', '표준', '조절', 'control', 'target', 'ideal']);
  final smm = _find(lines, ['골격근량', 'skeletalmusclemass', 'smm', '골격근'], 8, 80, not: ['지방분석', 'fatanalysis', '조절']);
  var pbf = _find(lines, ['체지방률', 'percentbodyfat', 'pbf'], 2, 70);
  if (pbf == null && weight != null) {
    final fat = _find(lines, ['체지방량', 'bodyfatmass'], 1, 150, not: ['조절', 'control']);
    if (fat != null && fat < weight) pbf = double.parse((fat / weight * 100).toStringAsFixed(1));
  }
  DateTime? date;
  final dm = RegExp(r'(20\d{2})\s*[.\-/년]\s*(\d{1,2})\s*[.\-/월]\s*(\d{1,2})').firstMatch(text);
  if (dm != null) {
    final y = int.parse(dm.group(1)!), mo = int.parse(dm.group(2)!), d = int.parse(dm.group(3)!);
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
      final dt = DateTime(y, mo, d);
      if (!dt.isAfter(DateTime.now())) date = dt;
    }
  }
  return InbodyResult(weightKg: weight, skeletalMuscleKg: smm, bodyFatPct: pbf, date: date);
}
