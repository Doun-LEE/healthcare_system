/// 폰 내부 저장소. 앱 데이터 전체를 JSON 파일 하나로 저장한다.
///
/// 개인용 앱이고 데이터가 작기 때문에 DB 대신 단일 문서 저장을 택했다.
/// 쓰기는 임시 파일에 쓴 뒤 rename 해서 중간에 꺼져도 파일이 깨지지 않게 한다.
library;

import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import '../services/partner.dart';

class AppData {
  AppData({
    this.accessCode = '23007344',
    this.currentUserId,
    List<UserProfile>? profiles,
    List<Gym>? gyms,
    List<DayPlan>? plans,
    Map<String, Map<String, ExerciseProgress>>? progress,
    DateTime? updatedAt,
    List<PartnerLink>? partners,
    Map<String, DateTime>? deleted,
    Map<String, DateTime>? editedAt,
  })  : deleted = deleted ?? {},
        editedAt = editedAt ?? {},
        profiles = profiles ?? [],
        gyms = gyms ?? [],
        plans = plans ?? [],
        progress = progress ?? {},
        partners = partners ?? [],
        updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// 일부러 지운 것('userId|날짜' 기록, 'gym:id', 'profile:id' → 지운 시각). 기기끼리 합칠 때 되살리지 않는다.
  final Map<String, DateTime> deleted;

  /// 헬스장·프로필별 마지막 수정 시각('gym:id', 'profile:id'). 기기끼리 합칠 때 더 최근 것을 남긴다.
  final Map<String, DateTime> editedAt;

  /// 등록한 운동 파트너(계정).
  final List<PartnerLink> partners;

  /// 읽다가 건너뛴 항목 수(이 앱 버전이 모르는 새 형식 등). 0이 아니면 이 데이터로 덮어쓰지 않는다.
  int skippedItems = 0;

  /// 이 기기에서 바뀌었는데 아직 클라우드에 못 올린 내용이 있음.
  bool unsynced = false;

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
        if (unsynced) 'unsynced': true,
        'updatedAt': updatedAt.toIso8601String(),
        'accessCode': accessCode,
        'currentUserId': currentUserId,
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'gyms': gyms.map((g) => g.toJson()).toList(),
        'plans': plans.map((p) => p.toJson()).toList(),
        'partners': partners.map((p) => p.toJson()).toList(),
        if (deleted.isNotEmpty) 'deleted': {for (final e in deleted.entries) e.key: e.value.toIso8601String()},
        if (editedAt.isNotEmpty) 'editedAt': {for (final e in editedAt.entries) e.key: e.value.toIso8601String()},
        'progress': {
          for (final e in progress.entries)
            e.key: {for (final p in e.value.entries) p.key: p.value.toJson()},
        },
      };

  /// 항목 하나가 깨졌거나 모르는 형식이어도 나머지는 살린다(건너뛴 수는 [skippedItems]).
  factory AppData.fromJson(Map<String, dynamic> j) {
    _skipped = 0;
    final d = AppData._fromJson(j);
    d.skippedItems = _skipped;
    d.unsynced = (j['unsynced'] as bool?) ?? false;
    return d;
  }

  factory AppData._fromJson(Map<String, dynamic> j) => AppData(
        updatedAt: j['updatedAt'] == null ? null : DateTime.tryParse(j['updatedAt'] as String),
        accessCode: j['accessCode'] as String? ?? '23007344',
        currentUserId: j['currentUserId'] as String?,
        profiles: _each(j['profiles'], UserProfile.fromJson),
        gyms: _each(j['gyms'], Gym.fromJson),
        plans: _each(j['plans'], DayPlan.fromJson),
        deleted: _times(j['deleted']),
        editedAt: _times(j['editedAt']),
        partners: _each(j['partners'], PartnerLink.fromJson),
        progress: {
          for (final e in ((j['progress'] as Map?) ?? {}).entries)
            e.key as String: {
              for (final p in (e.value as Map).entries)
                p.key as String: ?_one(p.value, ExerciseProgress.fromJson),
            },
        },
      );
}

int _skipped = 0;

T? _one<T>(Object? raw, T Function(Map<String, dynamic>) f) {
  try {
    return f((raw as Map).cast<String, dynamic>());
  } catch (_) {
    _skipped++;
    return null;
  }
}

List<T> _each<T>(Object? raw, T Function(Map<String, dynamic>) f) => [
      for (final x in (raw as List?) ?? const [])
        ?_one(x, f),
    ];

Map<String, DateTime> _times(Object? m) => {
      for (final e in ((m as Map?) ?? const {}).entries)
        if (DateTime.tryParse('${e.value}') != null) '${e.key}': DateTime.parse('${e.value}'),
    };

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

  File get _bak => File('${file.path}.bak');
  File get _tmp => File('${file.path}.tmp');
  bool _backedUp = false;

  Future<AppData?> _read(File f) async {
    try {
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      if (text.trim().isEmpty) return null;
      return AppData.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 본 파일 → (저장 도중 꺼졌을 때) 임시 파일 → 이번 실행 전 백업 순서로 읽는다.
  @override
  Future<AppData> load() async {
    final main = await _read(file);
    if (main != null) return main;
    if (await file.exists()) {
      try {
        await file.copy('${file.path}.corrupt');
      } catch (_) {}
    }
    return await _read(_tmp) ?? await _read(_bak) ?? AppData();
  }

  @override
  Future<void> save(AppData data) async {
    await file.parent.create(recursive: true);
    // 앱을 켠 뒤 처음 저장할 때 직전 상태를 .bak으로 남긴다(실행마다 하나).
    if (!_backedUp && await file.exists()) {
      try {
        await file.copy(_bak.path);
      } catch (_) {}
      _backedUp = true;
    }
    await _tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    // 지우고 옮기면 그 사이에 꺼질 때 파일이 사라진다 → 바로 덮어쓰기(원자적 교체).
    await _tmp.rename(file.path);
  }
}
