// lib/happiness_shop_2/common/models/base_category.dart
import 'package:flutter/material.dart';

/// 모든 카테고리가 구현해야 하는 기본 인터페이스
abstract class BaseCategory {
  /// 카테고리 ID
  String get id;

  /// 한국어 이름
  String get nameKo;

  /// 영어 이름
  String get nameEn;

  /// 아이콘 이모지
  String get icon;

  /// 한국어 서브타이틀
  String get subtitleKo;

  /// 영어 서브타이틀
  String get subtitleEn;

  /// 카테고리 탭 화면 빌드
  Widget buildTabScreen(BuildContext context);

  /// 카테고리 초기화
  Future<void> initialize();
}

