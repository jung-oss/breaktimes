// lib/happiness_shop_2/categories/quotes/services/quotes_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/quote_item.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/services/love_ledger.dart';
import '../../../common/services/shop_charge_service.dart';
import '../../../common/services/shop_functions.dart';

/// 행복 글귀 서비스 (글귀 만들기는 서버 함수가 합니다)
class QuotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _quotes =>
      _firestore.collection('users').doc(userId).collection('quotes');

  /// 오늘의 생각으로 글귀를 서버에서 만듭니다. 사랑하기는 서버가 결과를 저장할 때 빠집니다.
  Future<QuoteItem?> createQuoteFromThought(String userThought) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');

    final result = await ShopFunctions.call('shopCreateResult', {
      'kind': 'quote',
      'locale': 'ko',
      'dayStart': ShopFunctions.localDayStartMillis(),
      'text': userThought.trim(),
    });
    if (result['charged'] == true) {
      LoveLedger.track(LoveLedgerEntry(
        isEarn: false,
        amount: HeartCost.QUOTE,
        reason: LoveReason.quote,
        balanceAfter: (result['balanceAfter'] as num?)?.toInt() ?? 0,
      ));
    }

    final snap = await _quotes.doc(result['id'] as String).get();
    return snap.exists ? QuoteItem.fromFirestore(snap) : null;
  }

  /// 예전 앱에서 'pending'에 멈춘 글귀는 실패로 표시합니다(사랑하기는 빠지지 않았음).
  Future<void> resumePending() async {
    if (userId.isEmpty) return;
    try {
      final snapshot = await _quotes.where('status', isEqualTo: 'pending').get();
      for (final doc in snapshot.docs) {
        if (ShopChargeService.isStalePending(doc.data())) {
          await ShopChargeService().markFailed(doc.reference);
        }
      }
    } catch (_) {}
  }

  /// 사용자의 모든 글귀 가져오기 (Stream)
  Stream<List<QuoteItem>> getUserQuotesStream() {
    return _quotes
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => QuoteItem.fromFirestore(doc)).toList());
  }

  /// 오늘의 글귀 가져오기
  Future<QuoteItem?> getTodayQuote() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final snapshot = await _quotes
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return QuoteItem.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  /// 글귀 삭제
  Future<void> deleteQuote(String quoteId) async {
    try {
      await _quotes.doc(quoteId).delete();
    } catch (e) {
      throw Exception('DELETE_FAILED');
    }
  }

  /// 글귀 수정 후 다시 만들기(무료, 서버 함수)
  Future<void> updateQuote(String quoteId, String newThought) async {
    await ShopFunctions.call('shopRegenerateQuote', {
      'quoteId': quoteId,
      'text': newThought.trim(),
    });
  }
}
