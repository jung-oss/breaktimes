// lib/happiness_shop_2/common/services/shop_charge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// 예전 앱 버전이 남긴 'pending' 결과를 정리하는 도우미입니다.
///
/// 사랑하기 차감과 AI 결과 만들기는 이제 서버 함수(shop_functions.dart)가 합니다.
/// 예전 앱은 결과를 'pending'으로 먼저 저장하고 앱에서 만들었는데, 그 사이 앱이 꺼지면
/// 그대로 멈춰 있었습니다. 그런 결과는 사랑하기가 빠지지 않았으므로 '실패'로 바꿔
/// 사용자가 다시 받을 수 있게 합니다.
class ShopChargeService {
  /// 만들다 멈춘 결과를 'failed'로 표시합니다(사랑하기는 빠지지 않은 상태).
  Future<void> markFailed(DocumentReference<Map<String, dynamic>> docRef) async {
    try {
      await docRef.update({
        'status': 'failed',
        'failReason': 'ERROR',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// 오래 'pending'에 머문 문서인지(방금 만든 것은 건드리지 않도록 [minAge]를 둡니다)
  static bool isStalePending(Map<String, dynamic> data,
      {Duration minAge = const Duration(seconds: 30)}) {
    if (data['status'] != 'pending') return false;
    final updatedAt = data['updatedAt'];
    if (updatedAt is! Timestamp) return true;
    return DateTime.now().difference(updatedAt.toDate()) > minAge;
  }
}
