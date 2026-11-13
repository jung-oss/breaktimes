// lib/happiness_shop_2/screens/collection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';
import '../common/models/shop_catalog_item.dart';
import '../common/services/catalog_shop_service.dart';
import '../common/theme/shop_tokens.dart';
import '../common/widgets/shop_widgets.dart';

/// 도감: 묶음별로 모은 카드와 아직 못 모은 칸을 보여 줍니다. 보기는 무료입니다.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.service,
    required this.titleKo,
    required this.titleEn,
  });

  final CatalogShopService service;
  final String titleKo;
  final String titleEn;

  static Route<void> route(
          CatalogShopService service, String titleKo, String titleEn) =>
      MaterialPageRoute(
        builder: (_) => CollectionScreen(
          service: service,
          titleKo: titleKo,
          titleEn: titleEn,
        ),
      );

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<List<CollectionSetProgress>> _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.service.loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final t = ShopTokens.of(context);

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text(isKorean
            ? '${widget.titleKo} 도감'
            : '${widget.titleEn} collection'),
      ),
      body: FutureBuilder<List<CollectionSetProgress>>(
        future: _progress,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Message(
              isKorean
                  ? '도감을 불러오지 못했어요. 잠시 후 다시 열어 주세요.'
                  : 'Could not load the collection. Please try again shortly.',
            );
          }
          final sets = snap.data ?? const [];
          if (sets.isEmpty) {
            return _Message(
              isKorean ? '아직 준비된 카드가 없어요.' : 'No cards yet.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              for (final set in sets) ...[
                _SetSection(
                  set: set,
                  categoryId: widget.service.categoryId,
                  isKorean: isKorean,
                ),
                const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SetSection extends StatelessWidget {
  const _SetSection({
    required this.set,
    required this.categoryId,
    required this.isKorean,
  });

  final CollectionSetProgress set;
  final String categoryId;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final total = set.items.length;
    final owned = set.ownedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                set.name(isKorean),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                ),
              ),
            ),
            Text(
              '$owned / $total',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.plum,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(ShopShape.chip),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : owned / total,
            minHeight: 8,
            color: t.plum,
            backgroundColor: t.plumSoft,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          set.isComplete
              ? (set.bonusClaimed
                  ? (isKorean
                      ? '완성했어요! 보너스 사랑하기 +${CatalogShopService.setBonus}를 받았어요.'
                      : 'Complete! You got +${CatalogShopService.setBonus} Love.')
                  : (isKorean ? '완성했어요!' : 'Complete!'))
              : (isKorean
                  ? '다 모으면 사랑하기 +${CatalogShopService.setBonus}개를 받아요.'
                  : 'Complete it to get +${CatalogShopService.setBonus} Love.'),
          style: TextStyle(fontSize: 13, color: t.ink2),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            for (final item in set.items)
              set.ownedIds.contains(item.id)
                  ? _OwnedCard(
                      item: item,
                      categoryId: categoryId,
                      isKorean: isKorean,
                    )
                  : _EmptyCard(isKorean: isKorean),
          ],
        ),
      ],
    );
  }
}

class _OwnedCard extends StatelessWidget {
  const _OwnedCard({
    required this.item,
    required this.categoryId,
    required this.isKorean,
  });

  final ShopCatalogItem item;
  final String categoryId;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final subtitle = item.subtitle(isKorean);
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShopShape.card),
        side: BorderSide(color: t.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(ShopShape.card),
        onTap: () => showCatalogCardSheet(context, item, categoryId, isKorean),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShopArt.pill(categoryId, size: 32, radius: 10),
              const Spacer(),
              Text(
                item.title(isKorean),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: t.ink2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.isKorean});

  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Semantics(
      label: isKorean ? '아직 못 모은 카드' : 'Not collected yet',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: t.ground,
          borderRadius: BorderRadius.circular(ShopShape.card),
          border: Border.all(color: t.line, width: 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline, color: t.ink2, size: 28),
              const SizedBox(height: 6),
              Text(
                isKorean ? '아직 못 모았어요' : 'Not yet',
                style: TextStyle(fontSize: 13, color: t.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 전체 내용(무료로 다시 보기)
Future<void> showCatalogCardSheet(BuildContext context, ShopCatalogItem item,
    String categoryId, bool isKorean) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final t = ShopTokens.of(sheetContext);
      final subtitle = item.subtitle(isKorean);
      return Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ShopShape.sheet)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(sheetContext).viewPadding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ShopArt.pill(categoryId, size: 48, radius: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title(isKorean),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: t.ink,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.coralDeep,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.body(isKorean),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.7,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: ShopShape.minTouch,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: TextButton.styleFrom(foregroundColor: t.ink2),
                  child: Text(
                    isKorean ? '닫기' : 'Close',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: TextStyle(fontSize: 15, color: t.ink2),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
