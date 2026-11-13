import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/fortune_item.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/services/love_ledger.dart';
import '../../../common/services/shop_charge_service.dart';
import '../../../common/services/shop_functions.dart';

class FortuneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _fortunes =>
      _firestore.collection('users').doc(userId).collection('fortunes');

  /// 오늘의 운세를 서버에서 만듭니다. 사랑하기는 서버가 결과를 저장할 때 빠집니다.
  Future<FortuneItem?> createTodayFortune({
    required String locale,
    String? mood,
    bool forceRegenerate = false,
  }) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');

    if (!forceRegenerate) {
      final existing = await getTodayFortune();
      if (existing != null) return existing;
    }

    final result = await ShopFunctions.call('shopCreateResult', {
      'kind': 'fortune',
      'locale': locale,
      'dayStart': ShopFunctions.localDayStartMillis(),
      if (mood != null) 'mood': mood,
    });
    _track(result, LoveReason.fortune);

    final snap = await _fortunes.doc(result['id'] as String).get();
    return snap.exists ? FortuneItem.fromFirestore(snap) : null;
  }

  /// 예전 앱에서 'pending'에 멈춘 운세는 실패로 표시해 다시 받을 수 있게 합니다
  /// (그 운세는 사랑하기가 빠지지 않았습니다).
  Future<void> resumeIfPending(FortuneItem item) async {
    final docRef = _fortunes.doc(item.id);
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null || !ShopChargeService.isStalePending(data)) return;
    await ShopChargeService().markFailed(docRef);
  }

  /// 오늘 받은 운세 중 가장 최근 것(다시 받기를 했으면 새 운세)
  Future<FortuneItem?> getTodayFortune() async {
    if (userId.isEmpty) return null;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final snapshot = await _fortunes
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .get();
      if (snapshot.docs.isEmpty) return null;
      // 색인을 따로 만들지 않도록 앱에서 최신순으로 고릅니다(하루 몇 건뿐).
      final items = snapshot.docs.map(FortuneItem.fromFirestore).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.first;
    } catch (_) {
      return null;
    }
  }

  Stream<List<FortuneItem>> getUserFortunesStream() {
    return _fortunes
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FortuneItem.fromFirestore).toList());
  }

  Future<void> deleteFortune(String id) async {
    await _fortunes.doc(id).delete();
  }

  void _track(Map<String, dynamic> result, LoveReason reason) {
    if (result['charged'] != true) return;
    LoveLedger.track(LoveLedgerEntry(
      isEarn: false,
      amount: HeartCost.FORTUNE,
      reason: reason,
      balanceAfter: (result['balanceAfter'] as num?)?.toInt() ?? 0,
    ));
  }
}
