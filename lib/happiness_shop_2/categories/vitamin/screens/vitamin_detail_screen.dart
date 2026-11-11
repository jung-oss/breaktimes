// lib/happiness_shop_2/categories/vitamin/screens/vitamin_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/vitamin_slot.dart';
import '../services/vitamin_service.dart';
import 'vitamin_add_screen.dart';

class VitaminDetailScreen extends StatelessWidget {
  final VitaminSlot slot;
  final VitaminService service;

  const VitaminDetailScreen({
    super.key,
    required this.slot,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          slot.title.isEmpty ? (isKorean ? '슬롯' : 'Slot') : slot.title,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VitaminAddScreen(
                    slot: slot,
                    type: slot.type,
                    service: service,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (slot.type) {
      case VitaminSlotType.photo:
        return _buildPhotoView(context);
      case VitaminSlotType.video:
        return _buildVideoView(context);
      case VitaminSlotType.music:
      case VitaminSlotType.videoUrl:
        return _buildUrlView(context);
      case VitaminSlotType.quote:
        return _buildQuoteView(context);
      case VitaminSlotType.empty:
        return const Center(child: Text('Empty slot'));
    }
  }

  Widget _buildPhotoView(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final hasMemo = slot.content.text != null && slot.content.text!.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 이미지
          InteractiveViewer(
            child: Image.network(
              slot.content.imageUrl ?? '',
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error),
              fit: BoxFit.contain,
            ),
          ),
          // 메모 표시
          if (hasMemo) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 20,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isKorean ? '메모' : 'Memo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    slot.content.text!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoView(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasMemo = slot.content.text != null && slot.content.text!.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 영상 썸네일 또는 아이콘
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 썸네일이 있으면 표시
                if (slot.content.thumbnailUrl != null)
                  Image.network(
                    slot.content.thumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.videocam, size: 64);
                    },
                  )
                else
                  const Icon(Icons.videocam, size: 64),
                // 재생 아이콘
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 제목
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              slot.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 영상 재생 버튼
          if (slot.content.compressedUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  // 비디오 재생 로직
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(isKorean ? '영상 재생' : 'Play Video'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          // 메모 표시
          if (hasMemo) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 20,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isKorean ? '메모' : 'Memo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    slot.content.text!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrlView(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final url = slot.content.url ?? '';
    final hasMemo = slot.content.text != null && slot.content.text!.isNotEmpty;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              slot.type == VitaminSlotType.music
                  ? Icons.music_note
                  : Icons.play_circle,
              size: 64,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 24),
            Text(
              slot.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              url,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(isKorean ? '링크 열기' : 'Open Link'),
            ),
            // 메모 표시
            if (hasMemo) ...[
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.note,
                          size: 20,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isKorean ? '메모' : 'Memo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slot.content.text!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteView(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 원본 텍스트
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(
                    Icons.format_quote,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    slot.content.text ?? '',
                    style: TextStyle(
                      fontSize: 20,
                      fontStyle: FontStyle.italic,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (slot.content.author != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      '- ${slot.content.author}',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // AI 명언 (있는 경우)
          if (slot.content.aiQuote != null &&
              slot.content.aiQuote!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              color: Colors.purple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.purple,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isKorean ? 'AI가 생성한 명언' : 'AI Generated Quote',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      slot.content.aiQuote!,
                      style: TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isKorean ? '콘텐츠 삭제' : 'Delete Content'),
        content: Text(
          isKorean
              ? '이 콘텐츠를 삭제하시겠습니까?\n슬롯은 비워지지만 유지됩니다.'
              : 'Would you like to delete this content?\nThe slot will be emptied but kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isKorean ? '삭제' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await service.clearSlotContent(slot.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isKorean ? '콘텐츠가 삭제되었습니다' : 'Content deleted',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isKorean ? '삭제에 실패했습니다' : 'Failed to delete',
              ),
            ),
          );
        }
      }
    }
  }
}
