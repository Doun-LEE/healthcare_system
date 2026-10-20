/// 앱 버전 표시 + GitHub Releases 에서 새 버전 확인 (APK 배포용).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const String githubRepo = 'Doun-LEE/healthcare_system';
const String releasesPage = 'https://github.com/$githubRepo/releases/latest';

class ReleaseInfo {
  ReleaseInfo({required this.version, required this.apkUrl, required this.notes, required this.pageUrl});
  final String version; // 'X.Y.Z'
  final String? apkUrl;
  final String notes;
  final String pageUrl;
}

class AppUpdate {
  static PackageInfo? _info;

  static Future<String> currentVersion() async {
    _info ??= await PackageInfo.fromPlatform();
    final v = _info!.version;
    final b = _info!.buildNumber;
    return b.isEmpty ? v : '$v ($b)';
  }

  static Future<String> currentVersionOnly() async {
    _info ??= await PackageInfo.fromPlatform();
    return _info!.version;
  }

  /// 최신 릴리스. 없거나 네트워크 실패면 null.
  static Future<ReleaseInfo?> latest() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'),
              headers: {'accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
      String? apk;
      for (final a in (j['assets'] as List? ?? const [])) {
        final name = (a as Map)['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apk = a['browser_download_url'] as String?;
          break;
        }
      }
      return ReleaseInfo(
        version: tag,
        apkUrl: apk,
        notes: (j['body'] as String?) ?? '',
        pageUrl: (j['html_url'] as String?) ?? releasesPage,
      );
    } catch (_) {
      return null;
    }
  }

  /// a > b 이면 양수. '1.2.10' vs '1.2.9' 같은 비교를 숫자로 한다.
  static int compare(String a, String b) {
    List<int> parse(String v) =>
        v.split('-').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final x = parse(a), y = parse(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0;
      final yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi - yi;
    }
    return 0;
  }
}
