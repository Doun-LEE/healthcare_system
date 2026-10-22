import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

final _cache = <String, Uint8List>{};
String _key(String id) => 'fit_photo_$id';

Future<void> savePhoto(String id, Uint8List bytes) async {
  _cache[id] = bytes;
  try {
    web.window.localStorage.setItem(_key(id), base64Encode(bytes));
  } catch (_) {
    // 브라우저 저장 공간이 꽉 차면 이번 세션 동안만 보인다.
  }
}

Future<Uint8List?> loadPhoto(String id) async {
  final hit = _cache[id];
  if (hit != null) return hit;
  final s = web.window.localStorage.getItem(_key(id));
  if (s == null || s.isEmpty) return null;
  try {
    final bytes = base64Decode(s);
    _cache[id] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<void> deletePhoto(String id) async {
  _cache.remove(id);
  web.window.localStorage.removeItem(_key(id));
}
