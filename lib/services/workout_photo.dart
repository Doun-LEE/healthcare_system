/// 운동 기록 사진(애플 워치·갤럭시 워치·가민·나이키 런 등 캡처) → 유산소 세부 기록.
///
/// 1순위: 기기 안 글자 인식(OCR) + 규칙 파서([WorkoutTextParser]) — 한도·서버 없이 동작.
/// 2순위: 시간·거리를 못 찾았을 때만 Firebase AI Logic(Gemini)에 사진을 보내 보충한다.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/models.dart';
import 'ai_coach.dart';
import 'ocr.dart';
import 'workout_text_parser.dart';

export 'workout_text_parser.dart' show PhotoWorkout;

/// 사진 한 장(바이트 + MIME).
class WorkoutImage {
  const WorkoutImage(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

class WorkoutPhotoReader {
  /// 사진을 읽는다. 어느 방법으로도 못 읽으면 [AiCoachException].
  /// [allowAi]가 false 면(오늘 AI 한도 소진) 기기 인식만 쓴다. AI 를 실제로 썼으면 [onAiUsed]를 부른다.
  static Future<PhotoWorkout> read(List<WorkoutImage> images,
      {void Function(String)? onStep, DateTime? today, bool allowAi = true, void Function()? onAiUsed}) async {
    if (images.isEmpty) throw AiCoachException('사진을 골라 주세요.');

    PhotoWorkout? local;
    Object? localError;
    try {
      final texts = <String>[];
      for (var i = 0; i < images.length; i++) {
        onStep?.call('${images.length > 1 ? '${i + 1}/${images.length} 장 ' : ''}글자 읽는 중…');
        final t = await recognizeText(images[i].bytes, onStep: onStep);
        if (t != null) texts.add(t);
      }
      if (texts.isNotEmpty) local = WorkoutTextParser.parse(texts.join('\n'), today: today);
    } catch (e) {
      localError = e;
    }
    if (local != null && local.usable) return local;

    if (!allowAi) {
      if (local != null && !local.stats.isEmpty) return local;
      throw AiCoachException('기기에서 시간·거리를 찾지 못했고, 오늘 AI 보충 한도를 다 써서 AI 는 쓸 수 없어요. 숫자가 크게 보이는 요약 화면을 캡처해 다시 시도하거나 직접 입력하세요.');
    }
    onStep?.call('AI로 사진 읽는 중…');
    PhotoWorkout ai;
    try {
      ai = await _gemini(images);
      onAiUsed?.call();
    } on AiCoachException catch (e) {
      if (local != null && !local.stats.isEmpty) return local; // 뭔가는 읽었으니 그걸로
      throw AiCoachException(
        '${localError == null ? '기기에서 시간·거리를 찾지 못했고' : '기기 인식 실패($localError),'} AI도 쓸 수 없어요: ${e.message}\n'
        '숫자가 크게 보이는 요약 화면을 캡처해 다시 시도하거나 직접 입력하세요.',
      );
    }
    if (local == null) return ai;
    // 기기에서 읽은 값을 우선, 빈 칸만 AI로 채운다.
    final a = ai.stats, l = local.stats;
    l.durationSec ??= a.durationSec;
    l.distanceKm ??= a.distanceKm;
    l.activeKcal ??= a.activeKcal;
    l.totalKcal ??= a.totalKcal;
    l.avgHr ??= a.avgHr;
    l.maxHr ??= a.maxHr;
    l.paceSec ??= a.paceSec;
    l.cadence ??= a.cadence;
    l.strideM ??= a.strideM;
    l.contactMs ??= a.contactMs;
    l.powerW ??= a.powerW;
    l.elevationM ??= a.elevationM;
    l.speedKmh ??= a.speedKmh;
    l.effort ??= a.effort;
    if (l.splits.isEmpty) l.splits.addAll(a.splits);
    if (local.title == null) local.exerciseId = ai.exerciseId;
    return PhotoWorkout(exerciseId: local.exerciseId, stats: l, date: local.date ?? ai.date, title: local.title ?? ai.title, method: '기기 안 인식 + AI');
  }

  static const _system = '''
너는 운동 앱(애플 워치 피트니스, 갤럭시 워치/삼성 헬스, 가민, 나이키 런 클럽, 스트라바, 런데이 등) 화면 캡처에서
운동 기록 숫자를 읽는 도우미다. 여러 장이면 같은 운동의 다른 부분이니 합쳐서 하나로 답한다.
- 사진에 실제로 보이는 숫자만 쓴다. 보이지 않는 값은 넣지 말고 추측하지 않는다.
- 시간은 초로 바꾼다(1:11:42 → 4302). 페이스 7'02''/km → 422(초/km). mi 단위면 km로 바꾼다.
- 칼로리: '활동 킬로칼로리'는 activeKcal, '총 킬로칼로리'는 totalKcal.
- 케이던스는 spm(자전거는 rpm), 보폭은 m(cm면 m로), 지면 접촉 시간은 ms, 파워는 W, 등반 고도는 m.
- '운동 강도'가 1~10 숫자로 보이면 effort.
- 스플릿(1km마다)이 있으면 splits에 순서대로 넣는다. 스플릿이 없으면 구간을 넣는다.
- 그래프 축의 최소·최대 값은 평균으로 쓰지 않는다.
- exercise는 아래 목록의 id 중 가장 맞는 것 하나. 실외 달리기 → outdoor_run, 실내 달리기 → treadmill_run.
- 날짜가 보이면 date에 YYYY-MM-DD. 연도가 없으면 비운다.
출력은 JSON만.
''';

  static final _schema = Schema.object(
    properties: {
      'exercise': Schema.string(description: '목록의 운동 id'),
      'title': Schema.string(description: '사진에 보이는 운동 이름 그대로 (예: 실외 달리기)'),
      'date': Schema.string(description: 'YYYY-MM-DD, 보이면'),
      'durationSec': Schema.integer(),
      'distanceKm': Schema.number(),
      'activeKcal': Schema.integer(),
      'totalKcal': Schema.integer(),
      'avgHr': Schema.integer(),
      'maxHr': Schema.integer(),
      'paceSec': Schema.integer(description: '평균 페이스 초/km'),
      'cadence': Schema.integer(),
      'strideM': Schema.number(),
      'contactMs': Schema.integer(),
      'powerW': Schema.integer(),
      'elevationM': Schema.integer(),
      'speedKmh': Schema.number(),
      'effort': Schema.integer(),
      'splits': Schema.array(
        items: Schema.object(
          properties: {
            'distanceKm': Schema.number(),
            'sec': Schema.integer(),
            'paceSec': Schema.integer(),
            'hr': Schema.integer(),
          },
          optionalProperties: ['distanceKm', 'sec', 'paceSec', 'hr'],
        ),
      ),
    },
    optionalProperties: [
      'title', 'date', 'durationSec', 'distanceKm', 'activeKcal', 'totalKcal', 'avgHr', 'maxHr', 'paceSec', 'cadence', //
      'strideM', 'contactMs', 'powerW', 'elevationM', 'speedKmh', 'effort', 'splits',
    ],
  );

  static Future<PhotoWorkout> _gemini(List<WorkoutImage> images) async {
    final list = WorkoutTextParser.choices.map((e) => '${e.id}: ${e.name}').join('\n');
    final parts = <Part>[
      TextPart('운동 목록:\n$list\n\n아래 사진 ${images.length}장의 운동 기록을 읽어 줘.'),
      for (final i in images) InlineDataPart(i.mimeType, i.bytes),
    ];
    String? text;
    Object? lastError;
    for (final m in AiCoach.models) {
      try {
        final gm = FirebaseAI.googleAI().generativeModel(
          model: m,
          systemInstruction: Content.system(_system),
          generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: _schema),
        );
        final res = await gm.generateContent([Content.multi(parts)]).timeout(const Duration(seconds: 60));
        text = res.text;
        if (text != null && text.trim().isNotEmpty) break;
      } catch (e) {
        lastError = e;
        final msg = e.toString();
        if (msg.contains('403') || msg.contains('PERMISSION_DENIED') || msg.contains('not enabled')) {
          throw AiCoachException('Firebase 콘솔에서 AI Logic(Gemini)을 아직 켜지 않았습니다.');
        }
        if (msg.contains('429') || msg.contains('RESOURCE_EXHAUSTED') || msg.contains('quota')) {
          throw AiCoachException('오늘 AI 무료 한도를 다 썼어요.');
        }
      }
    }
    if (text == null || text.trim().isEmpty) {
      throw AiCoachException('AI 응답 없음${lastError == null ? '' : ' ($lastError)'}');
    }
    try {
      return parseAi(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      throw AiCoachException('AI가 사진 내용을 이해하지 못했어요.');
    }
  }

  /// 모델 응답 → 기록. 말이 안 되는 값(심박 300 등)은 버린다.
  static PhotoWorkout parseAi(Map<String, dynamic> j) {
    int? i(String k, int lo, int hi) {
      final v = j[k];
      final n = v is num ? v.round() : (v is String ? int.tryParse(v.trim()) : null);
      return n == null || n < lo || n > hi ? null : n;
    }

    double? d(String k, double lo, double hi) {
      final v = j[k];
      final n = v is num ? v.toDouble() : (v is String ? double.tryParse(v.trim()) : null);
      return n == null || n < lo || n > hi ? null : n;
    }

    final splits = <CardioSplit>[];
    for (final s in (j['splits'] as List?) ?? const []) {
      if (s is! Map) continue;
      int? si(String k, int lo, int hi) {
        final v = s[k];
        return v is num && v >= lo && v <= hi ? v.round() : null;
      }

      final km = s['distanceKm'];
      final sp = CardioSplit(
        distanceKm: km is num && km > 0 && km < 500 ? km.toDouble() : null,
        sec: si('sec', 1, 86400),
        paceSec: si('paceSec', 60, 3600),
        hr: si('hr', 30, 240),
      );
      if (sp.sec != null || sp.paceSec != null || sp.hr != null) splits.add(sp);
    }

    var stride = d('strideM', 0.1, 300);
    if (stride != null && stride > 3) stride = stride / 100; // cm로 온 경우
    final stats = CardioStats(
      durationSec: i('durationSec', 1, 86400),
      distanceKm: d('distanceKm', 0.01, 500),
      activeKcal: i('activeKcal', 1, 20000),
      totalKcal: i('totalKcal', 1, 20000),
      avgHr: i('avgHr', 30, 240),
      maxHr: i('maxHr', 30, 240),
      paceSec: i('paceSec', 60, 3600),
      cadence: i('cadence', 20, 260),
      strideM: stride,
      contactMs: i('contactMs', 50, 1000),
      powerW: i('powerW', 10, 2000),
      elevationM: i('elevationM', 0, 10000),
      speedKmh: d('speedKmh', 0.5, 120),
      effort: i('effort', 1, 10),
      splits: splits,
      source: '사진 인식(AI)',
    );

    final valid = {for (final e in WorkoutTextParser.choices) e.id};
    var id = (j['exercise'] as String?)?.trim() ?? '';
    if (!valid.contains(id)) id = 'outdoor_run';

    DateTime? date;
    final ds = j['date'];
    if (ds is String) {
      final p = DateTime.tryParse(ds.trim());
      if (p != null && p.year >= 2015) date = DateTime(p.year, p.month, p.day);
    }
    final title = (j['title'] as String?)?.trim();
    return PhotoWorkout(exerciseId: id, stats: stats, date: date, title: title == null || title.isEmpty ? null : title, method: 'AI 인식');
  }
}

/// 03'05" 형식 페이스.
String formatPace(int sec) => "${sec ~/ 60}'${(sec % 60).toString().padLeft(2, '0')}\"";

/// 1:11:42 / 53:41 형식 시간.
String formatDuration(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// 기록 카드에 보여 줄 짧은 항목들.
List<String> cardioStatChips(CardioStats s) {
  String km(double v) => v.toStringAsFixed(2);
  final pace = s.effectivePace;
  return [
    if (s.distanceKm != null) '${km(s.distanceKm!)}km',
    if (s.durationSec != null) formatDuration(s.durationSec!),
    if (pace != null) '${formatPace(pace)}/km',
    if (s.speedKmh != null) '${s.speedKmh!.toStringAsFixed(1)}km/h',
    if (s.avgHr != null) '평균 ${s.avgHr}bpm',
    if (s.maxHr != null) '최대 ${s.maxHr}bpm',
    if (s.cadence != null) '케이던스 ${s.cadence}spm',
    if (s.strideM != null) '보폭 ${s.strideM!.toStringAsFixed(2)}m',
    if (s.contactMs != null) '접지 ${s.contactMs}ms',
    if (s.powerW != null) '파워 ${s.powerW}W',
    if (s.elevationM != null) '고도 +${s.elevationM}m',
    if (s.totalKcal != null || s.activeKcal != null)
      s.totalKcal != null && s.activeKcal != null
          ? '${s.totalKcal}kcal (활동 ${s.activeKcal})'
          : '${s.totalKcal ?? s.activeKcal}kcal',
    if (s.effort != null) '강도 ${s.effort}/10',
  ];
}
