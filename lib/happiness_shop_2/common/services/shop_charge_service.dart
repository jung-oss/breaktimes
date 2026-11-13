// lib/happiness_shop_2/common/services/shop_charge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'love_ledger.dart';

/// 행복-가게 결과를 "만든 뒤에" 사랑하기를 빼는 공통 도우미입니다.
///
/// 순서
/// 1. [ensureAffordable]로 사랑하기가 충분한지 확인합니다(빼지는 않음).
/// 2. 결과 문서를 'pending'으로 만들 때 [chargeFields]를 함께 저장합니다.
/// 3. AI 결과가 나오면 [complete]가 결과 저장과 사랑하기 차감을 한 트랜잭션으로 처리합니다.
///    AI가 실패해 기본 문장이 나가면 빼지 않습니다.
///
/// 보안 규칙상 사랑하기를 다시 늘릴 수 없으므로 "먼저 빼고 실패하면 돌려주기"는 쓰지 않습니다.
class ShopChargeService {
  ShopChargeService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// 이 앱에서 지금 만들고 있는 결과 문서(같은 문서를 두 번 만들지 않기 위함)
  static final Set<String> _inFlight = {};

  String get _userId => _auth.currentUser?.uid ?? '';

  /// 사랑하기가 [cost]개 이상인지 확인합니다.
  /// 부족하면 INSUFFICIENT_HEARTS, 연결 문제면 NETWORK_ERROR 예외를 던집니다.
  Future<void> ensureAffordable(int cost) async {
    if (_userId.isEmpty) throw Exception('NOT_LOGGED_IN');
    final DocumentSnapshot<Map<String, dynamic>> userDoc;
    try {
      userDoc = await _firestore.collection('users').doc(_userId).get();
    } on FirebaseException {
      throw Exception('NETWORK_ERROR');
    }
    final hearts = (userDoc.data()?['heartCount'] as num?)?.toInt() ?? 0;
    if (hearts < cost) throw Exception('INSUFFICIENT_HEARTS');
  }

  /// 'pending' 결과 문서에 함께 저장할 값
  Map<String, dynamic> chargeFields(int cost, String locale) => {
        'heartCost': cost,
        'heartCharged': false,
        'locale': locale,
      };

  /// 같은 문서를 이미 만들고 있으면 false
  bool begin(String docId) => _inFlight.add(docId);

  void end(String docId) => _inFlight.remove(docId);

  /// 결과를 저장하고, 기본 문장이 아니면 그때 사랑하기를 뺍니다.
  ///
  /// - 문서가 이미 'pending'이 아니면 아무것도 하지 않습니다(두 번 빼지 않음).
  /// - 예전 문서처럼 heartCost가 없으면 이미 뺀 것으로 보고 빼지 않습니다.
  /// - 그사이 사랑하기가 부족해졌으면 결과를 주지 않고 'failed'로 둡니다.
  Future<void> complete(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> result, {
    required bool isFallback,
    required LoveReason reason,
  }) async {
    final userRef = _firestore.collection('users').doc(_userId);
    LoveLedgerEntry? charged;
    await _firestore.runTransaction((transaction) async {
      charged = null; // 트랜잭션이 다시 실행될 때를 위해 비웁니다
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'pending') return;

      final cost = (data['heartCost'] as num?)?.toInt() ?? 0;
      final alreadyCharged = data['heartCharged'] == true;
      final needCharge = cost > 0 && !alreadyCharged && !isFallback;

      final updates = <String, dynamic>{
        ...result,
        'isFallback': isFallback,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (needCharge) {
        final userSnap = await transaction.get(userRef);
        final hearts = (userSnap.data()?['heartCount'] as num?)?.toInt() ?? 0;
        if (hearts < cost) {
          transaction.update(docRef, {
            'status': 'failed',
            'failReason': 'INSUFFICIENT_HEARTS',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
        transaction.update(userRef, {
          'heartCount': hearts - cost,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        updates['heartCharged'] = true;
        final entry = LoveLedgerEntry(
          isEarn: false,
          amount: cost,
          reason: reason,
          balanceAfter: hearts - cost,
          itemPath: docRef.path,
        );
        LoveLedger.write(transaction, _firestore, _userId, entry);
        charged = entry;
      }

      transaction.update(docRef, updates);
    });
    final entry = charged;
    if (entry != null) LoveLedger.track(entry);
  }

  /// 만들다 오류가 나면 'failed'로 표시합니다(사랑하기는 빠지지 않은 상태).
  Future<void> markFailed(DocumentReference<Map<String, dynamic>> docRef) async {
    try {
      await docRef.update({
        'status': 'failed',
        'failReason': 'ERROR',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// 오래 'pending'에 머문 문서인지(앱이 꺼져 멈춘 결과).
  /// 방금 만든 문서를 다른 화면이 다시 만들지 않도록 [minAge]만큼 기다립니다.
  static bool isStalePending(Map<String, dynamic> data,
      {Duration minAge = const Duration(seconds: 30)}) {
    if (data['status'] != 'pending') return false;
    final updatedAt = data['updatedAt'];
    if (updatedAt is! Timestamp) return true;
    return DateTime.now().difference(updatedAt.toDate()) > minAge;
  }
}
