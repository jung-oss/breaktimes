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

class HappinessShopScreen extends StatefulWidget {
  const HappinessShopScreen({super.key});

  @override
  State<HappinessShopScreen> createState() => _HappinessShopScreenState();
}

class _HappinessShopScreenState extends State<HappinessShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HeartService _heartService = HeartService();
  int _heartCount = 0;
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
      final heartInfo = await _heartService.getHeartInfo();
      if (mounted) {
        setState(() {
          _heartCount = heartInfo.heartCount;
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // 헤더 (main_screen 스타일 반영)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 로고 (main_screen 스타일)
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/icons/4.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.favorite, color: Colors.red);
                      },
                    ),
                    Text(
                      isKorean ? '내 행복 컬렉션' : 'My Happiness Collection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                // 하트 표시
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red),
                    const SizedBox(width: 4),
                    StreamBuilder<int>(
                      stream: _heartService.heartCountStream(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? _heartCount;
                        return Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _categories.map((category) {
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.icon,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isKorean ? category.nameKo : category.nameEn,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            isKorean
                                ? category.subtitleKo
                                : category.subtitleEn,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
          // Tab content
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
