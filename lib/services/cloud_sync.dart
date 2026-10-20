/// Firebase 계정 + Firestore 동기화.
///
/// 구조: 로컬 저장소가 항상 1차(오프라인 동작). 계정에 로그인돼 있으면
/// 저장할 때마다 Firestore `users/{uid}/data/app` 문서에 전체 데이터를 올리고,
/// 앱 시작/로그인 시 클라우드가 더 최신이면 내려받는다.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/store.dart';

class CloudException implements Exception {
  CloudException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CloudSync {
  CloudSync._();

  static CloudSync? _instance;
  static bool get isConfigured => _instance != null;
  static CloudSync get instance => _instance!;

  /// [options]가 null이면 아무것도 하지 않는다(기기 전용 모드).
  static Future<void> init(FirebaseOptions? options) async {
    if (options == null) return;
    try {
      await Firebase.initializeApp(options: options);
      _instance = CloudSync._();
    } catch (_) {
      _instance = null;
    }
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get user => _auth.currentUser;
  String? get email => user?.email;
  bool get signedIn => user != null;
  Stream<User?> get authChanges => _auth.authStateChanges();

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc('users/$uid/data/app');

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw CloudException(_message(e));
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw CloudException(_message(e));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw CloudException(_message(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// 클라우드 데이터. 없으면 null.
  Future<(AppData, DateTime)?> pull() async {
    final u = user;
    if (u == null) return null;
    final snap = await _doc(u.uid).get();
    final data = snap.data();
    if (data == null) return null;
    final json = data['json'] as String?;
    if (json == null || json.isEmpty) return null;
    final ts = data['updatedAt'];
    final updatedAt = ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
    return (AppData.fromJson(jsonDecode(json) as Map<String, dynamic>), updatedAt);
  }

  Future<void> push(AppData data) async {
    final u = user;
    if (u == null) return;
    // Firestore 문서 한도(1MB)를 넘지 않게 6개월 지난 완료 계획은 정리한다.
    final cutoff = DateTime.now().subtract(const Duration(days: 180));
    data.plans.removeWhere((p) => p.isFinished && p.date.isBefore(cutoff));
    await _doc(u.uid).set({
      'json': jsonEncode(data.toJson()),
      'updatedAt': FieldValue.serverTimestamp(),
      'email': u.email,
    });
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => '이메일 형식이 올바르지 않습니다.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => '이메일 또는 비밀번호가 틀렸습니다.',
        'email-already-in-use' => '이미 가입된 이메일입니다. 로그인하세요.',
        'weak-password' => '비밀번호는 6자 이상이어야 합니다.',
        'too-many-requests' => '시도가 너무 많습니다. 잠시 후 다시 하세요.',
        'network-request-failed' => '네트워크 연결을 확인하세요.',
        _ => '오류: ${e.message ?? e.code}',
      };
}

/// 저장 요청을 1초 모았다가 한 번만 올리는 디바운서.
class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _t;
  void call(void Function() f) {
    _t?.cancel();
    _t = Timer(delay, f);
  }

  void cancel() => _t?.cancel();
}
