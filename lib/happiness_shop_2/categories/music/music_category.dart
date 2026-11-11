// lib/happiness_shop_2/categories/music/music_category.dart
import 'package:flutter/material.dart';
import '../../common/models/base_category.dart';
import 'screens/music_tab_screen.dart';

/// 행복 음악 카테고리
class MusicCategory implements BaseCategory {
  @override
  String get id => 'music';

  @override
  String get nameKo => '행복 음악';

  @override
  String get nameEn => 'Happiness Music';

  @override
  String get icon => '🎵';

  @override
  String get subtitleKo => '행복송';

  @override
  String get subtitleEn => 'Happy Songs';

  @override
  Widget buildTabScreen(BuildContext context) {
    return const MusicTabScreen();
  }

  @override
  Future<void> initialize() async {
    // 초기화 로직
  }
}

