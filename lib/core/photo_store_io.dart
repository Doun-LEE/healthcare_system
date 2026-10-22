import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

final _cache = <String, Uint8List>{};

Future<File> _file(String id) async {
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/equipment_photos');
  if (!await dir.exists()) await dir.create(recursive: true);
  return File('${dir.path}/$id.jpg');
}

Future<void> savePhoto(String id, Uint8List bytes) async {
  await (await _file(id)).writeAsBytes(bytes, flush: true);
  _cache[id] = bytes;
}

Future<Uint8List?> loadPhoto(String id) async {
  final hit = _cache[id];
  if (hit != null) return hit;
  final f = await _file(id);
  if (!await f.exists()) return null;
  final bytes = await f.readAsBytes();
  _cache[id] = bytes;
  return bytes;
}

Future<void> deletePhoto(String id) async {
  _cache.remove(id);
  final f = await _file(id);
  if (await f.exists()) await f.delete();
}
