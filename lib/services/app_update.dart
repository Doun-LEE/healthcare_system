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

  /// 빌드할 때 박아 넣은 '버전+빌드'(웹 CI). 웹의 PackageInfo 는 서버 version.json 을 읽어서
  /// '지금 실행 중인 번들'의 버전을 알 수 없으므로 이 값을 쓴다. 로컬 빌드면 빈 문자열.
  static const bundledBuild = String.fromEnvironment('APP_BUILD');

  static Future<String> currentVersion() async {
    if (bundledBuild.isNotEmpty) {
      final i = bundledBuild.indexOf('+');
      return i < 0 ? bundledBuild : '${bundledBuild.substring(0, i)} (${bundledBuild.substring(i + 1)})';
    }
    _info ??= await PackageInfo.fromPlatform();
    final v = _info!.version;
    final b = _info!.buildNumber;
    return b.isEmpty ? v : '$v ($b)';
  }

  /// '버전+빌드'(웹 version.json 과 같은 모양).
  static Future<String> currentVersionAndBuild() async {
    if (bundledBuild.isNotEmpty) return bundledBuild;
    _info ??= await PackageInfo.fromPlatform();
    final b = _info!.buildNumber;
    return b.isEmpty ? _info!.version : '${_info!.version}+$b';
  }

  static Future<String> currentVersionOnly() async {
    if (bundledBuild.isNotEmpty) return bundledBuild.split('+').first;
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
