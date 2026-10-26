import 'dart:convert';

import 'package:web/web.dart' as web;

import 'store.dart';

/// 웹(노트북에서 확인용): 브라우저 localStorage에 저장. 새로고침해도 유지된다.
Future<DataStore> createStore() async => WebStore();

class WebStore implements DataStore {
  static const _key = 'fit_routine_data';

  static const _bakKey = 'fit_routine_data_bak';
  bool _backedUp = false;

  AppData? _read(String key) {
    final text = web.window.localStorage.getItem(key);
    if (text == null || text.isEmpty) return null;
    try {
      return AppData.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppData> load() async => _read(_key) ?? _read(_bakKey) ?? AppData();

  @override
  Future<void> save(AppData data) async {
    if (!_backedUp) {
      final cur = web.window.localStorage.getItem(_key);
      if (cur != null && cur.isNotEmpty) {
        try {
          web.window.localStorage.setItem(_bakKey, cur);
        } catch (_) {}
      }
      _backedUp = true;
    }
    web.window.localStorage.setItem(_key, jsonEncode(data.toJson()));
  }
}
