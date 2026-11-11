// lib/happiness_shop_2/common/models/heart_info.dart

/// 하트 정보 모델
class HeartInfo {
  final int heartCount;
  final int slotCount;
  final int maxSlots;

  HeartInfo({
    required this.heartCount,
    required this.slotCount,
    required this.maxSlots,
  });

  factory HeartInfo.fromMap(Map<String, dynamic> map) {
    return HeartInfo(
      heartCount: map['heartCount'] ?? 0,
      slotCount: map['slotCount'] ?? 1,
      maxSlots: map['maxSlots'] ?? 20,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heartCount': heartCount,
      'slotCount': slotCount,
      'maxSlots': maxSlots,
    };
  }
}

