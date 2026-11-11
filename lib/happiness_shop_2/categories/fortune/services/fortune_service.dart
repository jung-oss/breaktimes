import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/fortune_item.dart';
import '../../../common/services/gemini_shop_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../../services/environment_service.dart';

class FortuneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiShopService _geminiService = GeminiShopService();
  final HeartCostService _heartCostService = HeartCostService();

  String get userId => _auth.currentUser?.uid ?? '';

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

    final success =
        await _heartCostService.checkAndSpendHearts(HeartCost.FORTUNE);
    if (!success) throw Exception('INSUFFICIENT_HEARTS');

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('fortunes')
        .doc();

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

    await docRef.set(item.toFirestore());
    _generateInBackground(docRef.id, locale, today, mood);
    return item;
  }

  Future<void> _generateInBackground(
    String docId,
    String locale,
    DateTime date,
    String? mood,
  ) async {
    try {
      final content = await _geminiService.generateFortune(
        date: date,
        locale: locale,
        mood: mood,
      );
      final modelName = EnvironmentService.instance.get(
        'GEMINI_MODEL_NAME',
        defaultValue: '',
      );
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fortunes')
          .doc(docId)
          .update({
        'content': content,
        'status': 'generated',
        'model': modelName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fortunes')
          .doc(docId)
          .update({
        'status': 'failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<FortuneItem?> getTodayFortune() async {
    if (userId.isEmpty) return null;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('fortunes')
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return FortuneItem.fromFirestore(snapshot.docs.first);
    } catch (_) {
      return null;
    }
  }

  Stream<List<FortuneItem>> getUserFortunesStream() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('fortunes')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FortuneItem.fromFirestore).toList());
  }

  Future<void> deleteFortune(String id) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('fortunes')
        .doc(id)
        .delete();
  }
}
