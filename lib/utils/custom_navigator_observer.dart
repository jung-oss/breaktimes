// lib/utils/custom_navigator_observer.dart

import 'package:flutter/material.dart';

// 화면 전환 이벤트를 처리하는 NavigatorObserver
class CustomNavigatorObserver extends NavigatorObserver {
  // 싱글톤 패턴 적용
  static final CustomNavigatorObserver _instance =
      CustomNavigatorObserver._internal();

  factory CustomNavigatorObserver() {
    return _instance;
  }

  CustomNavigatorObserver._internal();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRouteChange('PUSH', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRouteChange('POP', route, previousRoute);

    // 이전 화면의 State 객체에 didPopNext 메서드가 있는지 확인하고 호출
    if (previousRoute?.navigator?.context != null) {
      final state = previousRoute!.navigator!.context
          .findAncestorStateOfType<State<StatefulWidget>>();

      // didPopNext 메서드 호출 시도 - 개선된 방식
      if (state != null) {
        try {
          // RouteAware 인터페이스를 구현한 화면인지 확인
          if (state is RouteAware) {
            (state as RouteAware).didPopNext();
          }
          // 특정 클래스 타입인지 확인
          else if (_isRelaxScreenState(state)) {
            (state as dynamic).didPopNext();
          }
        } catch (e) {
          print('Error calling didPopNext: $e');
        }
      }
    }
  }

  // 특정 화면의 State 타입인지 확인하는 헬퍼 메서드
  bool _isRelaxScreenState(State state) {
    final typeName = state.runtimeType.toString();
    return typeName.contains('_RelaxMainScreenState') ||
        typeName.contains('_RelaxHistoryScreenState') ||
        typeName.contains('_RelaxAnalysisScreenState') ||
        typeName.contains('_BookmarkedScreenState');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRouteChange('REPLACE', newRoute, oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logRouteChange('REMOVE', route, previousRoute);
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didStartUserGesture(route, previousRoute);
    _logRouteChange('GESTURE_START', route, previousRoute);
  }

  @override
  void didStopUserGesture() {
    super.didStopUserGesture();
    print('Navigation GESTURE_STOP');
  }

  void _logRouteChange(
      String action, Route<dynamic>? current, Route<dynamic>? previous) {
    final currentName = _getRouteName(current);
    final previousName = _getRouteName(previous);
    print('Navigation $action: $previousName -> $currentName');
  }

  // 개선된 경로 이름 가져오기 메서드 - 모든 라우트 타입에 안전하게 동작
  String _getRouteName(Route<dynamic>? route) {
    if (route == null) return 'none';

    // 이름이 있으면 해당 이름 반환
    if (route.settings.name != null) return route.settings.name!;

    // 라우트 타입에 따라 안전하게 처리
    try {
      // 다이얼로그 라우트인지 확인
      if (_isDialogRoute(route)) {
        return 'dialog-${route.runtimeType}';
      }

      // 팝업 라우트인지 확인
      if (route is PopupRoute) {
        return 'popup-${route.runtimeType}';
      }

      // MaterialPageRoute와 같은 페이지 라우트인지 확인
      if (route is PageRoute) {
        return 'page-${route.runtimeType}';
      }

      // 기타 라우트 타입
      return route.runtimeType.toString();
    } catch (e) {
      print('Error getting route name: $e');
      return 'unknown-route';
    }
  }

  // 다이얼로그 라우트인지 확인하는 안전한 메서드
  bool _isDialogRoute(Route<dynamic> route) {
    final typeName = route.runtimeType.toString();
    return typeName.contains('DialogRoute');
  }
}

// RouteAware를 쉽게 구현할 수 있는 Mixin
mixin RelaxScreenRouteAware<T extends StatefulWidget> on State<T>
    implements RouteAware {
  static RouteObserver<PageRoute>? routeObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerRouteObserver();
  }

  void _registerRouteObserver() {
    if (routeObserver != null) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null && modalRoute is PageRoute) {
        routeObserver!.subscribe(this, modalRoute);
      }
    }
  }

  @override
  void dispose() {
    if (routeObserver != null) {
      routeObserver!.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPush() {
    // 화면이 푸시되었을 때 호출됨
    print('${widget.runtimeType} didPush');
  }

  @override
  void didPopNext() {
    // 이 화면 위에 있던 화면이 팝되었을 때 호출됨
    print('${widget.runtimeType} didPopNext');
    refreshData();
  }

  @override
  void didPushNext() {
    // 이 화면 위에 다른 화면이 푸시되었을 때 호출됨
    print('${widget.runtimeType} didPushNext');
  }

  @override
  void didPop() {
    // 이 화면이 팝되었을 때 호출됨
    print('${widget.runtimeType} didPop');
  }

  // 자식 클래스에서 구현해야 하는 메서드
  void refreshData();
}
