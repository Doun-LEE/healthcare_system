/// 웹앱 새 버전 반영(서비스 워커·캐시 비우고 새로고침). 앱(APK)에서는 아무것도 하지 않는다.
library;

export 'web_reload_io.dart' if (dart.library.js_interop) 'web_reload_web.dart';
