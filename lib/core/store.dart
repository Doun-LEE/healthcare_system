/// 폰 내부 저장소. 앱 데이터 전체를 JSON 파일 하나로 저장한다.
///
/// 개인용 앱이고 데이터가 작기 때문에 DB 대신 단일 문서 저장을 택했다.
/// 쓰기는 임시 파일에 쓴 뒤 rename 해서 중간에 꺼져도 파일이 깨지지 않게 한다.
library;

import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

class AppData {
  AppData({
    this.accessCode = '23007344',
    this.currentUserId,
    List<UserProfile>? profiles,
    List<Gym>? gyms,
    List<DayPlan>? plans,
    Map<String, Map<String, ExerciseProgress>>? progress,
    DateTime? updatedAt,
  })  : profiles = profiles ?? [],
        gyms = gyms ?? [],
        plans = plans ?? [],
        progress = progress ?? {},
        updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// 마지막 변경 시각. 클라우드와 어느 쪽이 최신인지 비교할 때 쓴다.
  DateTime updatedAt;

  bool get isEmpty => profiles.isEmpty && gyms.isEmpty && plans.isEmpty;

  /// 로그인 코드 (요구사항 4). 기본 23007344, 설정에서 변경 가능.
  String accessCode;

  String? currentUserId;
  final List<UserProfile> profiles;
  final List<Gym> gyms;
  final List<DayPlan> plans;

  /// userId → exerciseId → 진행 상태
  final Map<String, Map<String, ExerciseProgress>> progress;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'updatedAt': updatedAt.toIso8601String(),
        'accessCode': accessCode,
        'currentUserId': currentUserId,
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'gyms': gyms.map((g) => g.toJson()).toList(),
        'plans': plans.map((p) => p.toJson()).toList(),
        'progress': {
          for (final e in progress.entries)
            e.key: {for (final p in e.value.entries) p.key: p.value.toJson()},
        },
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        updatedAt: j['updatedAt'] == null ? null : DateTime.tryParse(j['updatedAt'] as String),
        accessCode: j['accessCode'] as String? ?? '23007344',
        currentUserId: j['currentUserId'] as String?,
        profiles: ((j['profiles'] as List?) ?? [])
            .map((p) => UserProfile.fromJson(p as Map<String, dynamic>))
            .toList(),
        gyms: ((j['gyms'] as List?) ?? [])
            .map((g) => Gym.fromJson(g as Map<String, dynamic>))
            .toList(),
        plans: ((j['plans'] as List?) ?? [])
            .map((p) => DayPlan.fromJson(p as Map<String, dynamic>))
            .toList(),
        progress: {
          for (final e in ((j['progress'] as Map?) ?? {}).entries)
            e.key as String: {
              for (final p in (e.value as Map).entries)
                p.key as String:
                    ExerciseProgress.fromJson(p.value as Map<String, dynamic>),
            },
        },
      );
}

abstract class DataStore {
  Future<AppData> load();
  Future<void> save(AppData data);
}

/// 웹 데모·테스트용 메모리 저장소.
class MemoryStore implements DataStore {
  AppData? _data;

  @override
  Future<AppData> load() async => _data ?? AppData();

  @override
  Future<void> save(AppData data) async {
    // 직렬화를 거쳐 저장해 실제 저장소와 같은 동작을 보장한다.
    _data = AppData.fromJson(jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>);
  }
}

class LocalStore implements DataStore {
  LocalStore(this.file);

  final File file;

  @override
  Future<AppData> load() async {
    if (!await file.exists()) return AppData();
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return AppData();
      return AppData.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      // 깨진 파일은 백업해 두고 새로 시작한다.
      try {
        await file.copy('${file.path}.corrupt');
      } catch (_) {}
      return AppData();
    }
  }

  @override
  Future<void> save(AppData data) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }
}
