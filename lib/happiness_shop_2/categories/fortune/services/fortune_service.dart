import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/fortune_item.dart';
import '../../../common/services/gemini_shop_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/services/shop_charge_service.dart';
import '../../../common/services/love_ledger.dart';
import '../../../../services/environment_service.dart';

class FortuneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiShopService _geminiService = GeminiShopService();
  final ShopChargeService _charge = ShopChargeService();

  String get userId => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _fortunes =>
      _firestore.collection('users').doc(userId).collection('fortunes');

  /// 오늘의 운세를 만듭니다. 사랑하기는 운세가 나온 뒤에 빠집니다.
  Future<FortuneItem?> createTodayFortune({
    required String locale,
    String? mood,
    bool forceRegenerate = false,
  }) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!forceRegenerate) {
      final existing = await getTodayFortune();
      if (existing != null) return existing;
    }

    await _charge.ensureAffordable(HeartCost.FORTUNE);

    final docRef = _fortunes.doc();
    final item = FortuneItem(
      id: docRef.id,
      userId: userId,
      mood: mood,
      content: '',
      date: today,
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    try {
      await docRef.set({
        ...item.toFirestore(),
        ..._charge.chargeFields(HeartCost.FORTUNE, locale),
      });
    } on FirebaseException {
      throw Exception('NETWORK_ERROR');
    }
    _generateInBackground(docRef, locale, today, mood);
    return item;
  }

  Future<void> _generateInBackground(
    DocumentReference<Map<String, dynamic>> docRef,
    String locale,
    DateTime date,
    String? mood,
  ) async {
    if (!_charge.begin(docRef.id)) return;
    try {
      final result = await _geminiService.generateFortune(
        date: date,
        locale: locale,
        mood: mood,
      );
      final modelName = EnvironmentService.instance.get(
        'GEMINI_MODEL_NAME',
        defaultValue: '',
      );
      await _charge.complete(
        docRef,
        {
          'content': result.text,
          'status': 'generated',
          'model': result.isFallback ? '' : modelName,
        },
        isFallback: result.isFallback,
        reason: LoveReason.fortune,
      );
    } catch (_) {
      await _charge.markFailed(docRef);
    } finally {
      _charge.end(docRef.id);
    }
  }

  /// 앱이 꺼져 'pending'에 멈춘 운세를 이어서 만듭니다.
  Future<void> resumeIfPending(FortuneItem item) async {
    final docRef = _fortunes.doc(item.id);
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null || !ShopChargeService.isStalePending(data)) return;
    final locale = data['locale'] as String? ?? 'ko';
    _generateInBackground(docRef, locale, item.date, item.mood);
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
}
