import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comfort_item.dart';
import '../../../common/services/gemini_shop_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../../services/environment_service.dart';

class ComfortService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiShopService _geminiService = GeminiShopService();
  final HeartCostService _heartCostService = HeartCostService();

  String get userId => _auth.currentUser?.uid ?? '';

  Future<ComfortItem?> createComfort({
    required String userMessage,
    required String locale,
  }) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');
    if (userMessage.trim().length < 10) {
      throw Exception('MESSAGE_TOO_SHORT');
    }

    final success =
        await _heartCostService.checkAndSpendHearts(HeartCost.COMFORT);
    if (!success) throw Exception('INSUFFICIENT_HEARTS');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('comforts')
        .doc();

    final item = ComfortItem(
      id: docRef.id,
      userId: userId,
      userMessage: userMessage.trim(),
      content: '',
      date: today,
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    await docRef.set(item.toFirestore());
    _generateInBackground(docRef.id, userMessage.trim(), locale, today);
    return item;
  }

  Future<void> _generateInBackground(
    String docId,
    String userMessage,
    String locale,
    DateTime date,
  ) async {
    try {
      final content = await _geminiService.generateComfort(
        userMessage: userMessage,
        date: date,
        locale: locale,
      );
      final modelName = EnvironmentService.instance.get(
        'GEMINI_MODEL_NAME',
        defaultValue: '',
      );
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('comforts')
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
          .collection('comforts')
          .doc(docId)
          .update({
        'status': 'failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<ComfortItem>> getUserComfortsStream() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('comforts')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ComfortItem.fromFirestore).toList());
  }

  Future<void> deleteComfort(String id) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('comforts')
        .doc(id)
        .delete();
  }
}
