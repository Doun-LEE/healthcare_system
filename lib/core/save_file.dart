/// 이미지 등 바이트를 기기에 저장. 웹은 다운로드, 그 외는 앱 문서 폴더.
library;

export 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
