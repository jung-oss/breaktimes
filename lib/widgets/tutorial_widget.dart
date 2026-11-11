import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/localization/app_localizations.dart';
import '../services/tutorial_service.dart';
import 'package:go_router/go_router.dart';

/// 앱 사용 튜토리얼 위젯
///
/// 처음 앱을 사용하는 사용자에게 앱의 주요 기능을 소개하는 튜토리얼을 제공합니다.
class TutorialWidget extends StatefulWidget {
  /// 튜토리얼 완료 시 호출되는 콜백
  final VoidCallback? onComplete;

  const TutorialWidget({
    super.key,
    this.onComplete,
  });

  @override
  State<TutorialWidget> createState() => _TutorialWidgetState();
}

// TutorialPage 클래스
class TutorialPage {
  final String imagePath;
  final IconData icon;
  final Color color;

  TutorialPage({
    required this.imagePath,
    required this.icon,
    required this.color,
  });
}

class _TutorialWidgetState extends State<TutorialWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 튜토리얼 완료 처리
  void _completeTutorial() async {
    await TutorialService.markVisited();
    if (widget.onComplete != null) {
      widget.onComplete!();
    }
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    // 언어에 따라 튜토리얼 페이지 구성
    final List<TutorialPage> pages =
        isKorean ? _getKoreanPages() : _getEnglishPages();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 전체 화면 페이지 뷰
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: pages.length,
            itemBuilder: (context, index) {
              return _buildFullScreenTutorialPage(pages[index]);
            },
          ),

          // 페이지 인디케이터 (상단)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => _buildPageIndicator(index == _currentPage),
              ),
            ),
          ),

          // 건너뛰기 버튼 (우상단 - 작게)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: _completeTutorial,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  isKorean ? '건너뛰기' : 'Skip',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // 다음/시작하기 버튼 (하단 중앙 - 작게)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (_currentPage < pages.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _completeTutorial();
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F7A),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _currentPage < pages.length - 1
                        ? (isKorean ? '다음' : 'Next')
                        : (isKorean ? '시작하기' : 'Get Started'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// 한국어 튜토리얼 페이지 구성 (총 6페이지)
  List<TutorialPage> _getKoreanPages() {
    return [
      // 1번 페이지: 알림 설정하기 (1-2번 내용 통합)
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_1.png',
        icon: Icons.notifications_active,
        color: const Color(0xFFFF9F7A),
      ),

      // 2번 페이지: 감정 기록하기 (3번 내용)
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_2.png',
        icon: Icons.emoji_emotions,
        color: const Color(0xFFFF9F7A),
      ),

      // 3번 페이지: 감정 선택하기 (5번 내용)
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_3.png',
        icon: Icons.settings,
        color: const Color(0xFFFF9F7A),
      ),

      // 4번 페이지: 감정 공유 및 소통
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_4.png',
        icon: Icons.favorite,
        color: const Color(0xFFFF9F7A),
      ),

      // 5번 페이지: 미션 관리하기
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_5.png',
        icon: Icons.task_alt,
        color: const Color(0xFFFF9F7A),
      ),

      // 6번 페이지: 미션 통계 확인하기 (미션 달성률 분석)
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_6.png',
        icon: Icons.bar_chart,
        color: const Color(0xFFFF9F7A),
      ),
    ];
  }

  // 영어 튜토리얼 페이지 구성 (총 6페이지)
  List<TutorialPage> _getEnglishPages() {
    return [
      // 1번 페이지: 알림 설정하기 (1-2번 내용 통합)
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_1.png',
        icon: Icons.notifications_active,
        color: const Color(0xFFFF9F7A),
      ),

      // 2번 페이지: 감정 기록하기 (3번, 4번 내용)
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_2.png',
        icon: Icons.emoji_emotions,
        color: const Color(0xFFFF9F7A),
      ),

      // 3번 페이지: 감정 선택하기 (5번 내용)
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_3.png',
        icon: Icons.settings,
        color: const Color(0xFFFF9F7A),
      ),

      // 4번 페이지: 감정 공유 및 소통
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_4.png',
        icon: Icons.favorite,
        color: const Color(0xFFFF9F7A),
      ),

      // 5번 페이지: 미션 관리하기
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_5.png',
        icon: Icons.task_alt,
        color: const Color(0xFFFF9F7A),
      ),

      // 6번 페이지: 미션 통계 확인하기 (미션 달성률 분석)
      TutorialPage(
        imagePath: 'assets/images/tutorial/tutorial_6.png',
        icon: Icons.bar_chart,
        color: const Color(0xFFFF9F7A),
      ),
    ];
  }

  // 전체 화면 튜토리얼 페이지 - 이미지를 최대한 크게
  Widget _buildFullScreenTutorialPage(TutorialPage page) {
    return Stack(
      children: [
        // 전체 화면 이미지
        Positioned.fill(
          child: Image.asset(
            page.imagePath,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 100,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),

        // 하단 텍스트 오버레이
        Positioned(
          bottom: 100, // 버튼 공간 확보
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: 6,
      width: isActive ? 20 : 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
