// lib/happiness_shop_2/common/services/shop_functions.dart
import 'package:cloud_functions/cloud_functions.dart';

/// 행복-가게 서버 함수 호출 (functions/src/index.ts, 서울 지역)
///
/// 사랑하기를 늘리고 줄이는 일, AI 결과 만들기, 도감 모으기는 모두 서버가 합니다.
/// 서버 오류는 앱이 이미 쓰는 예외 문구(INSUFFICIENT_HEARTS, NETWORK_ERROR 등)로 바꿔 던집니다.
class ShopFunctions {
  ShopFunctions._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  /// 서버가 직접 알려 주는 오류 코드
  static const _knownCodes = {
    'NOT_LOGGED_IN',
    'INSUFFICIENT_HEARTS',
    'DAILY_LIMIT',
    'ALREADY_OWNED',
    'MAX_SLOTS',
    'NOT_ELIGIBLE',
    'NO_SUCH_CARD',
    'MESSAGE_TOO_SHORT',
    'EMPTY_TEXT',
  };

  static Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    try {
      final result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 70)),
          )
          .call<dynamic>(data);
      final value = result.data;
      return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? '';
      if (_knownCodes.contains(message)) throw Exception(message);
      if (e.code == 'unauthenticated') throw Exception('NOT_LOGGED_IN');
      if (e.code == 'not-found') throw Exception('NOT_FOUND');
      // 연결 끊김·시간 초과·서버 일시 오류 등: 사랑하기는 빠지지 않았습니다
      throw Exception('NETWORK_ERROR');
    } catch (_) {
      // 그 밖의 오류(플랫폼 오류 등)도 연결 문제로 안내합니다
      throw Exception('NETWORK_ERROR');
    }
  }

  /// 기기 기준 오늘 0시(결과 문서의 날짜로 씁니다)
  static int localDayStartMillis() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }
}
