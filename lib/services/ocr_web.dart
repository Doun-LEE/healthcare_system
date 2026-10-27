import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _script = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
Future<void>? _loading;

Future<void> _load() {
  if (web.window.hasProperty('Tesseract'.toJS).toDart) return Future.value();
  return _loading ??= () {
    final c = Completer<void>();
    final s = web.document.createElement('script') as web.HTMLScriptElement;
    s.src = _script;
    s.onload = ((web.Event _) => c.complete()).toJS;
    s.onerror = ((web.Event _) {
      _loading = null;
      c.completeError(StateError('글자 인식 모듈을 불러오지 못했어요(인터넷 확인).'));
    }).toJS;
    web.document.head!.append(s);
    return c.future;
  }();
}

/// 브라우저 안에서 Tesseract.js로 글자를 읽는다(한국어+영어). 처음엔 모델을 내려받아 느리다.
Future<String?> recognizeText(Uint8List bytes, {void Function(String)? onStep}) async {
  onStep?.call('글자 인식 준비 중…');
  await _load();
  onStep?.call('글자 읽는 중… (처음엔 한국어 모델을 받아서 30초쯤 걸려요)');
  final t = web.window.getProperty<JSObject>('Tesseract'.toJS);
  final url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  final p = t.callMethod<JSPromise<JSObject>>('recognize'.toJS, url.toJS, 'kor+eng'.toJS);
  final r = await p.toDart;
  return r.getProperty<JSObject>('data'.toJS).getProperty<JSString>('text'.toJS).toDart;
}
