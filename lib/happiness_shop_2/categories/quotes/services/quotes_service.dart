// lib/happiness_shop_2/categories/quotes/services/quotes_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/quote_item.dart';
import '../../../common/services/gemini_quote_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/services/shop_charge_service.dart';
import '../../../common/services/love_ledger.dart';
import '../../../../services/environment_service.dart';

/// 행복 글귀 서비스
class QuotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiQuoteService _geminiService = GeminiQuoteService();
  final ShopChargeService _charge = ShopChargeService();
  static final Random _random = Random();

  // 한국 작가 목록
  static final List<String> _koreanAuthors = [
    '하루키',
    '한강',
    '김영하',
    '이외수',
    '공지영',
  ];

  String get userId => _auth.currentUser?.uid ?? '';

  /// 오늘의 생각으로 글귀를 만듭니다. 사랑하기는 글귀가 나온 뒤에 빠집니다.
  Future<QuoteItem?> createQuoteFromThought(String userThought) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');

    // 1. 사랑하기가 충분한지만 확인합니다(빼지 않음)
    await _charge.ensureAffordable(HeartCost.QUOTE);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 2. 문서 생성 (pending 상태)
    final docRef =
        _firestore.collection('users').doc(userId).collection('quotes').doc();

    final quoteItem = QuoteItem(
      id: docRef.id,
      userId: userId,
      userThought: userThought,
      generatedQuote: '',
      date: today,
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    try {
      await docRef.set({
        ...quoteItem.toFirestore(),
        ..._charge.chargeFields(HeartCost.QUOTE, 'ko'),
      });
    } on FirebaseException {
      throw Exception('NETWORK_ERROR');
    }

    // 3. 백그라운드에서 AI 글귀 생성 → 결과 저장과 함께 사랑하기 차감
    _generateQuoteInBackground(docRef.id, userThought, today);

    return quoteItem;
  }

  /// 백그라운드에서 통합된 명언과 위로 글 생성
  Future<void> _generateQuoteInBackground(
      String quoteId, String userThought, DateTime date) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('quotes')
        .doc(quoteId);
    if (!_charge.begin(quoteId)) return;
    try {
      // 1. 통합된 명언과 위로 글 생성 (3~5줄)
      final result = await _geminiService.generateQuoteResult(userThought, date);

      // 2. 랜덤 작가 선택
      final author = _koreanAuthors[_random.nextInt(_koreanAuthors.length)];

      // 3. 생성된 내용 저장 (모델명은 Remote Config에서 가져옴)
      final modelName = EnvironmentService.instance.get(
        'GEMINI_MODEL_NAME',
        defaultValue: '',
      );
      await _charge.complete(
        docRef,
        {
          'comfortMessage': result.text,
          'authorName': author,
          'status': 'generated',
          'model': result.isFallback ? '' : modelName,
        },
        isFallback: result.isFallback,
        reason: LoveReason.quote,
      );
    } catch (e) {
      await _charge.markFailed(docRef);
    } finally {
      _charge.end(quoteId);
    }
  }

  /// 앱이 꺼져 'pending'에 멈춘 글귀를 이어서 만듭니다.
  Future<void> resumePending() async {
    if (userId.isEmpty) return;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quotes')
          .where('status', isEqualTo: 'pending')
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (!ShopChargeService.isStalePending(data)) continue;
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        _generateQuoteInBackground(
            doc.id, data['userThought'] as String? ?? '', date);
      }
    } catch (_) {}
  }

  /// 사용자의 모든 글귀 가져오기 (Stream)
  Stream<List<QuoteItem>> getUserQuotesStream() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('quotes')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => QuoteItem.fromFirestore(doc)).toList();
    });
  }

  /// 오늘의 글귀 가져오기
  Future<QuoteItem?> getTodayQuote() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quotes')
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
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('quotes')
          .doc(quoteId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete quote: $e');
    }
  }

  /// 글귀 수정 (하트 소진 없음 - 수정은 무료)
  Future<void> updateQuote(String quoteId, String newThought) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('quotes')
          .doc(quoteId);

      // 사용자 생각 업데이트
      await docRef.update({
        'userThought': newThought,
        'status': 'pending',
        'generatedQuote': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 백그라운드에서 새 글귀 및 작가 위로 메시지 생성
      final quote = await docRef.get();
      if (quote.exists) {
        final data = quote.data()!;
        final date = (data['date'] as Timestamp).toDate();
        _generateQuoteInBackground(quoteId, newThought, date);
      }
    } catch (e) {
      throw Exception('Failed to update quote: $e');
    }
  }
}
