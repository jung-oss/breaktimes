// lib/happiness_shop_2/categories/vitamin/widgets/vitamin_slot_grid.dart
import 'package:flutter/material.dart';
import '../models/vitamin_slot.dart';
import '../services/vitamin_service.dart';
import '../../../common/theme/shop_tokens.dart';
import '../../../common/widgets/pill_button.dart';
import 'vitamin_random_slot_widget.dart';

class VitaminSlotGrid extends StatelessWidget {
  final List<VitaminSlot> slots;
  final Function(VitaminSlot) onSlotTap;
  final VitaminService service;

  const VitaminSlotGrid({
    super.key,
    required this.slots,
    required this.onSlotTap,
    required this.service,
  });

  String _getPillImagePath(int index) {
    final pillIndex = index % 8;
    switch (pillIndex) {
      case 0:
        return 'assets/images/pill/1_red_pill.png';
      case 1:
        return 'assets/images/pill/2_orange_pill.png';
      case 2:
        return 'assets/images/pill/3_yellow_pill.png';
      case 3:
        return 'assets/images/pill/4_green_pill.png';
      case 4:
        return 'assets/images/pill/5_blue_pill.png';
      case 5:
        return 'assets/images/pill/6_navy_pill.png';
      case 6:
        return 'assets/images/pill/7_purple_pill.png';
      case 7:
        return 'assets/images/pill/8_colorfule_pill.png';
      default:
        return 'assets/images/pill/1_red_pill.png';
    }
  }

  Widget? _buildContentIcon(BuildContext context, VitaminSlot slot) {
    if (slot.isEmpty) return null;

    IconData iconData;
    switch (slot.type) {
      case VitaminSlotType.photo:
        iconData = Icons.image;
        break;
      case VitaminSlotType.video:
        iconData = Icons.videocam;
        break;
      case VitaminSlotType.music:
        iconData = Icons.music_note;
        break;
      case VitaminSlotType.videoUrl:
        iconData = Icons.play_circle;
        break;
      case VitaminSlotType.quote:
        iconData = Icons.format_quote;
        break;
      case VitaminSlotType.empty:
        return null;
    }

    final t = ShopTokens.of(context);
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: t.surface,
            shape: BoxShape.circle,
            border: Border.all(color: t.line),
          ),
          child: Icon(iconData, color: t.coralDeep, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 일반 슬롯 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              // 알약 이미지만 표시 (메모 표시 제거)
              return PillButton(
                imagePath: _getPillImagePath(slot.slotIndex),
                onTap: () => onSlotTap(slot),
                isEmpty: slot.isEmpty,
                overlay: _buildContentIcon(context, slot),
                showBadge: slot.content.aiQuote != null &&
                    slot.content.aiQuote!.isNotEmpty,
              );
            },
          ),
          const SizedBox(height: 24),
          // 랜덤 슬롯 섹션
          Center(
            child: Column(
              children: [
                Text(
                  isKorean ? '랜덤 슬롯' : 'Random Slot',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 16),
                VitaminRandomSlotWidget(
                  service: service,
                  onTap: () {
                    // 랜덤 슬롯 탭 시 상세 화면으로 이동
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
