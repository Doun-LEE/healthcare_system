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
