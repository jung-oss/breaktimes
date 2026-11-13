import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/locale_provider.dart';
import '../../screens/collection_screen.dart';
import '../models/shop_catalog_item.dart';
import '../services/catalog_shop_service.dart';
import '../theme/shop_tokens.dart';
import 'shop_widgets.dart';

/// 카탈로그형 행복상점 탭 (음악·꽃말·레시피·여행)
///
/// 아직 없는 카드 3장 중 1장을 골라 도감에 모읍니다(기획안 4.2 "고르기 + 도감").
class CatalogTabScreen extends StatefulWidget {
  final CatalogShopService service;

  final String titleKo;
  final String titleEn;
  final String ctaKo;
  final String ctaEn;

  final List<String>? filterTags;
  final List<String>? filterLabelsKo;
  final List<String>? filterLabelsEn;

  const CatalogTabScreen({
    super.key,
    required this.service,
    required this.titleKo,
    required this.titleEn,
    required this.ctaKo,
    required this.ctaEn,
    this.filterTags,
    this.filterLabelsKo,
    this.filterLabelsEn,
  });

  @override
  State<CatalogTabScreen> createState() => _CatalogTabScreenState();
}

class _CatalogTabScreenState extends State<CatalogTabScreen> {
  ShopCatalogItem? _lastCollected;
  bool _isLoading = false;
  String? _selectedTag;
  int _owned = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _refreshProgress();
  }

  Future<void> _refreshProgress() async {
    try {
      final sets = await widget.service.loadProgress();
      if (!mounted) return;
      setState(() {
        _owned = sets.fold(0, (sum, s) => sum + s.ownedCount);
        _total = sets.fold(0, (sum, s) => sum + s.items.length);
      });
    } catch (_) {}
  }

  bool get _allCollected => _total > 0 && _owned >= _total;

  Future<void> _choose() async {
    final isKorean =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode ==
            'ko';
    final cost = widget.service.heartCost;

    try {
      setState(() => _isLoading = true);
      final choices =
          await widget.service.loadChoices(tagFilter: _selectedTag);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (choices.isEmpty) {
        showShopToast(
          context,
          isKorean
              ? '도감을 모두 모았어요! 새 카드가 들어오면 알려 드릴게요.'
              : 'You collected them all! New cards are coming.',
          celebrate: true,
        );
        return;
      }

      final picked = await _showChoiceSheet(choices, isKorean);
      if (picked == null || !mounted) return;

      final ok = await confirmLoveSpend(
        context,
        isKorean: isKorean,
        categoryId: widget.service.categoryId,
        title: isKorean
            ? '「${picked.titleKo}」을 모을까요?'
            : 'Collect "${picked.titleEn}"?',
        subtitle: picked.setName(isKorean),
        cost: cost,
        actionLabel:
            isKorean ? '사랑하기 $cost개로 모으기' : 'Collect for $cost Love',
      );
      if (!ok || !mounted) return;

      setState(() => _isLoading = true);
      final result = await widget.service.collect(picked);
      if (!mounted) return;
      setState(() {
        _lastCollected = result.item;
        _isLoading = false;
      });
      await _refreshProgress();
      if (!mounted) return;

      final completed = result.completedSet;
      if (completed != null && result.bonusGranted) {
        showShopToast(
          context,
          isKorean
              ? '「${completed.name(true)}」 도감 완성! 사랑하기 +${CatalogShopService.setBonus}'
              : '"${completed.name(false)}" complete! +${CatalogShopService.setBonus} Love',
          celebrate: true,
        );
      } else if (completed != null) {
        showShopToast(
          context,
          isKorean
              ? '「${completed.name(true)}」 도감 완성!'
              : '"${completed.name(false)}" complete!',
          celebrate: true,
        );
      } else {
        showShopToast(
          context,
          isKorean
              ? '도감에 담았어요 · 사랑하기 남은 ${result.balanceAfter}개'
              : 'Added to your collection · ${result.balanceAfter} Love left',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.toString().contains('ALREADY_OWNED')) {
        showShopToast(
          context,
          isKorean
              ? '이미 모은 카드예요. 사랑하기는 그대로예요.'
              : 'Already collected. Your Love was not used.',
        );
        await _refreshProgress();
      } else {
        showShopError(context, e, isKorean);
      }
    }
  }

  /// 후보 카드 3장 중 1장을 고르는 창. 고르기 전에는 이름과 한 줄 설명만 보여 줍니다.
  Future<ShopCatalogItem?> _showChoiceSheet(
      List<ShopCatalogItem> choices, bool isKorean) {
    return showModalBottomSheet<ShopCatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final t = ShopTokens.of(sheetContext);
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ShopShape.sheet)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(sheetContext).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isKorean ? '오늘 마음에 드는 카드를 골라요' : 'Pick the card you like today',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isKorean
                    ? '아직 없는 카드만 보여 드려요. 고른 카드는 도감에 남아요.'
                    : 'Only cards you do not have yet. Your pick stays in your collection.',
                style: TextStyle(fontSize: 14, height: 1.5, color: t.ink2),
              ),
              const SizedBox(height: 16),
              for (final item in choices) ...[
                Material(
                  color: t.ground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShopShape.card),
                    side: BorderSide(color: t.line),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(ShopShape.card),
                    onTap: () => Navigator.of(sheetContext).pop(item),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 72),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            ShopArt.pill(widget.service.categoryId,
                                size: 44, radius: 12),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title(isKorean),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: t.ink,
                                    ),
                                  ),
                                  if (item.subtitle(isKorean) != null)
                                    Text(
                                      item.subtitle(isKorean)!,
                                      style: TextStyle(
                                          fontSize: 13, color: t.ink2),
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: t.ink2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: ShopShape.minTouch,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: TextButton.styleFrom(foregroundColor: t.ink2),
                  child: Text(
                    isKorean ? '다음에 할게요' : 'Not now',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final t = ShopTokens.of(context);
    final cost = widget.service.heartCost;
    final result = _lastCollected;

    return ColoredBox(
      color: t.ground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isKorean ? widget.titleKo : widget.titleEn,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                      ),
                    ),
                  ),
                  LovePriceTag(cost: cost, isKorean: isKorean),
                ],
              ),
              const SizedBox(height: 8),
              // 도감 진행: 누르면 도감 화면(무료)
              Material(
                color: t.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ShopShape.button),
                  side: BorderSide(color: t.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(ShopShape.button),
                  onTap: () async {
                    await Navigator.of(context).push(CollectionScreen.route(
                        widget.service, widget.titleKo, widget.titleEn));
                    _refreshProgress();
                  },
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: ShopShape.minTouch + 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.collections_bookmark_outlined,
                              color: t.plum),
                          const SizedBox(width: 10),
                          Text(
                            isKorean ? '내 도감' : 'My collection',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(ShopShape.chip),
                              child: LinearProgressIndicator(
                                value: _total == 0 ? 0 : _owned / _total,
                                minHeight: 6,
                                color: t.plum,
                                backgroundColor: t.plumSoft,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$_owned / $_total',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: t.plum,
                            ),
                          ),
                          Icon(Icons.chevron_right, color: t.ink2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.filterTags != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(widget.filterTags!.length, (i) {
                    final tag = widget.filterTags![i];
                    final label = isKorean
                        ? widget.filterLabelsKo![i]
                        : widget.filterLabelsEn![i];
                    final selected = _selectedTag == tag;
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? t.coralDeep : t.ink,
                      ),
                      backgroundColor: t.surface,
                      selectedColor: t.coralSoft,
                      side: BorderSide(
                        color: selected ? t.coralDeep : t.line,
                        width: selected ? 1.5 : 1,
                      ),
                      shape: const StadiumBorder(),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) {
                        setState(() => _selectedTag = selected ? null : tag);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: result == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShopArt.pill(widget.service.categoryId,
                                size: 96, radius: 24),
                            const SizedBox(height: 16),
                            Text(
                              _allCollected
                                  ? (isKorean
                                      ? '도감을 모두 모았어요! 모은 카드는 언제든 다시 볼 수 있어요.'
                                      : 'All collected! You can revisit them anytime.')
                                  : (isKorean
                                      ? '아직 없는 카드 3장 중 마음에 드는 1장을 골라 도감에 모아요.'
                                      : 'Pick 1 of 3 new cards and keep it in your collection.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 15, height: 1.5, color: t.ink2),
                            ),
                          ],
                        ),
                      )
                    : _ResultCard(item: result, isKorean: isKorean),
              ),
              const SizedBox(height: 12),
              LoveButton(
                isLoading: _isLoading,
                onPressed: _allCollected ? null : _choose,
                showHeart: !_allCollected,
                label: _allCollected
                    ? (isKorean ? '도감을 모두 모았어요' : 'All collected')
                    : (isKorean
                        ? '사랑하기 $cost개로 카드 고르기'
                        : 'Pick a card for $cost Love'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ShopCatalogItem item;
  final bool isKorean;

  const _ResultCard({required this.item, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final subtitle = item.subtitle(isKorean);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(ShopShape.card),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.setName(isKorean),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.plum,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title(isKorean),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.coralDeep,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              item.body(isKorean),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.7,
                color: t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
