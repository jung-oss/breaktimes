// lib/happiness_shop_2/common/services/love_ledger.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// 사랑하기가 늘거나 준 이유
///
/// 저장할 때는 [key]를 씁니다. 화면에 보일 이름은 [labelKo]/[labelEn]입니다.
enum LoveReason {
  // 벌기
  dailyCheckIn('dailyCheckIn', '매일 서랍 열기', 'Daily check-in'),
  mission('mission', '행복-미션 100%', 'Mission 100%'),
  happyBox('happyBox', '행복-함 작성', 'Happy Box entry'),
  collectionBonus('collectionBonus', '도감 완성', 'Collection complete'),

  // 쓰기
  fortune('fortune', '오늘의 운세', "Today's fortune"),
  comfort('comfort', '위로 편지', 'Comfort letter'),
  quote('quote', '행복 글귀', 'Happy quote'),
  music('music', '행복 음악', 'Happy music'),
  flowers('flowers', '행복 꽃말', 'Flower message'),
  recipe('recipe', '행복 레시피', 'Happy recipe'),
  travel('travel', '행복 여행', 'Happy trip'),
  vitaminSlot('vitaminSlot', '비타민 슬롯 늘리기', 'Vitamin slot'),

  /// 이유를 모르는 경우(예전 코드 경로)
  other('other', '기타', 'Other');

  const LoveReason(this.key, this.labelKo, this.labelEn);
  final String key;
  final String labelKo;
  final String labelEn;

  String label(bool isKorean) => isKorean ? labelKo : labelEn;

  static LoveReason fromKey(String? key) => LoveReason.values.firstWhere(
        (r) => r.key == key,
        orElse: () => LoveReason.other,
      );

  /// 카드 뽑기 카테고리 이름(categoryId)으로 이유 찾기
  static LoveReason fromCategoryId(String categoryId) {
    switch (categoryId) {
      case 'music':
        return LoveReason.music;
      case 'flowers':
        return LoveReason.flowers;
      case 'recipe':
        return LoveReason.recipe;
      case 'travel':
        return LoveReason.travel;
      default:
        return LoveReason.other;
    }
  }
}

/// 사랑하기 기록 한 줄
class LoveLedgerEntry {
  const LoveLedgerEntry({
    required this.isEarn,
    required this.amount,
    required this.reason,
    required this.balanceAfter,
    this.id = '',
    this.itemPath,
    this.createdAt,
  });

  /// 받은 기록인지(아니면 쓴 기록)
  final bool isEarn;

  /// 늘거나 준 개수(항상 양수)
  final int amount;
  final LoveReason reason;

  /// 이 일이 끝난 뒤의 잔액
  final int balanceAfter;
  final String id;

  /// 관련 결과 문서 경로(예: users/{uid}/fortunes/{id}). 없으면 null
  final String? itemPath;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'type': isEarn ? 'earn' : 'spend',
        'amount': amount,
        'reason': reason.key,
        'balanceAfter': balanceAfter,
        if (itemPath != null) 'itemPath': itemPath,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory LoveLedgerEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LoveLedgerEntry(
      id: doc.id,
      isEarn: data['type'] == 'earn',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      reason: LoveReason.fromKey(data['reason'] as String?),
      balanceAfter: (data['balanceAfter'] as num?)?.toInt() ?? 0,
      itemPath: data['itemPath'] as String?,
      // 방금 쓴 기록은 서버 시각이 아직 없을 수 있어 지금 시각으로 보여 줍니다
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// 사랑하기 기록(장부)
///
/// 경로: users/{uid}/love_ledger/{자동 ID}
/// 잔액을 바꾸는 트랜잭션 안에서 [write]를 함께 불러, 잔액과 기록이 함께 저장되게 합니다.
/// 지금은 앱이 기록을 쓰므로 참고용입니다. 서버 함수로 옮기면(기획안 4단계) 정확한 장부가 됩니다.
class LoveLedger {
  LoveLedger._();

  static CollectionReference<Map<String, dynamic>> collection(
          FirebaseFirestore firestore, String uid) =>
      firestore.collection('users').doc(uid).collection('love_ledger');

  /// 트랜잭션 안에서 기록 한 줄을 씁니다.
  static void write(
    Transaction transaction,
    FirebaseFirestore firestore,
    String uid,
    LoveLedgerEntry entry,
  ) {
    transaction.set(collection(firestore, uid).doc(), entry.toMap());
  }

  /// 트랜잭션이 성공한 뒤 사용 통계에 남깁니다. 실패해도 앱 동작에는 영향이 없습니다.
  static void track(LoveLedgerEntry entry) {
    try {
      FirebaseAnalytics.instance.logEvent(
        name: entry.isEarn ? 'love_earn' : 'love_spend',
        parameters: {
          'reason': entry.reason.key,
          'amount': entry.amount,
          'balance_after': entry.balanceAfter,
        },
      );
    } catch (_) {}
  }

  /// 최근 기록(새것부터)
  static Stream<List<LoveLedgerEntry>> stream(
    FirebaseFirestore firestore,
    String uid, {
    int limit = 200,
  }) {
    return collection(firestore, uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(LoveLedgerEntry.fromDoc).toList());
  }
}
