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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/store.dart';
import '../models/models.dart';
import 'partner.dart';

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

  /// 초기화 실패 이유(화면에 표시해 원인 파악용). 성공이면 null.
  static String? initError;

  /// [options]가 null이면 아무것도 하지 않는다(기기 전용 모드).
  static Future<void> init(FirebaseOptions? options) async {
    if (options == null) {
      initError = '이 플랫폼용 Firebase 설정이 없습니다.';
      return;
    }
    try {
      await Firebase.initializeApp(options: options);
      _instance = CloudSync._();
      initError = null;
    } catch (e) {
      _instance = null;
      initError = e.toString();
    }
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get user => _auth.currentUser;
  String? get email => user?.email;
  String? get displayName => user?.displayName;
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

  /// 구글(Gmail) 계정으로 로그인.
  /// - 웹: Firebase 팝업.
  /// - 안드로이드: google_sign_in → Firebase 자격증명. Firebase 콘솔에 안드로이드 앱(패키지
  ///   com.doun.fit_routine + 서명 SHA-1)이 등록되고 google-services.json 이 있어야 동작한다.
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()..addScope('email');
        await _auth.signInWithPopup(provider);
        return;
      }
      final gsi = GoogleSignIn.instance;
      await gsi.initialize();
      final account = await gsi.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw CloudException('구글 로그인 토큰을 받지 못했습니다.');
      await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    } on FirebaseAuthException catch (e) {
      throw CloudException(_message(e));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw CloudException('로그인을 취소했습니다.');
      throw CloudException('구글 로그인 실패: ${e.description ?? e.code.name}');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw CloudException(_message(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }

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

  // ───────── 파트너 ─────────

  static String emailKey(String email) =>
      base64Url.encode(utf8.encode(email.trim().toLowerCase())).replaceAll('=', '');

  /// 내 이메일을 검색 가능하게 등록하고 공개 프로필을 올린다.
  Future<void> publishPublic(Map<String, dynamic> publicProfile) async {
    final u = user;
    if (u == null) return;
    final batch = _db.batch();
    batch.set(_db.doc('users/${u.uid}/public/profile'), {...publicProfile, 'updatedAt': FieldValue.serverTimestamp()});
    if (u.email != null) {
      batch.set(_db.doc('emails/${emailKey(u.email!)}'), {
        'uid': u.uid,
        'name': publicProfile['name'],
        'email': u.email!.toLowerCase(),
      });
    }
    await batch.commit();
  }

  /// 이메일로 파트너 찾기. 없으면 null.
  Future<PartnerLink?> lookupByEmail(String email) async {
    final snap = await _db.doc('emails/${emailKey(email)}').get();
    final d = snap.data();
    if (d == null) return null;
    return PartnerLink(uid: d['uid'] as String, name: (d['name'] as String?) ?? '', email: (d['email'] as String?) ?? email);
  }

  Future<PartnerProfile?> fetchPartner(String uid) async {
    final snap = await _db.doc('users/$uid/public/profile').get();
    final d = snap.data();
    if (d == null) return null;
    return PartnerProfile.fromJson(d);
  }

  Future<void> sendJointRoutine({
    required String toUid,
    required DateTime date,
    required String code,
    required String title,
    required String fromName,
  }) async {
    final u = user;
    if (u == null) return;
    await _db.collection('users/$toUid/inbox').add({
      'type': 'joint',
      'fromUid': u.uid,
      'fromName': fromName,
      'date': dateKey(date),
      'code': code,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<InboxItem>> readInbox() async {
    final u = user;
    if (u == null) return const [];
    final snap = await _db.collection('users/${u.uid}/inbox').get();
    final out = <InboxItem>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      try {
        out.add(InboxItem(
          id: doc.id,
          fromUid: d['fromUid'] as String,
          fromName: (d['fromName'] as String?) ?? '파트너',
          date: parseDateKey(d['date'] as String),
          code: d['code'] as String,
          title: (d['title'] as String?) ?? '',
        ));
      } catch (_) {}
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  Future<void> deleteInbox(String id) async {
    final u = user;
    if (u == null) return;
    await _db.doc('users/${u.uid}/inbox/$id').delete();
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
