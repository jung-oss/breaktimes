// lib/happiness_shop_2/categories/vitamin/vitamin_category.dart
import 'package:flutter/material.dart';
import '../../common/models/base_category.dart';
import 'screens/vitamin_tab_screen.dart';
import 'services/vitamin_service.dart';

/// 행복 비타민 카테고리
class VitaminCategory implements BaseCategory {
  final VitaminService _service = VitaminService();

  @override
  String get id => 'vitamin';

  @override
  String get nameKo => '행복 비타민';

  @override
  String get nameEn => 'Happiness Vitamin';

  @override
  String get icon => '💊';

  @override
  String get subtitleKo => '기록';

  @override
  String get subtitleEn => 'Record';

  @override
  Widget buildTabScreen(BuildContext context) {
    return VitaminTabScreen(service: _service);
  }

  @override
  Future<void> initialize() async {
    await _service.ensureSlotsInitialized();
  }
}

