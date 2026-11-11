/// 행복상점 카탈로그 아이템 (음악·꽃말·레시피·여행)
class ShopCatalogItem {
  final String id;
  final String titleKo;
  final String titleEn;
  final String bodyKo;
  final String bodyEn;
  final String? subtitleKo;
  final String? subtitleEn;
  final List<String> tags;

  const ShopCatalogItem({
    required this.id,
    required this.titleKo,
    required this.titleEn,
    required this.bodyKo,
    required this.bodyEn,
    this.subtitleKo,
    this.subtitleEn,
    this.tags = const [],
  });

  String title(bool isKorean) => isKorean ? titleKo : titleEn;
  String body(bool isKorean) => isKorean ? bodyKo : bodyEn;
  String? subtitle(bool isKorean) =>
      isKorean ? subtitleKo : subtitleEn;
}
