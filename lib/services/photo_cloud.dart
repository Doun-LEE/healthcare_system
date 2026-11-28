/// 기구 사진 클라우드(Supabase Storage 'gym-photos' 버킷): 내가 찍은 사진을 올려 두고,
/// 친구 헬스장을 가져오거나 동기화하면 친구가 찍은 사진을 받아 이 기기에 저장한다.
/// 경로: {찍은 사람 uid}/{기구 id}.jpg. 버킷이 아직 없으면 조용히 아무것도 하지 않는다.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supa_sync.dart';

class PhotoCloud {
  PhotoCloud._();
  static const bucket = 'gym-photos';

  static String? get uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null; // 테스트 등 Firebase 초기화 전
    }
  }

  static bool get ready => SupaSync.enabled && uid != null;

  /// 이번 실행에서 못 받은 사진(없거나 권한 없음)은 다시 시도하지 않는다.
  static final _missing = <String>{};

  static StorageFileApi get _s => Supabase.instance.client.storage.from(bucket);

  /// 내 사진 올리기. 성공하면 true.
  static Future<bool> upload(String equipmentId, Uint8List bytes) async {
    final me = uid;
    if (!SupaSync.enabled || me == null) return false;
    try {
      await _s
          .uploadBinary('$me/$equipmentId.jpg', bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 30));
      _missing.remove('$me/$equipmentId');
      return true;
    } catch (e) {
      debugPrint('photo upload failed: $e');
      return false;
    }
  }

  static Future<void> remove(String equipmentId) async {
    final me = uid;
    if (!SupaSync.enabled || me == null) return;
    try {
      await _s.remove(['$me/$equipmentId.jpg']).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  /// [owner]가 찍은 사진 받기. 없으면 null.
  static Future<Uint8List?> download(String owner, String equipmentId) async {
    final key = '$owner/$equipmentId';
    if (!ready || _missing.contains(key)) return null;
    try {
      return await _s.download('$key.jpg').timeout(const Duration(seconds: 30));
    } catch (_) {
      _missing.add(key);
      return null;
    }
  }
}
