// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // 앱 색상 정의
  static const ColorScheme lightColorScheme = ColorScheme(
    primary: Color(0xFFFF9E80),
    primaryContainer: Color.fromARGB(255, 151, 35, 0),
    primaryFixed: Color.fromARGB(255, 201, 47, 0),
    secondary: Color(0xFF80DEEA),
    secondaryContainer: Color(0xFF26C6DA),
    surface: Color(0xFFFFFFFF),
    error: Color(0xFFB00020),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF000000),
    onSurface: Color(0xFF3E3E3E),
    onError: Color(0xFFFFFFFF),
    brightness: Brightness.light,
  );

  // 앱 색상 정의 - 다크모드
  static const ColorScheme darkColorScheme = ColorScheme(
    primary: Color(0xFFFFC2A9),
    primaryContainer: Color(0xFFFF9E80),
    primaryFixed: Color(0xFFFF9E80),
    secondary: Color(0xFFB2EBF2),
    secondaryContainer: Color(0xFF80DEEA),
    surface: Color(0xFF303030),
    error: Color(0xFFCF6679),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    onError: Color(0xFF000000),
    brightness: Brightness.dark,
  );

  // 감정별 색상
  static const Map<String, Color> moodColors = {
    'happy': Color(0xFFFFD54F), // 행복 😊
    'calm': Color(0xFF81C784), // 편안 😐
    'surprised': Color(0xFF7986CB), // 놀람 😩
    'sad': Color(0xFF64B5F6), // 슬픔 😢
    'angry': Color(0xFFFF8A65), // 분노 😠
  };

  // 폰트 패밀리 상수 정의
  static const String customFontFamily = 'customFontFamily'; // 사용할 폰트 이름

  // 텍스트 스타일 정의 업데이트
  static const TextStyle headingStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFF2C3E50),
    letterSpacing: 0.5,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Color(0xFF2C3E50),
    letterSpacing: 0.3,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Color(0xFF2C3E50),
    letterSpacing: 0.1,
  );

  static const TextStyle smallStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Color(0xFF2C3E50),
  );

  static const TextStyle buttonStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF2C3E50),
    letterSpacing: 0.2,
  );

  // 앱 전체 텍스트 스타일 정의
  static const TextTheme textTheme = TextTheme(
    // 추가적인 텍스트 스타일을 추가하여 headlineSmall를 정의합니다.
    headlineSmall: TextStyle(
      fontFamily: customFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: Color(0xFF2C3E50),
    ),

    // 섹션 타이틀 (예: '새로운 미션', '오늘의 미션', '할일 분석' 등)
    bodyLarge: TextStyle(
      fontFamily: customFontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFF2C3E50),
      letterSpacing: 0.2,
    ),
    // 서브 타이틀 (예: '달성률 추이', '감정 통계' 등)
    bodyMedium: TextStyle(
      fontFamily: customFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFF2C3E50),
      letterSpacing: 0.1,
    ),
    // 일반 텍스트
    bodySmall: TextStyle(
      fontFamily: customFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: Color(0xFF2C3E50),
    ),
    // 큰 제목 (예: 화면 타이틀)
    displayLarge: TextStyle(
      fontFamily: customFontFamily,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Color(0xFF2C3E50),
      letterSpacing: 0.5,
    ),
    // 중간 제목 (예: 섹션 타이틀)
    displayMedium: TextStyle(
      fontFamily: customFontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Color(0xFF2C3E50),
      letterSpacing: 0.3,
    ),
    // 작은 제목 (예: 카드 타이틀)
    titleLarge: TextStyle(
      fontFamily: customFontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFF2C3E50),
      letterSpacing: 0.2,
    ),
    // 버튼 텍스트
    labelLarge: TextStyle(
      fontFamily: customFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );

  // 카테고리 아이콘
  static const Map<String, IconData> categoryIcons = {
    'topic': Icons.lightbulb_outline,
    'progress': Icons.trending_up,
    'emotion': Icons.mood,
    'thought': Icons.edit_note,
    'distribution': Icons.pie_chart,
    'analysis': Icons.analytics,
    'calendar': Icons.calendar_today,
    'notification': Icons.notifications,
    'profile': Icons.person,
    'settings': Icons.settings,
  };

  // 다크 모드용 텍스트 스타일
  static const TextStyle darkHeadingStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle darkSubheadingStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  static const TextStyle darkBodyStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white70, // 약간 투명도를 주어 부드럽게
    letterSpacing: 0.1,
  );

  static const TextStyle darkSmallStyle = TextStyle(
    fontFamily: customFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.white70,
  );

  // 채팅 관련 색상
  static const chatColors = {
    'light': {
      'background': Color(0xFFFFF0F0),
      'text': Color(0xFF2C3E50),
      'title': Color(0xFFFF4081),
    },
    'dark': {
      'background': Color(0xFF2C2C2C),
      'text': Color(0xFFE0E0E0),
      'title': Color(0xFFFF80AB),
    },
  };

  // 미션 박스 관련 색상
  static const missionBoxColors = {
    'light': {
      'background': Color(0xFFFFF3E0),
      'text': Color(0xFF2C3E50),
    },
    'dark': {
      'background': Color(0xFF424242),
      'text': Color(0xFFFFFFFF),
    },
  };

  // 기록 카드 관련 색상
  static const recordCardColors = {
    'light': {
      'background': Colors.white,
      'text': Color(0xFF2C3E50),
    },
    'dark': {
      'background': Color(0xFF2C2C2C),
      'text': Color(0xFFE0E0E0),
    },
  };

  // 북마크/좋아요 관련 색상
  static const bookmarkColors = {
    'light': {
      'background': Color(0xFFF8F9FA),
      'card': Color(0xFFFFFFFF),
      'border': Color(0xFFE9ECEF),
      'text': Color(0xFF2C3E50),
      'title': Color(0xFF212529),
    },
    'dark': {
      'background': Color(0xFF2C2C2C),
      'card': Color(0xFF3C3C3C),
      'border': Color(0xFF4E4E4E),
      'text': Color(0xFFE0E0E0),
      'title': Color(0xFFFFFFFF),
    },
  };

  // 테마 데이터 - 라이트모드
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: lightColorScheme,
      useMaterial3: true,
      fontFamily: customFontFamily,
      scaffoldBackgroundColor: lightColorScheme.surface,
      textTheme: const TextTheme(
        displayLarge: headingStyle, // 큰 제목
        displayMedium: subheadingStyle, // 중간 제목
        bodyLarge: bodyStyle, // 본문 텍스트
        bodyMedium: smallStyle, // 작은 텍스트
        labelLarge: buttonStyle, // 버튼 텍스트
        headlineSmall: sectionTitleStyle, // 섹션 제목
      ),
      extensions: const [ChartColors.light],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFF9E80),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: lightColorScheme.primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: lightColorScheme.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: lightColorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightColorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: lightColorScheme.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightColorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: lightColorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 24),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: lightColorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor:
            WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return lightColorScheme.primary;
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor:
            WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return lightColorScheme.primary;
          }
          return Colors.white;
        }),
        trackColor:
            WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return lightColorScheme.primary.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
    );
  }

  // 테마 데이터 - 다크모드

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: darkColorScheme,
      useMaterial3: true,
      fontFamily: customFontFamily,
      scaffoldBackgroundColor: darkColorScheme.surface,
      textTheme: const TextTheme(
        displayLarge: darkHeadingStyle,
        displayMedium: darkSubheadingStyle,
        bodyLarge: darkBodyStyle,
        bodyMedium: darkSmallStyle,
        labelLarge: TextStyle(
          fontFamily: customFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        headlineSmall: TextStyle(
          fontFamily: customFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      // 차트 관련 색상 설정
      extensions: const [ChartColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: darkColorScheme.primaryContainer,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: darkColorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkColorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: darkColorScheme.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkColorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkColorScheme.surface,
        selectedItemColor: darkColorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 24),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkColorScheme.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor:
            WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return darkColorScheme.primary;
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor:
            WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return darkColorScheme.primary;
          }
          return Colors.white;
        }),
        trackColor:
            WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return darkColorScheme.primary.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
    );
  }
}

// 차트 테마 색상 정의를 위한 확장 클래스
class ChartColors extends ThemeExtension<ChartColors> {
  final Color? text;
  final Color? background;
  final Color? gridLine;

  const ChartColors({
    required this.text,
    required this.background,
    required this.gridLine,
  });

  @override
  ThemeExtension<ChartColors> copyWith({
    Color? text,
    Color? background,
    Color? gridLine,
  }) {
    return ChartColors(
      text: text ?? this.text,
      background: background ?? this.background,
      gridLine: gridLine ?? this.gridLine,
    );
  }

  @override
  ThemeExtension<ChartColors> lerp(
      ThemeExtension<ChartColors>? other, double t) {
    if (other is! ChartColors) {
      return this;
    }
    return ChartColors(
      text: Color.lerp(text, other.text, t),
      background: Color.lerp(background, other.background, t),
      gridLine: Color.lerp(gridLine, other.gridLine, t),
    );
  }

  // 라이트 모드용 차트 색상
  static const light = ChartColors(
    text: Color(0xFF666666),
    background: Colors.white,
    gridLine: Color(0xFFEEEEEE),
  );

  // 다크 모드용 차트 색상
  static const dark = ChartColors(
    text: Color(0xFFDDDDDD),
    background: Color(0xFF303030),
    gridLine: Color(0xFF555555),
  );
}
