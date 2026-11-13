/// 행복상점 카탈로그 아이템 (음악·꽃말·레시피·여행)
///
/// 도감: 같은 [setId]의 카드를 모두 모으면 묶음 하나를 완성합니다.
class ShopCatalogItem {
  final String id;
  final String titleKo;
  final String titleEn;
  final String bodyKo;
  final String bodyEn;
  final String? subtitleKo;
  final String? subtitleEn;
  final List<String> tags;

  /// 도감 묶음 ID (예: spring_flowers). 없으면 'default'
  final String setId;
  final String setNameKo;
  final String setNameEn;

  /// 도감 안 순서
  final int order;

  const ShopCatalogItem({
    required this.id,
    required this.titleKo,
    required this.titleEn,
    required this.bodyKo,
    required this.bodyEn,
    this.subtitleKo,
    this.subtitleEn,
    this.tags = const [],
    this.setId = 'default',
    this.setNameKo = '기본 도감',
    this.setNameEn = 'Collection',
    this.order = 0,
  });

  String title(bool isKorean) => isKorean ? titleKo : titleEn;
  String body(bool isKorean) => isKorean ? bodyKo : bodyEn;
  String? subtitle(bool isKorean) => isKorean ? subtitleKo : subtitleEn;
  String setName(bool isKorean) => isKorean ? setNameKo : setNameEn;

  /// 사용자 도감에 저장할 값
  Map<String, dynamic> toCollectionMap(String categoryId) => {
        'categoryId': categoryId,
        'catalogId': id,
        'setId': setId,
        'titleKo': titleKo,
        'titleEn': titleEn,
        'bodyKo': bodyKo,
        'bodyEn': bodyEn,
        if (subtitleKo != null) 'subtitleKo': subtitleKo,
        if (subtitleEn != null) 'subtitleEn': subtitleEn,
      };
}
