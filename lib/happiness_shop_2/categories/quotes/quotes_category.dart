// lib/happiness_shop_2/categories/quotes/quotes_category.dart
import 'package:flutter/material.dart';
import '../../common/models/base_category.dart';
import 'screens/quotes_tab_screen.dart';

/// 행복 글귀 카테고리
class QuotesCategory implements BaseCategory {
  @override
  String get id => 'quotes';

  @override
  String get nameKo => '행복 글귀';

  @override
  String get nameEn => 'Happiness Quotes';

  @override
  String get icon => '📝';

  @override
  String get subtitleKo => '좋은글';

  @override
  String get subtitleEn => 'Good Words';

  @override
  Widget buildTabScreen(BuildContext context) {
    return const QuotesTabScreen();
  }

  @override
  Future<void> initialize() async {
    // 초기화 로직 (필요시 추가)
  }
}

