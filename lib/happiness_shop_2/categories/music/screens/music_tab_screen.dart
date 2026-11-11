import 'package:flutter/material.dart';
import '../../../common/services/catalog_shop_service.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/widgets/catalog_tab_screen.dart';

class MusicTabScreen extends StatelessWidget {
  const MusicTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogTabScreen(
      service: CatalogShopService('music', HeartCost.MUSIC),
      iconEmoji: '🎵',
      titleKo: '행복 음악',
      titleEn: 'Happiness Music',
      ctaKo: '오늘의 추천 받기',
      ctaEn: 'Get Recommendation',
      lightGradient: [Colors.purple.shade50, Colors.white],
      filterTags: const ['calm', 'hope'],
      filterLabelsKo: const ['고요', '응원'],
      filterLabelsEn: const ['Calm', 'Hope'],
    );
  }
}
