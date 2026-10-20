import 'store.dart';

/// 웹(데모/개발용): 메모리 저장. 새로고침하면 사라진다.
Future<DataStore> createStore() async => MemoryStore();
