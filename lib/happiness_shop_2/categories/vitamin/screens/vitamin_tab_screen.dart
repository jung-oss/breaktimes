// lib/happiness_shop_2/categories/vitamin/screens/vitamin_tab_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vitamin_slot.dart';
import '../services/vitamin_service.dart';
import '../widgets/vitamin_slot_grid.dart';
import '../widgets/vitamin_content_type_sheet.dart';
import 'vitamin_detail_screen.dart';
import 'vitamin_add_screen.dart';
import '../../../../providers/locale_provider.dart';
import '../../../common/widgets/shop_widgets.dart';
import '../../../common/theme/shop_tokens.dart';

class VitaminTabScreen extends StatefulWidget {
  final VitaminService service;

  const VitaminTabScreen({
    super.key,
    required this.service,
  });

  @override
  State<VitaminTabScreen> createState() => _VitaminTabScreenState();
}

class _VitaminTabScreenState extends State<VitaminTabScreen> {
  int _slotCount = 0;
  int _maxSlots = 7;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final slotInfo = await widget.service.getUserSlotInfo();
      if (mounted) {
        setState(() {
          _slotCount = slotInfo['slotCount'] ?? 0;
          _maxSlots = slotInfo['maxSlots'] ?? 20;
          _isLoading = false;
        });
      }
      await widget.service.ensureSlotsInitialized();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchaseSlot() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';

    if (_slotCount >= _maxSlots) {
      showShopToast(
        context,
        isKorean
            ? '슬롯은 최대 $_maxSlots개까지 늘릴 수 있어요.'
            : 'You can have up to $_maxSlots slots.',
      );
      return;
    }

    final bool confirmed;
    try {
      confirmed = await confirmLoveSpend(
        context,
        isKorean: isKorean,
        categoryId: 'vitamin',
        title: isKorean ? '슬롯을 1개 늘릴까요?' : 'Add one slot?',
        subtitle: isKorean
            ? '$_slotCount개 → ${_slotCount + 1}개 · 최대 $_maxSlots개'
            : '$_slotCount → ${_slotCount + 1} · up to $_maxSlots',
        cost: VitaminService.SLOT_PRICE,
        actionLabel: isKorean
            ? '사랑하기 ${VitaminService.SLOT_PRICE}개로 늘리기'
            : 'Add for ${VitaminService.SLOT_PRICE} Love',
        note: isKorean
            ? '늘린 슬롯은 계속 내 것이에요. 슬롯을 비우거나 다시 채우는 건 무료예요.'
            : 'Added slots are yours to keep. Filling or clearing slots is free.',
      );
    } catch (e) {
      if (mounted) showShopError(context, e, isKorean);
      return;
    }
    if (!confirmed || !mounted) return;

    final success = await widget.service.purchaseSlot();
    if (!mounted) return;
    if (success) {
      await _loadInitialData();
      if (mounted) {
        await showSpentToast(context, VitaminService.SLOT_PRICE, isKorean);
      }
    } else {
      showShopToast(
        context,
        isKorean
            ? '슬롯을 늘리지 못했어요. 사랑하기는 그대로예요.'
            : 'Could not add a slot. Your Love was not used.',
      );
    }
  }

  void _handleSlotTap(VitaminSlot slot) {
    if (slot.isEmpty) {
      _showContentTypeBottomSheet(slot);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VitaminDetailScreen(
            slot: slot,
            service: widget.service,
          ),
        ),
      ).then((_) => _loadInitialData());
    }
  }

  void _showContentTypeBottomSheet(VitaminSlot slot) {
    showModalBottomSheet(
      context: context,
      builder: (context) => VitaminContentTypeSheet(
        onTypeSelected: (type) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VitaminAddScreen(
                slot: slot,
                type: type,
                service: widget.service,
              ),
            ),
          ).then((_) => _loadInitialData());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    final isKorean = languageCode == 'ko';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 디자인 시스템: 가게 바탕은 크림색(어두운 화면은 따뜻한 갈색)
    return Container(
      color: ShopTokens.of(context).ground,
      child: Column(
        children: [
          // 서브 헤더
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  isKorean ? '✨ 오늘의 작은 반짝임' : '✨ Today\'s Little Sparkle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<VitaminSlot>>(
                  stream: widget.service.getUserSlotsStream(),
                  builder: (context, snapshot) {
                    final slots = snapshot.data ?? [];
                    return Text(
                      isKorean
                          ? '사용 중: ${slots.where((s) => !s.isEmpty).length} / $_slotCount 슬롯'
                          : 'Used: ${slots.where((s) => !s.isEmpty).length} / $_slotCount slots',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // 슬롯 추가 버튼
          if (_slotCount < _maxSlots)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LoveButton(
                onPressed: _purchaseSlot,
                label: isKorean
                    ? '사랑하기 ${VitaminService.SLOT_PRICE}개로 슬롯 늘리기'
                    : 'Add a slot for ${VitaminService.SLOT_PRICE} Love',
              ),
            ),
          const SizedBox(height: 16),
          // 알약 그리드 레이아웃
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<VitaminSlot>>(
                    stream: widget.service.getUserSlotsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            isKorean ? '오류가 발생했습니다' : 'An error occurred',
                          ),
                        );
                      }

                      final slots = snapshot.data ?? [];

                      if (slots.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isKorean ? '슬롯이 없습니다' : 'No slots available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return VitaminSlotGrid(
                        slots: slots,
                        onSlotTap: _handleSlotTap,
                        service: widget.service,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
