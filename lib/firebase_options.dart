/// Firebase 프로젝트 설정 (healthcare-system).
///
/// 플랫폼별로 Firebase 콘솔에 등록된 앱의 값을 쓴다.
/// - 웹: 프로젝트 설정 → 내 앱(웹) firebaseConfig
/// - 안드로이드: android/app/google-services.json 의 값
/// 이 값들은 공개 식별자이며, 데이터 보호는 Firestore 규칙이 담당한다.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const _web = FirebaseOptions(
  apiKey: 'AIzaSyBC1ur1alIY9MKeK0u3yBX16fVg1zCw8QA',
  authDomain: 'healthcare-system-b55c0.firebaseapp.com',
  projectId: 'healthcare-system-b55c0',
  storageBucket: 'healthcare-system-b55c0.firebasestorage.app',
  messagingSenderId: '1043529698426',
  appId: '1:1043529698426:web:87a211e4883bc522fabfc3',
  measurementId: 'G-42M0CLZK34',
);

const _android = FirebaseOptions(
  apiKey: 'AIzaSyBDBeduPfkH1qLiJyNrzhm7-RZLKpy_kzs',
  projectId: 'healthcare-system-b55c0',
  storageBucket: 'healthcare-system-b55c0.firebasestorage.app',
  messagingSenderId: '1043529698426',
  appId: '1:1043529698426:android:218831437b87dc9dfabfc3',
);

FirebaseOptions? get firebaseOptions {
  if (kIsWeb) return _web;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return _android;
    case TargetPlatform.iOS:
      // iOS 앱은 아직 Firebase에 등록하지 않았다. 등록 후 GoogleService-Info.plist 값을 넣는다.
      return null;
    default:
      return _web;
  }
}
