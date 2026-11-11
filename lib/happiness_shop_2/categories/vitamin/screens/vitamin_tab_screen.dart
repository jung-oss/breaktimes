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
import '../../../common/services/heart_service.dart';

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
  final HeartService _heartService = HeartService();
  int _heartCount = 0;
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
      final heartInfo = await _heartService.getHeartInfo();
      if (mounted) {
        setState(() {
          _heartCount = heartInfo.heartCount;
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

    if (_heartCount < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean ? '하트가 부족합니다' : 'Not enough hearts'),
        ),
      );
      return;
    }

    if (_slotCount >= _maxSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKorean ? '최대 슬롯에 도달했습니다' : 'Maximum slots reached',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isKorean ? '슬롯 추가' : 'Add Slot'),
        content: Text(
          isKorean
              ? '슬롯을 추가하시겠습니까?\n하트 5개 사용'
              : 'Would you like to add a slot?\n5 hearts will be used',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isKorean ? '구매' : 'Purchase'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.service.purchaseSlot();
      if (success) {
        await _loadInitialData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isKorean ? '슬롯이 추가되었습니다! 🎉' : 'Slot added! 🎉',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isKorean ? '슬롯 추가에 실패했습니다' : 'Failed to add slot',
              ),
            ),
          );
        }
      }
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

    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[900]!,
                  Colors.grey[850]!,
                ],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.orange.shade50,
                  Colors.white,
                ],
              ),
      ),
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
              child: ElevatedButton.icon(
                onPressed: _purchaseSlot,
                icon: const Icon(Icons.add),
                label: Text(
                  isKorean ? '슬롯 추가하기 (하트 5개)' : 'Add Slot (5 Hearts)',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
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
