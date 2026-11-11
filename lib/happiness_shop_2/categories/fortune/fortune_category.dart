// lib/happiness_shop_2/categories/fortune/fortune_category.dart
import 'package:flutter/material.dart';
import '../../common/models/base_category.dart';
import 'screens/fortune_tab_screen.dart';

/// 행복 운세 카테고리
class FortuneCategory implements BaseCategory {
  @override
  String get id => 'fortune';

  @override
  String get nameKo => '행복 운세';

  @override
  String get nameEn => 'Happiness Fortune';

  @override
  String get icon => '🍀';

  @override
  String get subtitleKo => '운';

  @override
  String get subtitleEn => 'Fortune';

  @override
  Widget buildTabScreen(BuildContext context) {
    return const FortuneTabScreen();
  }

  @override
  Future<void> initialize() async {
    // 초기화 로직
  }
}

