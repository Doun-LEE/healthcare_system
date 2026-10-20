/// 인바디 결과지 사진 → 수치 추출 (요구사항 13).
///
/// Claude 비전 API에 사진을 보내고 JSON 스키마로 강제한 결과를 받는다.
/// Dart에는 공식 Anthropic SDK가 없어 HTTP를 직접 호출한다.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class InBodyResult {
  InBodyResult({
    this.weightKg,
    this.skeletalMuscleKg,
    this.bodyFatPct,
    this.heightCm,
    this.age,
    this.sex,
    this.bmi,
    this.notes = '',
  });

  final double? weightKg;
  final double? skeletalMuscleKg;
  final double? bodyFatPct;
  final double? heightCm;
  final int? age;
  final Sex? sex;
  final double? bmi;
  final String notes;

  bool get hasCore => weightKg != null && (skeletalMuscleKg != null || bodyFatPct != null);

  factory InBodyResult.fromJson(Map<String, dynamic> j) => InBodyResult(
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        skeletalMuscleKg: (j['skeletal_muscle_mass_kg'] as num?)?.toDouble(),
        bodyFatPct: (j['body_fat_percent'] as num?)?.toDouble(),
        heightCm: (j['height_cm'] as num?)?.toDouble(),
        age: (j['age'] as num?)?.toInt(),
        sex: switch (j['sex']) {
          'male' => Sex.male,
          'female' => Sex.female,
          _ => null,
        },
        bmi: (j['bmi'] as num?)?.toDouble(),
        notes: (j['notes'] as String?) ?? '',
      );

  /// 프로필에 반영. null 값은 기존 값을 유지한다.
  void applyTo(UserProfile p) {
    if (weightKg != null) p.weightKg = weightKg!;
    if (skeletalMuscleKg != null) p.skeletalMuscleKg = skeletalMuscleKg;
    if (bodyFatPct != null) p.bodyFatPct = bodyFatPct;
    if (heightCm != null) p.heightCm = heightCm!;
    if (age != null) p.age = age!;
    if (sex != null) p.sex = sex!;
    p.inbodyScannedAt = DateTime.now();
  }
}

class InBodyScanException implements Exception {
  InBodyScanException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InBodyScanner {
  InBodyScanner({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const model = 'claude-opus-5-5';

  static const _schema = {
    'type': 'object',
    'properties': {
      'weight_kg': {'type': ['number', 'null']},
      'skeletal_muscle_mass_kg': {'type': ['number', 'null']},
      'body_fat_percent': {'type': ['number', 'null']},
      'height_cm': {'type': ['number', 'null']},
      'age': {'type': ['integer', 'null']},
      'sex': {'type': ['string', 'null'], 'enum': ['male', 'female', null]},
      'bmi': {'type': ['number', 'null']},
      'notes': {'type': 'string'},
    },
    'required': [
      'weight_kg',
      'skeletal_muscle_mass_kg',
      'body_fat_percent',
      'height_cm',
      'age',
      'sex',
      'bmi',
      'notes',
    ],
    'additionalProperties': false,
  };

  static String mediaTypeOf(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49) return 'image/gif';
    if (bytes.length > 11 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Future<InBodyResult> scan(Uint8List imageBytes) async {
    if (apiKey.trim().isEmpty) {
      throw InBodyScanException('설정에서 Claude API 키를 먼저 입력하세요.');
    }
    final body = {
      'model': model,
      'max_tokens': 2048,
      'output_config': {
        'effort': 'low',
        'format': {'type': 'json_schema', 'schema': _schema},
      },
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaTypeOf(imageBytes),
                'data': base64Encode(imageBytes),
              },
            },
            {
              'type': 'text',
              'text': '이 사진은 인바디(InBody) 체성분 결과지입니다. '
                  '체중(kg), 골격근량(kg), 체지방률(%), 신장(cm), 나이, 성별, BMI를 읽어 JSON으로 주세요. '
                  '읽을 수 없는 값은 null. notes에는 결과지에서 눈에 띄는 점(부위별 근육 불균형 등)을 한국어 한두 문장으로.',
            },
          ],
        },
      ],
    };

    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey.trim(),
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw InBodyScanException('네트워크 오류: $e');
    }

    if (res.statusCode == 401) throw InBodyScanException('API 키가 올바르지 않습니다.');
    if (res.statusCode == 429) throw InBodyScanException('요청이 너무 많습니다. 잠시 후 다시 시도하세요.');
    if (res.statusCode >= 400) {
      String detail = res.body;
      try {
        detail = (jsonDecode(res.body)['error']['message'] as String?) ?? res.body;
      } catch (_) {}
      throw InBodyScanException('분석 실패 (${res.statusCode}): $detail');
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (json['stop_reason'] == 'refusal') {
      throw InBodyScanException('모델이 이 이미지를 분석하지 않았습니다. 다른 사진으로 시도하세요.');
    }
    final content = json['content'] as List;
    final text = content
        .cast<Map<String, dynamic>>()
        .firstWhere((b) => b['type'] == 'text', orElse: () => {'text': '{}'})['text'] as String;
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    final result = InBodyResult.fromJson(parsed);
    if (!result.hasCore) {
      throw InBodyScanException('결과지에서 체중/골격근량을 읽지 못했습니다. 더 밝고 정면으로 찍어 주세요.');
    }
    return result;
  }
}
