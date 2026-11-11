// app_router.dart 파일 수정

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth_screen.dart';
import '../screens/todo/todo_main_screen.dart';
import '../screens/todo/todo_history_screen.dart';
import '../screens/todo/todo_analysis_screen.dart';
import '../screens/relax/relax_main_screen.dart';
import '../screens/relax/relax_history_screen.dart';
import '../screens/relax/relax_analysis_screen.dart';
import '../screens/relax/bookmarked_screen.dart';
import '../screens/shop_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/main_screen.dart';
import '../screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/splash_screen.dart';
import '../utils/custom_navigator_observer.dart';

// 라우트 이름 상수 정의
class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String welcome = '/welcome';
  static const String main = '/main';
  static const String relax = '/relax';
  static const String relaxHistory = '/relax/history';
  static const String relaxAnalysis = '/relax/analysis';
  static const String relaxBookmarks = '/relax/bookmarks';
  static const String relaxMain = '/relax/main';
  static const String relaxMainTab = '/relax/main/:tab';

  static const String todo = '/todo';
  static const String todoHistory = '/todo/history';
  static const String todoAnalysis = '/todo/analysis';
  static const String chat = '/chat';
  static const String shop = '/shop';
  static const String blog = '/blog';
  static const String settings = '/settings';
}

// GoRouter 설정
final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  observers: [CustomNavigatorObserver()],
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: AppRoutes.main,
      builder: (context, state) {
        // 알림에서 시작되었을 경우 state.extra에 initialTab이 전달될 수 있음
        final int initialTab = state.extra != null && state.extra is int
            ? state.extra as int
            : 1; // 기본값은 RelaxMainScreen(1)

        return MainScreen(
          initialTab: initialTab,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.relax,
      builder: (context, state) => const RelaxMainScreen(),
      routes: [
        GoRoute(
          path: 'history',
          builder: (context, state) => const RelaxHistoryScreen(),
        ),
        GoRoute(
          path: 'analysis',
          builder: (context, state) => const RelaxAnalysisScreen(),
        ),
        GoRoute(
          path: 'bookmarks',
          builder: (context, state) => const BookmarkedScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.todo,
      builder: (context, state) => const TodoMainScreen(),
      routes: [
        GoRoute(
          path: 'history',
          builder: (context, state) => const TodoHistoryScreen(),
        ),
        GoRoute(
          path: 'analysis',
          builder: (context, state) => const TodoAnalysisScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: AppRoutes.shop,
      builder: (context, state) => const ShopScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('페이지를 찾을 수 없습니다: ${state.uri.path}'),
    ),
  ),
);

// 라우트 네비게이션 헬퍼 클래스
class AppNavigation {
  static void navigateTo(BuildContext context, String route, {Object? extra}) {
    context.go(route, extra: extra);
  }

  static void pushTo(BuildContext context, String route, {Object? extra}) {
    context.push(route, extra: extra);
  }

  static void pop(BuildContext context) {
    context.pop();
  }

  static void replaceWith(BuildContext context, String route, {Object? extra}) {
    context.replace(route, extra: extra);
  }

  // 알림에서 앱이 시작되었을 때의 라우팅을 처리하는 메서드
  static Future<void> handleNotificationRouting(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final forceNavigateToRelax =
          prefs.getBool('force_navigate_to_relax') ?? false;
      final launchedFromNotification =
          prefs.getBool('launched_from_notification') ?? false;

      print(
          'handleNotificationRouting - forceNavigateToRelax: $forceNavigateToRelax, launchedFromNotification: $launchedFromNotification');

      if (forceNavigateToRelax || launchedFromNotification) {
        final initialTab = prefs.getInt('initial_tab_index') ?? 1;

        print('알림에서 앱 시작 감지 - initialTab: $initialTab');

        // 플래그 초기화를 먼저 수행하여 중복 처리 방지
        await prefs.remove('force_navigate_to_relax');
        await prefs.remove('launched_from_notification');
        await prefs.remove('initial_route');

        // 그 후 라우팅 수행
        navigateTo(context, AppRoutes.main, extra: initialTab);
        print('알림 클릭: 라우팅 완료 - RelaxMainScreen으로 이동');
      }
    } catch (e) {
      print('알림 라우팅 처리 오류: $e');
    }
  }
}
