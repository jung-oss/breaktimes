import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'dart:convert';

/// 환경 변수 관리 서비스
/// Firebase Remote Config와 로컬 .env 파일을 병행하여 사용
class EnvironmentService {
  static EnvironmentService? _instance;
  static EnvironmentService get instance =>
      _instance ??= EnvironmentService._();

  EnvironmentService._();

  late FirebaseRemoteConfig _remoteConfig;
  bool _isInitialized = false;

  // 캐시된 환경 변수들
  Map<String, String> _cachedEnvVars = {};

  // 기본값들
  static const Map<String, String> _defaultValues = {
    'GEMINI_API_KEY': '',
    'GEMIN_API_KEY_SHOP': '',
    'GEMINI_MODEL_NAME': '',
    'CLOUD_PROJECT_NUMBER': '',
    'KAKAO_API_KEY': '',
    'DEBUG_MODE': 'false',
    'API_TIMEOUT': '30000',
    'CACHE_DURATION': '3600',
    'FEATURE_AI_CHAT': 'true',
    'FEATURE_TRANSLATION': 'true',
    'MAX_RETRY_COUNT': '3',
  };

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Logger.info('EnvironmentService 초기화 시작');

      // 1. 로컬 .env 파일 로드 (폴백용)
      await _loadLocalEnv();

      // 2. Firebase Remote Config 초기화
      await _initializeRemoteConfig();

      // 3. 캐시된 Remote Config 값 로드
      await _loadCachedRemoteConfig();

      // 4. Remote Config 업데이트 시도 (백그라운드)
      _fetchRemoteConfigInBackground();

      _isInitialized = true;
      Logger.info('EnvironmentService 초기화 완료');
    } catch (e) {
      Logger.error('EnvironmentService 초기화 실패: $e');
      // 로컬 .env만 사용하도록 폴백
      _isInitialized = true;
    }
  }

  /// 로컬 .env 파일 로드
  Future<void> _loadLocalEnv() async {
    try {
      await dotenv.load(fileName: ".env");
      Logger.debug('로컬 .env 파일 로드 완료');

      // .env 파일의 값들을 캐시에 저장 (기본값)
      for (String key in _defaultValues.keys) {
        final value = dotenv.env[key];
        if (value != null && value.isNotEmpty) {
          _cachedEnvVars[key] = value;
        }
      }
    } catch (e) {
      Logger.warn('로컬 .env 파일 로드 실패: $e');
    }
  }

  /// Firebase Remote Config 초기화
  Future<void> _initializeRemoteConfig() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Remote Config 설정
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1), // 1시간마다 업데이트 체크
        ),
      );

      // 기본값 설정
      await _remoteConfig.setDefaults(_defaultValues);

      Logger.debug('Firebase Remote Config 초기화 완료');
    } catch (e) {
      Logger.warn('Firebase Remote Config 초기화 실패: $e');
      rethrow;
    }
  }

  /// 캐시된 Remote Config 값 로드
  Future<void> _loadCachedRemoteConfig() async {
    try {
      // SharedPreferences에서 마지막 캐시된 값들 로드
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('remote_config_cache');

      if (cachedJson != null) {
        final cachedData = json.decode(cachedJson) as Map<String, dynamic>;
        _cachedEnvVars.addAll(cachedData.cast<String, String>());
        Logger.debug('캐시된 Remote Config 값 로드 완료');
      }

      // Remote Config의 현재 값들도 로드
      for (String key in _defaultValues.keys) {
        final value = _remoteConfig.getString(key);
        if (value.isNotEmpty) {
          _cachedEnvVars[key] = value;
        }
      }
    } catch (e) {
      Logger.warn('캐시된 Remote Config 로드 실패: $e');
    }
  }

  /// 백그라운드에서 Remote Config 업데이트
  void _fetchRemoteConfigInBackground() async {
    try {
      Logger.debug('Remote Config 백그라운드 업데이트 시작');

      await _remoteConfig.fetchAndActivate();

      // 새로운 값들을 캐시에 업데이트
      bool hasChanges = false;
      for (String key in _defaultValues.keys) {
        final newValue = _remoteConfig.getString(key);
        if (newValue.isNotEmpty && _cachedEnvVars[key] != newValue) {
          _cachedEnvVars[key] = newValue;
          hasChanges = true;
        }
      }

      if (hasChanges) {
        // 캐시를 SharedPreferences에 저장
        await _saveCacheToStorage();
        Logger.info('Remote Config 업데이트 완료 - 새로운 설정 적용됨');
      } else {
        Logger.debug('Remote Config 업데이트 완료 - 변경사항 없음');
      }
    } catch (e) {
      Logger.warn('Remote Config 백그라운드 업데이트 실패: $e');
    }
  }

  /// 캐시를 로컬 저장소에 저장
  Future<void> _saveCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = json.encode(_cachedEnvVars);
      await prefs.setString('remote_config_cache', cacheJson);

      // 마지막 업데이트 시간 저장
      await prefs.setInt(
          'remote_config_last_update', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      Logger.warn('Remote Config 캐시 저장 실패: $e');
    }
  }

  /// 환경 변수 값 가져오기
  String get(String key, {String? defaultValue}) {
    // 1. 캐시된 값 확인
    if (_cachedEnvVars.containsKey(key)) {
      return _cachedEnvVars[key]!;
    }

    // 2. Remote Config에서 확인
    if (_isInitialized) {
      try {
        final remoteValue = _remoteConfig.getString(key);
        if (remoteValue.isNotEmpty) {
          _cachedEnvVars[key] = remoteValue;
          return remoteValue;
        }
      } catch (e) {
        Logger.warn('Remote Config에서 $key 읽기 실패: $e');
      }
    }

    // 3. 로컬 .env에서 확인 (.env는 앱에 넣지 않으므로 대개 읽히지 않습니다)
    final localValue = dotenv.isInitialized ? dotenv.env[key] : null;
    if (localValue != null && localValue.isNotEmpty) {
      return localValue;
    }

    // 4. 기본값 반환
    return defaultValue ?? _defaultValues[key] ?? '';
  }

  /// Bool 값 가져오기
  bool getBool(String key, {bool defaultValue = false}) {
    final value = get(key, defaultValue: defaultValue.toString());
    return value.toLowerCase() == 'true';
  }

  /// Int 값 가져오기
  int getInt(String key, {int defaultValue = 0}) {
    final value = get(key, defaultValue: defaultValue.toString());
    return int.tryParse(value) ?? defaultValue;
  }

  /// 수동으로 Remote Config 업데이트
  Future<bool> forceUpdate() async {
    if (!_isInitialized) return false;

    try {
      Logger.info('Remote Config 수동 업데이트 시작');

      await _remoteConfig.fetchAndActivate();

      // 새로운 값들을 캐시에 업데이트
      bool hasChanges = false;
      for (String key in _defaultValues.keys) {
        final newValue = _remoteConfig.getString(key);
        if (newValue.isNotEmpty && _cachedEnvVars[key] != newValue) {
          final oldValue = _cachedEnvVars[key] ?? 'null';
          _cachedEnvVars[key] = newValue;
          hasChanges = true;
          Logger.debug('$key 업데이트: $oldValue → $newValue');
        }
      }

      if (hasChanges) {
        await _saveCacheToStorage();
        Logger.info(
            'Remote Config 수동 업데이트 완료 - ${hasChanges ? '변경사항 적용됨' : '변경사항 없음'}');
      }

      return hasChanges;
    } catch (e) {
      Logger.error('Remote Config 수동 업데이트 실패: $e');
      return false;
    }
  }

  /// 마지막 업데이트 시간 확인
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('remote_config_last_update');
      return timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// 현재 모든 환경 변수 상태 출력 (디버그용)
  void debugPrintAll() {
    Logger.debug('=== 현재 환경 변수 상태 ===');
    for (String key in _defaultValues.keys) {
      final value = get(key);
      final maskedValue = _shouldMaskValue(key) ? _maskValue(value) : value;
      Logger.debug('$key: $maskedValue');
    }
    Logger.debug('========================');
  }

  /// 값 마스킹이 필요한지 확인
  bool _shouldMaskValue(String key) {
    return key.contains('API_KEY') ||
        key.contains('SECRET') ||
        key.contains('TOKEN');
  }

  /// 값 마스킹
  String _maskValue(String value) {
    if (value.length <= 8) return '*' * value.length;
    return '${value.substring(0, 4)}${'*' * (value.length - 8)}${value.substring(value.length - 4)}';
  }
}

/// 전역 편의 함수들
class Env {
  static String get(String key, {String? defaultValue}) =>
      EnvironmentService.instance.get(key, defaultValue: defaultValue);

  static bool getBool(String key, {bool defaultValue = false}) =>
      EnvironmentService.instance.getBool(key, defaultValue: defaultValue);

  static int getInt(String key, {int defaultValue = 0}) =>
      EnvironmentService.instance.getInt(key, defaultValue: defaultValue);

  // 자주 사용되는 키들에 대한 편의 메서드
  static String get geminiApiKey => get('GEMINI_API_KEY');
  static String get geminiModelName =>
      get('GEMINI_MODEL_NAME', defaultValue: 'gemini-2.0-flash-lite');
  static String get cloudProjectNumber => get('CLOUD_PROJECT_NUMBER');
  static String get kakaoApiKey => get('KAKAO_API_KEY');
  static bool get debugMode => getBool('DEBUG_MODE');
  static int get apiTimeout => getInt('API_TIMEOUT', defaultValue: 30000);
  static bool get featureAiChat =>
      getBool('FEATURE_AI_CHAT', defaultValue: true);
  static bool get featureTranslation =>
      getBool('FEATURE_TRANSLATION', defaultValue: true);
}
