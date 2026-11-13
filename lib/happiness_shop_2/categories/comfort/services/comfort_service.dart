import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comfort_item.dart';
import '../../../common/services/gemini_shop_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/services/shop_charge_service.dart';
import '../../../common/services/love_ledger.dart';
import '../../../../services/environment_service.dart';

class ComfortService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiShopService _geminiService = GeminiShopService();
  final ShopChargeService _charge = ShopChargeService();

  String get userId => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _comforts =>
      _firestore.collection('users').doc(userId).collection('comforts');

  /// 위로 편지를 만듭니다. 사랑하기는 편지가 나온 뒤에 빠집니다.
  Future<ComfortItem?> createComfort({
    required String userMessage,
    required String locale,
  }) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');
    if (userMessage.trim().length < 10) {
      throw Exception('MESSAGE_TOO_SHORT');
    }

    await _charge.ensureAffordable(HeartCost.COMFORT);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docRef = _comforts.doc();

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

    try {
      await docRef.set({
        ...item.toFirestore(),
        ..._charge.chargeFields(HeartCost.COMFORT, locale),
      });
    } on FirebaseException {
      throw Exception('NETWORK_ERROR');
    }
    _generateInBackground(docRef, userMessage.trim(), locale, today);
    return item;
  }

  Future<void> _generateInBackground(
    DocumentReference<Map<String, dynamic>> docRef,
    String userMessage,
    String locale,
    DateTime date,
  ) async {
    if (!_charge.begin(docRef.id)) return;
    try {
      final result = await _geminiService.generateComfort(
        userMessage: userMessage,
        date: date,
        locale: locale,
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
        reason: LoveReason.comfort,
      );
    } catch (_) {
      await _charge.markFailed(docRef);
    } finally {
      _charge.end(docRef.id);
    }
  }

  /// 앱이 꺼져 'pending'에 멈춘 위로 편지를 이어서 만듭니다.
  Future<void> resumePending() async {
    if (userId.isEmpty) return;
    try {
      final snapshot =
          await _comforts.where('status', isEqualTo: 'pending').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (!ShopChargeService.isStalePending(data)) continue;
        final message = data['userMessage'] as String? ?? '';
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        _generateInBackground(
            doc.reference, message, data['locale'] as String? ?? 'ko', date);
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
