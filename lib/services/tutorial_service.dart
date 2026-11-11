import 'package:shared_preferences/shared_preferences.dart';

/// 튜토리얼 관련 서비스
///
/// 사용자의 첫 방문 여부를 저장하고 확인하는 기능을 제공합니다.
class TutorialService {
  static const String _firstVisitKey = 'first_visit';
  static const String _lastTutorialVersionKey = 'last_tutorial_version';

  // 현재 튜토리얼 버전 - 튜토리얼 내용이 업데이트되면 이 값을 증가시켜 기존 사용자에게도 보여줄 수 있음
  static const int currentTutorialVersion = 1;

  /// 사용자가 처음 방문했는지 확인
  static Future<bool> isFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey(_firstVisitKey);
  }

  /// 사용자의 방문 기록 저장
  static Future<void> markVisited() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstVisitKey, true);
    await prefs.setInt(_lastTutorialVersionKey, currentTutorialVersion);
  }

  /// 튜토리얼을 보여줘야 하는지 확인
  ///
  /// 첫 방문이거나 튜토리얼 버전이 업데이트된 경우 true 반환
  static Future<bool> shouldShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();

    // 첫 방문인 경우
    if (!prefs.containsKey(_firstVisitKey)) {
      return true;
    }

    // 튜토리얼 버전이 업데이트된 경우
    final lastVersion = prefs.getInt(_lastTutorialVersionKey) ?? 0;
    return lastVersion < currentTutorialVersion;
  }

  /// 튜토리얼 버전 업데이트
  static Future<void> updateTutorialVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTutorialVersionKey, currentTutorialVersion);
  }

  /// 튜토리얼 상태 초기화 (테스트용)
  static Future<void> resetTutorialState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstVisitKey);
    await prefs.remove(_lastTutorialVersionKey);
  }
}
