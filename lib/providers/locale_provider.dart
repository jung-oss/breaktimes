import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/event_bus.dart';
import '../services/topic_service.dart';
import '../utils/logger.dart';

class LocaleProvider with ChangeNotifier {
  static const String LOCALE_KEY = 'app_locale';
  static const String TOPIC_KEY = 'today_topic';
  static const String TOPIC_ID_KEY = 'today_topic_id';
  static const String TOPIC_LOCALE_KEY = 'topic_locale';
  static const String TOPIC_DATE_KEY = 'today_topic_used_date';

  late Locale _locale;
  bool _isLoaded = false;

  // ✅ 주제 관리 상태 추가
  String? _dailyTopic;
  String? _topicId;
  bool _isTopicLoading = false;
  DateTime? _topicLoadedDate;

  final TopicService _topicService = TopicService();

  LocaleProvider() {
    _locale = const Locale('ko');
    _initializeLocaleAndTopic();
  }

  // Getters
  Locale get locale => _locale;
  bool get isLoaded => _isLoaded;

  // ✅ 주제 관련 Getters
  String? get dailyTopic => _dailyTopic;
  String? get topicId => _topicId;
  bool get isTopicLoading => _isTopicLoading;
  bool get isTopicLoaded => _dailyTopic != null && _topicId != null;

  // 편의 메서드들
  String get currentLanguageCode => _locale.languageCode;
  bool get isKorean => _locale.languageCode == 'ko';

  /// ✅ 초기화 - 언어와 주제를 함께 로드
  Future<void> _initializeLocaleAndTopic() async {
    try {
      Logger.info('LocaleProvider: 초기화 시작');

      // 1. 저장된 언어 설정 로드
      await _loadSavedLocale();

      // 2. 해당 언어로 오늘의 주제 로드
      await _loadDailyTopic();

      _isLoaded = true;

      Logger.info(
          'LocaleProvider: 초기화 완료 - 언어: ${_locale.languageCode}, 주제: $_dailyTopic');

      // 초기 로드 완료 이벤트 발생
      eventBus.fire('locale_topic_initialized', {
        'locale': _locale.languageCode,
        'topic': _dailyTopic,
        'topicId': _topicId,
        'isInitialLoad': true,
      });

      notifyListeners();
    } catch (e) {
      Logger.error('LocaleProvider 초기화 오류: $e');
      _isLoaded = true;

      // 오류 발생 시에도 기본값으로 초기화 완료 이벤트 발생
      eventBus.fire('locale_topic_initialized', {
        'locale': _locale.languageCode,
        'topic': _dailyTopic ?? _getDefaultTopic(),
        'topicId': _topicId ?? 'default_topic',
        'isInitialLoad': true,
      });

      notifyListeners();
    }
  }

  /// ✅ 언어 변경 - 주제 번역으로 처리 (주제 ID 유지)
  Future<void> setLocale(Locale locale) async {
    if (_locale != locale) {
      final previousLocale = _locale.languageCode;
      _locale = locale;

      try {
        Logger.info(
            'LocaleProvider: 언어 변경 시작 - $previousLocale -> ${locale.languageCode}');

        // 1. SharedPreferences에 언어 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(LOCALE_KEY, locale.languageCode);

        // 2. 현재 주제가 있고 오늘 날짜라면 번역만 수행
        final today = _getTodayString();
        final savedDate = prefs.getString(TOPIC_DATE_KEY);

        if (_topicId != null && savedDate == today) {
          // 동일한 주제 ID로 언어만 변경 (주제 번역)
          Logger.info('LocaleProvider: 기존 주제 번역 - ID: $_topicId');
          await _translateCurrentTopic(locale.languageCode);
        } else {
          // 날짜가 다르거나 주제가 없으면 새로 로드
          Logger.info('LocaleProvider: 새로운 주제 로드 필요');
          await _loadDailyTopic(forceReload: true);
        }

        Logger.info(
            'LocaleProvider: 언어 변경 완료 - ${locale.languageCode}, 주제: $_dailyTopic (ID: $_topicId)');

        // 3. 언어 변경 이벤트 발생
        eventBus.fire('locale_changed', {
          'previousLocale': previousLocale,
          'newLocale': locale.languageCode,
          'topic': _dailyTopic,
          'topicId': _topicId,
          'isInitialLoad': false,
        });

        // UI 업데이트
        notifyListeners();
      } catch (e) {
        Logger.error('LocaleProvider: 언어 설정 실패 - $e');

        // 실패 시 이전 상태로 복원
        _locale = Locale(previousLocale);
        notifyListeners();
        rethrow;
      }
    }
  }

  /// ✅ 저장된 언어 설정 로드
  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(LOCALE_KEY) ?? 'ko';
      _locale = Locale(savedLocale);

      Logger.debug('LocaleProvider: 저장된 언어 로드 - $savedLocale');
    } catch (e) {
      Logger.error('LocaleProvider: 언어 로드 오류 - $e');
      _locale = const Locale('ko'); // 기본값
    }
  }

  /// ✅ 현재 주제를 다른 언어로 번역
  Future<void> _translateCurrentTopic(String targetLanguage) async {
    if (_topicId == null) {
      Logger.warn('LocaleProvider: 번역할 주제 ID가 없음');
      return;
    }

    try {
      _isTopicLoading = true;
      notifyListeners();

      Logger.debug(
          'LocaleProvider: 주제 번역 시작 - ID: $_topicId, 언어: $targetLanguage');

      // TopicService의 translateTopic 메서드 사용
      final result =
          await _topicService.translateTopic(_topicId!, targetLanguage);

      if (result.containsKey('content') && result['content'] != null) {
        _dailyTopic = result['content'];
        // _topicId는 동일하게 유지
        _topicLoadedDate = DateTime.now();

        // SharedPreferences에 업데이트된 내용 저장
        final today = _getTodayString();
        await _saveTopic(today, targetLanguage);

        Logger.info('LocaleProvider: 주제 번역 완료 - $_dailyTopic (ID: $_topicId)');
      } else {
        throw Exception('주제 번역 결과가 비어있음');
      }
    } catch (e) {
      Logger.error('LocaleProvider: 주제 번역 오류 - $e');

      // 실패 시 기본 주제 사용
      _dailyTopic = _getDefaultTopic();
      Logger.info('LocaleProvider: 번역 실패로 기본 주제 사용 - $_dailyTopic');
    } finally {
      _isTopicLoading = false;
      notifyListeners();
    }
  }

  /// ✅ 오늘의 주제 로드
  Future<void> _loadDailyTopic({bool forceReload = false}) async {
    try {
      _isTopicLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final currentLocale = _locale.languageCode;

      // 캐시된 주제 확인
      if (!forceReload && await _shouldUseCachedTopic(today, currentLocale)) {
        Logger.debug('LocaleProvider: 캐시된 주제 사용 - $_dailyTopic');
        _isTopicLoading = false;
        notifyListeners();
        return;
      }

      Logger.debug('LocaleProvider: 새로운 주제 로드 시작 - 언어: $currentLocale');

      // TopicService로 주제 로드
      final result = await _topicService.loadDailyTopic(currentLocale);

      if (result.containsKey('content') && result['content'] != null) {
        _dailyTopic = result['content'];
        _topicId = result['topicId'];
        _topicLoadedDate = DateTime.now();

        // SharedPreferences에 저장
        await _saveTopic(today, currentLocale);

        Logger.info('LocaleProvider: 주제 로드 완료 - $_dailyTopic (ID: $_topicId)');
      } else {
        throw Exception('주제 로드 결과가 비어있음');
      }
    } catch (e) {
      Logger.error('LocaleProvider: 주제 로드 오류 - $e');

      // 실패 시 기본 주제 사용
      _dailyTopic = _getDefaultTopic();
      _topicId = 'default_topic';
      _topicLoadedDate = DateTime.now();
    } finally {
      _isTopicLoading = false;
      notifyListeners();
    }
  }

  /// ✅ 캐시된 주제 사용 여부 확인
  Future<bool> _shouldUseCachedTopic(String today, String currentLocale) async {
    if (_dailyTopic == null || _topicId == null) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(TOPIC_DATE_KEY);
      final savedLocale = prefs.getString(TOPIC_LOCALE_KEY);

      return savedDate == today && savedLocale == currentLocale;
    } catch (e) {
      return false;
    }
  }

  /// ✅ 주제 저장
  Future<void> _saveTopic(String today, String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(TOPIC_KEY, _dailyTopic!);
      await prefs.setString(TOPIC_ID_KEY, _topicId!);
      await prefs.setString(TOPIC_LOCALE_KEY, locale);
      await prefs.setString(TOPIC_DATE_KEY, today);

      Logger.debug('LocaleProvider: 주제 저장 완료');
    } catch (e) {
      Logger.error('LocaleProvider: 주제 저장 오류 - $e');
    }
  }

  /// ✅ 기본 주제 반환
  String _getDefaultTopic() {
    return _locale.languageCode.startsWith('ko')
        ? '오늘 하루 어떤 일이 있었나요?'
        : 'What happened today?';
  }

  /// ✅ 오늘 날짜 문자열
  String _getTodayString() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .toIso8601String()
        .split('T')[0];
  }

  /// ✅ 주제 강제 새로고침
  Future<void> refreshTopic() async {
    Logger.info('LocaleProvider: 주제 강제 새로고침');
    await _loadDailyTopic(forceReload: true);
  }

  /// ✅ 캐시 클리어
  Future<void> clearTopicCache() async {
    try {
      _topicService.clearCache();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(TOPIC_KEY);
      await prefs.remove(TOPIC_ID_KEY);
      await prefs.remove(TOPIC_LOCALE_KEY);
      await prefs.remove(TOPIC_DATE_KEY);

      _dailyTopic = null;
      _topicId = null;
      _topicLoadedDate = null;

      Logger.info('LocaleProvider: 주제 캐시 클리어 완료');
    } catch (e) {
      Logger.error('LocaleProvider: 캐시 클리어 오류 - $e');
    }
  }

  // 기존 호환성 메서드들
  Future<void> loadSavedLocale() async {
    await _loadSavedLocale();
  }

  Future<void> setLocaleByLanguageCode(String languageCode) async {
    await setLocale(Locale(languageCode));
  }

  Future<void> toggleLocale() async {
    final newLanguageCode = _locale.languageCode == 'ko' ? 'en' : 'ko';
    await setLocaleByLanguageCode(newLanguageCode);
  }

  @override
  void dispose() {
    // TopicService 정리는 필요 없음 (싱글톤)
    super.dispose();
  }
}
