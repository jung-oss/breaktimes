import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import '../happiness_shop_2/common/services/love_ledger.dart';
import '../happiness_shop_2/common/services/heart_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    // 웹 환경에서는 clientId를 다르게 처리
    clientId: kIsWeb
        ? '239335834410-hq9s9pm0dm67nlf8lpnhkkg0afpfcvfs.apps.googleusercontent.com' // 웹 클라이언트 ID
        : !kIsWeb && Platform.isIOS
            ? '270367364115-6v6b6lt7ehaos2l0fi4up9p3jb86v7hj.apps.googleusercontent.com' // iOS 클라이언트 ID
            : null, // Android에서는 google-services.json에서 자동으로 가져옴
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 인증 상태 변경 스트림
  Stream<User?> get userChanges => _auth.authStateChanges();

  // 프로필 이미지 업로드 - 웹 환경 고려
  Future<String?> uploadProfileImage(dynamic imageFile) async {
    try {
      if (_auth.currentUser == null) return null;

      final ref =
          _storage.ref().child('profile_images/${_auth.currentUser!.uid}');

      // 웹과 모바일 환경에 따라 다르게 처리
      if (kIsWeb) {
        // 웹 환경에서의 파일 업로드 처리
        await ref.putBlob(imageFile);
      } else {
        // 모바일 환경에서의 파일 업로드 처리
        await ref.putFile(imageFile as File);
      }

      final url = await ref.getDownloadURL();

      await _auth.currentUser!.updatePhotoURL(url);
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'photoURL': url});

      return url;
    } catch (e) {
      debugPrint('Profile image upload error: $e');
      rethrow;
    }
  }

  // 하트 카운트 증가
  Future<void> incrementHeartCount() async {
    try {
      if (_auth.currentUser == null) return;

      // 출석 보상은 서버 함수(loveClaimDaily)가 하루 한 번만 줍니다.
      final result = await HeartService.claimDaily(LoveReason.dailyCheckIn);
      if (result == DailyClaimResult.failed) {
        throw Exception('NETWORK_ERROR');
      }
    } catch (e) {
      debugPrint('Heart count increment error: $e');
      rethrow;
    }
  }

  // 하트 카운트 가져오기
  Future<int> getHeartCount() async {
    try {
      if (_auth.currentUser == null) return 0;

      final userData = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      return userData.data()?['heartCount'] ?? 0;
    } catch (e) {
      debugPrint('Get heart count error: $e');
      return 0;
    }
  }

  // 오늘 하트를 눌렀는지 확인
  Future<bool> hasGivenHeartToday() async {
    try {
      if (_auth.currentUser == null) return false;

      final userData = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      final lastHeartDate = userData.data()?['lastHeartDate'];
      final today = DateTime.now().toIso8601String().split('T')[0];

      return lastHeartDate == today;
    } catch (e) {
      debugPrint('Check heart status error: $e');
      return false;
    }
  }

  // 사용자 문서 생성/업데이트
  Future<void> _ensureUserDocument(User user, {String? provider}) async {
    try {
      debugPrint(
          '사용자 문서 확인 시작: ${user.uid}, provider: ${provider ?? "unknown"}');
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      debugPrint('사용자 문서 확인: ${user.uid}, 존재: ${userDoc.exists}');

      if (!userDoc.exists) {
        debugPrint('새 사용자 문서 생성 시작');
        // 기본 사용자 정보 생성
        await userDocRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'heartCount': 0,
          'lastHeartDate': null,
          'provider': provider ?? 'email', // Make sure provider is stored
          'settings': {
            'notificationsEnabled': false,
            'darkMode': false,
            'language': 'ko',
          },
        });

        // 하위 컬렉션 초기화를 배치로 처리
        final batch = _firestore.batch();
        final defaultCollections = [
          'todos',
          'moods',
          'progress',
          'used_topics'
        ];

        for (final collection in defaultCollections) {
          final dummyDocRef = userDocRef.collection(collection).doc();
          batch.set(dummyDocRef, {
            'initialized': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        debugPrint('새 사용자 문서 생성 완료: ${user.uid}');
      } else {
        debugPrint('기존 사용자 문서 업데이트 시작');
        // 마지막 로그인 시간만 업데이트
        await userDocRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          if (user.displayName != null) 'displayName': user.displayName,
          if (user.photoURL != null) 'photoURL': user.photoURL,
          if (provider != null)
            'provider': provider, // Update provider if provided
        });
        debugPrint('기존 사용자 문서 업데이트 완료: ${user.uid}');
      }

      // 업데이트 후 사용자 문서 다시 확인
      final updatedUserDoc = await userDocRef.get();
      debugPrint('업데이트 후 사용자 문서: ${updatedUserDoc.data()}');
    } catch (e) {
      debugPrint('사용자 문서 처리 오류: $e');
      rethrow;
    }
  }

  // 이메일/비밀번호 로그인
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _ensureUserDocument(credential.user!);
      }
      return credential;
    } catch (e) {
      debugPrint('Error signing in with email and password: $e');
      rethrow;
    }
  }

  // 구글 로그인 - 로깅 추가
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('구글 로그인 시도');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('구글 로그인 취소됨');
        return null;
      }

      debugPrint('구글 계정 선택됨: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      debugPrint('구글 인증 토큰 받음');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Firebase 인증 시작');
      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('Firebase 인증 완료: ${userCredential.user?.email}');

      if (userCredential.user != null) {
        final user = userCredential.user!;
        debugPrint(
            '사용자 정보: uid=${user.uid}, email=${user.email}, name=${user.displayName}, photo=${user.photoURL}');

        // 사용자 정보가 없는 경우 구글 계정 정보로 업데이트
        if (user.displayName == null || user.displayName!.isEmpty) {
          debugPrint('사용자 표시 이름 업데이트: ${googleUser.displayName}');
          await user.updateDisplayName(googleUser.displayName);
        }

        if (user.photoURL == null || user.photoURL!.isEmpty) {
          if (googleUser.photoUrl != null) {
            debugPrint('사용자 프로필 사진 업데이트: ${googleUser.photoUrl}');
            await user.updatePhotoURL(googleUser.photoUrl);
          }
        }

        // 사용자 정보 업데이트 후 문서 생성/업데이트
        await _ensureUserDocument(user, provider: 'google');

        // 업데이트 후 사용자 정보 다시 확인
        final updatedUser = _auth.currentUser;
        if (updatedUser != null) {
          debugPrint(
              '업데이트 후 사용자 정보: uid=${updatedUser.uid}, email=${updatedUser.email}, name=${updatedUser.displayName}, photo=${updatedUser.photoURL}');
        }
      } else {
        debugPrint('Firebase 인증 후 사용자 정보 없음');
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return null;
    }
  }

  // 카카오 로그인
  Future<UserCredential?> signInWithKakao() async {
    try {
      debugPrint('=== AuthService: 카카오 로그인 시작 ===');

      // 1. 카카오 로그인
      final token = await kakao.UserApi.instance.loginWithKakaoAccount();
      final kakaoUser = await kakao.UserApi.instance.me();

      debugPrint('=== 카카오 사용자 정보 ===');
      debugPrint('카카오 ID: ${kakaoUser.id}');
      debugPrint('이메일: ${kakaoUser.kakaoAccount?.email}');
      debugPrint('닉네임: ${kakaoUser.kakaoAccount?.profile?.nickname}');

      // 2. 기존 계정으로 먼저 로그인해 봅니다.
      // 보안 규칙상 로그인 전에는 users 문서를 검색할 수 없으므로, 검색 대신 로그인을 시도합니다.
      final tempEmail = 'kakao_${kakaoUser.id}@temp.app';
      UserCredential? existingCredential;
      try {
        existingCredential = await _auth.signInWithEmailAndPassword(
          email: tempEmail,
          password: 'KAKAO_${kakaoUser.id}',
        );
      } on FirebaseAuthException catch (e) {
        // 계정이 없으면 아래에서 새로 만듭니다. 그 밖의 오류(네트워크 등)는 그대로 알립니다.
        const notFoundCodes = {
          'user-not-found',
          'invalid-credential',
          'wrong-password',
          'invalid-email',
        };
        if (!notFoundCodes.contains(e.code)) rethrow;
        debugPrint('=== 기존 카카오 계정 없음 (${e.code}) ===');
      }

      if (existingCredential != null) {
        // 3. 기존 계정으로 로그인됨
        debugPrint('=== 기존 계정 로그인 성공 ===');
        if (existingCredential.user != null) {
          await _updateUserProfile(existingCredential.user!, kakaoUser);
          await _ensureUserDocument(existingCredential.user!,
              provider: 'kakao');
        }
        return existingCredential;
      } else {
        // 4. 새 계정 생성 (이메일 무관)
        debugPrint('=== 새 카카오 계정 생성 중 ===');
        final email = 'kakao_${kakaoUser.id}@temp.app'; // 고유한 임시 이메일

        try {
          final credential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: 'KAKAO_${kakaoUser.id}',
          );

          debugPrint('=== 새 계정 생성 성공 ===');

          if (credential.user != null) {
            await _updateUserProfile(credential.user!, kakaoUser);

            // 5. Firestore에 카카오 정보 저장
            await _firestore.collection('users').doc(credential.user!.uid).set({
              'kakaoId': kakaoUser.id.toString(),
              'uid': credential.user!.uid,
              'email': kakaoUser.kakaoAccount?.email, // 실제 이메일은 별도 저장
              'tempEmail': email, // 임시 이메일도 저장
              'displayName': kakaoUser.kakaoAccount?.profile?.nickname,
              'photoURL': kakaoUser.kakaoAccount?.profile?.profileImageUrl,
              'provider': 'kakao',
              'createdAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
              'heartCount': 0,
              'lastHeartDate': null,
              'settings': {
                'notificationsEnabled': true,
                'darkMode': false,
                'language': 'ko',
              },
            });

            // 하위 컬렉션 초기화
            final userDoc =
                _firestore.collection('users').doc(credential.user!.uid);
            await Future.wait([
              userDoc.collection('todos').doc('init').set({
                'initialized': true,
                'createdAt': FieldValue.serverTimestamp(),
              }),
              userDoc.collection('moods').doc('init').set({
                'initialized': true,
                'createdAt': FieldValue.serverTimestamp(),
              }),
              userDoc.collection('progress').doc('init').set({
                'initialized': true,
                'createdAt': FieldValue.serverTimestamp(),
              }),
              userDoc.collection('used_topics').doc('init').set({
                'initialized': true,
                'createdAt': FieldValue.serverTimestamp(),
              }),
            ]);

            debugPrint('=== 카카오 계정 생성 및 초기화 완료 ===');
          }

          return credential;
        } catch (createError) {
          debugPrint('=== 새 계정 생성 실패: $createError ===');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('=== Kakao login error: $e ===');
      rethrow;
    }
  }

  // 프로필 업데이트 helper 메서드
  Future<void> _updateUserProfile(
    User firebaseUser,
    kakao.User kakaoUser,
  ) async {
    final updates = <Future>[];

    if (kakaoUser.kakaoAccount?.profile?.nickname != null) {
      updates.add(
        firebaseUser.updateDisplayName(
          kakaoUser.kakaoAccount!.profile!.nickname!,
        ),
      );
    }

    if (kakaoUser.kakaoAccount?.profile?.profileImageUrl != null) {
      updates.add(
        firebaseUser.updatePhotoURL(
          kakaoUser.kakaoAccount!.profile!.profileImageUrl!,
        ),
      );
    }

    if (updates.isNotEmpty) {
      await Future.wait(updates);
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  // 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset email error: $e');
      rethrow;
    }
  }

  // 회원가입
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _ensureUserDocument(credential.user!);
      }
      return credential;
    } catch (e) {
      debugPrint('Error creating user with email and password: $e');
      rethrow;
    }
  }

  // 프로필 이미지 URL을 안전하게 가져오는 메서드
  Future<String> getProfileImageUrl(String userId) async {
    try {
      if (userId.isEmpty) return '';

      final ref = _storage.ref().child('profile_images/$userId');
      // 토큰이 포함된 새로운 다운로드 URL 생성
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('프로필 이미지 URL 가져오기 오류: $e');
      return ''; // 기본 이미지 URL 또는 빈 문자열 반환
    }
  }

  // 현재 사용자의 프로필 이미지 URL 가져오기
  Future<String> getCurrentUserProfileImageUrl() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    return await getProfileImageUrl(user.uid);
  }
}
