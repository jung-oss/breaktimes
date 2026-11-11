import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_router.dart';
import '../core/localization/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    // 알림 라우팅 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigation.handleNotificationRouting(context);
    });

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // 이미지 프리로딩을 위한 지연
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isLoaded = true;
        });
        _fadeController.forward();
      }
    });

    // 약간의 지연 후 인증 상태 확인
    Future.delayed(const Duration(seconds: 2), () {
      _checkAuthAndNavigate();
    });
  }

  void _checkAuthAndNavigate() {
    final user = _auth.currentUser;

    if (user != null) {
      // 사용자가 로그인한 경우 메인 화면으로 이동
      print('로그인 사용자: ${user.email}');
      print('UID: ${user.uid}');
      print(
          'Provider: ${user.providerData.isNotEmpty ? user.providerData[0].providerId : "unknown"}');

      // GoRouter를 사용하여 메인 화면으로 이동
      context.go(AppRoutes.main);
    } else {
      // 로그인하지 않은 경우 인증 화면으로 이동
      context.go(AppRoutes.auth);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoaded
          ? FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 앱 로고 이미지
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/main_icon.png',
                                width: 180,
                                height: 180,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Break time',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                              fontFamily: 'customFontFamily',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)
                                    .localeName
                                    .startsWith('ko')
                                ? '행복한 하루를 만들어 보세요'
                                : 'Create your happy day',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontFamily: 'customFontFamily',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Text(
                      '© 2025 All Rights Reserved By Plover',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            )
          : Container(), // 로딩 전에는 빈 화면 표시
    );
  }
}

/*





import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
import 'main_screen.dart'; // 메인 화면 import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 애니메이션 컨트롤러를 한 번만 생성
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800), // 애니메이션 시간 단축
      vsync: this,
    );

    // 애니메이션 설정
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // 애니메이션 시작 및 네비게이션 예약
    _initializeAnimation();
  }

  Future<void> _initializeAnimation() async {
    // 애니메이션 시작
    await _fadeController.forward();

    // 추가 지연 시간
    await Future.delayed(const Duration(milliseconds: 200)); // 지연 시간 단축

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted || _isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    // 현재 로그인된 사용자 확인
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    // 페이지 전환 애니메이션
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            // 사용자가 있으면 메인 화면으로, 없으면 로그인 화면으로
            user != null ? const MainScreen() : const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/main.png',
                          width: 220,
                          height: 220,
                          fit: BoxFit.cover,
                          // 이미지 캐싱 설정
                          cacheWidth: 220,
                          cacheHeight: 220,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '오늘 하루',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Text(
                  '© 2025 Gemma. All rights reserved.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/
