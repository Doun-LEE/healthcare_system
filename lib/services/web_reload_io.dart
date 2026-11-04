/// 앱(APK)용: 웹 새로고침 기능 없음.
class WebReload {
  WebReload._();

  /// 서버에 올라간 웹 버전('버전+빌드'). 앱에서는 null.
  static Future<String?> deployedVersion() async => null;

  /// 캐시를 비우고 새로고침. 앱에서는 아무것도 안 함.
  static Future<void> hardReload() async {}

  /// 이번 실행에서 이미 [version]으로 새로고침을 시도했는지(무한 새로고침 방지).
  static bool triedFor(String version) => true;
  static void markTried(String version) {}
}
