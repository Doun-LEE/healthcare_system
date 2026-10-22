import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 모바일/데스크톱: 앱 문서 폴더에 저장하고 경로를 알려준다(갤러리 저장은 공유 → 저장 사용).
Future<String?> saveBytesToDevice(Uint8List bytes, String name, String mimeType) async {
  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  return '저장했어요: ${f.path}\n갤러리에 넣으려면 "공유"에서 사진 앱/갤러리를 고르세요.';
}
