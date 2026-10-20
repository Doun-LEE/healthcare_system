import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'store.dart';

/// 모바일/데스크톱: 앱 문서 폴더의 JSON 파일.
Future<DataStore> createStore() async {
  final dir = await getApplicationDocumentsDirectory();
  return LocalStore(File('${dir.path}/fit_routine.json'));
}
