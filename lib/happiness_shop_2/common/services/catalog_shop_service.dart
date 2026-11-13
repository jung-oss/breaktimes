import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/catalog_seed.dart';
import '../models/shop_catalog_item.dart';
import 'love_ledger.dart';

/// 도감 한 묶음의 진행 상황
class CollectionSetProgress {
  const CollectionSetProgress({
    required this.setId,
    required this.items,
    required this.ownedIds,
    required this.bonusClaimed,
  });

  final String setId;

  /// 묶음의 카드(순서대로)
  final List<ShopCatalogItem> items;
  final Set<String> ownedIds;
  final bool bonusClaimed;

  int get ownedCount => items.where((i) => ownedIds.contains(i.id)).length;
  bool get isComplete => items.isNotEmpty && ownedCount == items.length;
  String name(bool isKorean) =>
      items.isEmpty ? '' : items.first.setName(isKorean);
}

/// 카드를 고른 결과
class CollectResult {
  const CollectResult({
    required this.item,
    required this.balanceAfter,
    this.completedSet,
    this.bonusGranted = false,
  });

  final ShopCatalogItem item;
  final int balanceAfter;

  /// 이번 카드로 완성한 묶음(없으면 null)
  final CollectionSetProgress? completedSet;

  /// 완성 보너스를 받았는지
  final bool bonusGranted;
}

/// 카탈로그 + 도감 (음악·꽃말·레시피·여행)
///
/// 흐름: 아직 없는 카드 3장을 보여 줌 → 사용자가 1장을 고름 →
/// 사랑하기 차감·도감 저장·기록을 한 트랜잭션으로 → 묶음을 다 모으면 보너스.
class CatalogShopService {
  CatalogShopService(this.categoryId, this.heartCost);

  final String categoryId;
  final int heartCost;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Random _random = Random();

  /// 묶음 완성 보너스(기획안 5.2)
  static const int setBonus = 3;

  /// 한 번에 보여 주는 후보 수
  static const int choiceCount = 3;

  String get userId => _auth.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users').doc(userId);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _userRef.collection('collection');

  String _collectionDocId(String itemId) => '${categoryId}__$itemId';

  String _bonusKey(String setId) => '${categoryId}__$setId';

  /// 카탈로그: Firestore에 있으면 그것을, 없으면 앱 안 초안 목록을 씁니다.
  Future<List<ShopCatalogItem>> loadCatalog() async {
    try {
      final snapshot = await _firestore
          .collection('shop_catalog')
          .doc(categoryId)
          .collection('items')
          .where('isActive', isEqualTo: true)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map(_fromDoc).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      }
    } catch (_) {}
    return catalogSeed[categoryId] ?? const [];
  }

  ShopCatalogItem _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ShopCatalogItem(
      id: doc.id,
      titleKo: data['titleKo'] ?? '',
      titleEn: data['titleEn'] ?? '',
      bodyKo: data['bodyKo'] ?? data['descriptionKo'] ?? '',
      bodyEn: data['bodyEn'] ?? data['descriptionEn'] ?? '',
      subtitleKo: data['subtitleKo'],
      subtitleEn: data['subtitleEn'],
      tags: List<String>.from(data['tags'] ?? []),
      setId: data['setId'] ?? 'default',
      setNameKo: data['setNameKo'] ?? '기본 도감',
      setNameEn: data['setNameEn'] ?? 'Collection',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  /// 이 카테고리에서 이미 모은 카드 ID
  ///
  /// 도감 이전에 받은 카드(`{category}_picks`)도 모은 것으로 셉니다.
  Future<Set<String>> loadOwnedIds() async {
    if (userId.isEmpty) return {};
    final owned = <String>{};
    final collected =
        await _collection.where('categoryId', isEqualTo: categoryId).get();
    for (final doc in collected.docs) {
      final id = doc.data()['catalogId'];
      if (id is String) owned.add(id);
    }
    try {
      final legacy = await _userRef.collection('${categoryId}_picks').get();
      for (final doc in legacy.docs) {
        final id = doc.data()['catalogId'];
        if (id is String) owned.add(id);
      }
    } catch (_) {}
    return owned;
  }

  /// 완성 보너스를 받은 묶음 키
  Future<Set<String>> _loadClaimedBonuses() async {
    final user = await _userRef.get();
    final bonuses = user.data()?['collectionBonuses'];
    return bonuses is Map ? bonuses.keys.cast<String>().toSet() : {};
  }

  /// 묶음별 진행 상황
  Future<List<CollectionSetProgress>> loadProgress() async {
    final catalog = await loadCatalog();
    final owned = await loadOwnedIds();
    final claimed = await _loadClaimedBonuses();
    final bySet = <String, List<ShopCatalogItem>>{};
    for (final item in catalog) {
      bySet.putIfAbsent(item.setId, () => []).add(item);
    }
    return [
      for (final entry in bySet.entries)
        CollectionSetProgress(
          setId: entry.key,
          items: entry.value..sort((a, b) => a.order.compareTo(b.order)),
          ownedIds: owned,
          bonusClaimed: claimed.contains(_bonusKey(entry.key)),
        ),
    ];
  }

  /// 아직 없는 카드 중 [choiceCount]장. [tagFilter]에 맞는 카드가 있으면 그중에서 고릅니다.
  /// 모두 모았으면 빈 목록입니다.
  Future<List<ShopCatalogItem>> loadChoices({String? tagFilter}) async {
    final catalog = await loadCatalog();
    final owned = await loadOwnedIds();
    var pool = catalog.where((i) => !owned.contains(i.id)).toList();
    if (tagFilter != null && tagFilter.isNotEmpty) {
      final filtered = pool.where((i) => i.tags.contains(tagFilter)).toList();
      if (filtered.isNotEmpty) pool = filtered;
    }
    pool.shuffle(_random);
    return pool.take(choiceCount).toList();
  }

  /// 고른 카드를 도감에 넣습니다. 사랑하기 차감·도감 저장·기록을 한 번에 처리합니다.
  ///
  /// 이미 가진 카드면 ALREADY_OWNED, 부족하면 INSUFFICIENT_HEARTS,
  /// 연결 문제면 NETWORK_ERROR 예외를 던집니다.
  Future<CollectResult> collect(ShopCatalogItem item) async {
    if (userId.isEmpty) throw Exception('NOT_LOGGED_IN');

    final docRef = _collection.doc(_collectionDocId(item.id));
    LoveLedgerEntry? spent;
    try {
      await _firestore.runTransaction((transaction) async {
        spent = null;
        final existing = await transaction.get(docRef);
        if (existing.exists) throw Exception('ALREADY_OWNED');
        final userDoc = await transaction.get(_userRef);
        final hearts = (userDoc.data()?['heartCount'] as num?)?.toInt() ?? 0;
        if (hearts < heartCost) throw Exception('INSUFFICIENT_HEARTS');

        transaction.update(_userRef, {
          'heartCount': hearts - heartCost,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(docRef, {
          ...item.toCollectionMap(categoryId),
          'collectedAt': FieldValue.serverTimestamp(),
        });
        final entry = LoveLedgerEntry(
          isEarn: false,
          amount: heartCost,
          reason: LoveReason.fromCategoryId(categoryId),
          balanceAfter: hearts - heartCost,
          itemPath: docRef.path,
        );
        LoveLedger.write(transaction, _firestore, userId, entry);
        spent = entry;
      });
    } on FirebaseException {
      throw Exception('NETWORK_ERROR');
    }
    final entry = spent!;
    LoveLedger.track(entry);

    // 이번 카드로 묶음을 완성했는지 확인하고 보너스를 받습니다.
    CollectionSetProgress? completed;
    var bonusGranted = false;
    var balance = entry.balanceAfter;
    try {
      final progress = await loadProgress();
      for (final set in progress) {
        if (set.setId == item.setId && set.isComplete) {
          completed = set;
          if (!set.bonusClaimed) {
            final after = await _claimSetBonus(set.setId);
            if (after != null) {
              bonusGranted = true;
              balance = after;
            }
          }
        }
      }
    } catch (_) {
      // 보너스 확인에 실패해도 카드는 이미 도감에 들어갔습니다.
    }

    return CollectResult(
      item: item,
      balanceAfter: balance,
      completedSet: completed,
      bonusGranted: bonusGranted,
    );
  }

  /// 묶음 완성 보너스(+[setBonus]). 이미 받았거나 실패하면 null, 받으면 받은 뒤 잔액.
  Future<int?> _claimSetBonus(String setId) async {
    final key = _bonusKey(setId);
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    LoveLedgerEntry? earned;
    try {
      await _firestore.runTransaction((transaction) async {
        earned = null;
        final userDoc = await transaction.get(_userRef);
        final bonuses = userDoc.data()?['collectionBonuses'];
        if (bonuses is Map && bonuses.containsKey(key)) return;
        final hearts = (userDoc.data()?['heartCount'] as num?)?.toInt() ?? 0;
        transaction.update(_userRef, {
          'heartCount': FieldValue.increment(setBonus),
          'collectionBonuses.$key': today,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final entry = LoveLedgerEntry(
          isEarn: true,
          amount: setBonus,
          reason: LoveReason.collectionBonus,
          balanceAfter: hearts + setBonus,
        );
        LoveLedger.write(transaction, _firestore, userId, entry);
        earned = entry;
      });
    } catch (_) {
      // 보안 규칙이 아직 보너스를 허용하지 않으면 여기로 옵니다.
      return null;
    }
    final entry = earned;
    if (entry == null) return null;
    LoveLedger.track(entry);
    return entry.balanceAfter;
  }
}
