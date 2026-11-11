// lib/happiness_shop_2/categories/quotes/services/firebase_daily_quotes_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_quote.dart';

/// Firebase에서 오늘의 명언을 가져오는 서비스
class FirebaseDailyQuotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 오늘의 명언 가져오기 (Firebase에서)
  Future<DailyQuote?> getTodayQuote() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 1. 먼저 오늘 날짜의 명언 조회 (date 필드가 있는 경우)
      try {
        final snapshot = await _firestore
            .collection('daily_quotes')
            .where('date', isEqualTo: Timestamp.fromDate(today))
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          return DailyQuote(
            quote: data['quote'] ?? '',
            author: data['author'] ?? '',
            source: data['source'],
          );
        }
      } catch (e) {
        // date 필드가 없거나 인덱스가 없는 경우 무시하고 다음 단계로
      }

      // 2. date 필드가 없거나 오늘 날짜의 명언이 없으면 최신 활성 명언 가져오기
      try {
        final latestSnapshot = await _firestore
            .collection('daily_quotes')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (latestSnapshot.docs.isNotEmpty) {
          final data = latestSnapshot.docs.first.data();
          return DailyQuote(
            quote: data['quote'] ?? '',
            author: data['author'] ?? '',
            source: data['source'],
          );
        }
      } catch (e) {
        // createdAt으로 정렬이 안 되면 그냥 최신 문서 가져오기
        final latestSnapshot = await _firestore
            .collection('daily_quotes')
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (latestSnapshot.docs.isNotEmpty) {
          final data = latestSnapshot.docs.first.data();
          return DailyQuote(
            quote: data['quote'] ?? '',
            author: data['author'] ?? '',
            source: data['source'],
          );
        }
      }

      return null;
    } catch (e) {
      print('FirebaseDailyQuotesService 오류: $e');
      return null;
    }
  }
}
