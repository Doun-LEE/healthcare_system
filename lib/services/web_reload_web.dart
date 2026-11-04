import 'dart:convert';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// 웹앱 새 버전 반영. 오프라인 우선 서비스 워커가 예전 빌드를 계속 보여주는 걸 막는다.
class WebReload {
  WebReload._();

  static const _key = 'fr_reload_tried';

  /// 서버에 올라간 웹 버전(flutter build 가 만든 version.json). 실패하면 null.
  static Future<String?> deployedVersion() async {
    try {
      final base = Uri.base;
      final url = base.replace(path: '/version.json', queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'}, fragment: '');
      final res = await http.get(url, headers: {'cache-control': 'no-cache'}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return j['version'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 서비스 워커 등록 해제 + 캐시 삭제 후 새로고침.
  static Future<void> hardReload() async {
    try {
      final regs = (await web.window.navigator.serviceWorker.getRegistrations().toDart).toDart;
      for (final r in regs) {
        await r.unregister().toDart;
      }
    } catch (_) {}
    try {
      final keys = (await web.window.caches.keys().toDart).toDart;
      for (final k in keys) {
        await web.window.caches.delete(k.toDart).toDart;
      }
    } catch (_) {}
    web.window.location.reload();
  }

  static bool triedFor(String version) {
    try {
      return web.window.sessionStorage.getItem(_key) == version;
    } catch (_) {
      return false;
    }
  }

  static void markTried(String version) {
    try {
      web.window.sessionStorage.setItem(_key, version);
    } catch (_) {}
  }
}
