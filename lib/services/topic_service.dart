// topic_service.dart - 오류 수정된 성능 최적화 버전
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/firestore_paths.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 🚀 성능 최적화된 주제 관리 서비스
///
/// 주요 개선사항:
/// 1. 청크 단위 비동기 처리로 메인 스레드 블로킹 방지
/// 2. 주제 풀 크기 축소 (200개 → 50개) - 메모리 75% 절약
/// 3. 백그라운드 업데이트 주기 최적화 (60분 → 30분)
/// 4. 프레임 스킵 모니터링 및 성능 통계
/// 5. 안전한 초기화 및 타임아웃 적용
class TopicService {
  static final TopicService _instance = TopicService._internal();
  factory TopicService() => _instance;

  TopicService._internal() {
    _initializeServiceSafely();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // 🔧 최적화된 설정 상수 (소문자 camelCase로 수정)
  // ============================================================================

  // 메모리 최적화
  // 등록된 질문을 모두 쓰도록 넉넉히 둡니다 (이전 50개 제한 해제, 안전 상한 1000개)
  static const int topicPoolSize = 1000;
  static const int weeklyPreloadDays = 5; // 7 → 5 (메모리 절약)
  static const int maxRetryCount = 2; // 3 → 2 (빠른 포기)

  // 성능 최적화
  static const int cacheExpiryHours = 12; // 24 → 12 (더 자주 정리)
  static const int backgroundUpdateMinutes = 30; // 60 → 30 (더 자주 업데이트)
  static const int chunkSize = 10; // 청크 단위 처리 크기
  static const int maxLoadTimes = 50; // 100 → 50 (메모리 절약)

  // 순환 설정
  static const int rotationResetDays = 90;

  // ============================================================================
  // SharedPreferences 키 상수 (소문자 camelCase로 수정)
  // ============================================================================

  // 기존 호환성 키들
  static const String keyTopicKo = 'today_topic_ko';
  static const String keyTopicEn = 'today_topic_en';
  static const String keyTopic = 'today_topic';
  static const String keyTopicId = 'today_topic_id';
  static const String keyTopicUsed = 'topic_used_date';
  static const String keyTopicLocale = 'topic_locale';
  static const String keyTopicLastLoaded = 'topic_last_loaded';

  // 최적화 캐시 키들
  static const String keyTopicPool = 'topic_pool_v4_optimized';
  static const String keyTopicPoolUpdated = 'topic_pool_updated_v4';
  static const String keyWeeklyTopics = 'weekly_topics_v4_optimized';

  // 중복 방지 시스템 키들
  static const String keyUsedTopicsBitmap = 'used_topics_bitmap_v4';
  static const String keyTopicsFingerprint = 'topics_fingerprint_v4';
  static const String keyRotationResetDate = 'rotation_reset_date_v4';

  // 오늘 질문 캐시가 어느 계정의 것인지
  static const String keyTopicCacheUid = 'topic_cache_uid_v1';

  // ============================================================================
  // 메모리 캐시 변수들
  // ============================================================================

  // L1 캐시 (메모리)
  String? _cachedTopicId;
  String? _cachedTopicKo;
  String? _cachedTopicEn;
  DateTime? _topicCacheTime;
  String? _lastCachedLanguage;

  // 주제 풀 캐시 (축소됨)
  List<Map<String, dynamic>>? _topicPool;
  DateTime? _topicPoolCacheTime;

  // 주간 캐시 (축소됨)
  Map<String, Map<String, String>>? _weeklyTopicsCache;

  // 중복 방지 시스템
  Set<String>? _usedTopicIds;
  String? _currentTopicsFingerprint;
  DateTime? _lastRotationReset;

  // 상태 관리
  bool _loadingTopic = false;
  bool _preloadingPool = false;
  Completer<Map<String, String>>? _loadingCompleter;

  // 백그라운드 작업
  Timer? _backgroundUpdateTimer;
  int _retryCount = 0;

  // 🔧 성능 모니터링 (개선됨)
  int _cacheHits = 0;
  int _cacheMisses = 0;
  List<int> _loadTimes = [];
  int _frameSkipCount = 0;
  int _totalRequests = 0;

  // ============================================================================
  // 🚀 메인 API - 성능 최적화된 주제 로드
  // ============================================================================

  /// 최적화된 오늘의 주제 로드 (메인 스레드 블로킹 최소화)
  Future<Map<String, String>> loadDailyTopic(String? locale) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      final String language =
          locale?.split('_')[0] ?? 'ko'; // language 변수 정의 수정
      final today = _getTodayString();

      // 다른 계정으로 바뀌었으면 앞 사람의 오늘 질문 캐시를 비웁니다
      await _resetCachesIfUserChanged();

      // 🔧 즉시 메인 스레드 양보 (프레임 스킵 방지)
      await Future.delayed(Duration.zero);

      // L1: 메모리 캐시 체크 (1-2ms)
      if (_isMemoryCacheValid(today, language)) {
        final content = language == 'ko' ? _cachedTopicKo : _cachedTopicEn;
        if (content != null && content.isNotEmpty) {
          _recordPerformance(stopwatch.elapsedMilliseconds, true);
          return {'content': content, 'topicId': _cachedTopicId!};
        }
      }

      // 중복 로딩 방지
      if (_loadingTopic) {
        if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
          return await _loadingCompleter!.future;
        }
      }

      _loadingTopic = true;
      _loadingCompleter = Completer<Map<String, String>>();

      try {
        final result = await _loadTopicOptimized(today, language);
        _loadingCompleter!.complete(result);
        _recordPerformance(stopwatch.elapsedMilliseconds, false);
        return result;
      } catch (e) {
        _loadingCompleter!.completeError(e);
        rethrow;
      } finally {
        _loadingTopic = false;
      }
    } catch (e) {
      Logger.error('TopicService: 주제 로드 오류 - $e');
      _recordPerformance(stopwatch.elapsedMilliseconds, false);
      return _getDefaultTopic(locale?.split('_')[0] ?? 'ko');
    }
  }

  /// 🔧 최적화된 주제 로딩 로직
  Future<Map<String, String>> _loadTopicOptimized(
      String today, String language) async {
    // L2: 주간 캐시 체크 (5-10ms)
    final weeklyResult = await _getFromWeeklyCache(today, language);
    if (weeklyResult != null) {
      await _updateMemoryCache(
          weeklyResult['topicId']!, weeklyResult['content']!, language);
      return weeklyResult;
    }

    // L3: 로컬 캐시 체크 (10-20ms)
    final localResult = await _getFromLocalCache(today, language);
    if (localResult != null) {
      await _updateMemoryCache(
          localResult['topicId']!, localResult['content']!, language);
      await _updateWeeklyCache(today, localResult, language);
      return localResult;
    }

    // L4: 서버에서 로드 (최적화 적용)
    await _ensureUsedTopicsLoaded();
    await _ensureTopicPoolOptimized();

    final result = await _selectTopicAsync(today, language);

    // 모든 캐시 업데이트
    await _updateAllCachesAsync(today, result, language);

    return result;
  }

  /// 🔧 비동기 주제 선택 (청크 단위 처리로 메인 스레드 보호)
  Future<Map<String, String>> _selectTopicAsync(
      String today, String language) async {
    if (_topicPool == null || _topicPool!.isEmpty) {
      throw Exception('주제 풀이 비어있음');
    }

    // 🔧 오늘 날짜의 주제가 이미 선택되었는지 확인 (중복 방지 강화)
    final todayTopicId = await _getTodayTopicId(today);
    if (todayTopicId != null) {
      // 오늘 이미 선택된 주제가 있으면 해당 주제 반환
      final existingTopic = _topicPool!.firstWhere(
        (t) => t['id'] == todayTopicId,
        orElse: () => <String, dynamic>{},
      );

      if (existingTopic.isNotEmpty) {
        final content = _getLocalizedContent(existingTopic, language);
        Logger.info(
            'TopicService: 오늘 이미 선택된 주제 재사용 - $content (ID: $todayTopicId)');
        return {
          'content': content,
          'topicId': todayTopicId,
        };
      }
    }

    // 로그인한 사용자: 사용자별로 겹치지 않는 무작위 질문 (기록은 파이어스토어)
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final userTopic = await _selectTopicForUser(uid, today);
      if (userTopic != null) {
        final topicId = userTopic['id'] as String;
        final content = _getLocalizedContent(userTopic, language);
        Logger.info('TopicService: 사용자별 질문 선택 - $content (ID: $topicId)');
        _recordTopicUsageSync(today, topicId);
        return {'content': content, 'topicId': topicId};
      }
    }

    // 아래는 로그인 전이거나 서버에 닿지 못할 때 쓰는 기기 기록 방식입니다
    final userSalt = _stableHash(uid ?? '');

    // 사용 이력이 로드되었는지 확인 (null 체크 강화)
    await _ensureUsedTopicsLoaded();
    if (_usedTopicIds == null) {
      _usedTopicIds = <String>{};
      Logger.warn('TopicService: 사용 이력이 null이어서 초기화됨');
    }

    // 청크 단위로 사용 가능한 주제 필터링
    final availableTopics = await _getAvailableTopicsAsync();

    Map<String, dynamic> selectedTopic;
    String selectionReason;

    if (availableTopics.isNotEmpty) {
      final dateHash = _generateDateHash(today) ^ userSalt;
      final index = dateHash % availableTopics.length;
      selectedTopic = availableTopics[index];
      selectionReason =
          '새로운 주제 (${availableTopics.length}/${_topicPool!.length} 가능)';
    } else {
      Logger.info('TopicService: 모든 주제 사용됨, 스마트 순환 재시작');
      await _handleFullRotationCompleted(today);

      final dateHash = _generateDateHash(today) ^ userSalt;
      final index = dateHash % _topicPool!.length;
      selectedTopic = _topicPool![index];
      selectionReason = '순환 완료 후 재선택';
    }

    final topicId = selectedTopic['id'] as String;
    final content = _getLocalizedContent(selectedTopic, language);

    Logger.info('TopicService: $selectionReason - $content (ID: $topicId)');

    // 🔧 사용 기록을 즉시 동기적으로 추가 (중복 방지)
    _recordTopicUsageSync(today, topicId);

    return {
      'content': content,
      'topicId': topicId,
    };
  }

  /// 🔧 청크 단위 비동기 필터링 (메인 스레드 블로킹 방지)
  Future<List<Map<String, dynamic>>> _getAvailableTopicsAsync() async {
    if (_topicPool == null || _topicPool!.isEmpty) return [];

    // 🔧 null 체크 강화
    if (_usedTopicIds == null) {
      await _ensureUsedTopicsLoaded();
      if (_usedTopicIds == null) {
        _usedTopicIds = <String>{};
        Logger.warn('TopicService: 사용 이력이 null이어서 초기화됨 (필터링 중)');
      }
    }

    final List<Map<String, dynamic>> available = [];

    for (int i = 0; i < _topicPool!.length; i += chunkSize) {
      final end = math.min(i + chunkSize, _topicPool!.length);
      final chunk = _topicPool!.sublist(i, end);

      // 각 청크 처리 후 메인 스레드 양보
      await Future.delayed(Duration.zero);

      final filteredChunk = chunk
          .where((topic) => !_usedTopicIds!.contains(topic['id']))
          .toList();

      available.addAll(filteredChunk);
    }

    return available;
  }

  // ============================================================================
  // 🔧 최적화된 서비스 초기화
  // ============================================================================

  /// 안전한 서비스 초기화 (타임아웃 적용)
  Future<void> _initializeServiceSafely() async {
    try {
      Logger.debug('TopicService: 최적화된 서비스 초기화 시작');

      // 병렬 초기화 (타임아웃 적용)
      final initFutures = <Future>[
        _safeLoadMemoryCache(),
        _safeLoadUsedTopicsHistory(),
      ];

      await Future.wait(initFutures).timeout(
        Duration(seconds: 3),
        onTimeout: () {
          Logger.info('TopicService: 초기화 타임아웃'); // warning → info로 수정
          return [];
        },
      );

      // 백그라운드 작업 시작 (지연)
      _startBackgroundWorkOptimized();

      Logger.debug('TopicService: 최적화된 서비스 초기화 완료');
    } catch (e) {
      Logger.error('TopicService: 서비스 초기화 오류 - $e');
    }
  }

  /// 안전한 메모리 캐시 로드
  Future<void> _safeLoadMemoryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final savedDate = prefs.getString(keyTopicUsed);

      if (savedDate == today) {
        _cachedTopicId = prefs.getString(keyTopicId);
        _cachedTopicKo = prefs.getString(keyTopicKo);
        _cachedTopicEn = prefs.getString(keyTopicEn);
        _topicCacheTime = DateTime.now();
        Logger.debug('TopicService: 메모리 캐시 로드됨');
      }

      await _loadWeeklyTopicsCache();
    } catch (e) {
      Logger.info('TopicService: 메모리 캐시 로드 실패 - $e'); // warning → info로 수정
    }
  }

  /// 안전한 사용 주제 이력 로드
  Future<void> _safeLoadUsedTopicsHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bitmapJson = prefs.getString(keyUsedTopicsBitmap);
      if (bitmapJson != null) {
        final List<dynamic> usedIds = json.decode(bitmapJson);
        _usedTopicIds = Set<String>.from(usedIds);
      } else {
        _usedTopicIds = <String>{};
      }

      final resetDateStr = prefs.getString(keyRotationResetDate);
      if (resetDateStr != null) {
        _lastRotationReset = DateTime.parse(resetDateStr);
      }

      _currentTopicsFingerprint = prefs.getString(keyTopicsFingerprint);

      Logger.debug('TopicService: 사용된 주제 이력 로드됨 - ${_usedTopicIds!.length}개');
    } catch (e) {
      Logger.info('TopicService: 사용 이력 로드 실패 - $e'); // warning → info로 수정
      _usedTopicIds = <String>{};
    }
  }

  /// 최적화된 백그라운드 작업 시작
  void _startBackgroundWorkOptimized() {
    // 앱 시작 후 2초 지연으로 시작 영향 최소화
    Future.delayed(Duration(seconds: 2), () {
      if (!_preloadingPool) {
        _preloadTopicPoolOptimized();
      }
    });

    // 30분마다 백그라운드 업데이트
    _backgroundUpdateTimer = Timer.periodic(
      Duration(minutes: backgroundUpdateMinutes),
      (timer) => _performBackgroundMaintenanceOptimized(),
    );
  }

  // ============================================================================
  // 캐시 시스템 최적화
  // ============================================================================

  /// 주간 주제 캐시 로드
  Future<void> _loadWeeklyTopicsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weeklyTopicsJson = prefs.getString(keyWeeklyTopics);

      if (weeklyTopicsJson != null) {
        final Map<String, dynamic> decoded = json.decode(weeklyTopicsJson);
        _weeklyTopicsCache = decoded.map(
            (key, value) => MapEntry(key, Map<String, String>.from(value)));

        // 크기 제한 체크
        if (_weeklyTopicsCache!.length > weeklyPreloadDays) {
          _cleanupWeeklyCache();
        }

        Logger.debug(
            'TopicService: 주간 주제 캐시 로드됨 - ${_weeklyTopicsCache?.length}개');
      }
    } catch (e) {
      Logger.info('TopicService: 주간 주제 캐시 로드 실패 - $e'); // warning → info로 수정
      _weeklyTopicsCache = null;
    }
  }

  /// L2 캐시에서 가져오기 (주간 캐시)
  Future<Map<String, String>?> _getFromWeeklyCache(
      String today, String language) async {
    if (_weeklyTopicsCache == null) return null;

    final todayCache = _weeklyTopicsCache![today];
    if (todayCache != null && todayCache.containsKey(language)) {
      final content = todayCache[language];
      final topicId = todayCache['topicId'];

      if (content != null && topicId != null && content.isNotEmpty) {
        Logger.debug('TopicService: 주간 캐시 히트 - $language');
        return {'content': content, 'topicId': topicId};
      }
    }
    return null;
  }

  /// L3 캐시에서 가져오기 (로컬 캐시)
  Future<Map<String, String>?> _getFromLocalCache(
      String today, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(keyTopicUsed);

      if (savedDate == today) {
        final topicId = prefs.getString(keyTopicId);
        final content = language == 'ko'
            ? prefs.getString(keyTopicKo)
            : prefs.getString(keyTopicEn);

        if (topicId != null && content != null && content.isNotEmpty) {
          Logger.debug('TopicService: 로컬 캐시 히트 - $language');
          return {'content': content, 'topicId': topicId};
        }
      }
    } catch (e) {
      Logger.info('TopicService: 로컬 캐시 읽기 실패 - $e'); // warning → info로 수정
    }
    return null;
  }

  /// 메모리 캐시 업데이트
  Future<void> _updateMemoryCache(
      String topicId, String content, String language) async {
    _cachedTopicId = topicId;
    _topicCacheTime = DateTime.now();
    _lastCachedLanguage = language;

    if (language == 'ko') {
      _cachedTopicKo = content;
    } else {
      _cachedTopicEn = content;
    }

    Logger.debug('TopicService: 메모리 캐시 업데이트됨 - $language');
  }

  /// 주간 캐시 업데이트
  Future<void> _updateWeeklyCache(
      String today, Map<String, String> result, String language) async {
    try {
      _weeklyTopicsCache ??= {};

      // 기존 캐시가 있으면 가져오고, 없으면 새로 생성
      final existingCache = _weeklyTopicsCache![today] ?? {};

      // 현재 언어의 내용만 업데이트
      final updatedCache = Map<String, String>.from(existingCache);
      updatedCache['topicId'] = result['topicId']!;
      updatedCache[language] = result['content']!;

      _weeklyTopicsCache![today] = updatedCache;

      // 크기 제한
      if (_weeklyTopicsCache!.length > weeklyPreloadDays) {
        _cleanupWeeklyCache();
      }

      await _saveWeeklyTopicsCache();
    } catch (e) {
      Logger.info('TopicService: 주간 캐시 업데이트 실패 - $e'); // warning → info로 수정
    }
  }

  /// 모든 캐시 비동기 업데이트
  Future<void> _updateAllCachesAsync(
      String today, Map<String, String> result, String language) async {
    // 메모리 캐시 즉시 업데이트
    await _updateMemoryCache(result['topicId']!, result['content']!, language);

    // 나머지는 백그라운드에서 처리
    Future.microtask(() async {
      try {
        await _updateWeeklyCache(today, result, language);

        // 양쪽 언어로 저장하기 위해 번역 시도
        final topicId = result['topicId']!;
        final currentContent = result['content']!;

        // 현재 언어와 반대 언어의 내용을 가져오기 시도
        String koContent = currentContent;
        String enContent = currentContent;

        if (language == 'ko') {
          koContent = currentContent;
          // 영어 번역 시도
          if (_topicPool != null) {
            final topic = _topicPool!.firstWhere(
              (t) => t['id'] == topicId,
              orElse: () => <String, dynamic>{},
            );
            if (topic.isNotEmpty) {
              enContent = _getLocalizedContent(topic, 'en');
            }
          }
        } else {
          enContent = currentContent;
          // 한국어 번역 시도
          if (_topicPool != null) {
            final topic = _topicPool!.firstWhere(
              (t) => t['id'] == topicId,
              orElse: () => <String, dynamic>{},
            );
            if (topic.isNotEmpty) {
              koContent = _getLocalizedContent(topic, 'ko');
            }
          }
        }

        await _saveTodayTopic(topicId, koContent, enContent, today);
      } catch (e) {
        Logger.info(
            'TopicService: 백그라운드 캐시 업데이트 실패 - $e'); // warning → info로 수정
      }
    });
  }

  // ============================================================================
  // 주제 풀 관리 최적화
  // ============================================================================

  /// 최적화된 주제 풀 확보
  Future<void> _ensureTopicPoolOptimized() async {
    if (_topicPool != null &&
        _topicPool!.isNotEmpty &&
        _topicPoolCacheTime != null &&
        DateTime.now().difference(_topicPoolCacheTime!).inHours <
            cacheExpiryHours) {
      return; // 캐시가 유효함
    }

    await _loadTopicPoolFromServerOptimized();
  }

  /// 최적화된 서버에서 주제 풀 로드
  Future<void> _loadTopicPoolFromServerOptimized() async {
    if (_preloadingPool) return;

    _preloadingPool = true;

    try {
      Logger.debug('TopicService: 최적화된 주제 풀 로드 시작');

      // 타임아웃 적용하여 서버 요청
      final snapshot = await _firestore
          .collection('topics')
          .doc('topic')
          .collection('items')
          .where('isActive', isEqualTo: true)
          .limit(topicPoolSize) // 크기 제한
          .get()
          .timeout(Duration(seconds: 10));

      _topicPool = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _topicPoolCacheTime = DateTime.now();

      // 로컬에 저장 (비동기)
      _saveTopicPoolAsync();

      // 핑거프린트 업데이트
      _updateTopicsFingerprint();

      Logger.info('TopicService: 주제 풀 로드 완료 - ${_topicPool!.length}개');
    } catch (e) {
      Logger.error('TopicService: 주제 풀 로드 실패 - $e');
    } finally {
      _preloadingPool = false;
    }
  }

  /// 최적화된 주제 풀 프리로딩
  Future<void> _preloadTopicPoolOptimized() async {
    try {
      // 로컬 캐시 먼저 확인
      await _loadTopicPoolFromLocal();

      if (_topicPool == null || _topicPool!.isEmpty) {
        await _loadTopicPoolFromServerOptimized();
      }
    } catch (e) {
      Logger.info('TopicService: 프리로딩 실패 - $e'); // warning → info로 수정
    }
  }

  /// 로컬에서 주제 풀 로드
  Future<void> _loadTopicPoolFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final poolJson = prefs.getString(keyTopicPool);
      final updatedTime = prefs.getString(keyTopicPoolUpdated);

      if (poolJson != null) {
        final List<dynamic> decoded = json.decode(poolJson);
        _topicPool = decoded
            .map((topic) {
              final Map<String, dynamic> topicMap = Map.from(topic);

              // milliseconds를 다시 Timestamp로 복원 (필요한 경우)
              if (topicMap['createdAt'] is int) {
                topicMap['createdAt'] =
                    DateTime.fromMillisecondsSinceEpoch(topicMap['createdAt']);
              }
              if (topicMap['updatedAt'] is int) {
                topicMap['updatedAt'] =
                    DateTime.fromMillisecondsSinceEpoch(topicMap['updatedAt']);
              }

              return topicMap;
            })
            .cast<Map<String, dynamic>>()
            .toList();

        if (updatedTime != null) {
          _topicPoolCacheTime = DateTime.parse(updatedTime);
        }

        Logger.debug('TopicService: 로컬 캐시에서 주제 풀 로드됨 - ${_topicPool!.length}개');
      }
    } catch (e) {
      Logger.info('TopicService: 로컬 캐시 로드 실패 - $e');
    }
  }

  // ============================================================================
  // 백그라운드 작업 최적화
  // ============================================================================

  /// 최적화된 백그라운드 유지보수
  Future<void> _performBackgroundMaintenanceOptimized() async {
    try {
      // 메모리 사용량 체크 및 정리
      _checkMemoryUsageOptimized();

      // 성능 통계 정리
      _cleanupPerformanceStatsOptimized();

      // 필요시 주제 풀 업데이트 (낮은 우선순위)
      if (_shouldUpdateTopicPool()) {
        Future.microtask(() => _updateTopicPoolIfNeededOptimized());
      }
    } catch (e) {
      Logger.info('TopicService: 백그라운드 유지보수 실패 - $e'); // warning → info로 수정
    }
  }

  /// 주제 풀 업데이트 필요 여부 체크
  bool _shouldUpdateTopicPool() {
    if (_topicPoolCacheTime == null) return true;

    final cacheAge = DateTime.now().difference(_topicPoolCacheTime!);
    return cacheAge.inHours >= cacheExpiryHours;
  }

  /// 최적화된 메모리 사용량 체크
  void _checkMemoryUsageOptimized() {
    // 주제 풀 크기 제한
    if (_topicPool != null && _topicPool!.length > topicPoolSize) {
      _topicPool = _topicPool!.sublist(0, topicPoolSize);
      Logger.debug('TopicService: 주제 풀 크기 조정됨 ($topicPoolSize개)');
    }

    // 주간 캐시 크기 제한
    if (_weeklyTopicsCache != null &&
        _weeklyTopicsCache!.length > weeklyPreloadDays) {
      _cleanupWeeklyCache();
    }

    // 사용된 주제 이력 크기 제한
    if (_usedTopicIds != null && _usedTopicIds!.length > topicPoolSize * 2) {
      final usedList = _usedTopicIds!.toList();
      _usedTopicIds = Set.from(usedList.take(topicPoolSize));
      Logger.debug('TopicService: 사용 이력 크기 조정됨');
    }

    // 로드 시간 기록 크기 제한
    if (_loadTimes.length > maxLoadTimes) {
      _loadTimes = _loadTimes.sublist(_loadTimes.length - maxLoadTimes);
    }
  }

  /// 주간 캐시 정리
  void _cleanupWeeklyCache() {
    if (_weeklyTopicsCache == null) return;

    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: weeklyPreloadDays));

    _weeklyTopicsCache!.removeWhere((dateString, _) {
      try {
        final date = DateTime.parse(dateString);
        return date.isBefore(cutoffDate);
      } catch (e) {
        return true; // 파싱 실패한 항목 제거
      }
    });

    Logger.debug(
        'TopicService: 주간 캐시 정리 완료 - ${_weeklyTopicsCache!.length}개 남음');
  }

  // ============================================================================
  // 성능 모니터링 개선
  // ============================================================================

  /// 성능 기록 (프레임 스킵 감지 포함)
  void _recordPerformance(int loadTimeMs, bool cacheHit) {
    // 프레임 스킵 감지 (16ms 초과 시)
    if (loadTimeMs > 16) {
      _frameSkipCount++;
      if (loadTimeMs > 100) {
        Logger.info(
            'TopicService: 심각한 프레임 스킵 위험 - ${loadTimeMs}ms'); // warning → info로 수정
      }
    }

    if (cacheHit) {
      _cacheHits++;
    } else {
      _cacheMisses++;
    }

    _loadTimes.add(loadTimeMs);

    // 크기 제한
    if (_loadTimes.length > maxLoadTimes) {
      _loadTimes.removeAt(0);
    }
  }

  /// 최적화된 성능 통계 정리
  void _cleanupPerformanceStatsOptimized() {
    final now = DateTime.now();

    // 12시간마다 통계 리셋
    if (now.hour % 12 == 0 && now.minute < 5) {
      _cacheHits = 0;
      _cacheMisses = 0;
      _loadTimes.clear();
      _frameSkipCount = 0;
      _totalRequests = 0;
      Logger.debug('TopicService: 성능 통계 리셋됨');
    }
  }

  /// 개선된 성능 통계
  Map<String, dynamic> getPerformanceStats() {
    final totalTopics = _topicPool?.length ?? 0;
    final usedTopics = _usedTopicIds?.length ?? 0;
    final availableTopics = totalTopics - usedTopics;

    double avgLoadTime = 0;
    if (_loadTimes.isNotEmpty) {
      avgLoadTime = _loadTimes.reduce((a, b) => a + b) / _loadTimes.length;
    }

    double cacheHitRate = 0;
    if (_totalRequests > 0) {
      cacheHitRate = _cacheHits / _totalRequests;
    }

    return {
      'totalTopics': totalTopics,
      'usedTopics': usedTopics,
      'availableTopics': availableTopics,
      'usageRate':
          totalTopics > 0 ? ((usedTopics / totalTopics) * 100).round() : 0,
      'cacheHitRate': (cacheHitRate * 100).round(),
      'averageLoadTime': '${avgLoadTime.round()}ms',
      'frameSkipCount': _frameSkipCount,
      'totalRequests': _totalRequests,
      'memoryUsageKB': ((totalTopics * 24) / 1024).round(),
      'optimizationLevel': 'high',
      'poolSize': topicPoolSize,
      'chunkSize': chunkSize,
    };
  }

  // ============================================================================
  // 유틸리티 메서드들
  // ============================================================================

  /// 메모리 캐시 유효성 체크
  bool _isMemoryCacheValid(String today, String language) {
    if (_cachedTopicId == null || _topicCacheTime == null) return false;

    final now = DateTime.now();
    final cacheAge = now.difference(_topicCacheTime!);

    return cacheAge.inHours < 1 && _lastCachedLanguage == language;
  }

  /// 사용된 주제 이력 확보
  Future<void> _ensureUsedTopicsLoaded() async {
    if (_usedTopicIds != null) return;
    await _safeLoadUsedTopicsHistory();
  }

  /// 모든 주제 사용 완료 시 처리
  Future<void> _handleFullRotationCompleted(String today) async {
    final now = DateTime.now();

    // 시간 기반 초기화 (3개월마다)
    if (_lastRotationReset == null ||
        now.difference(_lastRotationReset!).inDays > rotationResetDays) {
      _usedTopicIds!.clear();
      _lastRotationReset = now;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyRotationResetDate, now.toIso8601String());
      await prefs.remove(keyUsedTopicsBitmap);

      Logger.info('TopicService: 3개월 주기 이력 완전 초기화');
      return;
    }

    // 부분 초기화 (50% 제거)
    if (_usedTopicIds!.length > _topicPool!.length * 0.8) {
      final removeCount = (_usedTopicIds!.length * 0.5).round();
      final usedList = _usedTopicIds!.toList()
        ..shuffle(math.Random(_generateDateHash(today)));

      for (int i = 0; i < removeCount && i < usedList.length; i++) {
        _usedTopicIds!.remove(usedList[i]);
      }

      Logger.info('TopicService: 사용 이력 50% 정리됨 (${_usedTopicIds!.length}개 남음)');
    }
  }

  /// 주제 사용 기록 (동기적 추가 + 비동기 저장)
  void _recordTopicUsageSync(String date, String topicId) {
    // 🔧 즉시 메모리에 추가 (동기적) - 중복 방지
    if (_usedTopicIds == null) {
      _usedTopicIds = <String>{};
    }
    _usedTopicIds!.add(topicId);

    // 비동기로 SharedPreferences에 저장
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final compactList = _usedTopicIds!.take(topicPoolSize * 2).toList();
        await prefs.setString(keyUsedTopicsBitmap, json.encode(compactList));
        Logger.debug('TopicService: 사용 이력 저장 완료 - $topicId');
      } catch (e) {
        Logger.info('TopicService: 사용 이력 저장 실패 - $e');
      }
    });
  }

  /// 주제 사용 기록 (비동기) - 하위 호환성 유지
  @Deprecated('Use _recordTopicUsageSync instead')
  void _recordTopicUsageAsync(String date, String topicId) {
    _recordTopicUsageSync(date, topicId);
  }

  /// 오늘 날짜의 주제 ID 가져오기
  Future<String?> _getTodayTopicId(String today) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(keyTopicUsed);

      if (savedDate == today) {
        final topicId = prefs.getString(keyTopicId);
        return topicId;
      }
    } catch (e) {
      Logger.info('TopicService: 오늘 주제 ID 조회 실패 - $e');
    }
    return null;
  }

  /// 오늘의 주제 로컬 저장
  Future<void> _saveTodayTopic(
      String topicId, String topicKo, String topicEn, String today) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(keyTopicId, topicId),
        prefs.setString(keyTopicKo, topicKo),
        prefs.setString(keyTopicEn, topicEn),
        prefs.setString(keyTopicUsed, today),
      ]);
    } catch (e) {
      Logger.info('TopicService: 로컬 저장 실패 - $e'); // warning → info로 수정
    }
  }

  /// 주간 캐시 저장
  Future<void> _saveWeeklyTopicsCache() async {
    try {
      if (_weeklyTopicsCache != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyWeeklyTopics, json.encode(_weeklyTopicsCache));
      }
    } catch (e) {
      Logger.info('TopicService: 주간 캐시 저장 실패 - $e'); // warning → info로 수정
    }
  }

  /// 주제 풀 비동기 저장
  void _saveTopicPoolAsync() {
    Future.microtask(() async {
      try {
        if (_topicPool != null) {
          // Timestamp 객체를 milliseconds로 변환하여 직렬화 가능하게 만듦
          final serializedPool = _topicPool!.map((topic) {
            final Map<String, dynamic> serialized = Map.from(topic);

            // Timestamp 필드들을 milliseconds로 변환
            if (serialized['createdAt'] is Timestamp) {
              serialized['createdAt'] =
                  (serialized['createdAt'] as Timestamp).millisecondsSinceEpoch;
            }
            if (serialized['updatedAt'] is Timestamp) {
              serialized['updatedAt'] =
                  (serialized['updatedAt'] as Timestamp).millisecondsSinceEpoch;
            }

            return serialized;
          }).toList();

          final prefs = await SharedPreferences.getInstance();
          await Future.wait([
            prefs.setString(keyTopicPool, json.encode(serializedPool)),
            prefs.setString(
                keyTopicPoolUpdated, DateTime.now().toIso8601String()),
          ]);

          Logger.debug('TopicService: 주제 풀 저장 성공 - ${serializedPool.length}개');
        }
      } catch (e) {
        Logger.info('TopicService: 주제 풀 저장 실패 - $e');
      }
    });
  }

  /// 주제 풀 업데이트 필요시 수행
  Future<void> _updateTopicPoolIfNeededOptimized() async {
    try {
      await _loadTopicPoolFromServerOptimized();
    } catch (e) {
      Logger.info(
          'TopicService: 주제 풀 백그라운드 업데이트 실패 - $e'); // warning → info로 수정

      if (_retryCount < maxRetryCount) {
        _retryCount++;
        Future.delayed(Duration(minutes: _retryCount * 5), () {
          _updateTopicPoolIfNeededOptimized();
        });
      }
    }
  }

  /// 주제 핑거프린트 업데이트
  void _updateTopicsFingerprint() {
    if (_topicPool != null) {
      _currentTopicsFingerprint = _calculateTopicsFingerprint(_topicPool!);

      Future.microtask(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              keyTopicsFingerprint, _currentTopicsFingerprint!);
        } catch (e) {
          Logger.info('TopicService: 핑거프린트 저장 실패 - $e'); // warning → info로 수정
        }
      });
    }
  }

  /// 핑거프린트 계산
  String _calculateTopicsFingerprint(List<Map<String, dynamic>> topics) {
    final buffer = StringBuffer();
    final sortedTopics = List<Map<String, dynamic>>.from(topics);
    sortedTopics
        .sort((a, b) => a['id'].toString().compareTo(b['id'].toString()));

    for (final topic in sortedTopics) {
      buffer.write(topic['id']);
      buffer.write(':');
      if (topic['createdAt'] != null) {
        if (topic['createdAt'] is int) {
          buffer.write(topic['createdAt']);
        } else if (topic['createdAt'] is Timestamp) {
          buffer
              .write((topic['createdAt'] as Timestamp).millisecondsSinceEpoch);
        }
      }
      buffer.write('|');
    }

    return buffer.toString().hashCode.toString();
  }

  // ============================================================================
  // 사용자별 질문 순환
  // ============================================================================

  /// 사용자마다 겹치지 않는 무작위 질문을 고릅니다.
  ///
  /// `users/{uid}.topicRotation`에 오늘 날짜·질문 ID·받은 질문 목록을 기록합니다.
  /// - 같은 날에는 어느 기기에서든 같은 질문을 돌려줍니다.
  /// - 모든 질문을 한 번씩 받기 전에는 반복하지 않습니다.
  /// - 한 바퀴를 다 돌면 새로 섞어 시작하되, 어제 질문은 바로 다시 내지 않습니다.
  /// 서버에 닿지 못하면 null을 돌려주고, 호출한 쪽이 기기 기록 방식으로 고릅니다.
  Future<Map<String, dynamic>?> _selectTopicForUser(
      String uid, String today) async {
    final pool = _topicPool;
    if (pool == null || pool.isEmpty) return null;

    Map<String, dynamic>? findTopic(Object? id) {
      if (id is! String) return null;
      for (final t in pool) {
        if (t['id'] == id) return t;
      }
      return null;
    }

    try {
      final userRef = _firestore.collection('users').doc(uid);

      final pickedId = await _firestore.runTransaction<String?>((tx) async {
        final snap = await tx.get(userRef);
        if (!snap.exists) return null;

        final raw = snap.data()?['topicRotation'];
        final rotation = raw is Map ? raw : const {};

        // 오늘 이미 고른 질문이 있으면 그대로 씁니다
        if (rotation['date'] == today && findTopic(rotation['topicId']) != null) {
          return rotation['topicId'] as String;
        }

        final poolIds = pool.map((t) => t['id'] as String).toList()..sort();
        final used = <String>{
          ...((rotation['usedIds'] as List?) ?? const []).whereType<String>(),
        }..retainWhere(poolIds.contains); // 지금은 없는 질문 기록은 정리
        var cycle = (rotation['cycle'] as num?)?.toInt() ?? 0;

        var available = poolIds.where((id) => !used.contains(id)).toList();
        if (available.isEmpty) {
          // 한 바퀴를 다 돌았으면 새로 시작합니다
          used.clear();
          cycle++;
          final lastId = rotation['topicId'];
          available = poolIds.where((id) => id != lastId).toList();
          if (available.isEmpty) available = poolIds;
        }

        // 사용자·날짜·바퀴 수로 정해지는 무작위 값이라 다시 불러도 결과가 같습니다
        final random = math.Random(_stableHash('$uid|$today|$cycle'));
        final id = available[random.nextInt(available.length)];
        used.add(id);

        tx.set(
          userRef,
          {
            'topicRotation': {
              'date': today,
              'topicId': id,
              'usedIds': used.toList(),
              'cycle': cycle,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          },
          SetOptions(merge: true),
        );
        return id;
      }).timeout(const Duration(seconds: 8));

      return findTopic(pickedId);
    } catch (e) {
      Logger.info('TopicService: 사용자별 질문 선택 실패, 기기 기록 방식 사용 - $e');
      return null;
    }
  }

  /// 기기에 남은 오늘 질문 캐시가 다른 계정의 것이면 비웁니다.
  Future<void> _resetCachesIfUserChanged() async {
    final uid = _auth.currentUser?.uid ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(keyTopicCacheUid) == uid) return;

      _cachedTopicId = null;
      _cachedTopicKo = null;
      _cachedTopicEn = null;
      _topicCacheTime = null;
      _weeklyTopicsCache = null;

      await Future.wait([
        prefs.remove(keyWeeklyTopics),
        prefs.remove(keyTopicUsed),
        prefs.setString(keyTopicCacheUid, uid),
      ]);
      Logger.debug('TopicService: 계정이 바뀌어 오늘 질문 캐시를 비웠습니다');
    } catch (e) {
      Logger.info('TopicService: 계정 확인 실패 - $e');
    }
  }

  /// 기기·실행마다 달라지지 않는 문자열 해시 (FNV-1a 32비트)
  int _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  /// 날짜 해시 생성
  int _generateDateHash(String dateString) {
    final cleanDate = dateString.replaceAll('-', '');
    final baseHash = int.parse(cleanDate);
    return (baseHash * 1103515245 + 12345) & 0x7fffffff;
  }

  /// 오늘 날짜 문자열
  String _getTodayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// 언어별 콘텐츠 추출
  String _getLocalizedContent(Map<String, dynamic> data, String language) {
    if (data.containsKey('translations')) {
      final translations = data['translations'] as Map<String, dynamic>;
      if (language == 'ko') {
        return translations['ko'] ?? data['content'] ?? '';
      } else {
        return translations['en'] ?? data['content'] ?? '';
      }
    } else {
      if (language == 'ko') {
        return data['topic_ko'] ?? data['content'] ?? '';
      } else {
        return data['topic_en'] ?? data['content'] ?? '';
      }
    }
  }

  /// 기본 주제 반환
  Map<String, String> _getDefaultTopic(String language) {
    final defaultTopics = {
      'ko': '오늘 하루 어떤 일이 있었나요?',
      'en': 'What happened today?',
    };

    return {
      'content': defaultTopics[language] ?? defaultTopics['ko']!,
      'topicId': 'default_topic',
    };
  }

  // ============================================================================
  // 기존 API 호환성 메서드들
  // ============================================================================

  /// 주제 번역 (기존 API 호환)
  Future<Map<String, String>> translateTopic(
      String topicId, String language) async {
    try {
      Logger.debug('TopicService: 주제 번역 시작 - ID: $topicId, 언어: $language');

      // 1. 메모리 캐시에서 해당 주제 찾기
      if (_topicPool != null) {
        final topic = _topicPool!.firstWhere(
          (t) => t['id'] == topicId,
          orElse: () => <String, dynamic>{},
        );

        if (topic.isNotEmpty) {
          final content = _getLocalizedContent(topic, language);
          Logger.debug('TopicService: 메모리 캐시에서 번역 완료 - $content');

          // 메모리 캐시도 해당 언어로 업데이트
          _updateMemoryCacheForTranslation(topicId, content, language);

          return {'content': content, 'topicId': topicId};
        }
      }

      // 2. Firestore에서 직접 조회
      Logger.debug('TopicService: Firestore에서 주제 조회 시작');
      final doc = await _firestore
          .collection('topics')
          .doc('topic')
          .collection('items')
          .doc(topicId)
          .get()
          .timeout(Duration(seconds: 5));

      if (doc.exists) {
        final data = doc.data()!;
        final content = _getLocalizedContent(data, language);

        Logger.debug('TopicService: Firestore에서 번역 완료 - $content');

        // 메모리 캐시 업데이트
        _updateMemoryCacheForTranslation(topicId, content, language);

        return {'content': content, 'topicId': topicId};
      }

      Logger.warn('TopicService: 주제 ID $topicId를 찾을 수 없어 기본 주제 반환');
      return _getDefaultTopic(language);
    } catch (e) {
      Logger.info('TopicService: 주제 번역 실패 - $e');
      return _getDefaultTopic(language);
    }
  }

  /// 번역을 위한 메모리 캐시 업데이트
  void _updateMemoryCacheForTranslation(
      String topicId, String content, String language) {
    _cachedTopicId = topicId;
    _topicCacheTime = DateTime.now();
    _lastCachedLanguage = language;

    if (language == 'ko') {
      _cachedTopicKo = content;
    } else {
      _cachedTopicEn = content;
    }

    Logger.debug('TopicService: 번역용 메모리 캐시 업데이트됨 - $language: $content');
  }

  /// 주제를 사용했음으로 표시 (호환성)
  Future<void> markTopicAsUsed(String topicId, String topic) async {
    // 호환성을 위해 유지
  }

  /// 캐시 클리어
  void clearCache() {
    _cachedTopicId = null;
    _cachedTopicKo = null;
    _cachedTopicEn = null;
    _topicCacheTime = null;
    _lastCachedLanguage = null;
    _topicPool = null;
    _topicPoolCacheTime = null;
    _weeklyTopicsCache = null;
    Logger.debug('TopicService: 모든 캐시 클리어됨');
  }

  /// 특정 주제가 이미 로드되었는지 확인
  bool isTopicLoaded(String? locale) {
    final today = _getTodayString();
    final language = locale?.split('_')[0] ?? 'ko';
    return _isMemoryCacheValid(today, language);
  }

  /// 현재 캐시된 주제 가져오기
  String? getCachedTopic() {
    return _cachedTopicKo ?? _cachedTopicEn;
  }

  /// 현재 캐시된 주제 ID 가져오기
  String? getCachedTopicId() {
    return _cachedTopicId;
  }

  /// 사용 이력 초기화 (개발/테스트용)
  void clearUsageHistory() {
    _usedTopicIds?.clear();
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyUsedTopicsBitmap);
      await prefs.remove(keyRotationResetDate);
    });
    Logger.info('TopicService: 사용 이력 수동 초기화됨');
  }

  /// 사용된 주제 ID 목록 조회
  List<String> getUsedTopicIds() {
    return _usedTopicIds?.toList() ?? [];
  }

  /// 특정 주제 사용 여부 확인
  bool isTopicUsed(String topicId) {
    return _usedTopicIds?.contains(topicId) ?? false;
  }

  /// 주제 강제 재선택 (테스트용)
  Future<Map<String, String>> forceSelectNewTopic(String? locale) async {
    clearCache();
    final today = _getTodayString();
    _weeklyTopicsCache?.remove(today);
    return await loadDailyTopic(locale);
  }

  /// 관리자용 주제 목록 가져오기
  Future<List<Map<String, dynamic>>> getTopics() async {
    try {
      final snapshot = await _firestore
          .collection('topics')
          .doc('topic')
          .collection('items')
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(Duration(seconds: 10));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        if (data.containsKey('translations')) {
          final translations = data['translations'] as Map<String, dynamic>;
          data['topic_ko'] = translations['ko'] ?? data['content'] ?? '';
          data['topic_en'] = translations['en'] ?? data['content'] ?? '';
        } else {
          data['topic_ko'] = data['content'] ?? '';
          data['topic_en'] = data['content'] ?? '';
        }

        return data;
      }).toList();
    } catch (e) {
      Logger.error('TopicService: 주제 목록 조회 오류 - $e');
      return [];
    }
  }

  /// 서비스 종료
  void dispose() {
    _backgroundUpdateTimer?.cancel();
    Logger.debug('TopicService: 서비스 종료됨');
  }
}
