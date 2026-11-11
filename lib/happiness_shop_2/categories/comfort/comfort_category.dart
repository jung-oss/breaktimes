// lib/happiness_shop_2/categories/comfort/comfort_category.dart
import 'package:flutter/material.dart';
import '../../common/models/base_category.dart';
import 'screens/comfort_tab_screen.dart';

/// 행복 위로 카테고리
class ComfortCategory implements BaseCategory {
  @override
  String get id => 'comfort';

  @override
  String get nameKo => '행복 위로';

  @override
  String get nameEn => 'Happiness Comfort';

  @override
  String get icon => '💌';

  @override
  String get subtitleKo => '위로';

  @override
  String get subtitleEn => 'Comfort';

  @override
  Widget buildTabScreen(BuildContext context) {
    return const ComfortTabScreen();
  }

  @override
  Future<void> initialize() async {
    // 초기화 로직
  }
}

