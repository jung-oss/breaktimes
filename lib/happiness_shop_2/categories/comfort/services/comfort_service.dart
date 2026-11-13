import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comfort_item.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/services/love_ledger.dart';
import '../../../common/services/shop_charge_service.dart';
import '../../../common/services/shop_functions.dart';

class ComfortService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _comforts =>
      _firestore.collection('users').doc(userId).collection('comforts');

  /// 위로 편지를 서버에서 만듭니다. 사랑하기는 서버가 결과를 저장할 때 빠집니다.
  /// 위기 문장이면 서버가 안내문을 무료로 돌려줍니다.
  Future<ComfortItem?> createComfort({
    required String userMessage,
    required String locale,
  }) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');
    if (userMessage.trim().length < 10) {
      throw Exception('MESSAGE_TOO_SHORT');
    }

    final result = await ShopFunctions.call('shopCreateResult', {
      'kind': 'comfort',
      'locale': locale,
      'dayStart': ShopFunctions.localDayStartMillis(),
      'text': userMessage.trim(),
    });
    if (result['charged'] == true) {
      LoveLedger.track(LoveLedgerEntry(
        isEarn: false,
        amount: HeartCost.COMFORT,
        reason: LoveReason.comfort,
        balanceAfter: (result['balanceAfter'] as num?)?.toInt() ?? 0,
      ));
    }

    final snap = await _comforts.doc(result['id'] as String).get();
    return snap.exists ? ComfortItem.fromFirestore(snap) : null;
  }

  /// 예전 앱에서 'pending'에 멈춘 편지는 실패로 표시합니다(사랑하기는 빠지지 않았음).
  Future<void> resumePending() async {
    if (userId.isEmpty) return;
    try {
      final snapshot =
          await _comforts.where('status', isEqualTo: 'pending').get();
      for (final doc in snapshot.docs) {
        if (ShopChargeService.isStalePending(doc.data())) {
          await ShopChargeService().markFailed(doc.reference);
        }
      }
    } catch (_) {}
  }

  Stream<List<ComfortItem>> getUserComfortsStream() {
    return _comforts
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ComfortItem.fromFirestore).toList());
  }

  Future<void> deleteComfort(String id) async {
    await _comforts.doc(id).delete();
  }
}
