// lib/happiness_shop_2/categories/vitamin/widgets/vitamin_content_type_sheet.dart
import 'package:flutter/material.dart';
import '../models/vitamin_slot.dart';
import '../../../common/theme/shop_tokens.dart';

class VitaminContentTypeSheet extends StatelessWidget {
  final Function(VitaminSlotType) onTypeSelected;

  const VitaminContentTypeSheet({
    super.key,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isKorean = languageCode == 'ko';
    final t = ShopTokens.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 8 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ShopShape.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isKorean ? '콘텐츠 타입을 선택하세요' : 'Select Content Type',
            style: TextStyle(
              fontSize: 22,
              height: 30 / 22,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 20),
          _buildTypeOption(
            context,
            icon: Icons.image,
            title: isKorean ? '갤러리에서 사진 선택' : 'Photo from Gallery',
            subtitle:
                isKorean ? '나만의 소중한 사진을 저장하세요' : 'Save your precious photos',
            type: VitaminSlotType.photo,
          ),
          const SizedBox(height: 12),
          _buildTypeOption(
            context,
            icon: Icons.videocam,
            title: isKorean ? '갤러리에서 영상 선택' : 'Video from Gallery',
            subtitle: isKorean
                ? '나만의 소중한 영상을 저장하세요 (최대 5분)'
                : 'Save your precious videos (max 5 min)',
            type: VitaminSlotType.video,
          ),
          Divider(height: 32, color: t.line),
          _buildTypeOption(
            context,
            icon: Icons.music_note,
            title: isKorean ? '음악 링크' : 'Music Link',
            subtitle:
                isKorean ? 'YouTube, Spotify 등' : 'YouTube, Spotify, etc.',
            type: VitaminSlotType.music,
          ),
          const SizedBox(height: 12),
          _buildTypeOption(
            context,
            icon: Icons.play_circle,
            title: isKorean ? '영상 링크' : 'Video Link',
            subtitle: isKorean ? 'YouTube 등' : 'YouTube, etc.',
            type: VitaminSlotType.videoUrl,
          ),
          const SizedBox(height: 12),
          _buildTypeOption(
            context,
            icon: Icons.format_quote,
            title: isKorean ? '명언/메시지' : 'Quote/Message',
            subtitle: isKorean ? '나만의 메시지 작성' : 'Write your own message',
            type: VitaminSlotType.quote,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VitaminSlotType type,
  }) {
    final t = ShopTokens.of(context);
    final radius = BorderRadius.circular(ShopShape.card);

    return Material(
      color: t.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTypeSelected(type);
        },
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: ShopShape.minTouch),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.coralSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: t.coralDeep, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        color: t.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.ink2),
            ],
          ),
        ),
      ),
    );
  }
}
