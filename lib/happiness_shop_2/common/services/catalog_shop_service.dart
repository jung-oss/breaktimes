import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shop_catalog_item.dart';
import '../services/heart_cost_service.dart';

/// Firestore 카탈로그 + 로컬 폴백으로 콘텐츠 제공
class CatalogShopService {
  CatalogShopService(this.categoryId, this.heartCost);

  final String categoryId;
  final int heartCost;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HeartCostService _heartCostService = HeartCostService();
  static final Random _random = Random();

  String get userId => _auth.currentUser?.uid ?? '';

  Future<List<ShopCatalogItem>> loadCatalog() async {
    try {
      final snapshot = await _firestore
          .collection('shop_catalog')
          .doc(categoryId)
          .collection('items')
          .where('isActive', isEqualTo: true)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map(_fromDoc).toList();
      }
    } catch (_) {}
    return _fallbackItems();
  }

  ShopCatalogItem _fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopCatalogItem(
      id: doc.id,
      titleKo: data['titleKo'] ?? '',
      titleEn: data['titleEn'] ?? '',
      bodyKo: data['bodyKo'] ?? data['descriptionKo'] ?? '',
      bodyEn: data['bodyEn'] ?? data['descriptionEn'] ?? '',
      subtitleKo: data['subtitleKo'],
      subtitleEn: data['subtitleEn'],
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Future<ShopCatalogItem?> drawWithHearts({String? tagFilter}) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');

    final success = await _heartCostService.checkAndSpendHearts(heartCost);
    if (!success) throw Exception('INSUFFICIENT_HEARTS');

    var catalog = await loadCatalog();
    if (tagFilter != null && tagFilter.isNotEmpty) {
      catalog = catalog
          .where((item) => item.tags.contains(tagFilter))
          .toList();
      if (catalog.isEmpty) catalog = await loadCatalog();
    }

    final picked = catalog[_random.nextInt(catalog.length)];
    await _saveUserPick(picked);
    return picked;
  }

  Future<void> _saveUserPick(ShopCatalogItem item) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('${categoryId}_picks')
          .add({
        'catalogId': item.id,
        'titleKo': item.titleKo,
        'titleEn': item.titleEn,
        'bodyKo': item.bodyKo,
        'bodyEn': item.bodyEn,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> getUserPicksStream() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('${categoryId}_picks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  List<ShopCatalogItem> _fallbackItems() {
    switch (categoryId) {
      case 'music':
        return const [
          ShopCatalogItem(
            id: 'music_calm_1',
            titleKo: '고요한 아침',
            titleEn: 'Quiet Morning',
            bodyKo: '잔잔한 피아노 선율로 하루를 부드럽게 시작해 보세요.',
            bodyEn: 'Start your day gently with a calm piano melody.',
            tags: ['calm', 'morning'],
          ),
          ShopCatalogItem(
            id: 'music_hope_1',
            titleKo: '작은 응원',
            titleEn: 'Little Cheer',
            bodyKo: '지친 마음에 작은 박수를 더하는 따뜻한 멜로디입니다.',
            bodyEn: 'A warm melody that adds a small cheer to tired hearts.',
            tags: ['hope', 'cheer'],
          ),
        ];
      case 'flowers':
        return const [
          ShopCatalogItem(
            id: 'flower_sunflower',
            titleKo: '해바라기',
            titleEn: 'Sunflower',
            bodyKo: '당신은 충분히 빛나고 있어요.',
            bodyEn: 'You are already shining brightly.',
            subtitleKo: '기다림, 존경',
            subtitleEn: 'Adoration, loyalty',
            tags: ['bright'],
          ),
          ShopCatalogItem(
            id: 'flower_lavender',
            titleKo: '라벤더',
            titleEn: 'Lavender',
            bodyKo: '오늘은 마음을 천천히 쉬게 해도 괜찮아요.',
            bodyEn: 'It is okay to let your heart rest slowly today.',
            subtitleKo: '평온, 치유',
            subtitleEn: 'Calm, healing',
            tags: ['calm'],
          ),
        ];
      case 'recipe':
        return const [
          ShopCatalogItem(
            id: 'recipe_tomato_egg',
            titleKo: '토마토 계란볶음',
            titleEn: 'Tomato Egg Stir-fry',
            bodyKo: '10분 · 쉬움\n재료: 계란 2개, 토마토 1개, 소금\n1. 계란을 익힌다\n2. 토마토를 넣고 볶는다\n3. 소금으로 간한다',
            bodyEn: '10 min · Easy\nEggs, tomato, salt\n1. Scramble eggs\n2. Add tomato\n3. Season',
            tags: ['quick', 'warm'],
          ),
        ];
      case 'travel':
        return const [
          ShopCatalogItem(
            id: 'travel_walk',
            titleKo: '근처 산책로',
            titleEn: 'Nearby Walk',
            bodyKo: '15분만 걸어도 마음이 조금 가벼워질 수 있어요.',
            bodyEn: 'Even a 15-minute walk can lighten your mood.',
            subtitleKo: '근처 산책',
            subtitleEn: 'Local walk',
            tags: ['walk'],
          ),
          ShopCatalogItem(
            id: 'travel_imagine',
            titleKo: '바닷가 상상 여행',
            titleEn: 'Imaginary Beach',
            bodyKo: '눈을 감고 파도 소리를 상상해 보세요. 잠깐의 휴식이면 충분해요.',
            bodyEn: 'Close your eyes and imagine ocean waves. A short break is enough.',
            subtitleKo: '상상 여행',
            subtitleEn: 'Imaginary trip',
            tags: ['imagine'],
          ),
        ];
      default:
        return const [];
    }
  }
}
