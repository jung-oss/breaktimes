// lib/happiness_shop_2/categories/recipe/recipe_category.dart
import 'package:flutter/material.dart';
import '../../common/models/base_category.dart';
import 'screens/recipe_tab_screen.dart';

/// 행복 레시피 카테고리
class RecipeCategory implements BaseCategory {
  @override
  String get id => 'recipe';

  @override
  String get nameKo => '행복 레시피';

  @override
  String get nameEn => 'Happiness Recipe';

  @override
  String get icon => '🍰';

  @override
  String get subtitleKo => '추가';

  @override
  String get subtitleEn => 'Recipe';

  @override
  Widget buildTabScreen(BuildContext context) {
    return const RecipeTabScreen();
  }

  @override
  Future<void> initialize() async {
    // 초기화 로직
  }
}

