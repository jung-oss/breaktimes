// lib/happiness_shop_2/screens/happiness_shop_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../common/services/heart_service.dart';
import '../categories/vitamin/vitamin_category.dart';
import '../categories/quotes/quotes_category.dart';
import '../categories/music/music_category.dart';
import '../categories/fortune/fortune_category.dart';
import '../categories/comfort/comfort_category.dart';
import '../categories/flowers/flowers_category.dart';
import '../categories/recipe/recipe_category.dart';
import '../categories/travel/travel_category.dart';
import '../common/models/base_category.dart';
import '../common/theme/shop_tokens.dart';
import '../common/widgets/shop_widgets.dart';

class HappinessShopScreen extends StatefulWidget {
  const HappinessShopScreen({super.key});

  @override
  State<HappinessShopScreen> createState() => _HappinessShopScreenState();
}

class _HappinessShopScreenState extends State<HappinessShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HeartService _heartService = HeartService();
  bool _isLoading = true;

  // 8개 카테고리
  final List<BaseCategory> _categories = [
    VitaminCategory(),
    QuotesCategory(),
    MusicCategory(),
    FortuneCategory(),
    ComfortCategory(),
    FlowersCategory(),
    RecipeCategory(),
    TravelCategory(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadInitialData();
    _initializeCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      await _heartService.getHeartInfo();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeCategories() async {
    for (final category in _categories) {
      try {
        await category.initialize();
      } catch (e) {
        // 카테고리 초기화 실패는 무시
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    final isKorean = languageCode == 'ko';
    final t = ShopTokens.of(context);

    return Scaffold(
      backgroundColor: t.ground,
      body: Column(
        children: [
          // 탭 줄 + 사랑하기 잔액 칩 (앱 상단바 아래에 머리글을 하나 더 두지 않습니다)
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: _categories.map((category) {
                      return Tab(
                        height: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ShopArt.pill(category.id, size: 28, radius: 8),
                            const SizedBox(width: 8),
                            Text(isKorean ? category.nameKo : category.nameEn),
                          ],
                        ),
                      );
                    }).toList(),
                    labelColor: t.ink,
                    unselectedLabelColor: t.ink2,
                    indicatorColor: t.coral,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 12),
                  child: LoveBalanceChip(isKorean: isKorean),
                ),
              ],
            ),
          ),
          // 탭 내용
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: _categories.map((category) {
                      return category.buildTabScreen(context);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
