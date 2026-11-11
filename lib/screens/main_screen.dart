// main_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/tutorial_widget.dart';
import 'todo/todo_main_screen.dart';
import 'relax/relax_main_screen.dart';
import '../widgets/custom_drawer.dart';
import '../routes/app_router.dart'; // 라우터 import
import 'package:go_router/go_router.dart'; // GoRouter import
import '../screens/shop_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/relax_provider.dart';
import '../widgets/music_player_widget.dart';
import '../providers/music_provider.dart';

// 뮤직 플레이어 상태를 전역으로 관리하기 위한 키
class MainScreen extends StatefulWidget {
  final int initialTab;

  const MainScreen({
    Key? key,
    this.initialTab = 0, // 기본값은 0 (첫 번째 탭)
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();

  // Add the missing audioPlayerKey
  final GlobalKey<AudioPlayerScreenState> audioPlayerKey =
      GlobalKey<AudioPlayerScreenState>();

  // RelaxProvider 참조
  late RelaxProvider _relaxProvider;

  @override
  void initState() {
    super.initState();

    print('MainScreen.initState - initialTab: ${widget.initialTab}');

    _selectedIndex = widget.initialTab;

    // 알림에서 시작된 경우 RelaxMainScreen 초기화 처리 - 더 명확하게 표시
    if (_selectedIndex == 1) {
      print('알림에서 시작: RelaxMainScreen 초기화 수행');
      _checkNotificationTopic();
    }

    _scrollController.addListener(_scrollListener);

    // 앱 시작 시 튜토리얼 표시 여부 확인
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkAndShowTutorial();
      _checkLoginStatus();

      // 알림에서 앱이 시작되었는지 확인 - 우선순위 높게 처리
      await _checkNotificationStart();

      // 라우팅 명시적 처리
      AppNavigation.handleNotificationRouting(context);
    });
  }

  // 알림에서 앱이 시작되었는지 확인하고 필요한 설정 수행
  Future<void> _checkNotificationStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final openRelaxScreen = prefs.getBool('open_relax_screen') ?? false;

      if (openRelaxScreen) {
        // RelaxMainScreen 탭으로 이동
        setState(() {
          _selectedIndex = 1; // RelaxMainScreen 탭 인덱스
        });

        // 오늘의 주제 확인
        final topicFromNotification =
            prefs.getBool('topic_from_notification') ?? false;

        if (topicFromNotification && mounted) {
          // 오늘의 주제가 알림에서 왔으면 RelaxProvider에 반영
          _relaxProvider = Provider.of<RelaxProvider>(context, listen: false);

          // RelaxProvider 초기화 및 새로고침
          await _relaxProvider.initialize();

          // 상태 플래그 초기화 (다음에 앱을 시작할 때 영향 없도록)
          await prefs.remove('open_relax_screen');
          await prefs.remove('topic_from_notification');

          // 안내 메시지 표시
          if (mounted) {
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                final isKorean =
                    Localizations.localeOf(context).languageCode == 'ko';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isKorean
                          ? '알림을 통해 앱이 시작되었습니다. 오늘의 주제가 로드되었습니다.'
                          : 'App launched from notification. Today\'s topic has been loaded.',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      print('알림 시작 확인 오류: $e');
    }
  }

  // 알림에서 전달된 주제 확인
  Future<void> _checkNotificationTopic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromNotification =
          prefs.getBool('topic_from_notification') ?? false;

      if (fromNotification) {
        // 이미 RelaxMainScreen으로 이동 설정됨
        // RelaxProvider 초기화 트리거 필요
        Future.microtask(() {
          final relaxProvider =
              Provider.of<RelaxProvider>(context, listen: false);
          relaxProvider.initialize();
        });

        // 알림 관련 플래그 초기화
        await prefs.remove('topic_from_notification');
      }
    } catch (e) {
      print('알림 주제 확인 오류: $e');
    }
  }

  // 스크롤 리스너
  void _scrollListener() {
    // 기존 구현 유지
  }

  // 튜토리얼 표시 여부 확인 및 표시
  Future<void> _checkAndShowTutorial() async {
    final shouldShow = await TutorialService.shouldShowTutorial();
    if (shouldShow && mounted) {
      _showTutorial();
    }
  }

  // 튜토리얼 표시
  void _showTutorial() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TutorialWidget(
        onComplete: () {
          print('튜토리얼 완료');
        },
      ),
    );
  }

  // 로그인 상태 확인
  void _checkLoginStatus() {
    final user = _authService.currentUser;
    debugPrint("로그인 상태: ${user != null ? '로그인됨' : '게스트'}");
    if (user != null) {
      debugPrint("사용자 ID: ${user.uid}");
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await _authService.signOut();
      // 로그아웃 성공 후 AuthScreen으로 이동
      if (mounted) {
        context.go(AppRoutes.auth); // GoRouter를 사용하여 이동
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    context.pop(); // 드로어 닫기
  }

  // String 타입의 route를 받아서 적절한 화면으로 이동하는 함수
  void _navigateToRoute(String route) {
    if (Navigator.canPop(context)) {
      context.pop(); // 드로어 닫기
    }
    context.push(route);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('MainScreen.build - _selectedIndex: $_selectedIndex');
    return Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            return AspectRatio(
              aspectRatio: 3 / 2,
              child: Image.asset(
                'assets/images/happyday_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('이미지 로드 에러: $error');
                  return Text('이미지 로드 실패');
                },
              ),
            );
          },
        ),
        actions: [
          // Fixed IconButton with proper tooltip
          Consumer<MusicProvider>(
            builder: (context, musicProvider, child) {
              return IconButton(
                icon: musicProvider.isLoading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Icon(
                        musicProvider.isPlaying
                            ? Icons.volume_up
                            : Icons.volume_off,
                      ),
                onPressed: () async {
                  // 로딩 중인 경우 재생 명령 무시
                  if (musicProvider.isLoading) return;
                  await musicProvider.togglePlay();
                },
                tooltip: musicProvider.isPlaying ? '음소거' : '재생',
              );
            },
          ),
        ],
      ),
      drawer: CustomDrawer(
        currentIndex: _selectedIndex,
        onItemSelected: _onItemSelected,
        onSignOut: () => _signOut(context),
        onNavigateToRoute: _navigateToRoute,
      ),
      body: Stack(
        children: [
          _screens[_selectedIndex],
          // 숨겨진 오디오 플레이어 (UI는 표시되지 않지만 기능은 사용 가능)
          Offstage(
            offstage: true,
            child: AudioPlayerScreen(key: audioPlayerKey),
          ),
        ],
      ),
    );
  }

  final List<Widget> _screens = [
    const TodoMainScreen(),
    const RelaxMainScreen(),
    const ChatScreen(),
    const ShopScreen(),
    const SettingsScreen(),
  ];
}
