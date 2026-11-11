import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전반에서 로깅을 위한 유틸리티 클래스
///
/// 개발 및 프로덕션 환경에서 일관된 로깅을 제공하며,
/// 필요에 따라 로그 레벨을 조정할 수 있습니다.
class Logger {
  // 로그 레벨 정의
  static const int _levelVerbose = 0;
  static const int _levelDebug = 1;
  static const int _levelInfo = 2;
  static const int _levelWarn = 3;
  static const int _levelError = 4;
  static const int _levelNone = 5;

  // 현재 로그 레벨 (기본값: 디버그 모드에서는 debug, 릴리즈 모드에서는 info)
  static int _currentLevel = kDebugMode ? _levelDebug : _levelInfo;

  // 로그 저장 여부
  static bool _saveToStorage = false;

  // 최대 로그 보관 수
  static const int _maxLogHistory = 1000;

  // 로그 저장을 위한 키
  static const String _logStorageKey = 'app_logs';

  /// 로거 초기화
  static Future<void> initialize({bool saveToStorage = false}) async {
    _saveToStorage = saveToStorage;

    if (_saveToStorage) {
      // 저장소에서 기존 로그 정리 (오래된 로그 삭제)
      await _cleanupOldLogs();
    }

    info(
        'Logger 초기화: 로그 레벨=${_getLevelName(_currentLevel)}, 저장=$_saveToStorage');
  }

  /// 로그 레벨 설정
  static void setLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'verbose':
        _currentLevel = _levelVerbose;
        break;
      case 'debug':
        _currentLevel = _levelDebug;
        break;
      case 'info':
        _currentLevel = _levelInfo;
        break;
      case 'warn':
      case 'warning':
        _currentLevel = _levelWarn;
        break;
      case 'error':
        _currentLevel = _levelError;
        break;
      case 'none':
        _currentLevel = _levelNone;
        break;
      default:
        _currentLevel = kDebugMode ? _levelDebug : _levelInfo;
    }

    info('로그 레벨이 ${_getLevelName(_currentLevel)}(으)로 설정되었습니다');
  }

  /// 자세한 로그 (개발 시 상세 정보)
  static void verbose(String message) {
    _log(_levelVerbose, message);
  }

  /// 디버그 로그 (개발 중 디버깅용)
  static void debug(String message) {
    _log(_levelDebug, message);
  }

  /// 정보 로그 (일반적인 정보)
  static void info(String message) {
    _log(_levelInfo, message);
  }

  /// 경고 로그 (잠재적 문제)
  static void warn(String message) {
    _log(_levelWarn, message);
  }

  /// 오류 로그 (실제 발생한 오류)
  static void error(String message, {StackTrace? stackTrace}) {
    final fullMessage = stackTrace != null ? '$message\n$stackTrace' : message;

    _log(_levelError, fullMessage);
  }

  /// 실제 로깅 수행 메서드
  static void _log(int level, String message) {
    // 현재 로그 레벨보다 낮은 레벨의 로그는 무시
    if (level < _currentLevel) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelName = _getLevelName(level);
    final formattedMessage = '[$levelName] $timestamp: $message';

    // 콘솔에 출력
    if (kDebugMode) {
      switch (level) {
        case _levelVerbose:
        case _levelDebug:
          debugPrint(formattedMessage);
          break;
        case _levelInfo:
          debugPrint('\x1B[34m$formattedMessage\x1B[0m'); // 파란색
          break;
        case _levelWarn:
          debugPrint('\x1B[33m$formattedMessage\x1B[0m'); // 노란색
          break;
        case _levelError:
          debugPrint('\x1B[31m$formattedMessage\x1B[0m'); // 빨간색
          break;
      }
    }

    // 저장소에 저장
    if (_saveToStorage) {
      _saveLogToStorage(formattedMessage);
    }
  }

  /// 로그 레벨 이름 반환
  static String _getLevelName(int level) {
    switch (level) {
      case _levelVerbose:
        return 'VERBOSE';
      case _levelDebug:
        return 'DEBUG';
      case _levelInfo:
        return 'INFO';
      case _levelWarn:
        return 'WARN';
      case _levelError:
        return 'ERROR';
      default:
        return 'UNKNOWN';
    }
  }

  /// 로그를 저장소에 저장
  static void _saveLogToStorage(String logMessage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList(_logStorageKey) ?? [];

      // 로그 추가
      logs.add(logMessage);

      // 최대 개수 제한
      if (logs.length > _maxLogHistory) {
        logs.removeRange(0, logs.length - _maxLogHistory);
      }

      await prefs.setStringList(_logStorageKey, logs);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('로그 저장 오류: $e');
      }
    }
  }

  /// 오래된 로그 정리
  static Future<void> _cleanupOldLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList(_logStorageKey) ?? [];

      if (logs.length > _maxLogHistory) {
        logs.removeRange(0, logs.length - _maxLogHistory);
        await prefs.setStringList(_logStorageKey, logs);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('로그 정리 오류: $e');
      }
    }
  }

  /// 저장된 로그 가져오기
  static Future<List<String>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_logStorageKey) ?? [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('로그 가져오기 오류: $e');
      }
      return [];
    }
  }

  /// 특정 레벨 로그만 필터링하여 가져오기
  static Future<List<String>> getFilteredLogs(String level) async {
    final logs = await getLogs();
    final prefix = '[$level]';

    return logs.where((log) => log.contains(prefix)).toList();
  }

  /// 로그 초기화
  static Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_logStorageKey, []);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('로그 초기화 오류: $e');
      }
    }
  }
}
