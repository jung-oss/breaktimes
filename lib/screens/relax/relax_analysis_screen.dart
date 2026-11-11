import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mood_models.dart';
import '../../widgets/calendar_widget.dart';
import '../../core/localization/app_localizations.dart';
import '../../utils/date_formatter.dart';
import '../../providers/relax_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../utils/event_bus.dart';
import '../../utils/custom_navigator_observer.dart';
import '../../utils/logger.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'dart:math';

// ============================================================================
// 캐시 관리 클래스들 (성능 최적화용)
// ============================================================================

/// 메모리 캐시 관리 (L1 Cache)
class HistoryMemoryCache {
  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration CACHE_DURATION = Duration(minutes: 5);

  static bool isCacheValid(String userId) {
    if (!_cache.containsKey(userId)) return false;
    final cacheTime = _cacheTime[userId];
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < CACHE_DURATION;
  }

  static List<Map<String, dynamic>>? getCachedEntries(String userId) {
    if (isCacheValid(userId)) {
      Logger.debug('HistoryCache: 메모리 캐시 히트 - $userId');
      return List.from(_cache[userId]!);
    }
    return null;
  }

  static void setCachedEntries(
      String userId, List<Map<String, dynamic>> entries) {
    _cache[userId] = List.from(entries);
    _cacheTime[userId] = DateTime.now();
    Logger.debug('HistoryCache: 메모리 캐시 저장됨 - ${entries.length}개 엔트리');
  }

  static void clearCache(String? userId) {
    if (userId != null) {
      _cache.remove(userId);
      _cacheTime.remove(userId);
    } else {
      _cache.clear();
      _cacheTime.clear();
    }
    Logger.debug('HistoryCache: 메모리 캐시 클리어됨');
  }
}

/// 로컬 저장소 캐시 관리 (L2 Cache)
class HistoryLocalCache {
  static const String _cacheKey = 'user_entries_cache';
  static const String _cacheTimeKey = 'user_entries_cache_time';
  static const Duration CACHE_DURATION = Duration(hours: 2);

  static Future<List<Map<String, dynamic>>?> getLocalCache(
      String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString('${_cacheKey}_$userId');
      final cacheTimeStr = prefs.getString('${_cacheTimeKey}_$userId');

      if (cacheJson != null && cacheTimeStr != null) {
        final cacheTime = DateTime.parse(cacheTimeStr);
        if (DateTime.now().difference(cacheTime) < CACHE_DURATION) {
          final List<dynamic> decoded = json.decode(cacheJson);
          final entries = decoded.cast<Map<String, dynamic>>();
          Logger.debug('HistoryCache: 로컬 캐시 히트 - ${entries.length}개 엔트리');
          return entries;
        }
      }
    } catch (e) {
      Logger.error('HistoryCache: 로컬 캐시 읽기 오류 - $e');
    }
    return null;
  }

  static Future<void> saveLocalCache(
      String userId, List<Map<String, dynamic>> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serializedEntries = entries.map((entry) {
        final Map<String, dynamic> serialized = Map.from(entry);
        ['date', 'createdAt', 'updatedAt'].forEach((field) {
          if (serialized[field] is Timestamp) {
            serialized[field] =
                (serialized[field] as Timestamp).millisecondsSinceEpoch;
          }
        });
        return serialized;
      }).toList();

      final cacheJson = json.encode(serializedEntries);
      await prefs.setString('${_cacheKey}_$userId', cacheJson);
      await prefs.setString(
          '${_cacheTimeKey}_$userId', DateTime.now().toIso8601String());
      Logger.debug('HistoryCache: 로컬 캐시 저장됨 - ${entries.length}개 엔트리');
    } catch (e) {
      Logger.error('HistoryCache: 로컬 캐시 저장 오류 - $e');
    }
  }
}

class RelaxAnalysisScreen extends StatefulWidget {
  const RelaxAnalysisScreen({super.key});

  @override
  State<RelaxAnalysisScreen> createState() => _RelaxAnalysisScreenState();
}

class _RelaxAnalysisScreenState extends State<RelaxAnalysisScreen>
    with SingleTickerProviderStateMixin, RelaxScreenRouteAware {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // 추가

  // 기존 변수들...
  User? _user;
  List<MoodEntry> _moodEntries = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<DateTime, MoodEntry> _moodCalendarData = {};
  bool _isUserAuthenticated = false;

  // 🚀 실시간 스트림 구독 추가
  StreamSubscription<QuerySnapshot>? _userEntriesStreamSubscription;
  bool _streamInitialized = false;
  bool _isStreamActive = false;

  // 기존 이벤트 구독들...
  StreamSubscription? _entryAddedSubscription;
  StreamSubscription? _entryDeletedSubscription;
  StreamSubscription? _entryUpdatedSubscription;
  StreamSubscription? _dataRefreshNeededSubscription;

  // 애니메이션 및 성능 최적화
  late AnimationController _animationController;
  late Animation<double> _animation;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    // 애니메이션 설정 (기존과 동일)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // 최적화된 초기화
    _initializeScreen();
  }

  @override
  void dispose() {
    // 🚀 스트림 구독 해제 추가
    _cleanupStreams();
    _cleanupEventListeners();
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // 🚀 스트림 정리 메서드 추가
  void _cleanupStreams() {
    _userEntriesStreamSubscription?.cancel();
    _userEntriesStreamSubscription = null;
    _streamInitialized = false;
    _isStreamActive = false;
    Logger.debug('RelaxAnalysisScreen: 스트림 정리 완료');
  }

  // ============================================================================
  // 최적화된 초기화 (성능 개선)
  // ============================================================================

  void _initializeScreen() {
    // 1. 사용자 인증 확인
    _checkAuthentication();

    // 2. 이벤트 리스너 설정
    _setupEventListeners();

    // 3. 캐시된 데이터 즉시 로드
    _loadCachedData();

    // 🚀 4. 실시간 스트림 설정 (사용자가 인증된 경우)
    if (_isUserAuthenticated) {
      _setupRealtimeStream();
    }
  }

  // 🚀 실시간 스트림 설정 메서드 추가
  void _setupRealtimeStream() {
    if (!_isUserAuthenticated || _user == null || _streamInitialized) return;

    try {
      Logger.debug('RelaxAnalysisScreen: 실시간 스트림 설정 시작');

      // 사용자의 개인 컬렉션 모니터링 (분석 화면용)
      _userEntriesStreamSubscription = _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('moods')
          .orderBy('date', descending: true)
          .limit(100) // 분석을 위해 더 많은 데이터 로드
          .snapshots()
          .listen(
            _onStreamData,
            onError: _onStreamError,
            onDone: () => Logger.debug('RelaxAnalysisScreen: 스트림 종료'),
          );

      _streamInitialized = true;
      _isStreamActive = true;

      Logger.debug('RelaxAnalysisScreen: 실시간 스트림 활성화됨');
    } catch (e) {
      Logger.error('RelaxAnalysisScreen: 스트림 설정 오류 - $e');
      _streamInitialized = false;
      _isStreamActive = false;
    }
  }

  // 🚀 스트림 데이터 처리 메서드 추가
  void _onStreamData(QuerySnapshot snapshot) async {
    if (!mounted || !_isUserAuthenticated) return;

    try {
      Logger.debug('RelaxAnalysisScreen: 실시간 업데이트 - ${snapshot.docs.length}개');

      if (snapshot.docs.isEmpty) {
        // 빈 결과 처리
        if (_moodEntries.isNotEmpty) {
          if (mounted) {
            setState(() {
              _moodEntries = [];
              _moodCalendarData = {};
              _isLoading = false;
            });
          }
          Logger.debug('RelaxAnalysisScreen: 실시간 업데이트 - 빈 목록으로 변경');
        }
        return;
      }

      // 🚀 Firestore 문서를 MoodEntry로 변환
      final entries = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        entries.add(data);
      }

      // 기존 캐시 업데이트
      if (_user != null) {
        HistoryMemoryCache.setCachedEntries(_user!.uid, entries);
        HistoryLocalCache.saveLocalCache(_user!.uid, entries);
      }

      // MoodEntry로 변환 및 상태 업데이트
      _processEntriesFromCache(entries);

      Logger.debug('RelaxAnalysisScreen: 실시간 데이터 처리 완료 - ${entries.length}개');
    } catch (e) {
      Logger.error('RelaxAnalysisScreen: 스트림 데이터 처리 오류 - $e');
    }
  }

  // 🚀 스트림 오류 처리 메서드 추가
  void _onStreamError(error) {
    Logger.error('RelaxAnalysisScreen: 스트림 오류 - $error');
    _isStreamActive = false;

    // 재연결 시도 (1회만)
    Timer(Duration(seconds: 3), () {
      if (mounted && _isUserAuthenticated && !_isStreamActive) {
        Logger.debug('RelaxAnalysisScreen: 스트림 재연결 시도');
        _streamInitialized = false; // 재연결을 위해 플래그 리셋
        _setupRealtimeStream();
      }
    });
  }

  void _checkAuthentication() {
    _user = _auth.currentUser;
    _isUserAuthenticated = _user != null;

    if (_user != null) {
      Logger.debug('RelaxAnalysisScreen: 인증된 사용자 - ${_user!.uid}');
    } else {
      Logger.debug('RelaxAnalysisScreen: 인증되지 않은 사용자');
      setState(() => _isLoading = false);
    }
  }

  /// 캐시된 데이터 즉시 로드 (성능 최적화)
  void _loadCachedData() {
    if (!_isUserAuthenticated || _user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userId = _user!.uid;

      // 1. 메모리 캐시 확인
      final memoryCache = HistoryMemoryCache.getCachedEntries(userId);
      if (memoryCache != null && memoryCache.isNotEmpty) {
        _processEntriesFromCache(memoryCache);
        Logger.debug('RelaxAnalysisScreen: 메모리 캐시에서 ${memoryCache.length}개 로드');
        return;
      }

      // 2. Provider 데이터 확인
      final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);
      if (relaxProvider.userEntries.isNotEmpty) {
        _processEntriesFromProvider(relaxProvider.userEntries);
        Logger.debug(
            'RelaxAnalysisScreen: Provider에서 ${relaxProvider.userEntries.length}개 로드');
        return;
      }

      // 3. 로컬 캐시 확인 (비동기)
      _loadFromLocalCache(userId);
    } catch (e) {
      Logger.error('RelaxAnalysisScreen: 캐시 로드 오류 - $e');
      setState(() => _isLoading = false);
    }
  }

  /// 로컬 캐시에서 비동기 로드
  void _loadFromLocalCache(String userId) async {
    try {
      final localCache = await HistoryLocalCache.getLocalCache(userId);
      if (localCache != null && localCache.isNotEmpty) {
        final restoredEntries = _restoreTimestamps(localCache);
        _processEntriesFromCache(restoredEntries);
        Logger.debug('RelaxAnalysisScreen: 로컬 캐시에서 ${localCache.length}개 로드');
      } else {
        // 캐시가 없으면 Provider로 로드
        _loadDataViaProvider();
      }
    } catch (e) {
      Logger.error('RelaxAnalysisScreen: 로컬 캐시 로드 오류 - $e');
      _loadDataViaProvider();
    }
  }

  /// Provider를 통한 데이터 로드 (기존 로직 유지)
  Future<void> _loadDataViaProvider() async {
    if (!_isUserAuthenticated || _user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);

      final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);
      await relaxProvider.loadUserEntries();

      _processEntriesFromProvider(relaxProvider.userEntries);
    } catch (e) {
      Logger.error('RelaxAnalysisScreen: Provider 데이터 로드 오류 - $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 캐시 데이터를 MoodEntry로 변환 처리
  void _processEntriesFromCache(List<Map<String, dynamic>> entries) {
    try {
      final moodEntries = <MoodEntry>[];
      final calendarData = <DateTime, MoodEntry>{};

      for (var entryMap in entries) {
        try {
          final moodEntry = MoodEntry.fromMap(entryMap);
          moodEntries.add(moodEntry);

          final dateOnly = DateTime(
            moodEntry.date.year,
            moodEntry.date.month,
            moodEntry.date.day,
          );
          calendarData[dateOnly] = moodEntry;
        } catch (entryError) {
          Logger.warn('RelaxAnalysisScreen: 개별 엔트리 변환 오류 - $entryError');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _moodEntries = moodEntries;
          _moodCalendarData = calendarData;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('RelaxAnalysisScreen: 캐시 데이터 처리 오류 - $e');
      setState(() => _isLoading = false);
    }
  }

  /// Provider 데이터를 MoodEntry로 변환 처리 (기존 로직)
  void _processEntriesFromProvider(List<Map<String, dynamic>> entries) {
    try {
      final moodEntries = <MoodEntry>[];
      final calendarData = <DateTime, MoodEntry>{};

      for (var entryMap in entries) {
        try {
          final moodEntry = MoodEntry.fromMap(entryMap);
          moodEntries.add(moodEntry);

          final dateOnly = DateTime(
            moodEntry.date.year,
            moodEntry.date.month,
            moodEntry.date.day,
          );
          calendarData[dateOnly] = moodEntry;
        } catch (entryError) {
          Logger.warn('RelaxAnalysisScreen: Provider 엔트리 변환 오류 - $entryError');
          continue;
        }
      }

      // 캐시 저장 (백그라운드)
      if (_user != null && entries.isNotEmpty) {
        HistoryMemoryCache.setCachedEntries(_user!.uid, entries);
        HistoryLocalCache.saveLocalCache(_user!.uid, entries);
      }

      if (mounted) {
        setState(() {
          _moodEntries = moodEntries;
          _moodCalendarData = calendarData;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('RelaxAnalysisScreen: Provider 데이터 처리 오류 - $e');
      setState(() => _isLoading = false);
    }
  }

  /// Timestamp 필드 복원 (로컬 캐시용)
  List<Map<String, dynamic>> _restoreTimestamps(
      List<Map<String, dynamic>> entries) {
    return entries.map((entry) {
      final restored = Map<String, dynamic>.from(entry);

      ['date', 'createdAt', 'updatedAt'].forEach((field) {
        if (restored[field] is int) {
          try {
            restored[field] =
                DateTime.fromMillisecondsSinceEpoch(restored[field]);
          } catch (e) {
            Logger.warn('RelaxAnalysisScreen: $field 복원 오류 - $e');
          }
        } else if (restored[field] is String) {
          try {
            restored[field] = DateTime.parse(restored[field]);
          } catch (e) {
            Logger.warn('RelaxAnalysisScreen: $field 파싱 오류 - $e');
          }
        }
      });

      return restored;
    }).toList();
  }

  // ============================================================================
  // 이벤트 버스 리스너 (간소화)
  // ============================================================================

  // 🚀 이벤트 리스너 간소화 (스트림이 메인이므로)
  void _setupEventListeners() {
    // 이벤트 버스는 보조적으로만 사용
    _entryAddedSubscription = eventBus.on(EventBus.entryAdded, (event) {
      // 스트림이 자동으로 처리하므로 별도 액션 불필요
      Logger.debug('RelaxAnalysisScreen: 엔트리 추가 이벤트 수신 (스트림에서 자동 처리됨)');
    });

    _entryDeletedSubscription = eventBus.on(EventBus.entryDeleted, (event) {
      Logger.debug('RelaxAnalysisScreen: 엔트리 삭제 이벤트 수신 (스트림에서 자동 처리됨)');
    });

    _entryUpdatedSubscription = eventBus.on(EventBus.entryUpdated, (event) {
      Logger.debug('RelaxAnalysisScreen: 엔트리 업데이트 이벤트 수신 (스트림에서 자동 처리됨)');
    });

    // 데이터 새로고침 요청만 수동으로 처리
    _dataRefreshNeededSubscription =
        eventBus.on(EventBus.dataRefreshNeeded, (event) {
      if (mounted) {
        if (event is DataRefreshNeededEvent) {
          final screens = event.screens;
          if (screens.isEmpty || screens.contains('RelaxAnalysisScreen')) {
            refreshData();
          }
        } else {
          refreshData();
        }
      }
    });
  }

  void _cleanupEventListeners() {
    _entryAddedSubscription?.cancel();
    _entryDeletedSubscription?.cancel();
    _entryUpdatedSubscription?.cancel();
    _dataRefreshNeededSubscription?.cancel();
  }

  // ============================================================================
  // 유틸리티 메서드들
  // ============================================================================

  void _debounceRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      if (mounted) _loadDataViaProvider();
    });
  }

  // 기존 refreshData 메서드 수정
  @override
  void refreshData() {
    Logger.debug('RelaxAnalysisScreen: 수동 데이터 새로고침 시작');

    // 스트림이 활성화되어 있으면 스트림이 자동으로 최신 데이터를 가져옴
    if (_isStreamActive) {
      Logger.debug('RelaxAnalysisScreen: 스트림 활성화 상태 - 자동 새로고침됨');
      return;
    }

    // 스트림이 비활성화된 경우에만 수동 로드
    _loadDataViaProvider();
  }

  /// 수동 새로고침 (Pull-to-refresh 용) - 기존과 동일
  Future<void> _manualRefresh() async {
    Logger.debug('RelaxAnalysisScreen: 수동 새로고침 시작');
    await _loadDataViaProvider();
  }

  // ============================================================================
  // UI 데이터 처리 메서드들 (기존과 동일)
  // ============================================================================

  Map<String, int> getMoodDistribution() {
    if (_moodEntries.isEmpty) {
      return {
        '😊': 0,
        '😢': 0,
        '😠': 0,
        '😩': 0,
        '😐': 0,
      };
    }

    Map<String, int> distribution = {
      '😊': 0,
      '😢': 0,
      '😠': 0,
      '😩': 0,
      '😐': 0,
    };

    for (var entry in _moodEntries) {
      if (distribution.containsKey(entry.mood)) {
        distribution[entry.mood] = distribution[entry.mood]! + 1;
      }
    }
    return distribution;
  }

  Map<DateTime, MoodProgress> _convertToProgressData() {
    final progressData = <DateTime, MoodProgress>{};

    _moodCalendarData.forEach((date, moodEntry) {
      progressData[date] = moodEntry.toMoodProgress();
    });

    return progressData;
  }

  MoodEntry? _getSelectedDateMoodEntry() {
    final dateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return _moodCalendarData[dateOnly];
  }

  // ============================================================================
  // UI 빌드 메서드들 (기존 디자인 완전 유지)
  // ============================================================================

  Widget _buildSelectedDateInfo() {
    final moodEntry = _getSelectedDateMoodEntry();
    final localizations = AppLocalizations.of(context);
    final isKorean = localizations.localeName.startsWith('ko');

    if (moodEntry == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              isKorean
                  ? '선택한 날짜에 기록된 감정이 없습니다.'
                  : 'No recorded emotion on the selected date.',
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  moodEntry.mood,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    DateFormatter.formatDate(
                        moodEntry.date, localizations.localeName),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              moodEntry.topic,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              moodEntry.content,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 상태 (기존과 동일)
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 인증되지 않은 사용자에 대한 처리 (기존과 동일)
    if (!_isUserAuthenticated) {
      final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                isKorean ? '로그인이 필요합니다.' : 'Login required.',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final distribution = getMoodDistribution();
    final totalEntries = _moodEntries.length;
    final moodProgress = _convertToProgressData();
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _manualRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _animation,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // 캘린더 위젯 (기존과 동일)
                      Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  isKorean ? '감정 기록 캘린더' : 'Mood Calendar',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              CalendarWidget<MoodProgress>(
                                progressData: moodProgress,
                                selectedDate: _selectedDate,
                                onDaySelected: (day) {
                                  setState(() {
                                    _selectedDate = day;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 선택한 날짜의 감정 정보 (기존과 동일)
                      _buildSelectedDateInfo(),

                      // 감정 분석 타이틀 (기존과 동일)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.analytics,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              isKorean ? '감정 분석' : 'Emotion Analysis',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),

                      // 감정 차트 컨테이너 (기존 높이 유지)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.65,
                        child: MoodChartContainer(
                          distribution: distribution,
                          totalEntries: totalEntries,
                          moodEntries: _moodEntries,
                        ),
                      ),

                      // 감정 통계 표시 (기존과 동일)
                      if (_moodEntries.isNotEmpty)
                        MoodStatisticsWidget(
                          distribution: distribution,
                          totalEntries: totalEntries,
                        ),

                      // 하단 여백 추가 (기존과 동일)
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MoodChart 위젯들 (기존과 동일하게 내장)
// ============================================================================

/// 감정 차트 컨테이너 위젯
class MoodChartContainer extends StatefulWidget {
  final Map<String, int> distribution;
  final int totalEntries;
  final List<MoodEntry> moodEntries;

  const MoodChartContainer({
    super.key,
    required this.distribution,
    required this.totalEntries,
    this.moodEntries = const [],
  });

  @override
  State<MoodChartContainer> createState() => _MoodChartContainerState();
}

class _MoodChartContainerState extends State<MoodChartContainer>
    with SingleTickerProviderStateMixin {
  int _currentChartIndex = 0;
  final PageController _pageController = PageController();
  String _selectedPeriod = '전체';
  final List<String> _chartTypes = ['pie', 'bar', 'line'];
  final List<String> _periodOptions = ['전체', '주간', '월간', '년간'];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentChartIndex = _tabController.index;
        });
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _getChartName(String chartType, BuildContext context) {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
    switch (chartType) {
      case 'pie':
        return isKorean ? '파이 차트' : 'Pie Chart';
      case 'bar':
        return isKorean ? '막대 차트' : 'Bar Chart';
      case 'line':
        return isKorean ? '라인 차트' : 'Line Chart';
      default:
        return chartType;
    }
  }

  String _getLocalizedPeriod(String period, BuildContext context) {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
    if (!isKorean) {
      switch (period) {
        case '전체':
          return 'All';
        case '일간':
          return 'Daily';
        case '주간':
          return 'Weekly';
        case '월간':
          return 'Monthly';
        case '년간':
          return 'Yearly';
        default:
          return period;
      }
    }
    return period;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final chartColors = Theme.of(context).extension<ChartColors>();
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
    final textSize = MediaQuery.of(context).size.width * 0.04;

    if (widget.totalEntries == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isKorean ? '아직 기록된 감정이 없습니다.' : 'No emotion records yet.',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 탭바 추가
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: _getChartName('pie', context)),
            Tab(text: _getChartName('bar', context)),
            Tab(text: _getChartName('line', context)),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
        ),
        const SizedBox(height: 8),
        // 기간 선택 드롭다운
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                isKorean ? '기간: ' : 'Period: ',
                style: TextStyle(
                  fontSize: textSize * 0.8,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                ),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                items: _periodOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      _getLocalizedPeriod(value, context),
                      style: TextStyle(fontSize: textSize * 0.8),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPeriod = newValue;
                    });
                  }
                },
                icon: const Icon(Icons.arrow_drop_down),
                underline: Container(
                  height: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? chartColors?.background : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentChartIndex = index;
                });
                _tabController.animateTo(index);
              },
              children: [
                // 파이 차트
                MoodPieChartWidget(
                  distribution: widget.distribution,
                  totalEntries: widget.totalEntries,
                  selectedPeriod: _selectedPeriod,
                  moodEntries: widget.moodEntries,
                ),
                // 막대 차트
                LayoutBuilder(builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: SizedBox(
                      height: max(constraints.maxHeight, 190),
                      child: MoodBarChartWidget(
                        distribution: widget.distribution,
                        selectedPeriod: _selectedPeriod,
                        moodEntries: widget.moodEntries,
                      ),
                    ),
                  );
                }),
                // 라인 차트
                MoodLineChartWidget(
                  moodEntries: widget.moodEntries,
                  selectedPeriod: _selectedPeriod,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 파이 차트 위젯
class MoodPieChartWidget extends StatelessWidget {
  final Map<String, int> distribution;
  final int totalEntries;
  final String selectedPeriod;
  final List<MoodEntry> moodEntries;

  const MoodPieChartWidget({
    super.key,
    required this.distribution,
    required this.totalEntries,
    this.selectedPeriod = '전체',
    this.moodEntries = const [],
  });

  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😊':
        return Colors.green;
      case '😢':
        return Colors.blue;
      case '😠':
        return Colors.red;
      case '😩':
        return Colors.purple;
      case '😐':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Map<String, int> getFilteredDistribution() {
    if (selectedPeriod == '전체' || moodEntries.isEmpty) {
      return distribution;
    }

    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case '주간':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '월간':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '년간':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return distribution;
    }

    final filteredDistribution = {
      '😊': 0,
      '😢': 0,
      '😠': 0,
      '😩': 0,
      '😐': 0,
    };

    for (var entry in moodEntries) {
      if (entry.date.isAfter(startDate) &&
          filteredDistribution.containsKey(entry.mood)) {
        filteredDistribution[entry.mood] =
            filteredDistribution[entry.mood]! + 1;
      }
    }

    return filteredDistribution;
  }

  @override
  Widget build(BuildContext context) {
    final filteredDistribution = getFilteredDistribution();
    final filteredTotal = filteredDistribution.values.fold(0, (a, b) => a + b);
    final orderedEmojis = ['😊', '😐', '😩', '😠', '😢'];

    final List<PieChartSectionData> sections = [];
    for (var emoji in orderedEmojis) {
      if (filteredDistribution.containsKey(emoji) &&
          filteredDistribution[emoji]! > 0) {
        final value = filteredDistribution[emoji]!;
        final percentage = filteredTotal > 0
            ? (value / filteredTotal * 100).toStringAsFixed(1)
            : '0.0';

        sections.add(PieChartSectionData(
          color: _getMoodColor(emoji),
          value: value.toDouble(),
          title: '$percentage%',
          radius: 130,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgeWidget: Text(
            emoji,
            style: const TextStyle(
              fontSize: 30,
              color: Colors.white,
            ),
          ),
          badgePositionPercentageOffset: 0.98,
        ));
      }
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 1.3,
        child: PieChart(
          PieChartData(
            sections: sections,
            sectionsSpace: 2,
            centerSpaceRadius: 30,
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                // 터치 이벤트 핸들링
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 감정별 막대 차트 위젯
class MoodBarChartWidget extends StatelessWidget {
  final Map<String, int> distribution;
  final String selectedPeriod;
  final List<MoodEntry> moodEntries;

  const MoodBarChartWidget({
    super.key,
    required this.distribution,
    this.selectedPeriod = '전체',
    this.moodEntries = const [],
  });

  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😊':
        return Colors.green;
      case '😢':
        return Colors.blue;
      case '😠':
        return Colors.red;
      case '😩':
        return Colors.purple;
      case '😐':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Map<String, int> getFilteredDistribution() {
    if (selectedPeriod == '전체' || moodEntries.isEmpty) {
      return distribution;
    }

    final now = DateTime.now();
    DateTime startDate;

    switch (selectedPeriod) {
      case '주간':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '월간':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '년간':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return distribution;
    }

    final filteredDistribution = {
      '😊': 0,
      '😢': 0,
      '😠': 0,
      '😩': 0,
      '😐': 0,
    };

    for (var entry in moodEntries) {
      if (entry.date.isAfter(startDate) &&
          filteredDistribution.containsKey(entry.mood)) {
        filteredDistribution[entry.mood] =
            filteredDistribution[entry.mood]! + 1;
      }
    }

    return filteredDistribution;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final filteredDistribution = getFilteredDistribution();
    final orderedEmojis = ['😊', '😐', '😩', '😠', '😢'];
    final List<BarChartGroupData> barGroups = [];
    final int totalCount = filteredDistribution.values.fold(0, (a, b) => a + b);

    for (int i = 0; i < orderedEmojis.length; i++) {
      final emoji = orderedEmojis[i];
      final count = filteredDistribution[emoji] ?? 0;
      final percentage = totalCount > 0 ? (count / totalCount * 100) : 0.0;

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: percentage,
            color: _getMoodColor(emoji),
            width: 30,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 15, right: 5, left: 5, bottom: 5),
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceEvenly,
            barGroups: barGroups,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 0.8,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    if (index >= 0 && index < orderedEmojis.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          orderedEmojis[index],
                          style: const TextStyle(fontSize: 20),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value % 25 == 0) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          '${value.toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  width: 1,
                ),
                left: BorderSide(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  width: 1,
                ),
              ),
            ),
            minY: 0,
            maxY: 100,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: isDarkMode ? Colors.grey[800]! : Colors.white,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final emoji = orderedEmojis[groupIndex];
                  final count = filteredDistribution[emoji] ?? 0;
                  return BarTooltipItem(
                    '$emoji: ${rod.toY.toStringAsFixed(1)}%\n총 $count회',
                    TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 날짜별 라인 차트 위젯
class MoodLineChartWidget extends StatelessWidget {
  final List<MoodEntry> moodEntries;
  final String selectedPeriod;

  const MoodLineChartWidget({
    super.key,
    required this.moodEntries,
    required this.selectedPeriod,
  });

  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😊':
        return Colors.green;
      case '😢':
        return Colors.blue;
      case '😠':
        return Colors.red;
      case '😩':
        return Colors.purple;
      case '😐':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  double _getMoodScore(String mood) {
    switch (mood) {
      case '😊':
        return 5.0;
      case '😐':
        return 4.0;
      case '😩':
        return 3.0;
      case '😠':
        return 2.0;
      case '😢':
        return 1.0;
      default:
        return 0.0;
    }
  }

  DateTime _getStartDate(DateTime now, String period) {
    switch (period) {
      case '전체':
        if (moodEntries.isNotEmpty) {
          final oldestEntry = moodEntries.reduce((value, element) =>
              value.date.isBefore(element.date) ? value : element);
          return oldestEntry.date;
        }
        return DateTime(now.year - 1, now.month, now.day);
      case '년간':
        return DateTime(now.year - 1, now.month, now.day);
      case '월간':
        return DateTime(now.year, now.month - 2, now.day);
      case '주간':
        return now.subtract(const Duration(days: 14));
      case '일간':
      default:
        return now.subtract(const Duration(days: 6));
    }
  }

  Map<DateTime, MoodEntry> _getMoodEntriesByDate() {
    final Map<DateTime, MoodEntry> result = {};
    for (final entry in moodEntries) {
      final dateOnly =
          DateTime(entry.date.year, entry.date.month, entry.date.day);
      result[dateOnly] = entry;
    }
    return result;
  }

  List<MapEntry<DateTime, String>> _getDateOrderedMoods() {
    final now = DateTime.now();
    final startDate = _getStartDate(now, selectedPeriod);
    final moodsByDate = _getMoodEntriesByDate();
    final List<MapEntry<DateTime, String>> result = [];

    if (selectedPeriod == '전체' && moodsByDate.isNotEmpty) {
      final sortedDates = moodsByDate.keys.toList()
        ..sort((a, b) => a.compareTo(b));
      for (final date in sortedDates) {
        result.add(MapEntry(date, moodsByDate[date]!.mood));
      }
    } else {
      DateTime date = startDate;
      while (date.isBefore(now) || isSameDay(date, now)) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (moodsByDate.containsKey(dateOnly)) {
          result.add(MapEntry(dateOnly, moodsByDate[dateOnly]!.mood));
        } else {
          result.add(MapEntry(dateOnly, ''));
        }
        date = date.add(const Duration(days: 1));
      }
    }
    return result;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
    final moodsByDate = _getDateOrderedMoods();

    if (moodsByDate.isEmpty) {
      return Center(
        child: Text(
          isKorean ? '표시할 데이터가 없습니다.' : 'No data to display.',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.grey,
          ),
        ),
      );
    }

    final List<FlSpot> spots = [];
    for (int i = 0; i < moodsByDate.length; i++) {
      final mood = moodsByDate[i].value;
      if (mood.isNotEmpty) {
        spots.add(FlSpot(i.toDouble(), _getMoodScore(mood)));
      }
    }

    final displayDates = <int>[];
    int interval = 1;

    if (moodsByDate.length > 60) {
      interval = 10;
    } else if (moodsByDate.length > 30) {
      interval = 5;
    } else if (moodsByDate.length > 14) {
      interval = 3;
    } else if (moodsByDate.length > 7) {
      interval = 2;
    }

    for (int i = 0; i < moodsByDate.length; i += interval) {
      displayDates.add(i);
    }

    if (!displayDates.contains(moodsByDate.length - 1) &&
        moodsByDate.isNotEmpty) {
      displayDates.add(moodsByDate.length - 1);
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          isKorean ? '감정 데이터가 없습니다.' : 'No mood data available.',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.grey,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 20, bottom: 10),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.toInt();
                  if (!displayDates.contains(index) ||
                      index >= moodsByDate.length) {
                    return const SizedBox.shrink();
                  }
                  final date = moodsByDate[index].key;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  );
                },
                interval: 1.0,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value % 1 == 0 && value >= 0 && value <= 5) {
                    String label;
                    switch (value.toInt()) {
                      case 5:
                        label = '😊';
                        break;
                      case 4:
                        label = '😐';
                        break;
                      case 3:
                        label = '😩';
                        break;
                      case 2:
                        label = '😠';
                        break;
                      case 1:
                        label = '😢';
                        break;
                      default:
                        return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                width: 1,
              ),
              left: BorderSide(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
          ),
          minY: 0,
          maxY: 5.5,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              gradient: LinearGradient(
                colors: [Colors.blue.shade300, Colors.blue],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  if (index >= moodsByDate.length) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: Colors.blue,
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                    );
                  }
                  final mood = moodsByDate[spot.x.toInt()].value;
                  return FlDotCirclePainter(
                    radius: 5,
                    color: _getMoodColor(mood),
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.blue.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: isDarkMode ? Colors.grey[800]! : Colors.white,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= moodsByDate.length) return null;
                  final entry = moodsByDate[index];
                  final date = entry.key;
                  final mood = entry.value;
                  if (mood.isEmpty) return null;
                  final moodScore = _getMoodScore(mood);
                  return LineTooltipItem(
                    '${DateFormat('yy/MM/dd').format(date)}\n$mood (${moodScore.toStringAsFixed(1)})',
                    TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 감정 통계 위젯
class MoodStatisticsWidget extends StatelessWidget {
  final Map<String, int> distribution;
  final int totalEntries;

  const MoodStatisticsWidget({
    super.key,
    required this.distribution,
    required this.totalEntries,
  });

  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😊':
        return Colors.green;
      case '😢':
        return Colors.blue;
      case '😠':
        return Colors.red;
      case '😩':
        return Colors.purple;
      case '😐':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Map<String, String> getMoodNameMap(String locale) {
    if (locale == 'ko') {
      return {
        '😊': '행복',
        '😐': '평온',
        '😩': '지침',
        '😠': '화남',
        '😢': '슬픔',
      };
    } else {
      return {
        '😊': 'Happy',
        '😐': 'Calm',
        '😩': 'Tired',
        '😠': 'Angry',
        '😢': 'Sad',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
    final moodNames = getMoodNameMap(isKorean ? 'ko' : 'en');
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKorean ? '감정 통계' : 'Mood Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            ...distribution.entries.map((entry) {
              final percentage = totalEntries > 0
                  ? (entry.value / totalEntries * 100).toStringAsFixed(1)
                  : '0.0';
              final moodName = moodNames[entry.key] ?? entry.key;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    Text(
                      moodName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getMoodColor(entry.key).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$percentage%',
                        style: TextStyle(
                          color: _getMoodColor(entry.key),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              isKorean
                  ? '전체 기록: $totalEntries'
                  : 'Total records: $totalEntries',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
