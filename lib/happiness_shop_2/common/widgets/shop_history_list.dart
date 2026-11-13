// lib/happiness_shop_2/common/widgets/shop_history_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/shop_tokens.dart';
import 'shop_widgets.dart';

/// 받은 기록 한 줄
class ShopHistoryEntry {
  const ShopHistoryEntry({
    required this.id,
    required this.date,
    required this.status,
    required this.content,
    this.caption,
  });

  final String id;
  final DateTime date;

  /// 'pending' | 'generated' | 'failed'
  final String status;
  final String content;

  /// 날짜 옆 보조 글(예: 기분, 내가 적은 말)
  final String? caption;
}

/// 운세·위로 등 "받은 기록" 공통 화면 (보기는 무료, 지우기는 확인 후)
class ShopHistoryScreen extends StatelessWidget {
  const ShopHistoryScreen({
    super.key,
    required this.isKorean,
    required this.title,
    required this.categoryId,
    required this.emptyText,
    required this.stream,
    required this.onDelete,
  });

  final bool isKorean;
  final String title;
  final String categoryId;
  final String emptyText;
  final Stream<List<ShopHistoryEntry>> stream;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final dateFormat = DateFormat(
      isKorean ? 'yyyy년 M월 d일' : 'MMMM d, yyyy',
      isKorean ? 'ko' : 'en',
    );

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<List<ShopHistoryEntry>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Centered(
              isKorean
                  ? '기록을 불러오지 못했어요. 잠시 후 다시 열어 주세요.'
                  : 'Could not load your history. Please try again shortly.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) return _Centered(emptyText);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _HistoryCard(
                item: item,
                dateText: dateFormat.format(item.date),
                isKorean: isKorean,
                categoryId: categoryId,
                onDelete: () => _confirmDelete(context, item),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ShopHistoryEntry item) async {
    final t = ShopTokens.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: Text(
          isKorean ? '이 기록을 지울까요?' : 'Delete this entry?',
          style: TextStyle(color: t.ink, fontWeight: FontWeight.w800),
        ),
        content: Text(
          isKorean
              ? '지운 기록은 되돌릴 수 없어요. 쓴 사랑하기는 돌아오지 않아요.'
              : 'This cannot be undone. Used Love is not returned.',
          style: TextStyle(color: t.ink2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: t.ink2),
            child: Text(isKorean ? '그대로 두기' : 'Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: t.coralDeep),
            child: Text(isKorean ? '지우기' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await onDelete(item.id);
      if (context.mounted) {
        showShopToast(context, isKorean ? '기록을 지웠어요.' : 'Deleted.');
      }
    } catch (e) {
      if (context.mounted) showShopError(context, e, isKorean);
    }
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.dateText,
    required this.isKorean,
    required this.categoryId,
    required this.onDelete,
  });

  final ShopHistoryEntry item;
  final String dateText;
  final bool isKorean;
  final String categoryId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final String preview;
    switch (item.status) {
      case 'generated':
        preview = item.content;
        break;
      case 'failed':
        preview = isKorean
            ? '잠시 문제가 생겼어요. 사랑하기는 그대로예요.'
            : 'Something went wrong. Your Love was not used.';
        break;
      default:
        preview = isKorean ? '마음을 담아 준비 중이에요' : 'Preparing with care';
    }
    final canOpen = item.status == 'generated';

    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShopShape.card),
        side: BorderSide(color: t.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(ShopShape.card),
        onTap: canOpen ? () => _openFull(context) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ShopArt.pill(categoryId, size: 40, radius: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [dateText, if (item.caption != null) item.caption!]
                          .join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.ink2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: canOpen ? t.ink : t.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: t.ink2),
                tooltip: isKorean ? '기록 지우기' : 'Delete entry',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFull(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final t = ShopTokens.of(sheetContext);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
          ),
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
                [dateText, if (item.caption != null) item.caption!].join(' · '),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.ink2,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.75,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: ShopShape.minTouch,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: TextButton.styleFrom(foregroundColor: t.ink2),
                  child: Text(
                    isKorean ? '닫기' : 'Close',
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
}

class _Centered extends StatelessWidget {
  const _Centered(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: TextStyle(fontSize: 15, color: t.ink2),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
