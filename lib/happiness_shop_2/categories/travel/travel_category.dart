// lib/happiness_shop_2/categories/travel/travel_category.dart
import 'package:flutter/material.dart';
import '../../common/models/base_category.dart';
import 'screens/travel_tab_screen.dart';

/// 행복 여행 카테고리
class TravelCategory implements BaseCategory {
  @override
  String get id => 'travel';

  @override
  String get nameKo => '행복 여행';

  @override
  String get nameEn => 'Happiness Travel';

  @override
  String get icon => '✈️';

  @override
  String get subtitleKo => '추가';

  @override
  String get subtitleEn => 'Travel';

  @override
  Widget buildTabScreen(BuildContext context) {
    return const TravelTabScreen();
  }

  @override
  Future<void> initialize() async {
    // 초기화 로직
  }
}

