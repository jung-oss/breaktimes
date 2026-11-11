import 'package:flutter/material.dart';
import '../../../common/services/catalog_shop_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/widgets/catalog_tab_screen.dart';

class RecipeTabScreen extends StatelessWidget {
  const RecipeTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogTabScreen(
      service: CatalogShopService('recipe', HeartCost.RECIPE),
      iconEmoji: '🍰',
      titleKo: '행복 레시피',
      titleEn: 'Happiness Recipe',
      ctaKo: '레시피 추천 받기',
      ctaEn: 'Get Recipe',
      lightGradient: [Colors.orange.shade50, Colors.white],
      filterTags: const ['quick', 'warm'],
      filterLabelsKo: const ['빠른', '따뜻한'],
      filterLabelsEn: const ['Quick', 'Warm'],
    );
  }
}
