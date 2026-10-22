/// 기구 실물 사진 저장소. 웹은 브라우저 저장소, 앱은 앱 문서 폴더.
///
/// 사진은 용량이 커서 계정 동기화(Firestore 문서 1MB 제한)에는 넣지 않고 이 기기에만 둔다.
library;

export 'photo_store_io.dart' if (dart.library.js_interop) 'photo_store_web.dart';
