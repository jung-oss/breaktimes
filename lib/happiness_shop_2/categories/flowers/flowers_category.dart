// lib/happiness_shop_2/categories/flowers/flowers_category.dart
import 'package:flutter/material.dart';
import '../../common/models/base_category.dart';
import 'screens/flowers_tab_screen.dart';

/// 행복 꽃말 카테고리
class FlowersCategory implements BaseCategory {
  @override
  String get id => 'flowers';

  @override
  String get nameKo => '행복 꽃말';

  @override
  String get nameEn => 'Happiness Flowers';

  @override
  String get icon => '🌸';

  @override
  String get subtitleKo => '꽃';

  @override
  String get subtitleEn => 'Flowers';

  @override
  Widget buildTabScreen(BuildContext context) {
    return const FlowersTabScreen();
  }

  @override
  Future<void> initialize() async {
    // 초기화 로직
  }
}

