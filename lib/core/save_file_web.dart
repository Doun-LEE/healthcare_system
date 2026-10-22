import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 웹: 브라우저 다운로드로 저장한다.
Future<String?> saveBytesToDevice(Uint8List bytes, String name, String mimeType) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..style.display = 'none';
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return '다운로드 폴더에 $name 으로 저장했어요.';
}

/// 웹: 이미지를 클립보드에 복사(카톡 PC 대화창에 Ctrl+V). 브라우저가 지원 안 하면 false.
Future<bool> copyImageToClipboard(Uint8List bytes, String mimeType) async {
  try {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
    final item = web.ClipboardItem({mimeType: blob}.jsify() as JSObject);
    await web.window.navigator.clipboard.write([item].toJS).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
