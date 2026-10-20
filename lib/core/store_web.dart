import 'dart:convert';

import 'package:web/web.dart' as web;

import 'store.dart';

/// 웹(노트북에서 확인용): 브라우저 localStorage에 저장. 새로고침해도 유지된다.
Future<DataStore> createStore() async => WebStore();

class WebStore implements DataStore {
  static const _key = 'fit_routine_data';

  @override
  Future<AppData> load() async {
    final text = web.window.localStorage.getItem(_key);
    if (text == null || text.isEmpty) return AppData();
    try {
      return AppData.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return AppData();
    }
  }

  @override
  Future<void> save(AppData data) async {
    web.window.localStorage.setItem(_key, jsonEncode(data.toJson()));
  }
}
