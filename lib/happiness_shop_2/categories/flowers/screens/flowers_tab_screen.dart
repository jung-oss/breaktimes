import 'package:flutter/material.dart';
import '../../../common/services/catalog_shop_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/widgets/catalog_tab_screen.dart';

class FlowersTabScreen extends StatelessWidget {
  const FlowersTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogTabScreen(
      service: CatalogShopService('flowers', HeartCost.FLOWERS),
      iconEmoji: '🌸',
      titleKo: '행복 꽃말',
      titleEn: 'Happiness Flowers',
      ctaKo: '오늘의 꽃 뽑기',
      ctaEn: 'Draw Flower',
      lightGradient: [Colors.pink.shade50, Colors.white],
    );
  }
}
