import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import '../../core/localization/app_localizations.dart';
import '../../providers/relax_provider.dart';
import '../../utils/event_bus.dart';
import '../../widgets/unified_entry_card.dart';
import '../../models/mood_models.dart';
import '../../utils/logger.dart';

// ============================================================================
// 캐시 관리 클래스들
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

  static void invalidateCache(String userId) {
    _cache.remove(userId);
    _cacheTime.remove(userId);
    Logger.debug('HistoryCache: 캐시 무효화됨 - $userId');
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
        } else {
          Logger.debug('HistoryCache: 로컬 캐시 만료됨');
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

      // Timestamp 객체를 직렬화 가능한 형태로 변환
      final serializedEntries = entries.map((entry) {
        final Map<String, dynamic> serialized = Map.from(entry);

        // Timestamp 필드들을 millisecondsSinceEpoch로 변환
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

  static Future<void> clearLocalCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_cacheKey}_$userId');
      await prefs.remove('${_cacheTimeKey}_$userId');
      Logger.debug('HistoryCache: 로컬 캐시 클리어됨 - $userId');
    } catch (e) {
      Logger.error('HistoryCache: 로컬 캐시 클리어 오류 - $e');
    }
  }
}

// ============================================================================
// RelaxHistoryScreen 메인 클래스
// ============================================================================

class RelaxHistoryScreen extends StatefulWidget {
  const RelaxHistoryScreen({super.key});

  @override
  State<RelaxHistoryScreen> createState() => _RelaxHistoryScreenState();
}

class _RelaxHistoryScreenState extends State<RelaxHistoryScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // ============================================================================
  // 상태 변수들
  // ============================================================================

  // Firebase & Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isUserAuthenticated = false;

  // 데이터 상태
  List<Map<String, dynamic>> _userEntries = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasError = false;
  String? _errorMessage;

  // UI 상태
  String? _expandedEntryId;
  final RefreshIndicator _refreshIndicator = RefreshIndicator(
    onRefresh: () => Future.value(),
    child: Container(),
  );

  // 실시간 스트림
  StreamSubscription<QuerySnapshot>? _userEntriesSubscription;
  bool _streamInitialized = false;
  bool _isStreamActive = false;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 3;

  // 이벤트 버스 구독
  StreamSubscription? _authStateSubscription;
  StreamSubscription? _entryVisibilitySubscription;
  StreamSubscription? _entryDeletedSubscription;
  StreamSubscription? _entryUpdatedSubscription;
  StreamSubscription? _publicStatusSubscription;
  StreamSubscription? _dataRefreshNeededSubscription;

  // 성능 최적화
  Timer? _debounceTimer;
  DateTime? _lastRefreshTime;
  static const Duration MIN_REFRESH_INTERVAL = Duration(seconds: 2);

  @override
  bool get wantKeepAlive => true;

  // ============================================================================
  // 라이프사이클 메서드들
  // ============================================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupStreams();
    _cleanupEventListeners();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 앱이 다시 활성화될 때 데이터 새로고침
        if (_isUserAuthenticated && mounted) {
          _refreshIfNeeded();
        }
        break;
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 갈 때 스트림 일시 정지
        _pauseStreams();
        break;
      default:
        break;
    }
  }

  // ============================================================================
  // 초기화 메서드들
  // ============================================================================

  /// 화면 초기화
  Future<void> _initializeScreen() async {
    Logger.debug('RelaxHistoryScreen: 초기화 시작');

    try {
      // 1. 인증 상태 확인 및 이벤트 리스너 설정
      await _setupAuthentication();
      _setupEventListeners();

      // 2. 캐시된 데이터로 즉시 UI 표시
      await _loadCachedDataImmediately();

      // 3. 백그라운드에서 실제 데이터 로드
      _loadFreshDataInBackground();
    } catch (e) {
      Logger.error('RelaxHistoryScreen: 초기화 오류 - $e');
      _handleError('초기화 중 오류가 발생했습니다.');
    }
  }

  /// 인증 설정 및 상태 모니터링
  Future<void> _setupAuthentication() async {
    // 현재 사용자 확인
    _user = _auth.currentUser;
    _isUserAuthenticated = _user != null;

    if (_user != null) {
      Logger.debug('RelaxHistoryScreen: 인증된 사용자 - ${_user!.uid}');
    }

    // 인증 상태 변화 모니터링
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (mounted) {
        _handleAuthStateChange(user);
      }
    });
  }

  /// 인증 상태 변화 처리
  void _handleAuthStateChange(User? user) {
    Logger.debug('RelaxHistoryScreen: Auth 상태 변경됨 - ${user?.uid}');

    final wasAuthenticated = _isUserAuthenticated;
    _user = user;
    _isUserAuthenticated = user != null;

    if (user != null && !wasAuthenticated) {
      // 새로 로그인된 경우
      _loadCachedDataImmediately();
      _loadFreshDataInBackground();
    } else if (user == null && wasAuthenticated) {
      // 로그아웃된 경우
      _cleanupOnLogout();
    }
  }

  /// 로그아웃 시 정리
  void _cleanupOnLogout() {
    _cleanupStreams();
    HistoryMemoryCache.clearCache(null);

    if (mounted) {
      setState(() {
        _userEntries = [];
        _isLoading = false;
        _hasError = false;
        _expandedEntryId = null;
      });
    }
  }

  // ============================================================================
  // 캐시 기반 데이터 로딩
  // ============================================================================

  /// 캐시된 데이터로 즉시 UI 표시
  Future<void> _loadCachedDataImmediately() async {
    if (!_isUserAuthenticated || _user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final userId = _user!.uid;

    // 1. 메모리 캐시 확인
    final memoryCache = HistoryMemoryCache.getCachedEntries(userId);
    if (memoryCache != null) {
      setState(() {
        _userEntries = memoryCache;
        _isLoading = false;
        _hasError = false;
      });
      Logger.debug(
          'RelaxHistoryScreen: 메모리 캐시로 즉시 표시 - ${memoryCache.length}개');
      return;
    }

    // 2. 로컬 캐시 확인
    final localCache = await HistoryLocalCache.getLocalCache(userId);
    if (localCache != null) {
      // Timestamp 필드 복원
      final restoredEntries = _restoreTimestamps(localCache);

      setState(() {
        _userEntries = restoredEntries;
        _isLoading = false;
        _hasError = false;
      });

      // 메모리 캐시에도 저장
      HistoryMemoryCache.setCachedEntries(userId, restoredEntries);
      Logger.debug(
          'RelaxHistoryScreen: 로컬 캐시로 즉시 표시 - ${restoredEntries.length}개');
      return;
    }

    // 3. 캐시가 없으면 로딩 상태 유지하되, 타임아웃 설정
    Logger.debug('RelaxHistoryScreen: 캐시 없음, 서버 로드 대기');

    // 🚀 신규 사용자를 위한 빠른 타임아웃
    Timer(Duration(seconds: 5), () {
      if (mounted && _isLoading && _userEntries.isEmpty) {
        Logger.debug('RelaxHistoryScreen: 로딩 타임아웃 - 빈 상태로 표시');
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
    });
  }

  /// 백그라운드에서 최신 데이터 로드
  void _loadFreshDataInBackground() {
    if (!_isUserAuthenticated || _user == null) return;

    // 디바운스 적용
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      _performFreshDataLoad();
    });
  }

  /// 실제 최신 데이터 로드 수행
  Future<void> _performFreshDataLoad() async {
    if (!mounted || !_isUserAuthenticated || _user == null) return;

    final userId = _user!.uid;

    try {
      Logger.debug('RelaxHistoryScreen: 최신 데이터 로드 시작');

      // 사용자의 모든 엔트리 로드 (공개/비공개 포함)
      await _loadUserEntriesFromFirestore(userId);

      // 실시간 스트림 설정 시도
      if (!_streamInitialized) {
        _setupRealtimeStream();
      }
    } catch (e) {
      Logger.error('RelaxHistoryScreen: 데이터 로드 오류 - $e');
      if (mounted && _userEntries.isEmpty) {
        _handleError('데이터를 불러오는 중 오류가 발생했습니다.');
      }
    }
  }

  /// Firestore에서 사용자 엔트리 직접 로드 (공개/비공개 모두) - 최적화됨
  Future<void> _loadUserEntriesFromFirestore(String userId) async {
    try {
      // 사용자의 개인 컬렉션에서 모든 엔트리 로드
      final userSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('moods')
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      // 🚀 신규 사용자 빠른 처리: 엔트리가 없으면 즉시 완료
      if (userSnapshot.docs.isEmpty) {
        Logger.debug('RelaxHistoryScreen: 신규 사용자 - 엔트리 없음');

        if (mounted) {
          setState(() {
            _userEntries = [];
            _hasError = false;
            _isLoading = false;
          });
        }

        // 빈 캐시 저장
        HistoryMemoryCache.setCachedEntries(userId, []);
        await HistoryLocalCache.saveLocalCache(userId, []);
        return;
      }

      // 🚀 배치 처리: 모든 엔트리 ID를 한 번에 수집
      final entryIds = userSnapshot.docs.map((doc) => doc.id).toList();

      // 🚀 단일 쿼리로 모든 공개 엔트리 정보 가져오기
      Map<String, Map<String, dynamic>> publicEntriesMap = {};

      if (entryIds.isNotEmpty) {
        try {
          // Firestore의 'in' 쿼리는 최대 10개까지만 지원하므로 청크로 나누어 처리
          final chunks = <List<String>>[];
          for (int i = 0; i < entryIds.length; i += 10) {
            chunks.add(entryIds.sublist(
                i, i + 10 > entryIds.length ? entryIds.length : i + 10));
          }

          for (final chunk in chunks) {
            final publicSnapshot = await _firestore
                .collection('publicEntries')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

            for (final doc in publicSnapshot.docs) {
              publicEntriesMap[doc.id] = doc.data();
            }
          }

          Logger.debug(
              'RelaxHistoryScreen: 배치로 공개 정보 로드됨 - ${publicEntriesMap.length}개');
        } catch (e) {
          Logger.warn('RelaxHistoryScreen: 배치 공개 상태 확인 오류 - $e');
        }
      }

      // 🚀 빠른 데이터 조합
      final entries = <Map<String, dynamic>>[];

      for (final doc in userSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // 배치로 가져온 공개 정보 적용
        final publicData = publicEntriesMap[doc.id];
        if (publicData != null) {
          data['isPublic'] = true;
          data['likeCount'] = publicData['likeCount'] ?? 0;
          data['isLiked'] = publicData['isLiked'] ?? false;
          data['isBookmarked'] = publicData['isBookmarked'] ?? false;
        } else {
          // 비공개 엔트리의 기본값
          data['isPublic'] = false;
          data['likeCount'] = 0;
          data['isLiked'] = false;
          data['isBookmarked'] = false;
        }

        entries.add(data);
      }

      // 데이터가 변경된 경우에만 업데이트
      if (!_isEntriesEqual(_userEntries, entries)) {
        // 캐시 업데이트
        HistoryMemoryCache.setCachedEntries(userId, entries);
        await HistoryLocalCache.saveLocalCache(userId, entries);

        if (mounted) {
          setState(() {
            _userEntries = entries;
            _hasError = false;
            _isLoading = false;
          });
        }

        Logger.debug('RelaxHistoryScreen: 데이터 업데이트됨 - ${entries.length}개');
      } else {
        // 데이터가 동일해도 로딩 상태는 해제
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Logger.error('RelaxHistoryScreen: Firestore 로드 오류 - $e');
      rethrow;
    }
  }

  // ============================================================================
  // 실시간 스트림 관리
  // ============================================================================

  /// 실시간 스트림 설정
  void _setupRealtimeStream() {
    if (!_isUserAuthenticated || _user == null || _streamInitialized) return;

    try {
      Logger.debug('RelaxHistoryScreen: 실시간 스트림 설정 시작');

      // 사용자의 개인 컬렉션 모니터링 (공개/비공개 모두 포함)
      _userEntriesSubscription = _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('moods')
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots()
          .listen(
            _onStreamData,
            onError: _onStreamError,
            onDone: () => Logger.debug('RelaxHistoryScreen: 스트림 종료'),
          );

      _streamInitialized = true;
      _isStreamActive = true;
      _reconnectAttempts = 0;

      Logger.debug('RelaxHistoryScreen: 실시간 스트림 활성화됨');
    } catch (e) {
      Logger.error('RelaxHistoryScreen: 스트림 설정 오류 - $e');
      _streamInitialized = false;
      _isStreamActive = false;
    }
  }

  /// 스트림 데이터 처리 (공개 상태 확인 포함) - 최적화됨
  void _onStreamData(QuerySnapshot snapshot) async {
    if (!mounted || !_isUserAuthenticated) return;

    try {
      // 🚀 빈 결과 빠른 처리
      if (snapshot.docs.isEmpty) {
        if (!_isEntriesEqual(_userEntries, [])) {
          // 캐시 업데이트
          if (_user != null) {
            HistoryMemoryCache.setCachedEntries(_user!.uid, []);
            HistoryLocalCache.saveLocalCache(_user!.uid, []);
          }

          setState(() {
            _userEntries = [];
            _hasError = false;
            _isLoading = false;
          });

          Logger.debug('RelaxHistoryScreen: 실시간 업데이트 - 빈 목록');
        }
        return;
      }

      // 🚀 배치 처리: 모든 엔트리 ID를 한 번에 수집
      final entryIds = snapshot.docs.map((doc) => doc.id).toList();

      // 🚀 단일 쿼리로 모든 공개 엔트리 정보 가져오기
      Map<String, Map<String, dynamic>> publicEntriesMap = {};

      try {
        // Firestore의 'in' 쿼리는 최대 10개까지만 지원하므로 청크로 나누어 처리
        final chunks = <List<String>>[];
        for (int i = 0; i < entryIds.length; i += 10) {
          chunks.add(entryIds.sublist(
              i, i + 10 > entryIds.length ? entryIds.length : i + 10));
        }

        for (final chunk in chunks) {
          final publicSnapshot = await _firestore
              .collection('publicEntries')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();

          for (final doc in publicSnapshot.docs) {
            publicEntriesMap[doc.id] = doc.data();
          }
        }

        Logger.debug(
            'RelaxHistoryScreen: 실시간 배치로 공개 정보 로드됨 - ${publicEntriesMap.length}개');
      } catch (e) {
        Logger.warn('RelaxHistoryScreen: 실시간 배치 공개 상태 확인 오류 - $e');
      }

      // 🚀 빠른 데이터 조합
      final entries = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // 배치로 가져온 공개 정보 적용
        final publicData = publicEntriesMap[doc.id];
        if (publicData != null) {
          data['isPublic'] = true;
          data['likeCount'] = publicData['likeCount'] ?? 0;
          data['isLiked'] = publicData['isLiked'] ?? false;
          data['isBookmarked'] = publicData['isBookmarked'] ?? false;
        } else {
          // 비공개 엔트리의 기본값
          data['isPublic'] = false;
          data['likeCount'] = 0;
          data['isLiked'] = false;
          data['isBookmarked'] = false;
        }

        entries.add(data);
      }

      // 데이터가 실제로 변경된 경우에만 업데이트
      if (!_isEntriesEqual(_userEntries, entries)) {
        // 캐시 업데이트
        if (_user != null) {
          HistoryMemoryCache.setCachedEntries(_user!.uid, entries);
          HistoryLocalCache.saveLocalCache(_user!.uid, entries);
        }

        setState(() {
          _userEntries = entries;
          _hasError = false;
          _isLoading = false;
        });

        Logger.debug('RelaxHistoryScreen: 실시간 업데이트 - ${entries.length}개');
      } else {
        // 데이터가 동일해도 로딩 상태는 해제
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Logger.error('RelaxHistoryScreen: 스트림 데이터 처리 오류 - $e');
    }
  }

  /// 스트림 오류 처리
  void _onStreamError(error) {
    Logger.error('RelaxHistoryScreen: 스트림 오류 - $error');

    _isStreamActive = false;

    // 재연결 시도
    if (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      _reconnectAttempts++;
      Timer(Duration(seconds: _reconnectAttempts * 2), () {
        if (mounted && _isUserAuthenticated) {
          _setupRealtimeStream();
        }
      });
    }
  }

  /// 스트림 일시 정지
  void _pauseStreams() {
    if (_userEntriesSubscription != null) {
      _userEntriesSubscription!.pause();
      Logger.debug('RelaxHistoryScreen: 스트림 일시 정지됨');
    }
  }

  /// 스트림 재개
  void _resumeStreams() {
    if (_userEntriesSubscription != null &&
        _userEntriesSubscription!.isPaused) {
      _userEntriesSubscription!.resume();
      Logger.debug('RelaxHistoryScreen: 스트림 재개됨');
    }
  }

  /// 스트림 정리
  void _cleanupStreams() {
    _userEntriesSubscription?.cancel();
    _userEntriesSubscription = null;
    _streamInitialized = false;
    _isStreamActive = false;
    Logger.debug('RelaxHistoryScreen: 스트림 정리 완료');
  }

  // ============================================================================
  // 새로고침 및 데이터 관리
  // ============================================================================

  /// 수동 새로고침
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    // 최소 간격 체크
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) < MIN_REFRESH_INTERVAL) {
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      // 캐시 무효화
      if (_user != null) {
        HistoryMemoryCache.invalidateCache(_user!.uid);
      }

      // 최신 데이터 로드
      await _performFreshDataLoad();

      _lastRefreshTime = DateTime.now();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// 필요시 새로고침
  void _refreshIfNeeded() {
    if (_user == null) return;

    // 메모리 캐시가 유효하지 않으면 새로고침
    if (!HistoryMemoryCache.isCacheValid(_user!.uid)) {
      _loadFreshDataInBackground();
    }
  }

  // ============================================================================
  // 이벤트 처리
  // ============================================================================

  /// 이벤트 리스너 설정
  void _setupEventListeners() {
    // 엔트리 가시성 변경
    _entryVisibilitySubscription =
        eventBus.on(EventBus.entryVisibilityChanged, (data) {
      if (data is EntryVisibilityChangedEvent && mounted) {
        _invalidateCacheAndRefresh();
      }
    });

    // 엔트리 삭제
    _entryDeletedSubscription = eventBus.on(EventBus.entryDeleted, (data) {
      if (mounted) {
        if (data is Map<String, dynamic> &&
            data['entryId'] == _expandedEntryId) {
          setState(() => _expandedEntryId = null);
        }
        _invalidateCacheAndRefresh();
      }
    });

    // 엔트리 업데이트
    _entryUpdatedSubscription = eventBus.on(EventBus.entryUpdated, (data) {
      if (mounted) {
        _invalidateCacheAndRefresh();
      }
    });

    // 공개 상태 변경
    _publicStatusSubscription =
        eventBus.on(EventBus.publicStatusChangedEvent, (data) {
      if (data is PublicStatusChangedEvent && mounted) {
        _invalidateCacheAndRefresh();
      }
    });

    // 데이터 새로고침 필요
    _dataRefreshNeededSubscription =
        eventBus.on(EventBus.dataRefreshNeeded, (data) {
      if (mounted) {
        _invalidateCacheAndRefresh();
      }
    });
  }

  /// 이벤트 리스너 정리
  void _cleanupEventListeners() {
    _authStateSubscription?.cancel();
    _entryVisibilitySubscription?.cancel();
    _entryDeletedSubscription?.cancel();
    _entryUpdatedSubscription?.cancel();
    _publicStatusSubscription?.cancel();
    _dataRefreshNeededSubscription?.cancel();
  }

  /// 캐시 무효화 및 새로고침
  void _invalidateCacheAndRefresh() {
    if (_user != null) {
      HistoryMemoryCache.invalidateCache(_user!.uid);
    }
    _loadFreshDataInBackground();
  }

  // ============================================================================
  // 유틸리티 메서드들
  // ============================================================================

  /// 엔트리 리스트 동등성 비교
  bool _isEntriesEqual(
      List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i]['id'] != list2[i]['id']) return false;
      if (list1[i]['content'] != list2[i]['content']) return false;
      if (list1[i]['likeCount'] != list2[i]['likeCount']) return false;
    }

    return true;
  }

  /// Timestamp 필드 복원
  List<Map<String, dynamic>> _restoreTimestamps(
      List<Map<String, dynamic>> entries) {
    return entries.map((entry) {
      final restored = Map<String, dynamic>.from(entry);

      ['date', 'createdAt', 'updatedAt'].forEach((field) {
        if (restored[field] is int) {
          restored[field] =
              Timestamp.fromMillisecondsSinceEpoch(restored[field]);
        }
      });

      return restored;
    }).toList();
  }

  /// 오류 처리
  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  /// 확장된 엔트리 설정
  void _setExpandedEntry(String? entryId) {
    setState(() => _expandedEntryId = entryId);
  }

  /// 모든 카드를 확장 상태로 초기화 (히스토리 화면에서는 편집/삭제 버튼이 항상 보여야 함)
  void _initializeAllCardsExpanded() {
    // RelaxHistoryScreen에서는 사용자 자신의 기록만 보므로
    // 기본적으로 모든 카드가 확장된 상태여야 함
    // 이는 _buildEntriesList에서 isInitiallyExpanded: true로 처리됨
  }

  /// 엔트리 업데이트 처리
  void _handleEntryUpdate(String entryId, String newContent) {
    // Provider를 통해 엔트리 업데이트
    final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);
    relaxProvider.updateMoodEntry(entryId, newContent).then((_) {
      // 캐시 무효화 및 새로고침
      _invalidateCacheAndRefresh();
    }).catchError((error) {
      Logger.error('RelaxHistoryScreen: 엔트리 업데이트 오류 - $error');
      // 오류 스낵바 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('엔트리 업데이트 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// 엔트리 삭제 처리
  void _handleEntryDelete(String entryId) {
    // 삭제 확인 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('삭제 확인'),
        content: Text('이 기록을 삭제하시겠습니까? 삭제된 기록은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performEntryDelete(entryId);
            },
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 실제 엔트리 삭제 수행
  void _performEntryDelete(String entryId) {
    final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);
    relaxProvider.deleteMoodEntry(entryId).then((_) {
      // 확장된 엔트리가 삭제된 경우 상태 초기화
      if (_expandedEntryId == entryId) {
        setState(() => _expandedEntryId = null);
      }
      // 캐시 무효화 및 새로고침
      _invalidateCacheAndRefresh();
      // 성공 스낵바 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('기록이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }).catchError((error) {
      Logger.error('RelaxHistoryScreen: 엔트리 삭제 오류 - $error');
      // 오류 스낵바 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('기록 삭제 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// 공개 상태 변경 처리
  void _handlePublicStatusChange(String entryId, bool isPublic) {
    final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);

    // 1. 즉시 로컬 상태 업데이트 (Optimistic Update)
    final entryIndex =
        _userEntries.indexWhere((entry) => entry['id'] == entryId);
    if (entryIndex != -1) {
      setState(() {
        _userEntries[entryIndex]['isPublic'] = isPublic;
        // 비공개로 변경하면 좋아요/북마크 정보 초기화
        if (!isPublic) {
          _userEntries[entryIndex]['likeCount'] = 0;
          _userEntries[entryIndex]['isLiked'] = false;
          _userEntries[entryIndex]['isBookmarked'] = false;
        }
      });

      // 캐시도 즉시 업데이트
      if (_user != null) {
        HistoryMemoryCache.setCachedEntries(_user!.uid, _userEntries);
        HistoryLocalCache.saveLocalCache(_user!.uid, _userEntries);
      }
    }

    // 2. 서버 업데이트
    relaxProvider.updateEntryPublicStatus(entryId, isPublic).then((_) {
      // 성공 스낵바 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPublic
                ? '기록이 공개되었습니다. 오늘의 주제에서 다른 사람들이 볼 수 있습니다.'
                : '기록이 비공개로 변경되었습니다. 이제 나만 볼 수 있습니다.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }).catchError((error) {
      Logger.error('RelaxHistoryScreen: 공개 상태 변경 오류 - $error');

      // 실패 시 로컬 상태 롤백
      if (entryIndex != -1) {
        setState(() {
          _userEntries[entryIndex]['isPublic'] = !isPublic;
        });
      }

      // 오류 스낵바 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('공개 상태 변경 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  // ============================================================================
  // UI 빌드
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Scaffold(
      /*
      appBar: AppBar(
        title: Text(isKorean ? '내 기록' : 'My Entries'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 실시간 상태 표시
          if (_isStreamActive)
            Container(
              margin: EdgeInsets.only(right: 16),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    isKorean ? '실시간' : 'Live',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      */
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _buildBody(isKorean),
      ),
    );
  }

  /// 본문 위젯 빌드
  Widget _buildBody(bool isKorean) {
    // 오류 상태
    if (_hasError) {
      return _buildErrorWidget(isKorean);
    }

    // 로딩 상태 (캐시도 없는 경우)
    if (_isLoading && _userEntries.isEmpty) {
      return _buildLoadingWidget(isKorean);
    }

    // 인증되지 않은 상태
    if (!_isUserAuthenticated) {
      return _buildUnauthenticatedWidget(isKorean);
    }

    // 데이터 없음
    if (_userEntries.isEmpty && !_isLoading) {
      return _buildEmptyWidget(isKorean);
    }

    // 엔트리 리스트
    return _buildEntriesList(isKorean);
  }

  /// 오류 위젯
  Widget _buildErrorWidget(bool isKorean) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? (isKorean ? '오류가 발생했습니다.' : 'An error occurred.'),
            style: TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleRefresh,
            icon: Icon(Icons.refresh),
            label: Text(isKorean ? '다시 시도' : 'Retry'),
          ),
        ],
      ),
    );
  }

  /// 로딩 위젯
  Widget _buildLoadingWidget(bool isKorean) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            isKorean ? '기록을 불러오는 중...' : 'Loading entries...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 인증되지 않은 상태 위젯
  Widget _buildUnauthenticatedWidget(bool isKorean) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            isKorean ? '로그인이 필요합니다.' : 'Login required.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyWidget(bool isKorean) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            isKorean ? '아직 기록이 없습니다.' : 'No entries yet.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            isKorean ? '첫 번째 기록을 작성해보세요!' : 'Write your first entry!',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleRefresh,
            icon: Icon(Icons.refresh),
            label: Text(isKorean ? '새로고침' : 'Refresh'),
          ),
        ],
      ),
    );
  }

  /// 엔트리 리스트 위젯
  Widget _buildEntriesList(bool isKorean) {
    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _userEntries.length,
          itemBuilder: (context, index) {
            final entry = _userEntries[index];
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: UnifiedEntryCard(
                entry: entry,
                expandable: true,
                isInitiallyExpanded: true, // 기본적으로 확장된 상태로 변경
                useExpandTracker: true,
                isTrackedAsExpanded: _expandedEntryId == entry['id'],
                onExpand: (entryId) => _setExpandedEntry(entryId),
                onCollapse: (entryId) => _setExpandedEntry(null),
                onUpdate: (entryId, newContent) {
                  // 엔트리 업데이트 처리
                  _handleEntryUpdate(entryId, newContent);
                },
                onDelete: (entryId) {
                  // 엔트리 삭제 처리
                  _handleEntryDelete(entryId);
                },
                onPublicChanged: (entryId, isPublic) {
                  // 공개 상태 변경 처리
                  _handlePublicStatusChange(entryId, isPublic);
                },
                showBookmark: true,
                showTopicBadge: true,
                compact: false, // 버튼들이 잘 보이도록 compact 모드 비활성화
              ),
            );
          },
        ),

        // 새로고침 중 표시
        if (_isRefreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    isKorean ? '새로고침 중...' : 'Refreshing...',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
