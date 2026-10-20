/// Firebase 프로젝트 설정.
///
/// Firebase 콘솔 → 프로젝트 설정 → 내 앱(웹) 의 firebaseConfig 값을 그대로 옮긴다.
/// 이 값들은 비밀키가 아니라 공개 식별자이며, 데이터 보호는 Firestore 보안 규칙
/// (firestore.rules)이 담당한다. null 이면 앱은 기기 저장 전용 모드로 동작한다.
library;

import 'package:firebase_core/firebase_core.dart';

const FirebaseOptions? firebaseOptions = null;

// 예시 (실제 값으로 교체):
// const FirebaseOptions? firebaseOptions = FirebaseOptions(
//   apiKey: 'AIza...',
//   authDomain: 'fitroutine-xxxx.firebaseapp.com',
//   projectId: 'fitroutine-xxxx',
//   storageBucket: 'fitroutine-xxxx.firebasestorage.app',
//   messagingSenderId: '1234567890',
//   appId: '1:1234567890:web:abcdef',
// );
