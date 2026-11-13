// lib/happiness_shop_2/common/services/heart_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/heart_info.dart';
import 'love_ledger.dart';
import 'shop_functions.dart';

/// 하루 보상 요청 결과
enum DailyClaimResult { awarded, alreadyClaimed, notEligible, failed }

/// 하트를 주는 활동
enum HeartReward {
  /// 행복-미션을 100% 달성했을 때
  mission('mission'),

  /// 행복-함에 글을 작성했을 때
  happyBox('happyBox');

  const HeartReward(this.key);
  final String key;

  /// 사랑하기 기록에 남길 이유
  LoveReason get ledgerReason =>
      this == HeartReward.mission ? LoveReason.mission : LoveReason.happyBox;
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

  /// 활동 보상으로 사랑하기 1개를 하루 한 번 받습니다(서버 함수 loveClaimDaily).
  ///
  /// 서버가 조건(미션 100%, 오늘 행복-함 글)을 직접 확인합니다.
  /// 받았으면 true, 이미 받았거나 조건이 안 되거나 실패하면 false입니다.
  Future<bool> awardDailyHeart(HeartReward reason) async {
    if (userId.isEmpty) return false;
    // 행복-함 글은 잠시 뒤(묶음 저장)에 서버에 올라가므로, 아직 안 보이면 몇 번 다시 물어봅니다.
    const retryDelays = [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ];
    for (final delay in retryDelays) {
      if (delay > Duration.zero) await Future.delayed(delay);
      final result = await claimDaily(reason.ledgerReason);
      if (result != DailyClaimResult.notEligible) {
        return result == DailyClaimResult.awarded;
      }
    }
    return false;
  }

  /// 하루 보상 한 번 요청(서버 함수 loveClaimDaily)
  static Future<DailyClaimResult> claimDaily(LoveReason reason) async {
    try {
      final result =
          await ShopFunctions.call('loveClaimDaily', {'reason': reason.key});
      if (result['awarded'] != true) return DailyClaimResult.alreadyClaimed;
      LoveLedger.track(LoveLedgerEntry(
        isEarn: true,
        amount: 1,
        reason: reason,
        balanceAfter: (result['balanceAfter'] as num?)?.toInt() ?? 0,
      ));
      return DailyClaimResult.awarded;
    } catch (e) {
      return e.toString().contains('NOT_ELIGIBLE')
          ? DailyClaimResult.notEligible
          : DailyClaimResult.failed;
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

