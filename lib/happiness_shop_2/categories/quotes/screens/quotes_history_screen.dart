// lib/happiness_shop_2/categories/quotes/screens/quotes_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../providers/locale_provider.dart';
import '../services/quotes_service.dart';
import '../models/quote_item.dart';
import '../../../common/theme/shop_tokens.dart';
import '../../../common/widgets/shop_widgets.dart';

class QuotesHistoryScreen extends StatefulWidget {
  const QuotesHistoryScreen({super.key});

  @override
  State<QuotesHistoryScreen> createState() => _QuotesHistoryScreenState();
}

class _QuotesHistoryScreenState extends State<QuotesHistoryScreen> {
  final QuotesService _service = QuotesService();

  @override
  Widget build(BuildContext context) {
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    final isKorean = languageCode == 'ko';
    final t = ShopTokens.of(context);

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text(isKorean ? '글귀 기록' : 'Quote History'),
      ),
      body: StreamBuilder<List<QuoteItem>>(
        stream: _service.getUserQuotesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: t.coral));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isKorean
                      ? '기록을 불러오지 못했어요. 잠시 후 다시 열어 주세요.'
                      : 'Could not load your history. Please try again shortly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: t.ink2),
                ),
              ),
            );
          }

          final quotes = snapshot.data ?? [];

          if (quotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShopArt.pill('quotes', size: 72, radius: 20),
                  const SizedBox(height: 16),
                  Text(
                    isKorean ? '아직 기록이 없습니다.' : 'No quotes yet.',
                    style: TextStyle(fontSize: 17, color: t.ink2),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quotes.length,
            itemBuilder: (context, index) {
              final quote = quotes[index];
              return _buildQuoteCard(quote, isKorean, t);
            },
          );
        },
      ),
    );
  }

  /// 목록 안 준비 중·문제 표시입니다(카드 안에 들어가므로 작게 둡니다).
  Widget _buildInlineStatus(QuoteItem quote, bool isKorean, ShopTokens t) {
    final failed = quote.status == 'failed';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.ground,
        borderRadius: BorderRadius.circular(ShopShape.button),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: failed
                ? Icon(Icons.sync_problem, size: 20, color: t.ink2)
                : CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: t.coral,
                    backgroundColor: t.coralSoft,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failed
                      ? (isKorean ? '잠시 문제가 생겼어요' : 'Something went wrong')
                      : (isKorean ? '마음을 담아 준비 중이에요' : 'Preparing with care'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  failed
                      ? (isKorean ? '사랑하기는 그대로예요.' : 'Your Love was not used.')
                      : (isKorean
                          ? '아직 사랑하기는 빠지지 않았어요.'
                          : 'No Love used yet.'),
                  style: TextStyle(fontSize: 13, color: t.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(QuoteItem quote, bool isKorean, ShopTokens t) {
    final dateFormat = DateFormat(
      isKorean ? 'yyyy년 MM월 dd일' : 'MMMM dd, yyyy',
      isKorean ? 'ko' : 'en',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShopShape.card),
          side: BorderSide(color: t.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showQuoteDetail(quote, isKorean),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateFormat.format(quote.date),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: t.coralDeep,
                      ),
                    ),
                    // 삭제 버튼
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _showDeleteDialog(quote, isKorean),
                      color: t.ink2,
                      tooltip: isKorean ? '삭제' : 'Delete',
                      constraints: const BoxConstraints(
                        minWidth: ShopShape.minTouch,
                        minHeight: ShopShape.minTouch,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 사용자의 생각
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: t.ground,
                          borderRadius:
                              BorderRadius.circular(ShopShape.button),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: t.coralSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.psychology,
                                    size: 16,
                                    color: t.coralDeep,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isKorean ? '오늘의 생각' : 'Today\'s Thought',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: t.ink2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              quote.userThought,
                              style: TextStyle(
                                fontSize: 15,
                                color: t.ink,
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 명언과 위로 글
                      if (quote.status == 'generated' &&
                          quote.comfortMessage != null &&
                          quote.comfortMessage!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius:
                                BorderRadius.circular(ShopShape.button),
                            border: Border.all(color: t.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // AI 아이콘과 작가 이름 표시
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: t.successSoft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      color: t.onSuccessSoft,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (quote.authorName != null)
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: t.coralSoft,
                                            borderRadius: BorderRadius.circular(
                                                ShopShape.chip),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person,
                                                color: t.coralDeep,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '${quote.authorName} 작가 스타일',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: t.coralDeep,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (quote.authorName != null)
                                const SizedBox(height: 16),
                              ...quote.comfortMessage!
                                  .split('\n')
                                  .where((line) => line.trim().isNotEmpty)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final line = entry.value.trim();
                                final isFirstLine = index == 0;
                                final lines = quote.comfortMessage!
                                    .split('\n')
                                    .where((l) => l.trim().isNotEmpty)
                                    .length;

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index < lines - 1
                                        ? (isFirstLine ? 14 : 10)
                                        : 0,
                                  ),
                                  child: Container(
                                    width:
                                        isFirstLine ? double.infinity : null,
                                    padding: isFirstLine
                                        ? const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10)
                                        : EdgeInsets.zero,
                                    decoration: isFirstLine
                                        ? BoxDecoration(
                                            color: t.ground,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          )
                                        : null,
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: isFirstLine ? 20 : 15,
                                        fontWeight: isFirstLine
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontStyle: isFirstLine
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        color: t.ink,
                                        height: isFirstLine ? 1.5 : 1.6,
                                        letterSpacing:
                                            isFirstLine ? 0.2 : 0.05,
                                      ),
                                      textAlign: isFirstLine
                                          ? TextAlign.center
                                          : TextAlign.left,
                                      maxLines: isFirstLine ? 2 : 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        )
                      else if (quote.status == 'pending' ||
                          quote.status == 'failed')
                        _buildInlineStatus(quote, isKorean, t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuoteDetail(QuoteItem quote, bool isKorean) {
    final t = ShopTokens.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        surfaceTintColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShopShape.card),
        ),
        title: Text(
          isKorean ? '글귀 상세' : 'Quote Detail',
          style: TextStyle(color: t.ink, fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 사용자의 생각
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.ground,
                  borderRadius: BorderRadius.circular(ShopShape.button),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKorean ? '오늘의 생각' : 'Today\'s Thought',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: t.ink2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quote.userThought,
                      style: TextStyle(
                        fontSize: 16,
                        color: t.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 명언과 위로 글
              if (quote.status == 'generated' &&
                  quote.comfortMessage != null &&
                  quote.comfortMessage!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(ShopShape.card),
                    border: Border.all(color: t.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작가 이름 표시
                      if (quote.authorName != null)
                        Row(
                          children: [
                            Icon(Icons.person, color: t.coralDeep, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${quote.authorName} 작가 스타일',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: t.coralDeep,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (quote.authorName != null) const SizedBox(height: 12),
                      // 명언과 위로 글 (첫 줄은 큰 글자로, 나머지는 일반 크기)
                      ...quote.comfortMessage!
                          .split('\n')
                          .where((line) => line.trim().isNotEmpty)
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final line = entry.value.trim();
                        final isFirstLine = index == 0;
                        final lines = quote.comfortMessage!
                            .split('\n')
                            .where((l) => l.trim().isNotEmpty)
                            .length;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index < lines - 1 ? (isFirstLine ? 16 : 12) : 0,
                          ),
                          child: SizedBox(
                            width: isFirstLine ? double.infinity : null,
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: isFirstLine ? 22 : 16,
                                fontWeight: isFirstLine
                                    ? FontWeight.bold
                                    : FontWeight.w400,
                                fontStyle: isFirstLine
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: t.ink,
                                height: isFirstLine ? 1.4 : 1.6,
                              ),
                              textAlign: isFirstLine
                                  ? TextAlign.center
                                  : TextAlign.left,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                )
              else if (quote.status == 'pending')
                ShopStatusView.pending(isKorean: isKorean)
              else if (quote.status == 'failed')
                ShopStatusView.failed(isKorean: isKorean),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: t.coralDeep,
              minimumSize:
                  const Size(ShopShape.minTouch, ShopShape.minTouch),
            ),
            child: Text(isKorean ? '닫기' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(QuoteItem quote, bool isKorean) {
    final t = ShopTokens.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.surface,
        surfaceTintColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShopShape.card),
        ),
        title: Text(
          isKorean ? '삭제 확인' : 'Delete Confirmation',
          style: TextStyle(color: t.ink, fontWeight: FontWeight.w800),
        ),
        content: Text(
          isKorean
              ? '이 글귀를 삭제하시겠습니까?'
              : 'Are you sure you want to delete this quote?',
          style: TextStyle(color: t.ink2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: t.ink2,
              minimumSize:
                  const Size(ShopShape.minTouch, ShopShape.minTouch),
            ),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _service.deleteQuote(quote.id);
                if (mounted) {
                  showShopToast(
                    this.context,
                    isKorean ? '삭제되었습니다' : 'Deleted',
                  );
                }
              } catch (e) {
                if (mounted) {
                  showShopToast(
                    this.context,
                    isKorean
                        ? '삭제하지 못했어요. 잠시 후 다시 시도해 주세요.'
                        : 'Could not delete. Please try again shortly.',
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: t.coralDeep,
              minimumSize:
                  const Size(ShopShape.minTouch, ShopShape.minTouch),
            ),
            child: Text(
              isKorean ? '삭제' : 'Delete',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
