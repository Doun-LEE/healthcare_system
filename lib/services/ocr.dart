/// 기기 안 글자 인식(OCR). 서버·AI 한도와 무관하게 동작한다.
///
/// - 안드로이드: Google ML Kit 한국어 모델(앱에 포함, 오프라인).
/// - 웹: Tesseract.js(처음 한 번 글자 모델을 내려받고 브라우저에 캐시).
/// - 그 외 플랫폼: null(→ AI 인식으로 넘어감).
library;

export 'ocr_io.dart' if (dart.library.js_interop) 'ocr_web.dart';
