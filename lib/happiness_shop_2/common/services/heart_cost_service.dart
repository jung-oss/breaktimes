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

/// 사랑하기 값과 "충분한지" 확인(빼는 일은 서버가 합니다)
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

  // 사랑하기를 빼는 일은 서버 함수(shop_functions.dart)가 합니다.
}

