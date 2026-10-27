/// 운동 기록 화면(애플 워치 피트니스·삼성 헬스·가민·나이키 런 등)의 글자 → 유산소 세부 기록.
///
/// AI 없이 규칙만으로 읽는다. 단위가 붙은 숫자(KM, BPM, SPM, KCAL, W, MS, '/KM)는 그 자체로
/// 뜻이 정해지므로 단위를 기준으로 찾고, 같은 단위가 여러 개면 가까운 라벨(평균·최대·활동·총)로 가른다.
library;

import '../data/catalog.dart';
import '../models/models.dart';

/// 사진(또는 글자)에서 읽은 결과.
class PhotoWorkout {
  PhotoWorkout({required this.exerciseId, required this.stats, this.date, this.title, this.method});

  /// 카탈로그의 유산소 운동 id(야외 러닝 등).
  String exerciseId;
  final CardioStats stats;

  /// 기록에 날짜가 보이면 그 날짜.
  final DateTime? date;

  /// 기록에 보이는 운동 이름(예: '실외 달리기').
  final String? title;

  /// 어떻게 읽었는지('기기 안 인식', 'AI 인식').
  String? method;

  /// 기록할 분(시간이 없으면 0).
  int get minutes => stats.durationSec == null ? 0 : (stats.durationSec! / 60).round().clamp(1, 1440);

  /// 시간이나 거리 중 하나는 있어야 쓸 만한 기록이다.
  bool get usable => stats.durationSec != null || stats.distanceKm != null;
}

class WorkoutTextParser {
  /// 사진에서 고를 수 있는 운동(유산소·스포츠).
  static List<Exercise> get choices =>
      exerciseCatalog.where((e) => e.group == MuscleGroup.cardio && e.loadType == LoadType.cardio && !e.warmupOnly).toList();

  /// 글자 → 기록. 아무것도 못 찾으면 비어 있는 stats로 돌려준다.
  static PhotoWorkout parse(String raw, {DateTime? today}) {
    final text = normalize(raw);
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final s = CardioStats(source: '사진 인식');

    s.durationSec = _duration(lines);
    s.distanceKm = _distance(text);
    _kcal(lines, s);
    _heart(lines, s);
    s.paceSec = _pace(lines, s);
    s.cadence = _first(text, RegExp(r'(\d{2,3})\s*(?:SPM|RPM|걸음/분|STEPS/MIN)'), 20, 260);
    s.powerW = _first(text, RegExp(r'(\d{2,4})\s*W(?![A-Z])'), 10, 2000);
    s.contactMs = _first(text, RegExp(r'(\d{2,4})\s*MS(?![A-Z])'), 50, 1000);
    s.strideM = _stride(text);
    s.elevationM = _elevation(lines);
    s.speedKmh = _dbl(text, RegExp(r'(\d+(?:[.,]\d+)?)\s*KM/H'), 0.5, 120);
    s.effort = _effort(text);
    s.splits.addAll(_splits(lines));

    final (id, title) = _exercise(lines);
    return PhotoWorkout(exerciseId: id, stats: s, date: _date(text, today ?? DateTime.now()), title: title, method: '기기 안 인식');
  }

  /// 대문자·기호 통일, 숫자 자리의 O/I/l 오인식 교정.
  static String normalize(String raw) {
    var t = raw
        .replaceAll('’', "'")
        .replaceAll('′', "'")
        .replaceAll('″', '"')
        .replaceAll('″', '"')
        .replaceAll("''", '"')
        .replaceAll('’', "'")
        .replaceAll('，', ',')
        .replaceAll('：', ':')
        .toUpperCase();
    // 숫자 사이의 O → 0, I/l → 1 (예: 1O.2OKM, O8:17)
    for (var i = 0; i < 2; i++) {
      t = t.replaceAllMapped(RegExp(r'(?<=[\d:.])O(?=[\d:.KBSM])|O(?=\d{1,2}:\d)|(?<=\d)O(?=\d)'), (_) => '0');
      t = t.replaceAllMapped(RegExp(r'(?<=[\d:.])[IL](?=[\d:.])'), (_) => '1');
    }
    return t;
  }

  static int? _first(String text, RegExp re, int lo, int hi) {
    for (final m in re.allMatches(text)) {
      final v = int.tryParse(m.group(1)!);
      if (v != null && v >= lo && v <= hi) return v;
    }
    return null;
  }

  static double? _dbl(String text, RegExp re, double lo, double hi) {
    for (final m in re.allMatches(text)) {
      final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (v != null && v >= lo && v <= hi) return v;
    }
    return null;
  }

  static final _time = RegExp(r'(?<![\d.])(\d{1,2}):(\d{2})(?::(\d{2}))?(?![\d.])');

  static int _sec(RegExpMatch m) {
    final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
    final c = m.group(3) == null ? null : int.parse(m.group(3)!);
    return c == null ? a * 60 + b : a * 3600 + b * 60 + c;
  }

  /// 라벨('운동 시간' 등) 뒤 2줄 안의 첫 시간 → 없으면 h:mm:ss 중 최대 → 없으면 mm:ss 중 최대
  /// (맨 윗줄의 상태바 시계와 스플릿 표의 행은 뺀다).
  static int? _duration(List<String> lines) {
    final label = RegExp(r'운동\s*시간|총\s*시간|TOTAL TIME|DURATION|ELAPSED|^시간$|MOVING TIME|WORKOUT TIME');
    for (var i = 0; i < lines.length; i++) {
      if (!label.hasMatch(lines[i]) || lines[i].contains('접촉')) continue;
      for (var j = i; j < lines.length && j <= i + 2; j++) {
        final m = _time.firstMatch(lines[j]);
        if (m != null && !_isSplitRow(lines[j])) {
          final v = _sec(m);
          if (v >= 30 && v <= 86400) return v;
        }
      }
    }
    int? best;
    for (final l in lines) {
      for (final m in _time.allMatches(l)) {
        if (m.group(3) == null) continue;
        final v = _sec(m);
        if (v >= 60 && v <= 86400 && (best == null || v > best)) best = v;
      }
    }
    if (best != null) return best;
    for (var i = 1; i < lines.length; i++) {
      if (_isSplitRow(lines[i])) continue;
      for (final m in _time.allMatches(lines[i])) {
        final v = _sec(m);
        if (v >= 60 && v <= 86400 && (best == null || v > best)) best = v;
      }
    }
    return best;
  }

  static final _splitRow = RegExp(r'^\s*(\d{1,2})\s+(?:(\d+(?:[.,]\d+)?)\s*KM\s+)?(\d{1,2}:\d{2}(?::\d{2})?)(?:\s*(\d{1,2})[' "'" r':](\d{2})"?\s*/?\s*KM)?\s*(?:(\d{2,3})\s*BPM)?');

  static bool _isSplitRow(String l) {
    final m = _splitRow.firstMatch(l);
    return m != null && (m.group(2) != null || m.group(4) != null || m.group(6) != null);
  }

  static double? _distance(String text) {
    double? best;
    for (final m in RegExp(r'(\d+(?:[.,]\d+)?)\s*(KM|MI)(?![A-Z/])').allMatches(text)) {
      var v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (v == null) continue;
      if (m.group(2) == 'MI') v *= 1.609;
      if (v >= 0.05 && v <= 500 && (best == null || v > best)) best = v;
    }
    return best;
  }

  static void _kcal(List<String> lines, CardioStats s) {
    final re = RegExp(r'(\d{2,5})\s*(?:KCAL|CAL|칼로리)');
    final vals = <(int, String)>[]; // (값, 앞 두 줄의 문맥)
    for (var i = 0; i < lines.length; i++) {
      for (final m in re.allMatches(lines[i])) {
        final v = int.parse(m.group(1)!);
        if (v < 1 || v > 20000) continue;
        final ctx = [for (var j = (i - 2).clamp(0, i); j <= i; j++) lines[j]].join(' ');
        // 같은 줄에 두 값이 있으면(왼쪽 활동, 오른쪽 총) 라벨도 그 순서로 온다.
        vals.add((v, ctx));
      }
    }
    if (vals.isEmpty) return;
    final act = vals.where((e) => e.$2.contains('활동') || e.$2.contains('ACTIVE')).toList();
    final tot = vals.where((e) => e.$2.contains('총') || e.$2.contains('TOTAL')).toList();
    if (act.isNotEmpty && tot.isNotEmpty && act.length == vals.length) {
      // 라벨 둘 다 같은 문맥에 걸림(한 줄에 "활동 킬로칼로리  총 킬로칼로리") → 순서대로.
      s.activeKcal = vals.first.$1;
      s.totalKcal = vals.length > 1 ? vals[1].$1 : null;
    } else if (act.isNotEmpty || tot.isNotEmpty) {
      s.activeKcal = act.isEmpty ? null : act.first.$1;
      s.totalKcal = tot.isEmpty ? null : tot.first.$1;
    } else if (vals.length == 1) {
      s.totalKcal = vals.first.$1;
    } else {
      final sorted = vals.map((e) => e.$1).toList()..sort();
      s.activeKcal = sorted.first;
      s.totalKcal = sorted.last;
    }
    if (s.activeKcal != null && s.totalKcal != null && s.activeKcal! > s.totalKcal!) {
      final t = s.activeKcal;
      s.activeKcal = s.totalKcal;
      s.totalKcal = t;
    }
  }

  static void _heart(List<String> lines, CardioStats s) {
    final re = RegExp(r'(\d{2,3})\s*BPM');
    int? avg, max;
    for (var i = 0; i < lines.length; i++) {
      if (_isSplitRow(lines[i])) continue;
      final ctx = [for (var j = (i - 2).clamp(0, i); j <= i; j++) lines[j]].join(' ');
      for (final m in re.allMatches(lines[i])) {
        final v = int.parse(m.group(1)!);
        if (v < 30 || v > 240) continue;
        // 같은 줄에서 이 값 바로 앞에 있는 라벨이 '최대'면 최대 심박("평균 150BPM  최대 181BPM").
        final before = lines[i].substring(0, m.start);
        final lastMax = _lastIndex(before, const ['최대', '최고', 'MAX', 'PEAK']);
        final lastAvg = _lastIndex(before, const ['평균', 'AVG', 'AVERAGE']);
        final isMax = lastMax >= 0 || lastAvg >= 0
            ? lastMax > lastAvg
            : RegExp(r'최대|최고|MAX|PEAK').hasMatch(ctx) && !RegExp(r'평균|AVG|AVERAGE').hasMatch(ctx);
        if (isMax && max == null && (avg == null || v >= avg)) {
          max = v;
        } else {
          avg ??= v;
        }
      }
    }
    s.avgHr = avg;
    s.maxHr = max;
  }

  static int _lastIndex(String s, List<String> words) {
    var best = -1;
    for (final w in words) {
      final i = s.lastIndexOf(w);
      if (i > best) best = i;
    }
    return best;
  }

  static final _paceRe = RegExp(r'(\d{1,2})[' "'" r':](\d{2})"?\s*/?\s*(KM|MI)');

  static int? _pace(List<String> lines, CardioStats s) {
    int? found;
    for (var i = 0; i < lines.length && found == null; i++) {
      if (_isSplitRow(lines[i])) continue;
      for (final m in _paceRe.allMatches(lines[i])) {
        var v = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
        if (m.group(3) == 'MI') v = (v / 1.609).round();
        if (v >= 60 && v <= 3600) {
          found = v;
          break;
        }
      }
    }
    final d = s.distanceKm, t = s.durationSec;
    if (d != null && t != null && d > 0) {
      final calc = (t / d).round();
      // 읽은 페이스가 계산값과 많이 다르면(스플릿 값을 집었거나 오인식) 계산값.
      if (found == null || (found - calc).abs() > calc * 0.35) return calc;
    }
    return found;
  }

  static double? _stride(String text) {
    for (final m in RegExp(r'(\d+[.,]\d+)\s*M(?![A-Z/])').allMatches(text)) {
      final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (v != null && v >= 0.3 && v <= 3) return v;
    }
    final cm = _first(text, RegExp(r'(\d{2,3})\s*CM'), 30, 300);
    return cm == null ? null : cm / 100;
  }

  static int? _elevation(List<String> lines) {
    final re = RegExp(r'(?<![\d.,])(\d{1,4})\s*M(?![A-Z/])');
    for (var i = 0; i < lines.length; i++) {
      final ctx = [for (var j = (i - 2).clamp(0, i); j <= i; j++) lines[j]].join(' ');
      if (!RegExp(r'고도|상승|ELEV|ASCENT|CLIMB').hasMatch(ctx)) continue;
      final v = _first(lines[i], re, 0, 10000);
      if (v != null) return v;
    }
    return null;
  }

  static int? _effort(String text) {
    final m = RegExp(r'(?:운동\s*강도|EFFORT|강도)[^\d\n]{0,15}(\d{1,2})').firstMatch(text) ??
        RegExp(r'(?<!\d)(\d{1,2})\s*(?:매우\s*어려움|어려움|보통|쉬움|힘듦|HARD|EASY|MODERATE)').firstMatch(text);
    final v = m == null ? null : int.tryParse(m.group(1)!);
    return v == null || v < 1 || v > 10 ? null : v;
  }

  static List<CardioSplit> _splits(List<String> lines) {
    final out = <CardioSplit>[];
    var expect = 1;
    for (final l in lines) {
      final m = _splitRow.firstMatch(l);
      if (m == null || !_isSplitRow(l)) continue;
      final idx = int.parse(m.group(1)!);
      if (idx != expect) {
        if (idx == 1 && out.isNotEmpty) break; // 두 번째 표(구간)는 안 읽는다
        continue;
      }
      expect++;
      final km = m.group(2) == null ? null : double.tryParse(m.group(2)!.replaceAll(',', '.'));
      final tm = _time.firstMatch(m.group(3)!);
      final sec = tm == null ? null : _sec(tm);
      final pace = m.group(4) == null ? null : int.parse(m.group(4)!) * 60 + int.parse(m.group(5)!);
      final hr = m.group(6) == null ? null : int.parse(m.group(6)!);
      out.add(CardioSplit(distanceKm: km, sec: sec, paceSec: pace, hr: hr != null && hr >= 30 && hr <= 240 ? hr : null));
      if (out.length >= 60) break;
    }
    return out;
  }

  static const _keywords = <(String, String)>[
    ('트레드밀 걷기', 'treadmill_walk'), ('실내 걷기', 'treadmill_walk'), ('실내 달리기', 'treadmill_run'), ('트레드밀', 'treadmill_run'),
    ('INDOOR RUN', 'treadmill_run'), ('INDOOR WALK', 'treadmill_walk'), ('TREADMILL', 'treadmill_run'),
    ('트레일', 'trail_run'), ('TRAIL', 'trail_run'),
    ('실외 달리기', 'outdoor_run'), ('야외 달리기', 'outdoor_run'), ('달리기', 'outdoor_run'), ('러닝', 'outdoor_run'), ('RUNNING', 'outdoor_run'), ('RUN', 'outdoor_run'),
    ('실외 걷기', 'outdoor_walk'), ('야외 걷기', 'outdoor_walk'), ('걷기', 'outdoor_walk'), ('WALK', 'outdoor_walk'),
    ('실내 사이클', 'bike'), ('실내 자전거', 'bike'), ('INDOOR CYCL', 'bike'), ('사이클', 'outdoor_bike'), ('자전거', 'outdoor_bike'), ('CYCL', 'outdoor_bike'), ('BIKE', 'outdoor_bike'), ('RIDE', 'outdoor_bike'),
    ('수영', 'swim'), ('SWIM', 'swim'),
    ('하이킹', 'hiking'), ('등산', 'hiking'), ('HIK', 'hiking'),
    ('계단', 'stairs'), ('STAIR', 'stairs'), ('로잉', 'rowing'), ('ROW', 'rowing'), ('일립티컬', 'elliptical'), ('ELLIPTICAL', 'elliptical'),
    ('줄넘기', 'jump_rope'), ('축구', 'soccer'), ('SOCCER', 'soccer'), ('FOOTBALL', 'soccer'), ('풋살', 'futsal'), ('농구', 'basketball'), ('BASKETBALL', 'basketball'),
    ('배드민턴', 'badminton'), ('테니스', 'tennis'), ('탁구', 'table_tennis'), ('배구', 'volleyball'), ('야구', 'baseball'), ('스쿼시', 'squash'),
    ('클라이밍', 'climbing'), ('복싱', 'boxing'), ('BOX', 'boxing'), ('주짓수', 'jiujitsu'), ('골프', 'golf'), ('GOLF', 'golf'), ('스키', 'ski'), ('스노보드', 'ski'), ('댄스', 'dance'), ('DANCE', 'dance'),
  ];

  static (String, String?) _exercise(List<String> lines) {
    final valid = {for (final e in choices) e.id};
    for (final l in lines) {
      for (final (k, id) in _keywords) {
        if (l.contains(k.toUpperCase()) && valid.contains(id)) {
          final title = l.length <= 24 ? l : k;
          return (id, title);
        }
      }
    }
    return ('outdoor_run', null);
  }

  static DateTime? _date(String text, DateTime today) {
    final full = RegExp(r'(20\d{2})\s*[.\-/년]\s*(\d{1,2})\s*[.\-/월]\s*(\d{1,2})').firstMatch(text);
    if (full != null) {
      final d = DateTime(int.parse(full.group(1)!), int.parse(full.group(2)!), int.parse(full.group(3)!));
      if (d.month >= 1 && d.month <= 12) return d;
    }
    final md = RegExp(r'(?<!\d)(\d{1,2})월\s*(\d{1,2})일').firstMatch(text);
    if (md != null) {
      var d = DateTime(today.year, int.parse(md.group(1)!), int.parse(md.group(2)!));
      if (d.isAfter(today)) d = DateTime(today.year - 1, d.month, d.day);
      return d;
    }
    if (text.contains('어제')) return DateTime(today.year, today.month, today.day - 1);
    if (text.contains('오늘')) return DateTime(today.year, today.month, today.day);
    return null;
  }
}
