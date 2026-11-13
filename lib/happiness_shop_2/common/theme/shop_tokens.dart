// lib/happiness_shop_2/common/theme/shop_tokens.dart
import 'package:flutter/material.dart';

/// 행복-가게 디자인 토큰 (docs/happiness_shop_design_system.md 2장)
///
/// 밝은·어두운 화면 값을 한곳에 둡니다. 가게 화면은 색을 직접 쓰지 않고 이 값을 씁니다.
class ShopTokens {
  const ShopTokens._({
    required this.ground,
    required this.surface,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.coral,
    required this.onCoral,
    required this.coralDeep,
    required this.coralSoft,
    required this.plum,
    required this.plumSoft,
    required this.heart,
    required this.sunSoft,
    required this.onSunSoft,
    required this.successSoft,
    required this.onSuccessSoft,
  });

  final Color ground;
  final Color surface;
  final Color line;
  final Color ink;
  final Color ink2;
  final Color coral;
  final Color onCoral;
  final Color coralDeep;
  final Color coralSoft;
  final Color plum;
  final Color plumSoft;
  final Color heart;
  final Color sunSoft;
  final Color onSunSoft;
  final Color successSoft;
  final Color onSuccessSoft;

  static const light = ShopTokens._(
    ground: Color(0xFFFFF8F1),
    surface: Color(0xFFFFFFFF),
    line: Color(0xFFF0E2D5),
    ink: Color(0xFF2C3E50),
    ink2: Color(0xFF5B6B7A),
    coral: Color(0xFFFF9E80),
    onCoral: Color(0xFF4A2316),
    coralDeep: Color(0xFFB8461F),
    coralSoft: Color(0xFFFFE5DB),
    plum: Color(0xFF6E2C91),
    plumSoft: Color(0xFFF3E8F8),
    heart: Color(0xFFE5486A),
    sunSoft: Color(0xFFFFF2C9),
    onSunSoft: Color(0xFF4A3500),
    successSoft: Color(0xFFE3F4E8),
    onSuccessSoft: Color(0xFF1F5133),
  );

  static const dark = ShopTokens._(
    ground: Color(0xFF1E1A18),
    surface: Color(0xFF2A2421),
    line: Color(0xFF43382F),
    ink: Color(0xFFF5EDE6),
    ink2: Color(0xFFC9BBB0),
    coral: Color(0xFFFFB59E),
    onCoral: Color(0xFF3A1A0F),
    coralDeep: Color(0xFFFFB59E),
    coralSoft: Color(0xFF4A2E24),
    plum: Color(0xFFD3A8EC),
    plumSoft: Color(0xFF3A2A45),
    heart: Color(0xFFFF7A93),
    sunSoft: Color(0xFF4A3B12),
    onSunSoft: Color(0xFFFFE7A3),
    successSoft: Color(0xFF1F3A29),
    onSuccessSoft: Color(0xFFB9E5C8),
  );

  static ShopTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// 모서리·간격 (디자인 시스템 4장)
class ShopShape {
  ShopShape._();
  static const double chip = 999;
  static const double button = 14;
  static const double card = 20;
  static const double sheet = 28;
  static const double minTouch = 48;
}
