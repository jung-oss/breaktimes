// lib/happiness_shop_2/common/services/heart_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/heart_info.dart';

/// 하트를 주는 활동
enum HeartReward {
  /// 행복-미션을 100% 달성했을 때
  mission('mission'),

  /// 행복-함에 글을 작성했을 때
  happyBox('happyBox');

  const HeartReward(this.key);
  final String key;
}

/// 하트 관리 공통 서비스
class HeartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

  /// 하트 정보 가져오기
  Future<HeartInfo> getHeartInfo() async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data() ?? {};

      return HeartInfo.fromMap({
        'heartCount': data['heartCount'] ?? 0,
        'slotCount': data['slotCount'] ?? 1,
        'maxSlots': data['maxSlots'] ?? 20,
      });
    } catch (e) {
      throw Exception('Failed to get heart info: $e');
    }
  }

  /// 하트 사용
  Future<bool> useHearts(int amount) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('User document not found');
        }

        final currentHearts = userDoc.data()?['heartCount'] ?? 0;

        if (currentHearts < amount) {
          return false;
        }

        transaction.update(userRef, {
          'heartCount': currentHearts - amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// 활동 보상으로 하트 1개를 하루 한 번 지급합니다.
  ///
  /// [reason]마다 받은 날짜를 `heartRewards.<reason>`에 기록해 같은 날 다시 주지 않습니다.
  /// 지급했으면 true, 이미 받았거나 실패하면 false를 돌려줍니다.
  Future<bool> awardDailyHeart(HeartReward reason) async {
    if (userId.isEmpty) return false;

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return false;

        final rewards = userDoc.data()?['heartRewards'];
        if (rewards is Map && rewards[reason.key] == today) {
          return false;
        }

        transaction.update(userRef, {
          'heartCount': FieldValue.increment(1),
          'heartRewards.${reason.key}': today,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// 하트 개수 스트림
  Stream<int> heartCountStream() {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['heartCount'] ?? 0) as int);
  }
}

