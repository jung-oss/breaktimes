import 'package:flutter/material.dart';
import '../../../common/services/catalog_shop_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/widgets/catalog_tab_screen.dart';

class TravelTabScreen extends StatelessWidget {
  const TravelTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogTabScreen(
      service: CatalogShopService('travel', HeartCost.TRAVEL),
      titleKo: '행복 여행',
      titleEn: 'Happiness Travel',
      ctaKo: '여행 추천 받기',
      ctaEn: 'Get Travel Idea',
      filterTags: const ['walk', 'imagine'],
      filterLabelsKo: const ['근처 산책', '상상 여행'],
      filterLabelsEn: const ['Local Walk', 'Imaginary Trip'],
    );
  }
}
