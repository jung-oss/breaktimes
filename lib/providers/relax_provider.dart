import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_models.dart';
import '../utils/event_bus.dart';
import 'dart:async';

// 필터링 옵션 정의를 위한 열거형
enum PublicEntrySortOption {
  latest, // 최신순
  popular, // 좋아요순
}

// 작업 상태 추적을 위한 열거형
enum OperationStatus {
  pending, // 로컬 업데이트 완료, 서버 저장 대기
  syncing, // 서버 동기화 중
  synced, // 서버 동기화 완료
  failed, // 동기화 실패
}

// 로컬 작업 상태를 추적하기 위한 클래스
class PendingOperation {
  final String id;
  final String
      type; // 'add', 'update', 'delete', 'toggle_like', 'toggle_bookmark'
  final Map<String, dynamic> data;
  final DateTime timestamp;
  OperationStatus status;
  int retryCount;

  PendingOperation({
    required this.id,
    required this.type,
    required this.data,
    DateTime? timestamp,
    this.status = OperationStatus.pending,
    this.retryCount = 0,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 실시간 스트림 최적화가 적용된 RelaxProvider
///
/// 주요 개선사항:
/// 1. Firestore 실시간 스트림으로 자동 동기화
/// 2. 변경된 문서만 선별적 업데이트
/// 3. 스트림 상태 관리 및 재연결 로직
/// 4. 메모리 효율적인 스트림 구독 관리
/// 5. ✅ LocaleProvider에서 주제 정보 받아서 사용
class RelaxProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ TopicService 제거 - LocaleProvider에서 관리

  // 상태 변수 - 주제 관련 변수들을 LocaleProvider에서 받아서 사용
  String? _dailyTopic;
  String? _topicId;
  String? _currentLocale;

  bool _hasWrittenToday = false;
  List<Map<String, dynamic>> _userEntries = [];
  List<Map<String, dynamic>> _publicEntries = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasMorePublicData = true;
  DocumentSnapshot? _lastDocument;

  // Optimistic Updates를 위한 상태 관리
  final Map<String, PendingOperation> _pendingOperations = {};
  final Map<String, Timer> _retryTimers = {};
  Timer? _batchSyncTimer;

  // 필터링 상태 변수
  PublicEntrySortOption _sortOption = PublicEntrySortOption.latest;
  bool _isChangingFilter = false;

  // ============================================================================
  // 실시간 스트림 관리 변수들
  // ============================================================================

  // 스트림 구독들
  StreamSubscription<QuerySnapshot>? _userEntriesSubscription;
  StreamSubscription<QuerySnapshot>? _publicEntriesSubscription;
  StreamSubscription<QuerySnapshot>? _todayEntrySubscription;
  StreamSubscription? _visibilitySubscription;
  StreamSubscription? _localeChangeSubscription;

  // 스트림 상태 관리
  bool _isUserStreamActive = false;
  bool _isPublicStreamActive = false;
  bool _streamInitialized = false;
  DateTime? _lastStreamReconnect;
  int _reconnectAttempts = 0;

  // 스트림 설정
  static const int STREAM_RECONNECT_DELAY_SECONDS = 5;
  static const int MAX_RECONNECT_ATTEMPTS = 3;
  static const int STREAM_IDLE_TIMEOUT_MINUTES = 30; // 30분 후 스트림 비활성화
  static const int PUBLIC_ENTRIES_LIMIT = 20; // 실시간 로딩할 공개 글 수

  // 페이지네이션 상태 (실시간 스트림 + 추가 로딩 혼합)
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastLoadedDoc;

  // 필터 상태 저장을 위한 키
  static const String PREF_SORT_OPTION = 'relax_sort_option';
  static const int MAX_RETRY_COUNT = 3;
  static const Duration BATCH_SYNC_DELAY = Duration(milliseconds: 500);

  // 게터들
  String? get dailyTopic => _dailyTopic;
  String? get topicId => _topicId;
  bool get hasWrittenToday => _hasWrittenToday;
  List<Map<String, dynamic>> get userEntries => _userEntries;
  List<Map<String, dynamic>> get publicEntries => _publicEntries;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get hasMorePublicData => _hasMorePublicData;
  PublicEntrySortOption get sortOption => _sortOption;
  bool get isChangingFilter => _isChangingFilter;

  // 대기 중인 작업 수 확인 (UI에서 동기화 상태 표시용)
  int get pendingOperationsCount => _pendingOperations.length;
  bool get hasPendingOperations => _pendingOperations.isNotEmpty;

  // 스트림 상태 확인 (디버깅/모니터링용)
  bool get isStreamActive => _isUserStreamActive || _isPublicStreamActive;
  bool get streamInitialized => _streamInitialized;

  RelaxProvider() {
    // 이벤트 버스 구독
    _visibilitySubscription = eventBus.on(
      EventBus.entryVisibilityChanged,
      (event) {
        if (event is EntryVisibilityChangedEvent) {
          _handleVisibilityChanged(event.entryId, event.isPublic);
        }
      },
    );

    // ✅ LocaleProvider의 언어/주제 변경 이벤트 구독
    _localeChangeSubscription = eventBus.on('locale_changed', (data) {
      final newLocale = data['newLocale'] as String;
      final newTopic = data['topic'] as String?;
      final newTopicId = data['topicId'] as String?;

      debugPrint('RelaxProvider: 언어/주제 변경 이벤트 수신');
      debugPrint('  - 언어: $newLocale');
      debugPrint('  - 주제: $newTopic');
      debugPrint('  - 주제ID: $newTopicId');

      // 주제 정보 업데이트
      _dailyTopic = newTopic;
      _topicId = newTopicId;
      _currentLocale = newLocale;

      // 공개 글 목록 새로고침 (주제가 바뀌었으므로)
      Future.microtask(() async {
        try {
          await _reinitializePublicStream();
        } catch (e) {
          debugPrint('RelaxProvider: 공개 글 새로고침 실패 - $e');
        }
      });

      notifyListeners();
    });

    // ✅ LocaleProvider 초기화 완료 이벤트 구독
    final localeInitSubscription =
        eventBus.on('locale_topic_initialized', (data) {
      if (data['isInitialLoad'] == true) {
        final locale = data['locale'] as String;
        final topic = data['topic'] as String?;
        final topicId = data['topicId'] as String?;

        debugPrint('RelaxProvider: LocaleProvider 초기화 완료 감지');
        debugPrint('  - 언어: $locale');
        debugPrint('  - 주제: $topic');
        debugPrint('  - 주제ID: $topicId');

        _dailyTopic = topic;
        _topicId = topicId;
        _currentLocale = locale;

        // 초기화 진행
        Future.microtask(() => initialize());
      }
    });

    // 초기 설정 로드
    _loadSavedSortOption();
  }

  /// ✅ LocaleProvider에서 주제 정보 업데이트 (main.dart의 ProxyProvider에서 호출)
  void updateFromLocaleProvider(String? topic, String? topicId, String locale) {
    if (_dailyTopic != topic ||
        _topicId != topicId ||
        _currentLocale != locale) {
      debugPrint('RelaxProvider: LocaleProvider로부터 주제 정보 업데이트');
      debugPrint('  - 주제: $topic');
      debugPrint('  - 주제ID: $topicId');
      debugPrint('  - 언어: $locale');

      final topicChanged = _topicId != topicId;

      _dailyTopic = topic;
      _topicId = topicId;
      _currentLocale = locale;

      // 주제가 변경된 경우 공개 글 목록 새로고침
      if (topicChanged) {
        Future.microtask(() async {
          try {
            await _reinitializePublicStream();
          } catch (e) {
            debugPrint('RelaxProvider: 공개 글 새로고침 실패 - $e');
          }
        });
      }

      notifyListeners();
    }
  }

  // ============================================================================
  // 초기화 및 기본 설정
  // ============================================================================

  // 저장된 정렬 옵션 로드
  Future<void> _loadSavedSortOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOptionIndex = prefs.getInt(PREF_SORT_OPTION);

      if (savedOptionIndex != null &&
          savedOptionIndex < PublicEntrySortOption.values.length) {
        _sortOption = PublicEntrySortOption.values[savedOptionIndex];
      }
    } catch (e) {
      debugPrint('정렬 옵션 로드 오류: $e');
    }
  }

  // 정렬 옵션 저장
  Future<void> _saveSortOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PREF_SORT_OPTION, _sortOption.index);
    } catch (e) {
      debugPrint('정렬 옵션 저장 오류: $e');
    }
  }

  @override
  void dispose() {
    // 모든 스트림 구독 해제
    _disposeStreams();

    // 타이머 정리
    _visibilitySubscription?.cancel();
    _localeChangeSubscription?.cancel();
    _batchSyncTimer?.cancel();
    _retryTimers.values.forEach((timer) => timer.cancel());

    super.dispose();
  }

  /// 모든 스트림 구독 해제
  void _disposeStreams() {
    _userEntriesSubscription?.cancel();
    _publicEntriesSubscription?.cancel();
    _todayEntrySubscription?.cancel();

    _isUserStreamActive = false;
    _isPublicStreamActive = false;
    _streamInitialized = false;

    debugPrint('RelaxProvider: 모든 스트림 구독 해제');
  }

  // 필터 변경 메서드
  Future<void> changeSortOption(PublicEntrySortOption option) async {
    if (_sortOption != option && !_isChangingFilter) {
      _isChangingFilter = true;
      notifyListeners();

      _sortOption = option;
      await _saveSortOption();

      // 필터가 변경되면 실시간 스트림도 재설정
      await _reinitializePublicStream();

      _isChangingFilter = false;
      notifyListeners();
    }
  }

  /// ✅ 간소화된 초기화 메서드 (주제 로드 제거)
  Future<void> initialize({bool forceReload = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('RelaxProvider: 초기화 시작');
      debugPrint('  - 현재 주제: $_dailyTopic');
      debugPrint('  - 현재 언어: $_currentLocale');

      final user = _auth.currentUser;
      if (user != null) {
        // 오늘 작성한 글 확인
        await _checkTodayEntry();

        // 실시간 스트림 초기화
        await _initializeStreams();
      }
    } catch (e) {
      debugPrint('RelaxProvider 초기화 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // 실시간 스트림 초기화 및 관리
  // ============================================================================

  /// 실시간 스트림들 초기화
  Future<void> _initializeStreams() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      debugPrint('RelaxProvider: 실시간 스트림 초기화 시작');

      // 1. 사용자 엔트리 스트림 설정
      await _setupUserEntriesStream(user.uid);

      // 2. 오늘 글 작성 여부에 따라 공개 글 스트림 설정
      if (_hasWrittenToday) {
        await _setupPublicEntriesStream();
      }

      // 3. 오늘 글 작성 여부 실시간 모니터링
      _setupTodayEntryStream(user.uid);

      _streamInitialized = true;
      debugPrint('RelaxProvider: 실시간 스트림 초기화 완료');
    } catch (e) {
      debugPrint('RelaxProvider: 스트림 초기화 오류 - $e');
      // 스트림 실패 시 폴백으로 기존 방식 사용
      await _fallbackToStaticLoading();
    }
  }

  /// 사용자 엔트리 실시간 스트림 설정
  Future<void> _setupUserEntriesStream(String userId) async {
    try {
      // 기존 구독 해제
      _userEntriesSubscription?.cancel();

      debugPrint('RelaxProvider: 사용자 엔트리 스트림 설정 시작');

      _userEntriesSubscription = _firestore
          .collection('publicEntries')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots()
          .listen(
            _onUserEntriesChanged,
            onError: _onUserStreamError,
            onDone: () => debugPrint('사용자 엔트리 스트림 종료'),
          );

      _isUserStreamActive = true;
      debugPrint('RelaxProvider: 사용자 엔트리 스트림 활성화');
    } catch (e) {
      debugPrint('RelaxProvider: 사용자 엔트리 스트림 설정 오류 - $e');
      _isUserStreamActive = false;
    }
  }

  /// 공개 엔트리 실시간 스트림 설정
  Future<void> _setupPublicEntriesStream() async {
    try {
      // 기존 구독 해제
      _publicEntriesSubscription?.cancel();

      debugPrint('RelaxProvider: 공개 엔트리 스트림 설정 시작');

      Query query = _firestore.collection('publicEntries');

      // 인덱스 오류 방지를 위한 쿼리 최적화
      bool useTopicFilter = false;

      // 기본 주제(default_0)가 아닌 경우에만 필터 적용
      if (_topicId != null && _topicId!.isNotEmpty && _topicId != 'default_0') {
        useTopicFilter = true;
        query = query.where('topicId', isEqualTo: _topicId);
        debugPrint('RelaxProvider: 주제 필터 적용 - $_topicId');
      } else {
        debugPrint('RelaxProvider: 기본 주제 사용, 필터 없이 전체 로드');
      }

      // 정렬 방식 적용 (인덱스 고려)
      switch (_sortOption) {
        case PublicEntrySortOption.latest:
          if (useTopicFilter) {
            // 주제 필터가 있을 때는 단순 정렬만 (인덱스 필요)
            try {
              query = query.orderBy('date', descending: true);
            } catch (e) {
              debugPrint('RelaxProvider: 복합 인덱스 없음, 단순 쿼리로 변경');
              // 인덱스가 없으면 주제 필터 제거하고 전체에서 정렬
              query = _firestore
                  .collection('publicEntries')
                  .orderBy('date', descending: true);
              useTopicFilter = false;
            }
          } else {
            query = query.orderBy('date', descending: true);
          }
          break;
        case PublicEntrySortOption.popular:
          if (useTopicFilter) {
            try {
              query = query.orderBy('likeCount', descending: true);
            } catch (e) {
              debugPrint('RelaxProvider: 복합 인덱스 없음, 단순 쿼리로 변경');
              query = _firestore
                  .collection('publicEntries')
                  .orderBy('likeCount', descending: true);
              useTopicFilter = false;
            }
          } else {
            query = query.orderBy('likeCount', descending: true);
          }
          break;
      }

      // 실시간으로 처리할 데이터 양 제한
      query = query.limit(PUBLIC_ENTRIES_LIMIT);

      _publicEntriesSubscription = query.snapshots().listen(
            (snapshot) => _onPublicEntriesChanged(snapshot, useTopicFilter),
            onError: _onPublicStreamError,
            onDone: () => debugPrint('공개 엔트리 스트림 종료'),
          );

      _isPublicStreamActive = true;
      debugPrint('RelaxProvider: 공개 엔트리 스트림 활성화 (주제필터: $useTopicFilter)');
    } catch (e) {
      debugPrint('RelaxProvider: 공개 엔트리 스트림 설정 오류 - $e');
      _isPublicStreamActive = false;

      // 스트림 설정 실패 시 폴백으로 정적 로딩
      Future.delayed(Duration(seconds: 2), () {
        _fallbackToStaticLoading();
      });
    }
  }

  /// 오늘 글 작성 여부 실시간 모니터링
  void _setupTodayEntryStream(String userId) {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      _todayEntrySubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('moods')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        final hadWrittenToday = _hasWrittenToday;
        _hasWrittenToday = snapshot.docs.isNotEmpty;

        // 상태가 변경된 경우
        if (hadWrittenToday != _hasWrittenToday) {
          debugPrint('RelaxProvider: 오늘 글 작성 상태 변경 - $_hasWrittenToday');

          if (_hasWrittenToday && !_isPublicStreamActive) {
            // 글을 처음 작성한 경우 공개 스트림 시작
            _setupPublicEntriesStream();
          } else if (!_hasWrittenToday && _isPublicStreamActive) {
            // 글을 모두 삭제한 경우 공개 스트림 중단
            _publicEntriesSubscription?.cancel();
            _isPublicStreamActive = false;
            _publicEntries.clear();
          }

          notifyListeners();
        }
      });

      debugPrint('RelaxProvider: 오늘 글 작성 모니터링 스트림 설정');
    } catch (e) {
      debugPrint('RelaxProvider: 오늘 글 모니터링 스트림 설정 오류 - $e');
    }
  }

  // ============================================================================
  // 스트림 이벤트 핸들러들
  // ============================================================================

  /// 사용자 엔트리 스트림 변경 처리
  void _onUserEntriesChanged(QuerySnapshot snapshot) async {
    try {
      debugPrint('RelaxProvider: 사용자 엔트리 스트림 변경감지 - ${snapshot.docs.length}개');

      final user = _auth.currentUser;
      if (user == null) return;

      final newEntries = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // 실시간으로 좋아요/북마크 상태도 확인 (비동기)
        _updateEntryMetadata(data, user.uid);

        newEntries.add(data);
      }

      // 변경 사항만 감지하여 UI 업데이트 최소화
      if (!_isListEqual(_userEntries, newEntries)) {
        _userEntries = newEntries;
        notifyListeners();

        debugPrint('RelaxProvider: 사용자 엔트리 업데이트됨 - ${newEntries.length}개');
      }
    } catch (e) {
      debugPrint('RelaxProvider: 사용자 엔트리 스트림 처리 오류 - $e');
    }
  }

  /// 공개 엔트리 스트림 변경 처리 (주제 필터링 지원)
  void _onPublicEntriesChanged(QuerySnapshot snapshot,
      [bool hasTopicFilter = false]) async {
    try {
      debugPrint('RelaxProvider: 공개 엔트리 스트림 변경감지 - ${snapshot.docs.length}개');

      final user = _auth.currentUser;
      if (user == null) return;

      final newEntries = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // 주제 필터가 없는 경우 클라이언트 측에서 필터링
        if (!hasTopicFilter &&
            _topicId != null &&
            _topicId!.isNotEmpty &&
            _topicId != 'default_0') {
          final entryTopicId = data['topicId'] as String?;
          if (entryTopicId != _topicId) {
            continue; // 현재 주제와 다르면 건너뛰기
          }
        }

        // 실시간으로 좋아요/북마크 상태도 확인 (비동기)
        _updateEntryMetadata(data, user.uid);

        newEntries.add(data);
      }

      // 스트림으로 로드된 항목들만 교체 (기존 더보기로 로드된 항목은 유지)
      final streamEntries = newEntries;
      final additionalEntries = _publicEntries.length > PUBLIC_ENTRIES_LIMIT
          ? _publicEntries.sublist(PUBLIC_ENTRIES_LIMIT)
          : <Map<String, dynamic>>[];

      final combinedEntries = [...streamEntries, ...additionalEntries];

      // 변경 사항만 감지하여 UI 업데이트 최소화
      if (!_isListEqual(_publicEntries, combinedEntries)) {
        _publicEntries = combinedEntries;
        _hasMorePublicData = snapshot.docs.length >= PUBLIC_ENTRIES_LIMIT;
        notifyListeners();

        debugPrint(
            'RelaxProvider: 공개 엔트리 업데이트됨 - ${combinedEntries.length}개 (필터링 후: ${streamEntries.length}개)');
      }
    } catch (e) {
      debugPrint('RelaxProvider: 공개 엔트리 스트림 처리 오류 - $e');
    }
  }

  /// 엔트리 메타데이터 업데이트 (좋아요/북마크 상태)
  Future<void> _updateEntryMetadata(
      Map<String, dynamic> data, String userId) async {
    try {
      final docId = data['id'] as String;

      // 좋아요 상태 확인 (백그라운드에서)
      Future(() async {
        try {
          final likeDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('likes')
              .doc(docId)
              .get();
          data['isLiked'] = likeDoc.exists;
        } catch (e) {
          data['isLiked'] = false;
        }
      });

      // 북마크 상태 확인 (백그라운드에서)
      Future(() async {
        try {
          final bookmarkDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('bookmarks')
              .doc(docId)
              .get();
          data['isBookmarked'] = bookmarkDoc.exists;
        } catch (e) {
          data['isBookmarked'] = false;
        }
      });
    } catch (e) {
      // 메타데이터 로드 실패해도 메인 데이터는 유지
      data['isLiked'] = false;
      data['isBookmarked'] = false;
    }
  }

  /// 스트림 오류 처리 - 사용자 엔트리
  void _onUserStreamError(dynamic error) {
    debugPrint('RelaxProvider: 사용자 엔트리 스트림 오류 - $error');
    _isUserStreamActive = false;

    // 재연결 시도
    _attemptStreamReconnection('user');
  }

  /// 스트림 오류 처리 - 공개 엔트리 (개선된 오류 처리)
  void _onPublicStreamError(dynamic error) {
    debugPrint('RelaxProvider: 공개 엔트리 스트림 오류 - $error');
    _isPublicStreamActive = false;

    // 인덱스 오류인 경우 즉시 폴백
    if (error.toString().contains('failed-precondition') ||
        error.toString().contains('requires an index')) {
      debugPrint('RelaxProvider: Firestore 인덱스 누락으로 정적 로딩으로 전환');
      _fallbackToStaticLoading();
      return;
    }

    // 기타 오류는 재연결 시도
    _attemptStreamReconnection('public');
  }

  /// 스트림 재연결 시도
  void _attemptStreamReconnection(String streamType) {
    if (_reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
      debugPrint('RelaxProvider: 최대 재연결 시도 횟수 초과, 정적 로딩으로 전환');
      _fallbackToStaticLoading();
      return;
    }

    _reconnectAttempts++;
    final delay =
        Duration(seconds: STREAM_RECONNECT_DELAY_SECONDS * _reconnectAttempts);

    debugPrint(
        'RelaxProvider: $streamType 스트림 재연결 시도 $_reconnectAttempts/${MAX_RECONNECT_ATTEMPTS} - ${delay.inSeconds}초 후');

    Timer(delay, () async {
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        if (streamType == 'user') {
          await _setupUserEntriesStream(user.uid);
        } else if (streamType == 'public') {
          await _setupPublicEntriesStream();
        }

        // 재연결 성공 시 재시도 카운터 리셋
        _reconnectAttempts = 0;
        _lastStreamReconnect = DateTime.now();
      } catch (e) {
        debugPrint('RelaxProvider: $streamType 스트림 재연결 실패 - $e');
      }
    });
  }

  /// 스트림 실패 시 정적 로딩으로 폴백
  Future<void> _fallbackToStaticLoading() async {
    debugPrint('RelaxProvider: 정적 로딩 모드로 전환');

    try {
      await loadUserEntries();

      if (_hasWrittenToday) {
        await _loadPublicEntries(refresh: true);
      }
    } catch (e) {
      debugPrint('RelaxProvider: 정적 로딩 폴백 오류 - $e');
    }
  }

  /// 공개 스트림 재초기화 (필터 변경 시)
  Future<void> _reinitializePublicStream() async {
    if (_isPublicStreamActive) {
      _publicEntriesSubscription?.cancel();
      _isPublicStreamActive = false;
    }

    if (_hasWrittenToday) {
      await _setupPublicEntriesStream();
    }
  }

  // ============================================================================
  // 유틸리티 메서드들
  // ============================================================================

  /// 리스트 동등성 비교 (변경 감지 최적화)
  bool _isListEqual(
      List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i]['id'] != list2[i]['id']) return false;
      // 주요 필드들만 비교하여 성능 최적화
      if (list1[i]['content'] != list2[i]['content']) return false;
      if (list1[i]['likeCount'] != list2[i]['likeCount']) return false;
    }

    return true;
  }

  // ============================================================================
  // 추가 데이터 로딩 (스트림 + 페이지네이션 혼합)
  // ============================================================================

  /// 더 많은 공개 글 로드 (스트림과 함께 사용)
  Future<void> loadMorePublicEntries() async {
    if (_isLoadingMore || !_hasMorePublicData) return;

    _isLoadingMore = true;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      Query query = _firestore.collection('publicEntries');

      if (_topicId != null && _topicId!.isNotEmpty) {
        query = query.where('topicId', isEqualTo: _topicId);
      }

      switch (_sortOption) {
        case PublicEntrySortOption.latest:
          query = query.orderBy('date', descending: true);
          break;
        case PublicEntrySortOption.popular:
          query = query.orderBy('likeCount', descending: true);
          break;
      }

      // 스트림 이후 문서부터 로드
      if (_publicEntries.length >= PUBLIC_ENTRIES_LIMIT) {
        final lastStreamDoc = _publicEntries[PUBLIC_ENTRIES_LIMIT - 1];
        final timestamp = lastStreamDoc['date'] as Timestamp?;
        if (timestamp != null) {
          query = query.startAfter([timestamp]);
        }
      }

      query = query.limit(10);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMorePublicData = false;
        return;
      }

      final newEntries = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // 메타데이터 업데이트
        await _updateEntryMetadata(data, user.uid);
        newEntries.add(data);
      }

      // 기존 데이터에 추가
      _publicEntries.addAll(newEntries);

      if (snapshot.docs.length < 10) {
        _hasMorePublicData = false;
      }

      notifyListeners();
      debugPrint('RelaxProvider: 추가 공개 글 ${newEntries.length}개 로드됨');
    } catch (e) {
      debugPrint('RelaxProvider: 추가 공개 글 로드 오류 - $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  // ============================================================================
  // 기존 메서드들 (최적화 적용)
  // ============================================================================

  /// ✅ 모든 데이터 새로고침 (주제 로드 제거)
  Future<void> refreshAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 주제는 LocaleProvider에서 관리하므로 여기서는 로드하지 않음
      await _checkTodayEntry();

      // 스트림이 활성화되어 있으면 스트림이 자동으로 데이터를 업데이트
      if (!_streamInitialized ||
          (!_isUserStreamActive && !_isPublicStreamActive)) {
        // 스트림이 비활성화된 경우에만 수동 로드
        await loadUserEntries();
        if (_hasWrittenToday) {
          await _loadPublicEntries(refresh: true);
        }
      }
    } catch (e) {
      debugPrint('데이터 새로고침 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 오늘 작성한 글이 있는지 확인
  Future<void> _checkTodayEntry() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _hasWrittenToday = false;
        return;
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('moods')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      _hasWrittenToday = snapshot.docs.isNotEmpty;
      debugPrint('오늘 작성한 글 여부: $_hasWrittenToday');
    } catch (e) {
      debugPrint('오늘 글 확인 오류: $e');
      _hasWrittenToday = false;
    }
  }

  // 사용자 감정 기록 로드 (폴백용)
  Future<void> loadUserEntries() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _userEntries = [];
        return;
      }

      final snapshot = await _firestore
          .collection('publicEntries')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      final entries = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // 좋아요 상태 확인
        final likeDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('likes')
            .doc(doc.id)
            .get();

        data['isLiked'] = likeDoc.exists;

        // 북마크 상태 확인
        final bookmarkDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('bookmarks')
            .doc(doc.id)
            .get();

        data['isBookmarked'] = bookmarkDoc.exists;

        entries.add(data);
      }

      _userEntries = entries;

      debugPrint('${_userEntries.length}개의 사용자 글 로드됨');
      notifyListeners();
    } catch (e) {
      debugPrint('사용자 글 로드 오류: $e');
    }
  }

  Future<void> _loadUserEntries() => loadUserEntries();

  // 공개 글 로드 메서드 (폴백용)
  Future<void> _loadPublicEntries({bool refresh = false}) async {
    if (refresh) {
      _publicEntries.clear();
      _lastDocument = null;
      _hasMorePublicData = true;
    }

    if (!_hasMorePublicData) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      Query query = _firestore.collection('publicEntries');

      if (_topicId != null && _topicId!.isNotEmpty) {
        query = query.where('topicId', isEqualTo: _topicId);
        debugPrint('주제($_topicId)와 일치하는 공개 글만 로드합니다.');
      }

      switch (_sortOption) {
        case PublicEntrySortOption.latest:
          query = query.orderBy('date', descending: true);
          debugPrint('정렬 방식: 최신순');
          break;
        case PublicEntrySortOption.popular:
          query = query.orderBy('likeCount', descending: true);
          debugPrint('정렬 방식: 좋아요순');
          break;
      }

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      query = query.limit(10);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMorePublicData = false;
        debugPrint('${_publicEntries.length}개의 공개 글을 로드했습니다.');
        notifyListeners();
        return;
      }

      final List<Map<String, dynamic>> newEntries = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          // 좋아요 상태 확인
          final likeDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('likes')
              .doc(doc.id)
              .get();

          data['isLiked'] = likeDoc.exists;

          // 북마크 상태 확인
          final bookmarkDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('bookmarks')
              .doc(doc.id)
              .get();

          data['isBookmarked'] = bookmarkDoc.exists;

          newEntries.add(data);
        } catch (e) {
          debugPrint('공개 글 처리 오류: $e');
          continue;
        }
      }

      _publicEntries.addAll(newEntries);
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      if (snapshot.docs.length < 10) {
        _hasMorePublicData = false;
      }

      debugPrint('${newEntries.length}개의 공개 글을 로드했습니다.');
      notifyListeners();
    } catch (e) {
      debugPrint('공개 글 로드 오류: $e');
    }
  }

  // ============================================================================
  // OPTIMISTIC UPDATES 핵심 구현부 (기존 코드 유지)
  // ============================================================================

  /// 감정 기록 추가 - Optimistic Updates 적용
  Future<bool> addMoodEntry({
    required String mood,
    required String content,
    required String topicId,
    required String topic,
    required bool isPublic,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 1. 즉시 로컬 상태 업데이트 (Optimistic Update)
    final now = DateTime.now();
    final tempId = 'temp_${now.millisecondsSinceEpoch}';

    final optimisticEntry = {
      'id': tempId,
      'userId': user.uid,
      'date': Timestamp.fromDate(now),
      'mood': mood,
      'content': content,
      'topic': topic,
      'topicId': topicId,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': null,
      'username': user.displayName ?? '나비잠',
      'userPhotoURL': user.photoURL,
      'likeCount': 0,
      'isLiked': false,
      'isBookmarked': false,
      '_isPending': true, // 임시 상태 표시
    };

    // 즉시 UI 업데이트
    _hasWrittenToday = true;
    _userEntries.insert(0, optimisticEntry);
    if (isPublic) {
      _publicEntries.insert(0, optimisticEntry);
    }

    // UI 즉시 반영
    notifyListeners();

    // 스트림이 비활성화되어 있고 처음 글을 작성한 경우 공개 스트림 시작
    if (_hasWrittenToday && !_isPublicStreamActive && isPublic) {
      _setupPublicEntriesStream();
    }

    // 이벤트 발생 (다른 화면들도 즉시 업데이트)
    eventBus.fire(EventBus.entryAdded, EntryAddedEvent(entry: optimisticEntry));

    // 2. 백그라운드에서 서버 저장 작업 추가
    final realId = now.millisecondsSinceEpoch.toString();
    final serverEntry = Map<String, dynamic>.from(optimisticEntry);
    serverEntry['id'] = realId;
    serverEntry.remove('_isPending');

    _addPendingOperation(PendingOperation(
      id: tempId,
      type: 'add',
      data: {
        'tempId': tempId,
        'realId': realId,
        'entry': serverEntry,
        'isPublic': isPublic,
      },
    ));

    // 배치 동기화 예약
    _scheduleBatchSync();

    return true;
  }

  /// 감정 기록 삭제 - Optimistic Updates 적용
  Future<bool> deleteMoodEntry(String entryId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 1. 즉시 로컬 상태 업데이트
    final userIndex =
        _userEntries.indexWhere((entry) => entry['id'] == entryId);
    final publicIndex =
        _publicEntries.indexWhere((entry) => entry['id'] == entryId);

    Map<String, dynamic>? deletedUserEntry;
    Map<String, dynamic>? deletedPublicEntry;

    if (userIndex != -1) {
      deletedUserEntry = _userEntries[userIndex];
      _userEntries.removeAt(userIndex);
    }

    if (publicIndex != -1) {
      deletedPublicEntry = _publicEntries[publicIndex];
      _publicEntries.removeAt(publicIndex);
    }

    // 오늘 작성 여부 재확인
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _hasWrittenToday = _userEntries.any((entry) {
      final entryDate = (entry['date'] as Timestamp).toDate();
      final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
      return entryDay.isAtSameMomentAs(today);
    });

    // 즉시 UI 업데이트
    notifyListeners();

    // 이벤트 발생
    eventBus.fire(
        EventBus.entryDeleted, {'entryId': entryId, 'entry': deletedUserEntry});

    // 2. 백그라운드에서 서버 삭제 작업 추가
    _addPendingOperation(PendingOperation(
      id: entryId,
      type: 'delete',
      data: {
        'entryId': entryId,
        'userEntry': deletedUserEntry,
        'publicEntry': deletedPublicEntry,
      },
    ));

    _scheduleBatchSync();
    return true;
  }

  /// 감정 기록 업데이트 - Optimistic Updates 적용
  Future<bool> updateMoodEntry(String entryId, String newContent) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 1. 즉시 로컬 상태 업데이트
    final now = DateTime.now();

    final userIndex =
        _userEntries.indexWhere((entry) => entry['id'] == entryId);
    if (userIndex != -1) {
      _userEntries[userIndex]['content'] = newContent;
      _userEntries[userIndex]['updatedAt'] = Timestamp.fromDate(now);
    }

    final publicIndex =
        _publicEntries.indexWhere((entry) => entry['id'] == entryId);
    if (publicIndex != -1) {
      _publicEntries[publicIndex]['content'] = newContent;
      _publicEntries[publicIndex]['updatedAt'] = Timestamp.fromDate(now);
    }

    // 즉시 UI 업데이트
    notifyListeners();

    // 이벤트 발생
    eventBus.fire(EventBus.entryUpdated, {
      'entryId': entryId,
      'content': newContent,
      'entry': userIndex != -1 ? _userEntries[userIndex] : null,
    });

    // 2. 백그라운드에서 서버 업데이트 작업 추가
    _addPendingOperation(PendingOperation(
      id: entryId,
      type: 'update',
      data: {
        'entryId': entryId,
        'content': newContent,
        'updatedAt': Timestamp.fromDate(now),
      },
    ));

    _scheduleBatchSync();
    return true;
  }

  /// 좋아요 토글 - Optimistic Updates 적용
  Future<bool> toggleLike(String entryId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 현재 좋아요 상태 확인
    final publicIndex =
        _publicEntries.indexWhere((entry) => entry['id'] == entryId);
    final userIndex =
        _userEntries.indexWhere((entry) => entry['id'] == entryId);

    if (publicIndex == -1 && userIndex == -1) return false;

    final currentEntry = publicIndex != -1
        ? _publicEntries[publicIndex]
        : _userEntries[userIndex];
    final authorId = currentEntry['userId'] as String;

    // 자신의 글에는 좋아요 불가
    if (user.uid == authorId) return false;

    final isCurrentlyLiked = currentEntry['isLiked'] as bool? ?? false;
    final currentLikeCount = currentEntry['likeCount'] as int? ?? 0;

    // 1. 즉시 로컬 상태 업데이트
    final newIsLiked = !isCurrentlyLiked;
    final newLikeCount =
        newIsLiked ? currentLikeCount + 1 : currentLikeCount - 1;

    // 공개 글 목록 업데이트
    if (publicIndex != -1) {
      _publicEntries[publicIndex]['isLiked'] = newIsLiked;
      _publicEntries[publicIndex]['likeCount'] = newLikeCount;
    }

    // 사용자 글 목록 업데이트
    if (userIndex != -1) {
      _userEntries[userIndex]['isLiked'] = newIsLiked;
      _userEntries[userIndex]['likeCount'] = newLikeCount;
    }

    // 즉시 UI 업데이트
    notifyListeners();

    // 이벤트 발생
    eventBus.fire(EventBus.likeStatusChanged, {
      'entryId': entryId,
      'isLiked': newIsLiked,
      'likeCount': newLikeCount,
    });

    // 2. 백그라운드에서 서버 작업 추가
    _addPendingOperation(PendingOperation(
      id: entryId,
      type: 'toggle_like',
      data: {
        'entryId': entryId,
        'authorId': authorId,
        'newIsLiked': newIsLiked,
        'newLikeCount': newLikeCount,
      },
    ));

    _scheduleBatchSync();
    return true;
  }

  /// 북마크 토글 - Optimistic Updates 적용
  Future<bool> toggleBookmark(String entryId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 현재 북마크 상태 확인
    final publicIndex =
        _publicEntries.indexWhere((entry) => entry['id'] == entryId);
    final userIndex =
        _userEntries.indexWhere((entry) => entry['id'] == entryId);

    if (publicIndex == -1 && userIndex == -1) return false;

    final currentEntry = publicIndex != -1
        ? _publicEntries[publicIndex]
        : _userEntries[userIndex];
    final isCurrentlyBookmarked =
        currentEntry['isBookmarked'] as bool? ?? false;
    final authorId = currentEntry['userId'] as String;

    // 1. 즉시 로컬 상태 업데이트
    final newIsBookmarked = !isCurrentlyBookmarked;

    // 공개 글 목록 업데이트
    if (publicIndex != -1) {
      _publicEntries[publicIndex]['isBookmarked'] = newIsBookmarked;
    }

    // 사용자 글 목록 업데이트
    if (userIndex != -1) {
      _userEntries[userIndex]['isBookmarked'] = newIsBookmarked;
    }

    // 즉시 UI 업데이트
    notifyListeners();

    // 이벤트 발생
    eventBus.fire(EventBus.bookmarkStatusChanged, {
      'entryId': entryId,
      'isBookmarked': newIsBookmarked,
    });

    // 2. 백그라운드에서 서버 작업 추가
    _addPendingOperation(PendingOperation(
      id: entryId,
      type: 'toggle_bookmark',
      data: {
        'entryId': entryId,
        'authorId': authorId,
        'newIsBookmarked': newIsBookmarked,
      },
    ));

    _scheduleBatchSync();
    return true;
  }

  // ============================================================================
  // 백그라운드 동기화 관리 (기존 코드 유지)
  // ============================================================================

  /// 대기 중인 작업 추가
  void _addPendingOperation(PendingOperation operation) {
    _pendingOperations[operation.id] = operation;
    debugPrint('대기 작업 추가: ${operation.type} - ${operation.id}');
  }

  /// 배치 동기화 예약
  void _scheduleBatchSync() {
    _batchSyncTimer?.cancel();
    _batchSyncTimer = Timer(BATCH_SYNC_DELAY, () {
      _executeBatchSync();
    });
  }

  /// 배치 동기화 실행
  Future<void> _executeBatchSync() async {
    if (_pendingOperations.isEmpty) return;

    debugPrint('배치 동기화 시작: ${_pendingOperations.length}개 작업');

    final operationsToProcess =
        Map<String, PendingOperation>.from(_pendingOperations);

    for (var operation in operationsToProcess.values) {
      if (operation.status == OperationStatus.pending) {
        operation.status = OperationStatus.syncing;
        _syncSingleOperation(operation);
      }
    }

    notifyListeners(); // 동기화 상태 변경 알림
  }

  /// 단일 작업 동기화
  Future<void> _syncSingleOperation(PendingOperation operation) async {
    try {
      bool success = false;

      switch (operation.type) {
        case 'add':
          success = await _syncAddEntry(operation);
          break;
        case 'delete':
          success = await _syncDeleteEntry(operation);
          break;
        case 'update':
          success = await _syncUpdateEntry(operation);
          break;
        case 'toggle_like':
          success = await _syncToggleLike(operation);
          break;
        case 'toggle_bookmark':
          success = await _syncToggleBookmark(operation);
          break;
      }

      if (success) {
        operation.status = OperationStatus.synced;
        _pendingOperations.remove(operation.id);
        debugPrint('동기화 성공: ${operation.type} - ${operation.id}');
      } else {
        throw Exception('동기화 실패');
      }
    } catch (e) {
      debugPrint('동기화 오류: ${operation.type} - ${operation.id} - $e');
      operation.status = OperationStatus.failed;
      operation.retryCount++;

      if (operation.retryCount < MAX_RETRY_COUNT) {
        // 재시도 예약 (지수 백오프)
        final retryDelay = Duration(seconds: (2 << operation.retryCount));
        _retryTimers[operation.id] = Timer(retryDelay, () {
          operation.status = OperationStatus.pending;
          _scheduleBatchSync();
        });
      } else {
        // 최대 재시도 횟수 초과 - 롤백 처리
        await _rollbackOperation(operation);
        _pendingOperations.remove(operation.id);
      }
    }

    notifyListeners();
  }

  /// 글 추가 동기화
  Future<bool> _syncAddEntry(PendingOperation operation) async {
    try {
      final data = operation.data;
      final tempId = data['tempId'] as String;
      final realId = data['realId'] as String;
      final entry = data['entry'] as Map<String, dynamic>;
      final isPublic = data['isPublic'] as bool;

      final user = _auth.currentUser;
      if (user == null) return false;

      final batch = _firestore.batch();

      // 사용자 컬렉션에 저장
      final userEntryRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('moods')
          .doc(realId);
      batch.set(userEntryRef, entry);

      // 공개 글인 경우 publicEntries에도 저장
      if (isPublic) {
        final publicEntryRef =
            _firestore.collection('publicEntries').doc(realId);
        batch.set(publicEntryRef, entry);
      }

      await batch.commit();

      // 로컬 상태에서 임시 ID를 실제 ID로 교체
      _replaceEntryId(tempId, realId);

      return true;
    } catch (e) {
      debugPrint('글 추가 동기화 오류: $e');
      return false;
    }
  }

  /// 글 삭제 동기화
  Future<bool> _syncDeleteEntry(PendingOperation operation) async {
    try {
      final data = operation.data;
      final entryId = data['entryId'] as String;
      final user = _auth.currentUser;
      if (user == null) return false;

      final batch = _firestore.batch();

      // 사용자 컬렉션에서 삭제
      final userEntryRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('moods')
          .doc(entryId);
      batch.delete(userEntryRef);

      // 공개 컬렉션에서도 삭제
      final publicEntryRef =
          _firestore.collection('publicEntries').doc(entryId);
      batch.delete(publicEntryRef);

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('글 삭제 동기화 오류: $e');
      return false;
    }
  }

  /// 글 업데이트 동기화
  Future<bool> _syncUpdateEntry(PendingOperation operation) async {
    try {
      final data = operation.data;
      final entryId = data['entryId'] as String;
      final content = data['content'] as String;
      final updatedAt = data['updatedAt'] as Timestamp;
      final user = _auth.currentUser;
      if (user == null) return false;

      final batch = _firestore.batch();

      // 사용자 컬렉션 업데이트
      final userEntryRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('moods')
          .doc(entryId);
      batch.update(userEntryRef, {'content': content, 'updatedAt': updatedAt});

      // 공개 컬렉션도 업데이트 (존재하는 경우)
      final publicEntryRef =
          _firestore.collection('publicEntries').doc(entryId);
      final publicDoc = await publicEntryRef.get();
      if (publicDoc.exists) {
        batch.update(
            publicEntryRef, {'content': content, 'updatedAt': updatedAt});
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('글 업데이트 동기화 오류: $e');
      return false;
    }
  }

  /// 좋아요 토글 동기화
  Future<bool> _syncToggleLike(PendingOperation operation) async {
    try {
      final data = operation.data;
      final entryId = data['entryId'] as String;
      final authorId = data['authorId'] as String;
      final newIsLiked = data['newIsLiked'] as bool;
      final newLikeCount = data['newLikeCount'] as int;

      final user = _auth.currentUser;
      if (user == null) return false;

      final userLikesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likes')
          .doc(entryId);

      final entryRef = _firestore.collection('publicEntries').doc(entryId);

      await _firestore.runTransaction((transaction) async {
        if (newIsLiked) {
          // 좋아요 추가
          transaction.set(userLikesRef, {
            'entryId': entryId,
            'userId': authorId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // 좋아요 제거
          transaction.delete(userLikesRef);
        }

        // 좋아요 수 업데이트
        transaction.update(entryRef, {'likeCount': newLikeCount});
      });

      return true;
    } catch (e) {
      debugPrint('좋아요 토글 동기화 오류: $e');
      return false;
    }
  }

  /// 북마크 토글 동기화
  Future<bool> _syncToggleBookmark(PendingOperation operation) async {
    try {
      final data = operation.data;
      final entryId = data['entryId'] as String;
      final authorId = data['authorId'] as String;
      final newIsBookmarked = data['newIsBookmarked'] as bool;

      final user = _auth.currentUser;
      if (user == null) return false;

      final userBookmarkRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('bookmarks')
          .doc(entryId);

      if (newIsBookmarked) {
        // 북마크 추가
        await userBookmarkRef.set({
          'entryId': entryId,
          'userId': authorId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 북마크 제거
        await userBookmarkRef.delete();
      }

      return true;
    } catch (e) {
      debugPrint('북마크 토글 동기화 오류: $e');
      return false;
    }
  }

  /// 작업 롤백 처리
  Future<void> _rollbackOperation(PendingOperation operation) async {
    debugPrint('작업 롤백: ${operation.type} - ${operation.id}');

    // 롤백 로직은 작업 유형에 따라 다름
    switch (operation.type) {
      case 'add':
        // 추가된 항목을 로컬에서 제거
        final tempId = operation.data['tempId'] as String;
        _userEntries.removeWhere((entry) => entry['id'] == tempId);
        _publicEntries.removeWhere((entry) => entry['id'] == tempId);
        break;
      case 'delete':
        // 삭제된 항목을 로컬에서 복원
        final userEntry = operation.data['userEntry'] as Map<String, dynamic>?;
        final publicEntry =
            operation.data['publicEntry'] as Map<String, dynamic>?;
        if (userEntry != null) _userEntries.insert(0, userEntry);
        if (publicEntry != null) _publicEntries.insert(0, publicEntry);
        break;
      // 기타 롤백 로직...
    }

    notifyListeners();

    // 사용자에게 동기화 실패 알림
    eventBus.fire(
        EventBus.dataRefreshNeeded,
        DataRefreshNeededEvent(
            screens: ['RelaxMainScreen', 'RelaxHistoryScreen']));
  }

  /// 임시 ID를 실제 ID로 교체
  void _replaceEntryId(String tempId, String realId) {
    // 사용자 글 목록에서 교체
    final userIndex = _userEntries.indexWhere((entry) => entry['id'] == tempId);
    if (userIndex != -1) {
      _userEntries[userIndex]['id'] = realId;
      _userEntries[userIndex].remove('_isPending');
    }

    // 공개 글 목록에서 교체
    final publicIndex =
        _publicEntries.indexWhere((entry) => entry['id'] == tempId);
    if (publicIndex != -1) {
      _publicEntries[publicIndex]['id'] = realId;
      _publicEntries[publicIndex].remove('_isPending');
    }
  }

  // ============================================================================
  // 기존 메서드들 (변경 없음)
  // ============================================================================

  // 공개/비공개 상태 변경 처리
  void _handleVisibilityChanged(String entryId, bool isPublic) {
    final entryIndex =
        _userEntries.indexWhere((entry) => entry['id'] == entryId);
    if (entryIndex != -1) {
      _userEntries[entryIndex]['isPublic'] = isPublic;
    }

    final publicIndex =
        _publicEntries.indexWhere((entry) => entry['id'] == entryId);
    if (publicIndex != -1) {
      if (!isPublic) {
        _publicEntries.removeAt(publicIndex);
      } else {
        _publicEntries[publicIndex]['isPublic'] = true;
      }
    } else if (isPublic) {
      // 새로 공개된 글은 실시간 스트림이 자동으로 추가
      debugPrint('RelaxProvider: 새로 공개된 글은 스트림에서 자동 추가됨');
    }

    notifyListeners();
  }

  // 공개/비공개 상태 변경
  Future<bool> updateEntryPublicStatus(String entryId, bool isPublic) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final batch = _firestore.batch();

      final userEntryRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('moods')
          .doc(entryId);

      batch.update(userEntryRef, {'isPublic': isPublic});

      final publicEntryRef =
          _firestore.collection('publicEntries').doc(entryId);

      if (isPublic) {
        final docSnapshot = await userEntryRef.get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          batch.set(publicEntryRef, data);
        }
      } else {
        batch.delete(publicEntryRef);
      }

      await batch.commit();

      eventBus.fire(EventBus.entryVisibilityChanged,
          EntryVisibilityChangedEvent(entryId, isPublic));

      _handleVisibilityChanged(entryId, isPublic);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('감정 기록 공개 상태 업데이트 오류: $e');
      return false;
    }
  }

  // 감정 분포 가져오기
  Map<String, int> getMoodDistribution() {
    final distribution = <String, int>{};
    for (var entry in _userEntries) {
      distribution[entry['mood']] = (distribution[entry['mood']] ?? 0) + 1;
    }
    return distribution;
  }

  // 오늘 작성한 글 가져오기
  MoodEntry? getTodayEntry() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final entryMap in _userEntries) {
      try {
        DateTime entryDate;
        if (entryMap['date'] is Timestamp) {
          entryDate = (entryMap['date'] as Timestamp).toDate();
        } else if (entryMap['date'] is DateTime) {
          entryDate = entryMap['date'] as DateTime;
        } else {
          continue;
        }

        final entryDay =
            DateTime(entryDate.year, entryDate.month, entryDate.day);

        if (entryDay.isAtSameMomentAs(today)) {
          return MoodEntry.fromMap(entryMap);
        }
      } catch (e) {
        debugPrint('getTodayEntry 오류: $e');
        continue;
      }
    }

    return null;
  }

  // ============================================================================
  // 스트림 관리 및 디버깅 메서드들
  // ============================================================================

  /// 스트림 상태 정보 가져오기 (디버깅용)
  Map<String, dynamic> getStreamStatus() {
    return {
      'streamInitialized': _streamInitialized,
      'isUserStreamActive': _isUserStreamActive,
      'isPublicStreamActive': _isPublicStreamActive,
      'reconnectAttempts': _reconnectAttempts,
      'lastStreamReconnect': _lastStreamReconnect?.toIso8601String(),
      'pendingOperations': _pendingOperations.length,
      'userEntriesCount': _userEntries.length,
      'publicEntriesCount': _publicEntries.length,
    };
  }

  /// 스트림 강제 재연결 (디버깅/관리용)
  Future<void> forceReconnectStreams() async {
    debugPrint('RelaxProvider: 스트림 강제 재연결 시작');

    // 기존 스트림 해제
    _disposeStreams();

    // 재연결 카운터 리셋
    _reconnectAttempts = 0;

    // 스트림 재초기화
    await _initializeStreams();

    debugPrint('RelaxProvider: 스트림 강제 재연결 완료');
  }

  /// 스트림 상태 모니터링 (개발용)
  void startStreamMonitoring() {
    Timer.periodic(Duration(minutes: 5), (timer) {
      final status = getStreamStatus();
      debugPrint('RelaxProvider 스트림 상태: $status');

      // 스트림이 비정상적으로 중단된 경우 재연결 시도
      if (_streamInitialized &&
          !_isUserStreamActive &&
          _auth.currentUser != null) {
        debugPrint('RelaxProvider: 사용자 스트림 비활성화 감지, 재연결 시도');
        _attemptStreamReconnection('user');
      }
    });
  }

  /// 스트림 성능 메트릭 수집
  Map<String, dynamic> getStreamMetrics() {
    return {
      'streamUptime': _lastStreamReconnect != null
          ? DateTime.now().difference(_lastStreamReconnect!).inMinutes
          : 0,
      'totalReconnectAttempts': _reconnectAttempts,
      'averageStreamLatency': 0, // 실제 구현에서는 측정 필요
      'streamHealth':
          _isUserStreamActive || _isPublicStreamActive ? 'healthy' : 'degraded',
    };
  }
}
