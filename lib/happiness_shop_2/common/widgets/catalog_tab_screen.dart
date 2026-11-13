import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/locale_provider.dart';
import '../models/shop_catalog_item.dart';
import '../services/catalog_shop_service.dart';
import '../theme/shop_tokens.dart';
import 'shop_widgets.dart';

/// 카탈로그형 행복상점 탭 (음악·꽃말·레시피·여행)
class CatalogTabScreen extends StatefulWidget {
  final CatalogShopService service;

  /// 예전 머리글용 이모지. 디자인 시스템에서는 알약 사진을 쓰므로 쓰지 않습니다.
  final String iconEmoji;
  final String titleKo;
  final String titleEn;
  final String ctaKo;
  final String ctaEn;

  /// 예전 배경 그라데이션. 디자인 시스템에서는 크림 바탕을 쓰므로 쓰지 않습니다.
  final List<Color> lightGradient;
  final List<String>? filterTags;
  final List<String>? filterLabelsKo;
  final List<String>? filterLabelsEn;

  const CatalogTabScreen({
    super.key,
    required this.service,
    required this.iconEmoji,
    required this.titleKo,
    required this.titleEn,
    required this.ctaKo,
    required this.ctaEn,
    required this.lightGradient,
    this.filterTags,
    this.filterLabelsKo,
    this.filterLabelsEn,
  });

  @override
  State<CatalogTabScreen> createState() => _CatalogTabScreenState();
}

class _CatalogTabScreenState extends State<CatalogTabScreen> {
  ShopCatalogItem? _todayResult;
  bool _isLoading = false;
  String? _selectedTag;

  Future<void> _draw() async {
    final locale =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    final isKorean = locale == 'ko';
    final cost = widget.service.heartCost;

    try {
      final ok = await confirmLoveSpend(
        context,
        isKorean: isKorean,
        categoryId: widget.service.categoryId,
        title: isKorean ? widget.titleKo : widget.titleEn,
        subtitle: isKorean ? widget.ctaKo : widget.ctaEn,
        cost: cost,
      );
      if (!ok || !mounted) return;

      setState(() => _isLoading = true);
      final item = await widget.service.drawWithHearts(tagFilter: _selectedTag);
      if (!mounted) return;
      setState(() {
        _todayResult = item;
        _isLoading = false;
      });
      await showSpentToast(context, cost, isKorean);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showShopError(context, e, isKorean);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final t = ShopTokens.of(context);
    final cost = widget.service.heartCost;
    final result = _todayResult;

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
                              isKorean
                                  ? '사랑하기 $cost개로 오늘의 행복을 받아 보세요.'
                                  : "Get today's happiness for $cost Love.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: t.ink2),
                            ),
                          ],
                        ),
                      )
                    : _ResultCard(item: result, isKorean: isKorean),
              ),
              const SizedBox(height: 12),
              LoveButton(
                isLoading: _isLoading,
                onPressed: _draw,
                label: isKorean
                    ? '사랑하기 $cost개로 ${widget.ctaKo}'
                    : '${widget.ctaEn} for $cost Love',
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
