/// 앱 안 오류 보고: Flutter·Dart에서 잡히지 않은 예외를 Firestore `errors/` 에 남긴다.
///
/// Crashlytics 는 안드로이드에 google-services.json 과 Gradle 플러그인이 있어야 하고 웹은 지원하지 않아서,
/// 지금 단계(10명 테스트)에는 콘솔에서 바로 볼 수 있는 이 방식이 더 가볍다.
/// - 같은 오류는 세션당 한 번, 세션당 최대 8건만 보낸다(폭주 방지).
/// - 로그인한 사용자만(규칙상 uid 가 필요). 비밀값·개인정보는 담지 않는다(오류 문자열과 스택만).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ErrorReport {
  ErrorReport._();

  static final _sent = <String>{};
  static int _count = 0;
  static const _maxPerSession = 8;
  static String _version = '';
  static bool _installed = false;
  static bool enabled = true;

  /// 앱 시작 시 한 번. Firebase 가 초기화된 뒤에 부른다.
  static Future<void> install() async {
    if (_installed) return;
    _installed = true;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      prev?.call(details);
      record(details.exception, details.stack, where: 'flutter:${details.library ?? ''}');
    };
    PlatformDispatcher.instance.onError = (e, st) {
      record(e, st, where: 'dart');
      return true;
    };
  }

  /// 잡은 예외도 보낼 수 있다(예: 동기화 실패).
  static Future<void> record(Object error, StackTrace? stack, {String where = ''}) async {
    if (!enabled || kDebugMode) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final err = _cut(error.toString(), 1000);
      final key = '$where|${err.substring(0, err.length > 120 ? 120 : err.length)}';
      if (_sent.contains(key) || _count >= _maxPerSession) return;
      _sent.add(key);
      _count++;
      await FirebaseFirestore.instance.collection('errors').add({
        'uid': uid,
        'at': FieldValue.serverTimestamp(),
        'error': err,
        'stack': _cut(stack?.toString() ?? '', 6000),
        'where': _cut(where, 200),
        'version': _cut(_version, 40),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      }).timeout(const Duration(seconds: 10));
    } catch (_) {
      // 보고 자체가 실패해도 앱은 계속.
    }
  }

  static String _cut(String s, int n) => s.length <= n ? s : s.substring(0, n);
}
