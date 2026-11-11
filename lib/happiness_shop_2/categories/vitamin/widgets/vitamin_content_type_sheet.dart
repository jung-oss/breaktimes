// lib/happiness_shop_2/categories/vitamin/widgets/vitamin_content_type_sheet.dart
import 'package:flutter/material.dart';
import '../models/vitamin_slot.dart';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isKorean ? '콘텐츠 타입을 선택하세요' : 'Select Content Type',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          _buildTypeOption(
            context,
            icon: Icons.image,
            title: isKorean ? '갤러리에서 사진 선택' : 'Photo from Gallery',
            subtitle: isKorean
                ? '나만의 소중한 사진을 저장하세요'
                : 'Save your precious photos',
            type: VitaminSlotType.photo,
            color: Colors.blue,
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
            color: Colors.purple,
          ),
          const Divider(height: 32),
          _buildTypeOption(
            context,
            icon: Icons.music_note,
            title: isKorean ? '음악 링크' : 'Music Link',
            subtitle: isKorean ? 'YouTube, Spotify 등' : 'YouTube, Spotify, etc.',
            type: VitaminSlotType.music,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildTypeOption(
            context,
            icon: Icons.play_circle,
            title: isKorean ? '영상 링크' : 'Video Link',
            subtitle: isKorean ? 'YouTube 등' : 'YouTube, etc.',
            type: VitaminSlotType.videoUrl,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildTypeOption(
            context,
            icon: Icons.format_quote,
            title: isKorean ? '명언/메시지' : 'Quote/Message',
            subtitle: isKorean ? '나만의 메시지 작성' : 'Write your own message',
            type: VitaminSlotType.quote,
            color: Colors.green,
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
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTypeSelected(type);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.grey[800]
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode
                ? Colors.grey[700]!
                : color.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

