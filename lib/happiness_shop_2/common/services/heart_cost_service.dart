// lib/happiness_shop_2/common/services/heart_cost_service.dart
import 'heart_service.dart';

/// 하트 소진 비용 상수
class HeartCost {
  static const int QUOTE = 1; // 행복 글귀
  static const int MUSIC = 1; // 행복 음악
  static const int FORTUNE = 1; // 행복 운세
  static const int COMFORT = 1; // 행복 위로
  static const int FLOWERS = 1; // 행복 꽃말
  static const int RECIPE = 1; // 행복 레시피
  static const int TRAVEL = 1; // 행복 여행
}

/// 하트 소진 통합 관리 서비스
class HeartCostService {
  final HeartService _heartService = HeartService();

  /// 하트 소진 가능 여부 확인
  Future<bool> canAfford(int cost) async {
    try {
      final heartInfo = await _heartService.getHeartInfo();
      return heartInfo.heartCount >= cost;
    } catch (e) {
      return false;
    }
  }

  /// 하트 소진 (트랜잭션 사용)
  Future<bool> spendHearts(int cost) async {
    try {
      return await _heartService.useHearts(cost);
    } catch (e) {
      return false;
    }
  }

  /// 하트 소진 가능 여부 확인 및 소진 (통합)
  Future<bool> checkAndSpendHearts(int cost) async {
    final canAfford = await this.canAfford(cost);
    if (!canAfford) {
      return false;
    }
    return await spendHearts(cost);
  }
}

