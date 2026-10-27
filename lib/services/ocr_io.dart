import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// 사진 속 글자를 줄 단위로 돌려준다(위→아래, 같은 줄은 왼쪽→오른쪽). 지원 안 하는 기기면 null.
Future<String?> recognizeText(Uint8List bytes, {void Function(String)? onStep}) async {
  if (!Platform.isAndroid && !Platform.isIOS) return null;
  onStep?.call('기기에서 글자 읽는 중…');
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
  await f.writeAsBytes(bytes, flush: true);
  final rec = TextRecognizer(script: TextRecognitionScript.korean);
  try {
    final r = await rec.processImage(InputImage.fromFilePath(f.path));
    return _rows(r);
  } finally {
    await rec.close();
    try {
      await f.delete();
    } catch (_) {}
  }
}

/// ML Kit는 블록(문단) 단위로 주기 때문에 두 칸 배치(왼쪽 "운동 시간", 오른쪽 "거리")가
/// 세로로 떨어져 나온다. 세로 위치가 비슷한 줄을 한 행으로 합쳐 표 모양을 되살린다.
String _rows(RecognizedText r) {
  final lines = [for (final b in r.blocks) ...b.lines];
  if (lines.isEmpty) return '';
  lines.sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));
  final rows = <List<TextLine>>[];
  for (final l in lines) {
    if (rows.isNotEmpty) {
      final last = rows.last;
      final ref = last.first;
      final tol = (ref.boundingBox.height + l.boundingBox.height) * 0.3;
      if ((ref.boundingBox.center.dy - l.boundingBox.center.dy).abs() <= tol) {
        last.add(l);
        continue;
      }
    }
    rows.add([l]);
  }
  return rows.map((row) {
    row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    return row.map((l) => l.text).join('  ');
  }).join('\n');
}
