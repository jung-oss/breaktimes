// lib/happiness_shop_2/categories/vitamin/screens/vitamin_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/vitamin_slot.dart';
import '../services/vitamin_service.dart';
import '../../../common/theme/shop_tokens.dart';
import '../../../common/widgets/shop_widgets.dart';
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
    final t = ShopTokens.of(context);

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text(
          slot.title.isEmpty ? (isKorean ? '슬롯' : 'Slot') : slot.title,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: isKorean ? '수정' : 'Edit',
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
            icon: const Icon(Icons.delete_outline),
            tooltip: isKorean ? '비우기' : 'Clear',
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
        final isKorean = Localizations.localeOf(context).languageCode == 'ko';
        return Center(
          child: Text(
            isKorean ? '빈 슬롯이에요' : 'Empty slot',
            style: TextStyle(fontSize: 16, color: ShopTokens.of(context).ink2),
          ),
        );
    }
  }

  bool get _hasMemo =>
      slot.content.text != null && slot.content.text!.isNotEmpty;

  /// 카드 모양: surface 바탕 + 1px 테두리 + 모서리 20
  BoxDecoration _cardDecoration(ShopTokens t, {Color? color}) {
    return BoxDecoration(
      color: color ?? t.surface,
      borderRadius: BorderRadius.circular(ShopShape.card),
      border: Border.all(color: t.line),
    );
  }

  /// 메모 카드
  Widget _buildMemoCard(BuildContext context, {EdgeInsets? margin}) {
    final t = ShopTokens.of(context);
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: margin,
      decoration: _cardDecoration(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 20, color: t.coralDeep),
              const SizedBox(width: 8),
              Text(
                isKorean ? '메모' : 'Memo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            slot.content.text!,
            style: TextStyle(fontSize: 16, color: t.ink, height: 1.6),
          ),
        ],
      ),
    );
  }

  /// 주 버튼(사랑하기를 쓰지 않음): coral 바탕 + onCoral 글자
  Widget _buildPrimaryButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final t = ShopTokens.of(context);
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: t.coral,
          foregroundColor: t.onCoral,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShopShape.button),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildPhotoView(BuildContext context) {
    final t = ShopTokens.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          // 이미지
          InteractiveViewer(
            child: Image.network(
              slot.content.imageUrl ?? '',
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: t.coral),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Padding(
                padding: const EdgeInsets.all(32),
                child:
                    Icon(Icons.broken_image_outlined, size: 48, color: t.ink2),
              ),
              fit: BoxFit.contain,
            ),
          ),
          // 메모 표시
          if (_hasMemo) ...[
            const SizedBox(height: 16),
            _buildMemoCard(context, margin: const EdgeInsets.all(16)),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoView(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final t = ShopTokens.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 영상 썸네일 또는 아이콘
          Container(
            width: double.infinity,
            height: 300,
            color: t.line,
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
                      return Icon(Icons.videocam, size: 64, color: t.ink2);
                    },
                  )
                else
                  Icon(Icons.videocam, size: 64, color: t.ink2),
                // 재생 아이콘(영상 위 표시라 어두운 막을 둡니다)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(153),
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
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 영상 재생 버튼
          if (slot.content.compressedUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPrimaryButton(
                context,
                icon: Icons.play_arrow,
                label: isKorean ? '영상 재생' : 'Play Video',
                onPressed: () {
                  // 비디오 재생 로직
                },
              ),
            ),
          // 메모 표시
          if (_hasMemo) ...[
            const SizedBox(height: 16),
            _buildMemoCard(context, margin: const EdgeInsets.all(16)),
          ],
        ],
      ),
    );
  }

  Widget _buildUrlView(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final t = ShopTokens.of(context);
    final url = slot.content.url ?? '';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: t.coralSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                slot.type == VitaminSlotType.music
                    ? Icons.music_note
                    : Icons.play_circle,
                size: 48,
                color: t.coralDeep,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              slot.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              url,
              style: TextStyle(fontSize: 14, color: t.ink2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildPrimaryButton(
              context,
              icon: Icons.open_in_new,
              label: isKorean ? '링크 열기' : 'Open Link',
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            // 메모 표시
            if (_hasMemo) ...[
              const SizedBox(height: 32),
              _buildMemoCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteView(BuildContext context) {
    final t = ShopTokens.of(context);
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final hasAiQuote =
        slot.content.aiQuote != null && slot.content.aiQuote!.isNotEmpty;
    final aiStatus = slot.content.aiQuoteStatus;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 원본 텍스트
          Container(
            padding: const EdgeInsets.all(32),
            decoration: _cardDecoration(t),
            child: Column(
              children: [
                Icon(Icons.format_quote, size: 48, color: t.coralDeep),
                const SizedBox(height: 24),
                Text(
                  slot.content.text ?? '',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    color: t.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (slot.content.author != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    '- ${slot.content.author}',
                    style: TextStyle(fontSize: 16, color: t.ink2),
                  ),
                ],
              ],
            ),
          ),
          // AI 명언 (있는 경우)
          if (hasAiQuote) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: _cardDecoration(t, color: t.coralSoft),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: t.coralDeep, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isKorean ? 'AI가 생성한 명언' : 'AI Generated Quote',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: t.coralDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    slot.content.aiQuote!,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                      color: t.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else if (aiStatus == 'pending' || aiStatus == 'failed') ...[
            // AI 명언 상태 표시(읽기만 합니다)
            const SizedBox(height: 24),
            _buildAiStatusCard(context, failed: aiStatus == 'failed'),
          ],
        ],
      ),
    );
  }

  Widget _buildAiStatusCard(BuildContext context, {required bool failed}) {
    final t = ShopTokens.of(context);
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(t),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: failed
                ? Icon(Icons.sync_problem, color: t.ink2, size: 30)
                : CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: t.coral,
                    backgroundColor: t.coralSoft,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              failed
                  ? (isKorean ? '잠시 문제가 생겼어요' : 'Something went wrong')
                  : (isKorean ? '마음을 담아 준비 중이에요' : 'Preparing with care'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final t = ShopTokens.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShopShape.card),
        ),
        title: Text(
          isKorean ? '콘텐츠 삭제' : 'Delete Content',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: t.ink,
          ),
        ),
        content: Text(
          isKorean
              ? '이 콘텐츠를 삭제할까요?\n슬롯은 비워지지만 그대로 남아요.'
              : 'Would you like to delete this content?\nThe slot will be emptied but kept.',
          style: TextStyle(fontSize: 16, height: 1.5, color: t.ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: t.ink2,
              minimumSize: const Size(64, ShopShape.minTouch),
            ),
            child: Text(
              isKorean ? '취소' : 'Cancel',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.coralDeep,
              side: BorderSide(color: t.coralDeep, width: 1.5),
              minimumSize: const Size(64, ShopShape.minTouch),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ShopShape.button),
              ),
            ),
            child: Text(
              isKorean ? '삭제' : 'Delete',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          showShopToast(
            context,
            isKorean ? '콘텐츠를 삭제했어요' : 'Content deleted',
          );
        }
      } catch (e) {
        if (context.mounted) {
          showShopToast(
            context,
            isKorean
                ? '잠시 문제가 생겼어요. 다시 시도해 주세요.'
                : 'Something went wrong. Please try again.',
          );
        }
      }
    }
  }
}
