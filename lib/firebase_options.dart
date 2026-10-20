/// Firebase 프로젝트 설정 (healthcare-system).
///
/// Firebase 콘솔 → 프로젝트 설정 → 내 앱(웹) 의 firebaseConfig 값.
/// 이 값들은 비밀키가 아니라 공개 식별자이며, 데이터 보호는 Firestore 보안 규칙
/// (firestore.rules)이 담당한다. null 이면 앱은 기기 저장 전용 모드로 동작한다.
library;

import 'package:firebase_core/firebase_core.dart';

// ignore: unnecessary_nullable_for_final_variable_declarations
const FirebaseOptions? firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBC1ur1alIY9MKeK0u3yBX16fVg1zCw8QA',
  authDomain: 'healthcare-system-b55c0.firebaseapp.com',
  projectId: 'healthcare-system-b55c0',
  storageBucket: 'healthcare-system-b55c0.firebasestorage.app',
  messagingSenderId: '1043529698426',
  appId: '1:1043529698426:web:87a211e4883bc522fabfc3',
  measurementId: 'G-42M0CLZK34',
);
