// lib/happiness_shop_2/categories/quotes/screens/quotes_tab_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../services/quotes_service.dart';
import '../models/quote_item.dart';
import 'quotes_write_modal.dart';
import 'quotes_history_screen.dart';
import '../../../common/services/heart_cost_service.dart';
import '../services/firebase_daily_quotes_service.dart';
import '../models/daily_quote.dart';
import '../../../common/widgets/shop_widgets.dart';
import '../../../common/theme/shop_tokens.dart';

class QuotesTabScreen extends StatefulWidget {
  const QuotesTabScreen({super.key});

  @override
  State<QuotesTabScreen> createState() => _QuotesTabScreenState();
}

class _QuotesTabScreenState extends State<QuotesTabScreen> {
  final QuotesService _service = QuotesService();
  final FirebaseDailyQuotesService _firebaseDailyQuotesService =
      FirebaseDailyQuotesService();
  QuoteItem? _todayQuote;
  bool _hasWrittenToday = false;
  DailyQuote? _dailyQuote;

  @override
  void initState() {
    super.initState();
    _loadTodayQuote();
    // 앱이 꺼져 'pending'에 멈춘 글귀를 이어서 만듭니다
    _service.resumePending();
    _loadDailyQuote();
  }

  Future<void> _loadDailyQuote() async {
    try {
      final quote = await _firebaseDailyQuotesService.getTodayQuote();
      if (mounted) {
        setState(() {
          _dailyQuote = quote;
        });
      }
    } catch (e) {
      print('오늘의 명언 로드 실패: $e');
      if (mounted) {
        setState(() {
          _dailyQuote = null;
        });
      }
    }
  }

  Future<void> _loadTodayQuote() async {
    try {
      final quote = await _service.getTodayQuote();
      if (mounted) {
        setState(() {
          _todayQuote = quote;
          _hasWrittenToday = quote != null;
        });
      }
    } catch (e) {
      // 오류 처리
    }
  }

  void _showWriteQuoteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      useSafeArea: true,
      builder: (context) => QuotesWriteModal(
        service: _service,
        existingQuote: _todayQuote,
      ),
    ).then((result) {
      if (result == true) {
        _loadTodayQuote(); // 사랑하기 상태를 다시 확인합니다
      }
    });
  }

  Widget _buildQuoteCard(QuoteItem quote, bool isKorean) {
    final t = ShopTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사용자의 생각
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.coralSoft,
                      borderRadius: BorderRadius.circular(ShopShape.button),
                    ),
                    child: Icon(
                      Icons.psychology,
                      size: 20,
                      color: t.coralDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isKorean ? '오늘의 생각' : 'Today\'s Thought',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                quote.userThought,
                style: TextStyle(
                  fontSize: 17,
                  color: t.ink,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // 명언과 위로 글
        if (quote.status == 'generated' &&
            quote.comfortMessage != null &&
            quote.comfortMessage!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(ShopShape.card),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI 아이콘과 작가 이름 표시
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.successSoft,
                        borderRadius: BorderRadius.circular(ShopShape.button),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: t.onSuccessSoft,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (quote.authorName != null)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: t.coralSoft,
                              borderRadius:
                                  BorderRadius.circular(ShopShape.chip),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person,
                                  color: t.coralDeep,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${quote.authorName} 작가 스타일',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: t.coralDeep,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (quote.authorName != null) const SizedBox(height: 20),
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
                      bottom: index < lines - 1 ? (isFirstLine ? 20 : 14) : 0,
                    ),
                    child: Container(
                      width: isFirstLine ? double.infinity : null,
                      padding: isFirstLine
                          ? const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12)
                          : EdgeInsets.zero,
                      decoration: isFirstLine
                          ? BoxDecoration(
                              color: t.ground,
                              borderRadius:
                                  BorderRadius.circular(ShopShape.button),
                            )
                          : null,
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: isFirstLine ? 24 : 17,
                          fontWeight:
                              isFirstLine ? FontWeight.bold : FontWeight.w500,
                          fontStyle:
                              isFirstLine ? FontStyle.italic : FontStyle.normal,
                          color: t.ink,
                          height: isFirstLine ? 1.5 : 1.7,
                          letterSpacing: isFirstLine ? 0.3 : 0.1,
                        ),
                        textAlign:
                            isFirstLine ? TextAlign.center : TextAlign.left,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    final isKorean = languageCode == 'ko';
    final t = ShopTokens.of(context);

    // 디자인 시스템: 가게 바탕은 크림색(어두운 화면은 따뜻한 갈색)
    return Container(
      color: t.ground,
      child: Column(
        children: [
          // 상단 오늘의 명언/글귀 카드 (프레임 배경 적용)
          if (_dailyQuote != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              clipBehavior: Clip.antiAlias,
              constraints: const BoxConstraints(
                minHeight: 200,
              ),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(ShopShape.card),
                border: Border.all(color: t.line),
                image: const DecorationImage(
                  image: AssetImage('assets/images/decorative_box.png'),
                  fit: BoxFit.fill,
                  alignment: Alignment.center,
                  opacity: 0.15, // 투명도 15%
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isKorean ? '오늘의 명언' : 'Today\'s Quote',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: Text(
                      _dailyQuote!.quote,
                      style: TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: t.ink,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '- ${_dailyQuote!.author}',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: t.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 행복 글쓰기 카드 (항상 표시, 기록 보기 버튼 포함)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(ShopShape.card),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isKorean ? '행복 글쓰기' : 'Happiness Quote Writing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: t.ink,
                        ),
                      ),
                    ),
                    // 기록 보기 버튼 (항상 표시)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QuotesHistoryScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: t.coralDeep,
                        minimumSize: const Size(
                            ShopShape.minTouch, ShopShape.minTouch),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ShopShape.button),
                        ),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: Text(
                        isKorean ? '기록 보기' : 'History',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                // 작성 버튼 (글 작성 전에만 표시)
                if (!_hasWrittenToday) ...[
                  const SizedBox(height: 12),
                  LoveButton(
                    onPressed: _showWriteQuoteModal,
                    label: isKorean
                        ? '생각 적고 글귀 받기 · 사랑하기 ${HeartCost.QUOTE}개'
                        : 'Write and get a quote · ${HeartCost.QUOTE} Love',
                  ),
                ],
              ],
            ),
          ),
          // 오늘 글귀가 있으면 표시
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (_hasWrittenToday && _todayQuote != null)
                    _buildQuoteCard(_todayQuote!, isKorean)
                  else if (!_hasWrittenToday)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(ShopShape.card),
                            child: Image.asset(
                              'assets/images/store/quotes_logo.png',
                              width: 300,
                              height: 300,
                              errorBuilder: (context, error, stackTrace) {
                                return ShopArt.pill('quotes',
                                    size: 96, radius: 24);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isKorean
                                ? '오늘의 생각을 기록하면\nAI가 따뜻한 글귀를 만들어드려요.'
                                : 'Record your thoughts today\nand AI will create a warm quote for you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: t.ink2),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
