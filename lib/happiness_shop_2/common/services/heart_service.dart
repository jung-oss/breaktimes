// lib/happiness_shop_2/common/services/heart_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/heart_info.dart';

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

  /// 하트 개수 스트림
  Stream<int> heartCountStream() {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['heartCount'] ?? 0) as int);
  }
}

