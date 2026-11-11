import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/locale_provider.dart';
import '../models/shop_catalog_item.dart';
import '../services/catalog_shop_service.dart';
import '../services/heart_cost_service.dart';

/// 카탈로그형 행복상점 탭 (음악·꽃말·레시피·여행)
class CatalogTabScreen extends StatefulWidget {
  final CatalogShopService service;
  final String iconEmoji;
  final String titleKo;
  final String titleEn;
  final String ctaKo;
  final String ctaEn;
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
  bool _hasEnoughHearts = true;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _checkHearts();
  }

  Future<void> _checkHearts() async {
    final canAfford =
        await HeartCostService().canAfford(widget.service.heartCost);
    if (mounted) setState(() => _hasEnoughHearts = canAfford);
  }

  Future<void> _draw() async {
    final locale =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    final isKorean = locale == 'ko';
    setState(() => _isLoading = true);
    try {
      final item = await widget.service.drawWithHearts(
        tagFilter: _selectedTag,
      );
      if (mounted) {
        setState(() {
          _todayResult = item;
          _isLoading = false;
        });
        _checkHearts();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString();
      String text;
      if (msg.contains('INSUFFICIENT_HEARTS')) {
        text = isKorean ? '하트가 부족해요.' : 'Insufficient hearts.';
      } else if (msg.contains('NOT_LOGGED_IN')) {
        text = isKorean ? '로그인이 필요합니다.' : 'Please sign in first.';
      } else {
        text = isKorean
            ? '잠시 문제가 생겼어요. 다시 시도해 주세요.'
            : 'Something went wrong. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.grey[900]!, Colors.grey[850]!],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.lightGradient,
              ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.iconEmoji} ${isKorean ? widget.titleKo : widget.titleEn}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (widget.filterTags != null) ...[
                Wrap(
                  spacing: 8,
                  children: List.generate(widget.filterTags!.length, (i) {
                    final tag = widget.filterTags![i];
                    final label = isKorean
                        ? widget.filterLabelsKo![i]
                        : widget.filterLabelsEn![i];
                    final selected = _selectedTag == tag;
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedTag = selected ? null : tag;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _todayResult == null
                    ? Center(
                        child: Text(
                          isKorean
                              ? '하트 1개로 오늘의 행복을 받아보세요.'
                              : 'Get today\'s happiness with 1 heart.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      )
                    : _ResultCard(item: _todayResult!, isKorean: isKorean),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                ),
              ElevatedButton(
                onPressed: _isLoading || !_hasEnoughHearts ? null : _draw,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isKorean
                      ? '${widget.ctaKo} (하트 ${widget.service.heartCost}개)'
                      : '${widget.ctaEn} (${widget.service.heartCost} Hearts)',
                ),
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title(isKorean),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (item.subtitle(isKorean) != null) ...[
              const SizedBox(height: 8),
              Text(
                item.subtitle(isKorean)!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              item.body(isKorean),
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
