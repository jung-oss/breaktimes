import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/localization/app_localizations.dart';
import '../../providers/relax_provider.dart';
import '../../utils/event_bus.dart';
import '../../utils/custom_navigator_observer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/unified_entry_card.dart';

class BookmarkedScreen extends StatefulWidget {
  const BookmarkedScreen({super.key});

  @override
  State<BookmarkedScreen> createState() => _BookmarkedScreenState();
}

class _BookmarkedScreenState extends State<BookmarkedScreen>
    with SingleTickerProviderStateMixin, RelaxScreenRouteAware {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookmarkedEntries = [];
  List<Map<String, dynamic>> _likedEntries = [];
  final ScrollController _scrollController = ScrollController();
  String? _expandedEntryId;
  User? _user;

  // ============================================================================
  // 실시간 스트림 관리 변수들
  // ============================================================================

  // 스트림 구독들
  StreamSubscription<QuerySnapshot>? _bookmarksSubscription;
  StreamSubscription<QuerySnapshot>? _likesSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription? _likeStatusSubscription;
  StreamSubscription? _bookmarkStatusSubscription;
  StreamSubscription? _entryDeletedSubscription;
  StreamSubscription? _entryUpdatedSubscription;
  StreamSubscription? _visibilityChangedSubscription;
  StreamSubscription? _dataRefreshNeededSubscription;

  // 스트림 상태 관리
  bool _bookmarkStreamInitialized = false;
  bool _likesStreamInitialized = false;
  bool _hasPermissionError = false;
  bool _isUserAuthenticated = false;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 2;
  static const int STREAM_RECONNECT_DELAY_SECONDS = 3;

  // 캐시된 엔트리 데이터 (중복 쿼리 방지)
  final Map<String, Map<String, dynamic>> _entriesCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _scrollController.addListener(_scrollListener);

    // Firebase Auth 상태 리스너 먼저 설정
    _setupAuthStateListener();

    // 이벤트 버스 구독 설정
    _setupEventListeners();
  }

  void _handleTabChange() {
    // Collapse expanded card when tab changes
    if (_expandedEntryId != null) {
      setState(() {
        _expandedEntryId = null;
      });
    }
  }

  void _scrollListener() {
    // Infinite scroll implementation (if needed in the future)
  }

  // ============================================================================
  // Firebase Auth 상태 관리
  // ============================================================================

  /// Firebase Auth 상태 리스너 설정
  void _setupAuthStateListener() {
    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      debugPrint('BookmarkedScreen: Auth 상태 변경됨 - ${user?.uid}');

      _user = user;
      _isUserAuthenticated = user != null;

      if (user != null) {
        // 사용자가 인증되면 초기화 시작
        _initializeBookmarkedScreen();
      } else {
        // 사용자가 로그아웃되면 스트림 정리
        _cleanupStreams();
        setState(() {
          _bookmarkedEntries = [];
          _likedEntries = [];
          _isLoading = false;
        });
      }
    });
  }

  /// 초기 인증 상태 확인 및 대기
  Future<bool> _waitForAuthentication() async {
    // 이미 인증된 경우
    if (_isUserAuthenticated && _user != null) {
      return true;
    }

    // 현재 사용자 확인
    _user = _auth.currentUser;
    if (_user != null) {
      _isUserAuthenticated = true;
      debugPrint('BookmarkedScreen: 기존 인증 사용자 확인됨 - ${_user!.uid}');
      return true;
    }

    // 인증 완료까지 최대 5초 대기
    debugPrint('BookmarkedScreen: 인증 완료 대기 중...');

    for (int i = 0; i < 50; i++) {
      // 100ms씩 50번 = 5초
      await Future.delayed(Duration(milliseconds: 100));

      _user = _auth.currentUser;
      if (_user != null) {
        _isUserAuthenticated = true;
        debugPrint('BookmarkedScreen: 인증 완료 - ${_user!.uid}');
        return true;
      }
    }

    debugPrint('BookmarkedScreen: 인증 대기 시간 초과');
    return false;
  }

  // ============================================================================
  // 초기화 및 실시간 스트림 설정
  // ============================================================================

  /// BookmarkedScreen 초기화
  Future<void> _initializeBookmarkedScreen() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('BookmarkedScreen: 초기화 시작');

      // 1. 인증 상태 확인 및 대기
      final isAuthenticated = await _waitForAuthentication();
      if (!isAuthenticated) {
        debugPrint('BookmarkedScreen: 사용자 인증되지 않음');
        setState(() => _isLoading = false);
        return;
      }

      // 2. 먼저 정적 방법으로 데이터 로드
      await _loadStaticData();

      // 3. 실시간 스트림 시도 (인증 확인 후)
      if (!_hasPermissionError && _isUserAuthenticated) {
        await _trySetupStreams();
      }

      debugPrint(
          'BookmarkedScreen: 초기화 완료 (북마크스트림: $_bookmarkStreamInitialized, 좋아요스트림: $_likesStreamInitialized)');
    } catch (e) {
      debugPrint('BookmarkedScreen: 초기화 오류 - $e');

      // 오류 발생 시 정적 로딩으로 폴백
      await _loadStaticData();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 정적 데이터 로드 (안전한 방법)
  Future<void> _loadStaticData() async {
    try {
      debugPrint('BookmarkedScreen: 정적 데이터 로드 시작');

      if (_user == null) return;

      // 북마크된 엔트리 로드
      final bookmarksSnapshot = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('bookmarks')
          .orderBy('createdAt', descending: true)
          .get();

      final bookmarkedIds =
          bookmarksSnapshot.docs.map((doc) => doc.id).toList();

      // 좋아요한 엔트리 로드
      final likesSnapshot = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('likes')
          .orderBy('createdAt', descending: true)
          .get();

      final likedIds = likesSnapshot.docs.map((doc) => doc.id).toList();

      // 엔트리 데이터 가져오기
      final bookmarkedEntries =
          await _fetchEntriesData(bookmarkedIds, likedIds, true);
      final likedEntries =
          await _fetchEntriesData(likedIds, bookmarkedIds, false);

      if (mounted) {
        setState(() {
          _bookmarkedEntries = bookmarkedEntries;
          _likedEntries = likedEntries;
        });
      }

      debugPrint(
          'BookmarkedScreen: 정적 데이터 로드 완료 (북마크: ${bookmarkedEntries.length}개, 좋아요: ${likedEntries.length}개)');
    } catch (e) {
      debugPrint('BookmarkedScreen: 정적 데이터 로드 오류 - $e');
    }
  }

  /// 엔트리 데이터 가져오기 (공통 메서드)
  Future<List<Map<String, dynamic>>> _fetchEntriesData(List<String> primaryIds,
      List<String> secondaryIds, bool isPrimaryBookmark) async {
    final entries = <Map<String, dynamic>>[];

    if (primaryIds.isEmpty) return entries;

    // Firestore 'in' 쿼리 제한으로 10개씩 배치 처리
    for (var i = 0; i < primaryIds.length; i += 10) {
      final endIndex = i + 10 < primaryIds.length ? i + 10 : primaryIds.length;
      final chunk = primaryIds.sublist(i, endIndex);

      try {
        final entriesSnapshot = await _firestore
            .collection('publicEntries')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in entriesSnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;

          // 상태 설정
          if (isPrimaryBookmark) {
            data['isBookmarked'] = true;
            data['isLiked'] = secondaryIds.contains(doc.id);
          } else {
            data['isLiked'] = true;
            data['isBookmarked'] = secondaryIds.contains(doc.id);
          }

          entries.add(data);

          // 캐시에 저장
          _entriesCache[doc.id] = data;
        }
      } catch (e) {
        debugPrint('BookmarkedScreen: 엔트리 데이터 가져오기 오류 - $e');
        continue;
      }
    }

    // 원본 글 작성 시간 기준으로 정렬 (최신 글이 위로)
    entries.sort((a, b) {
      final aDate = a['date'] as Timestamp?;
      final bDate = b['date'] as Timestamp?;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate); // 내림차순 정렬
    });

    return entries;
  }

  /// 실시간 스트림 설정 시도
  Future<void> _trySetupStreams() async {
    if (!_isUserAuthenticated || _user == null || _hasPermissionError) {
      debugPrint('BookmarkedScreen: 스트림 설정 조건 미충족');
      return;
    }

    try {
      debugPrint('BookmarkedScreen: 실시간 스트림 설정 시도');

      // 권한 테스트
      await _testFirestorePermission();

      // 북마크 및 좋아요 스트림 설정
      await Future.wait([
        _setupBookmarksStream(),
        _setupLikesStream(),
      ]);
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint('BookmarkedScreen: 권한 오류 감지, 정적 모드로 전환');
        _hasPermissionError = true;
      } else {
        debugPrint('BookmarkedScreen: 스트림 설정 오류 - $e');
        rethrow;
      }
    }
  }

  /// Firestore 권한 테스트
  Future<void> _testFirestorePermission() async {
    try {
      if (_user == null) {
        throw Exception('User not authenticated for permission test');
      }

      // 북마크 컬렉션 권한 테스트
      await _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('bookmarks')
          .limit(1)
          .get(const GetOptions(source: Source.server));

      debugPrint('BookmarkedScreen: Firestore 권한 확인됨');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception('Permission denied');
      }
      rethrow;
    }
  }

  /// 북마크 실시간 스트림 설정
  Future<void> _setupBookmarksStream() async {
    if (!_isUserAuthenticated || _user == null) return;

    try {
      debugPrint('BookmarkedScreen: 북마크 스트림 설정 시작');

      // 기존 구독 해제
      _bookmarksSubscription?.cancel();

      _bookmarksSubscription = _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('bookmarks')
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: false)
          .listen(
            _onBookmarksChanged,
            onError: (error) => _onStreamError(error, 'bookmarks'),
            onDone: () => debugPrint('BookmarkedScreen: 북마크 스트림 종료'),
          );

      _bookmarkStreamInitialized = true;
      debugPrint('BookmarkedScreen: 북마크 실시간 스트림 활성화');
    } catch (e) {
      debugPrint('BookmarkedScreen: 북마크 스트림 설정 오류 - $e');
      _bookmarkStreamInitialized = false;
      rethrow;
    }
  }

  /// 좋아요 실시간 스트림 설정
  Future<void> _setupLikesStream() async {
    if (!_isUserAuthenticated || _user == null) return;

    try {
      debugPrint('BookmarkedScreen: 좋아요 스트림 설정 시작');

      // 기존 구독 해제
      _likesSubscription?.cancel();

      _likesSubscription = _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('likes')
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: false)
          .listen(
            _onLikesChanged,
            onError: (error) => _onStreamError(error, 'likes'),
            onDone: () => debugPrint('BookmarkedScreen: 좋아요 스트림 종료'),
          );

      _likesStreamInitialized = true;
      debugPrint('BookmarkedScreen: 좋아요 실시간 스트림 활성화');
    } catch (e) {
      debugPrint('BookmarkedScreen: 좋아요 스트림 설정 오류 - $e');
      _likesStreamInitialized = false;
      rethrow;
    }
  }

  /// 북마크 스트림 변경 처리
  void _onBookmarksChanged(QuerySnapshot snapshot) async {
    try {
      debugPrint('BookmarkedScreen: 북마크 스트림 변경감지 - ${snapshot.docs.length}개');

      final bookmarkIds = snapshot.docs.map((doc) => doc.id).toList();

      // 현재 좋아요 목록 가져오기
      final currentLikedIds =
          _likedEntries.map((e) => e['id'] as String).toList();

      // 북마크된 엔트리 데이터 가져오기
      final newBookmarkedEntries =
          await _fetchEntriesData(bookmarkIds, currentLikedIds, true);

      if (mounted && !_isListEqual(_bookmarkedEntries, newBookmarkedEntries)) {
        setState(() {
          _bookmarkedEntries = newBookmarkedEntries;
        });
        debugPrint(
            'BookmarkedScreen: 북마크 엔트리 업데이트됨 - ${newBookmarkedEntries.length}개 (원본 글 시간순 정렬)');
      }
    } catch (e) {
      debugPrint('BookmarkedScreen: 북마크 스트림 처리 오류 - $e');
    }
  }

  /// 좋아요 스트림 변경 처리
  void _onLikesChanged(QuerySnapshot snapshot) async {
    try {
      debugPrint('BookmarkedScreen: 좋아요 스트림 변경감지 - ${snapshot.docs.length}개');

      final likedIds = snapshot.docs.map((doc) => doc.id).toList();

      // 현재 북마크 목록 가져오기
      final currentBookmarkedIds =
          _bookmarkedEntries.map((e) => e['id'] as String).toList();

      // 좋아요한 엔트리 데이터 가져오기
      final newLikedEntries =
          await _fetchEntriesData(likedIds, currentBookmarkedIds, false);

      if (mounted && !_isListEqual(_likedEntries, newLikedEntries)) {
        setState(() {
          _likedEntries = newLikedEntries;
        });
        debugPrint(
            'BookmarkedScreen: 좋아요 엔트리 업데이트됨 - ${newLikedEntries.length}개 (원본 글 시간순 정렬)');
      }
    } catch (e) {
      debugPrint('BookmarkedScreen: 좋아요 스트림 처리 오류 - $e');
    }
  }

  /// 스트림 오류 처리
  void _onStreamError(dynamic error, String streamType) {
    debugPrint('BookmarkedScreen: $streamType 스트림 오류 - $error');

    if (streamType == 'bookmarks') {
      _bookmarkStreamInitialized = false;
    } else {
      _likesStreamInitialized = false;
    }

    // 권한 오류인 경우 재시도하지 않음
    if (error.toString().contains('permission-denied')) {
      debugPrint('BookmarkedScreen: 권한 오류로 인한 스트림 중단, 정적 모드로 전환');
      _hasPermissionError = true;

      if (mounted) {
        setState(() {}); // UI 상태 업데이트
      }
      return;
    }

    // 다른 오류의 경우 재연결 시도
    _attemptStreamReconnection(streamType);
  }

  /// 스트림 재연결 시도
  void _attemptStreamReconnection(String streamType) {
    if (_reconnectAttempts >= MAX_RECONNECT_ATTEMPTS ||
        _hasPermissionError ||
        !_isUserAuthenticated) {
      debugPrint('BookmarkedScreen: $streamType 스트림 재연결 중단');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: STREAM_RECONNECT_DELAY_SECONDS);

    debugPrint(
        'BookmarkedScreen: $streamType 스트림 재연결 시도 $_reconnectAttempts/$MAX_RECONNECT_ATTEMPTS');

    Timer(delay, () async {
      if (!mounted || _hasPermissionError || !_isUserAuthenticated) return;

      try {
        if (streamType == 'bookmarks') {
          await _setupBookmarksStream();
        } else {
          await _setupLikesStream();
        }
        _reconnectAttempts = 0; // 성공 시 리셋
      } catch (e) {
        debugPrint('BookmarkedScreen: $streamType 스트림 재연결 실패 - $e');
      }
    });
  }

  /// 스트림 정리
  void _cleanupStreams() {
    _bookmarksSubscription?.cancel();
    _likesSubscription?.cancel();
    _bookmarksSubscription = null;
    _likesSubscription = null;
    _bookmarkStreamInitialized = false;
    _likesStreamInitialized = false;
    debugPrint('BookmarkedScreen: 스트림 정리 완료');
  }

  // ============================================================================
  // 이벤트 버스 리스너 설정 (핵심 - 즉시 반영을 위함)
  // ============================================================================

  /// 이벤트 리스너 설정
  void _setupEventListeners() {
    // Like status changed event - 핵심 리스너
    _likeStatusSubscription = eventBus.on(
      EventBus.likeStatusChanged,
      (data) {
        debugPrint('BookmarkedScreen: Like status changed event detected');
        if (!mounted) return;

        if (data is Map<String, dynamic>) {
          final entryId = data['entryId'] as String;
          final isLiked = data['isLiked'] as bool;
          final likeCount = data['likeCount'] as int;

          setState(() {
            // 북마크 탭 업데이트
            final bookmarkIndex =
                _bookmarkedEntries.indexWhere((e) => e['id'] == entryId);
            if (bookmarkIndex != -1) {
              _bookmarkedEntries[bookmarkIndex]['isLiked'] = isLiked;
              _bookmarkedEntries[bookmarkIndex]['likeCount'] = likeCount;
            }

            // 좋아요 탭 업데이트
            final likeIndex =
                _likedEntries.indexWhere((e) => e['id'] == entryId);
            if (likeIndex != -1) {
              _likedEntries[likeIndex]['likeCount'] = likeCount;

              // 좋아요 해제 시 목록에서 제거 (스트림이 비활성화된 경우)
              if (!isLiked && !_likesStreamInitialized) {
                _likedEntries.removeAt(likeIndex);
              }
            }
          });

          // 스트림이 비활성화된 경우 수동 업데이트
          if (!_likesStreamInitialized && isLiked) {
            // 새로 좋아요된 항목을 좋아요 목록에 추가
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) _loadStaticData();
            });
          }
        }
      },
    );

    // Bookmark status changed event - 핵심 리스너
    _bookmarkStatusSubscription = eventBus.on(
      EventBus.bookmarkStatusChanged,
      (data) {
        debugPrint('BookmarkedScreen: Bookmark status changed event detected');
        if (!mounted) return;

        if (data is Map<String, dynamic>) {
          final entryId = data['entryId'] as String;
          final isBookmarked = data['isBookmarked'] as bool;

          setState(() {
            // 북마크 탭에서 제거/추가
            if (!isBookmarked) {
              _bookmarkedEntries.removeWhere((e) => e['id'] == entryId);
            }

            // 좋아요 탭 업데이트
            final likeIndex =
                _likedEntries.indexWhere((e) => e['id'] == entryId);
            if (likeIndex != -1) {
              _likedEntries[likeIndex]['isBookmarked'] = isBookmarked;
            }
          });

          // 스트림이 비활성화된 경우 수동 업데이트
          if (!_bookmarkStreamInitialized && isBookmarked) {
            // 새로 북마크된 항목을 북마크 목록에 추가
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) _loadStaticData();
            });
          }
        }
      },
    );

    // Entry deleted event
    _entryDeletedSubscription = eventBus.on(
      EventBus.entryDeleted,
      (data) {
        debugPrint('BookmarkedScreen: Entry deleted event detected');
        if (mounted) {
          String? entryId;
          if (data is Map<String, dynamic> && data.containsKey('entryId')) {
            entryId = data['entryId'] as String;
          } else if (data is String) {
            entryId = data;
          }

          if (entryId != null) {
            setState(() {
              _bookmarkedEntries.removeWhere((e) => e['id'] == entryId);
              _likedEntries.removeWhere((e) => e['id'] == entryId);
            });
          }
        }
      },
    );

    // Entry updated event
    _entryUpdatedSubscription = eventBus.on(
      EventBus.entryUpdated,
      (data) {
        debugPrint('BookmarkedScreen: Entry updated event detected');
        if (data is Map<String, dynamic> && mounted) {
          final entryId = data['entryId'] as String?;
          final content = data['content'] as String?;

          if (entryId != null && content != null) {
            setState(() {
              // 북마크 탭 업데이트
              final bookmarkIndex =
                  _bookmarkedEntries.indexWhere((e) => e['id'] == entryId);
              if (bookmarkIndex != -1) {
                _bookmarkedEntries[bookmarkIndex]['content'] = content;
                _bookmarkedEntries[bookmarkIndex]['updatedAt'] = DateTime.now();
              }

              // 좋아요 탭 업데이트
              final likeIndex =
                  _likedEntries.indexWhere((e) => e['id'] == entryId);
              if (likeIndex != -1) {
                _likedEntries[likeIndex]['content'] = content;
                _likedEntries[likeIndex]['updatedAt'] = DateTime.now();
              }
            });
          }
        }
      },
    );

    // Visibility changed event
    _visibilityChangedSubscription = eventBus.on(
      EventBus.entryVisibilityChanged,
      (data) {
        debugPrint('BookmarkedScreen: Visibility changed event detected');
        if (data is EntryVisibilityChangedEvent && mounted) {
          final entryId = data.entryId;
          final isPublic = data.isPublic;

          setState(() {
            // 북마크 탭 업데이트
            final bookmarkIndex =
                _bookmarkedEntries.indexWhere((e) => e['id'] == entryId);
            if (bookmarkIndex != -1) {
              _bookmarkedEntries[bookmarkIndex]['isPublic'] = isPublic;
            }

            // 좋아요 탭 업데이트
            final likeIndex =
                _likedEntries.indexWhere((e) => e['id'] == entryId);
            if (likeIndex != -1) {
              _likedEntries[likeIndex]['isPublic'] = isPublic;
            }
          });
        }
      },
    );

    // Data refresh needed event
    _dataRefreshNeededSubscription = eventBus.on(
      EventBus.dataRefreshNeeded,
      (event) {
        debugPrint('BookmarkedScreen: Data refresh needed event detected');
        if (mounted) {
          if (event is DataRefreshNeededEvent) {
            final screens = event.screens;
            if (screens.isEmpty || screens.contains('BookmarkedScreen')) {
              refreshData();
            }
          } else {
            refreshData();
          }
        }
      },
    );
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
    }

    return true;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();

    // Cancel all subscriptions
    _authStateSubscription?.cancel();
    _bookmarksSubscription?.cancel();
    _likesSubscription?.cancel();
    _likeStatusSubscription?.cancel();
    _bookmarkStatusSubscription?.cancel();
    _entryDeletedSubscription?.cancel();
    _entryUpdatedSubscription?.cancel();
    _visibilityChangedSubscription?.cancel();
    _dataRefreshNeededSubscription?.cancel();

    super.dispose();
  }

  // RelaxScreenRouteAware implementation
  @override
  void refreshData() {
    if (_bookmarkStreamInitialized || _likesStreamInitialized) {
      debugPrint('BookmarkedScreen: 스트림 활성화 상태, 자동 새로고침됨');
    } else {
      debugPrint('BookmarkedScreen: 수동 데이터 새로고침 시작');
      _loadStaticData();
    }
  }

  /// 수동 새로고침 (Pull-to-refresh 용)
  Future<void> _manualRefresh() async {
    debugPrint('BookmarkedScreen: 수동 새로고침 시작');

    // 항상 정적 데이터로 새로고침 (가장 안전)
    await _loadStaticData();

    // 스트림이 비활성화된 경우 스트림 재시도
    if (_isUserAuthenticated &&
        !_hasPermissionError &&
        (!_bookmarkStreamInitialized || !_likesStreamInitialized)) {
      try {
        _hasPermissionError = false;
        _reconnectAttempts = 0;
        await _trySetupStreams();
      } catch (e) {
        debugPrint('BookmarkedScreen: 수동 새로고침 중 스트림 설정 실패 - $e');
      }
    }
  }

  // Handle entry expansion
  void _setExpandedEntry(String? entryId) {
    setState(() {
      _expandedEntryId = entryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);

    // 인증되지 않은 사용자에 대한 처리
    if (!_isUserAuthenticated) {
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

    return Scaffold(
      body: Column(
        children: [
          // 연결 상태 표시
          if (_hasPermissionError)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync_problem, size: 20, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isKorean
                          ? '실시간 동기화를 위해 당겨서 새로고침해주세요'
                          : 'Pull to refresh for real-time sync',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                  if (_bookmarkStreamInitialized ||
                      _likesStreamInitialized) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.fiber_manual_record,
                      size: 12,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isKorean ? '실시간' : 'Live',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 8),
                      Text(isKorean ? '좋아요' : 'Likes'),
                      if (_likesStreamInitialized) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.fiber_manual_record,
                          size: 8,
                          color: Colors.green,
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 8),
                      Text(isKorean ? '북마크' : 'Bookmarks'),
                      if (_bookmarkStreamInitialized) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.fiber_manual_record,
                          size: 8,
                          color: Colors.green,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),

          // Main content
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isKorean ? '데이터를 불러오는 중...' : 'Loading data...',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _manualRefresh,
                    color: Theme.of(context).primaryColor,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Likes tab
                        _buildEntriesList(
                            _likedEntries, isKorean, relaxProvider,
                            isBookmarksTab: false),

                        // Bookmarks tab
                        _buildEntriesList(
                            _bookmarkedEntries, isKorean, relaxProvider,
                            isBookmarksTab: true),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(
      List<Map<String, dynamic>> entries, bool isKorean, RelaxProvider provider,
      {required bool isBookmarksTab}) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBookmarksTab ? Icons.bookmark_border : Icons.favorite_border,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              isBookmarksTab
                  ? (isKorean ? '북마크한 글이 없습니다.' : 'No bookmarked entries.')
                  : (isKorean ? '좋아요한 글이 없습니다.' : 'No liked entries.'),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _manualRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(
                isKorean ? '새로고침' : 'Refresh',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final entryId = entry['id'] as String;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: UnifiedEntryCard(
            entry: entry,
            expandable: true,
            isTrackedAsExpanded: entry['id'] == _expandedEntryId,
            onTap: () {
              setState(() {
                _expandedEntryId =
                    _expandedEntryId == entry['id'] ? null : entry['id'];
              });
            },
            onPublicChanged: (id, isPublic) async {
              // Check if user owns this entry
              if (entry['userId'] == FirebaseAuth.instance.currentUser?.uid) {
                await provider.updateEntryPublicStatus(id, isPublic);

                // 스트림이 비활성화된 경우 로컬 업데이트
                if (!_bookmarkStreamInitialized && !_likesStreamInitialized) {
                  setState(() {
                    final bookmarkIndex =
                        _bookmarkedEntries.indexWhere((e) => e['id'] == id);
                    if (bookmarkIndex != -1) {
                      _bookmarkedEntries[bookmarkIndex]['isPublic'] = isPublic;
                    }

                    final likeIndex =
                        _likedEntries.indexWhere((e) => e['id'] == id);
                    if (likeIndex != -1) {
                      _likedEntries[likeIndex]['isPublic'] = isPublic;
                    }
                  });
                }
              }
            },
            onDelete: (id) async {
              // Check if user owns this entry
              if (entry['userId'] == FirebaseAuth.instance.currentUser?.uid) {
                await provider.deleteMoodEntry(id);

                // 스트림이 비활성화된 경우 로컬 업데이트
                if (!_bookmarkStreamInitialized && !_likesStreamInitialized) {
                  setState(() {
                    _bookmarkedEntries.removeWhere((e) => e['id'] == id);
                    _likedEntries.removeWhere((e) => e['id'] == id);
                  });
                }
              }
            },
            onUpdate: (id, newContent) async {
              // Check if user owns this entry
              if (entry['userId'] == FirebaseAuth.instance.currentUser?.uid) {
                await provider.updateMoodEntry(id, newContent);

                // 스트림이 비활성화된 경우 로컬 업데이트
                if (!_bookmarkStreamInitialized && !_likesStreamInitialized) {
                  setState(() {
                    final bookmarkIndex =
                        _bookmarkedEntries.indexWhere((e) => e['id'] == id);
                    if (bookmarkIndex != -1) {
                      _bookmarkedEntries[bookmarkIndex]['content'] = newContent;
                      _bookmarkedEntries[bookmarkIndex]['updatedAt'] =
                          DateTime.now();
                    }

                    final likeIndex =
                        _likedEntries.indexWhere((e) => e['id'] == id);
                    if (likeIndex != -1) {
                      _likedEntries[likeIndex]['content'] = newContent;
                      _likedEntries[likeIndex]['updatedAt'] = DateTime.now();
                    }
                  });
                }
              }
            },
          ),
        );
      },
    );
  }
}
