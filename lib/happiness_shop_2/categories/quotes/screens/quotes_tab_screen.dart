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

class QuotesTabScreen extends StatefulWidget {
  const QuotesTabScreen({super.key});

  @override
  State<QuotesTabScreen> createState() => _QuotesTabScreenState();
}

class _QuotesTabScreenState extends State<QuotesTabScreen> {
  final QuotesService _service = QuotesService();
  final HeartCostService _heartCostService = HeartCostService();
  final FirebaseDailyQuotesService _firebaseDailyQuotesService =
      FirebaseDailyQuotesService();
  QuoteItem? _todayQuote;
  bool _hasWrittenToday = false;
  bool _hasEnoughHearts = true;
  DailyQuote? _dailyQuote;

  @override
  void initState() {
    super.initState();
    _loadTodayQuote();
    _checkHeartAvailability();
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

  Future<void> _checkHeartAvailability() async {
    final canAfford = await _heartCostService.canAfford(HeartCost.QUOTE);
    if (mounted) {
      setState(() {
        _hasEnoughHearts = canAfford;
      });
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
        _loadTodayQuote();
        _checkHeartAvailability(); // 하트 상태 재확인
      }
    });
  }

  Widget _buildQuoteCard(QuoteItem quote, bool isKorean) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사용자의 생각 (개선된 디자인)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                      Colors.blue[900]!,
                      Colors.blue[800]!,
                    ]
                  : [
                      Colors.blue.shade100,
                      Colors.blue.shade50,
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.psychology,
                      size: 20,
                      color: isDarkMode ? Colors.blue[200] : Colors.blue[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isKorean ? '오늘의 생각' : 'Today\'s Thought',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.blue[100] : Colors.blue[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                quote.userThought,
                style: TextStyle(
                  fontSize: 17,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // 통합된 명언과 위로 글 (개선된 디자인)
        if (quote.status == 'generated' &&
            quote.comfortMessage != null &&
            quote.comfortMessage!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        Colors.purple[900]!,
                        Colors.pink[900]!,
                      ]
                    : [
                        Colors.purple.shade100,
                        Colors.pink.shade100,
                        Colors.orange.shade50,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: Colors.purple.withOpacity(0.4),
                width: 2,
              ),
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
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.purple,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (quote.authorName != null)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person,
                                color: Colors.purple,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${quote.authorName} 작가 스타일',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.purple.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
                      padding: isFirstLine
                          ? const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12)
                          : EdgeInsets.zero,
                      decoration: isFirstLine
                          ? BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
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
                          color: isDarkMode ? Colors.white : Colors.black87,
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  isKorean ? '글귀 생성 중...' : 'Generating quote...',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          )
        else if (quote.status == 'failed')
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isKorean ? '글귀 생성에 실패했습니다.' : 'Failed to generate quote.',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.red.shade700,
              ),
            ),
          ),
      ],
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
                  Colors.blue.shade50,
                  Colors.white,
                ],
              ),
      ),
      child: Column(
        children: [
          // 상단 오늘의 명언/글귀 카드 (프레임 배경 적용)
          if (_dailyQuote != null)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 200,
                ),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const AssetImage('assets/images/decorative_box.png'),
                    fit: BoxFit.fill,
                    alignment: Alignment.center,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withOpacity(0.15), // 투명도 15%
                      BlendMode.modulate, // 원본 이미지와 곱해서 자연스럽게 반투명 처리
                    ),
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
                        color: Colors.brown.shade800,
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
                          color: Colors.brown.shade700,
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
                          color: Colors.brown.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 행복 글쓰기 카드 (항상 표시, 기록 보기 버튼 포함)
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isKorean ? '행복 글쓰기' : 'Happiness Quote Writing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
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
                        icon: const Icon(Icons.history, size: 18),
                        label: Text(
                          isKorean ? '기록 보기' : 'History',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  // 작성 버튼 (글 작성 전에만 표시)
                  if (!_hasWrittenToday) ...[
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _hasEnoughHearts
                              ? _showWriteQuoteModal
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isKorean
                                            ? '하트가 부족합니다. 하트를 충전해주세요.'
                                            : 'Insufficient hearts. Please charge hearts.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor:
                                _hasEnoughHearts ? null : Colors.grey,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_hasEnoughHearts)
                                const Icon(Icons.favorite_border, size: 18),
                              if (!_hasEnoughHearts) const SizedBox(width: 8),
                              Text(
                                isKorean
                                    ? '기록하기 (하트 ${HeartCost.QUOTE}개)'
                                    : 'Write (${HeartCost.QUOTE} Hearts)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_hasEnoughHearts)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              isKorean ? '하트가 부족합니다' : 'Insufficient hearts',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 오늘 글귀가 있으면 표시
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
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
                            borderRadius: BorderRadius.circular(5),
                            child: Image.asset(
                              'assets/images/store/quotes_logo.png',
                              width: 300,
                              height: 300,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.format_quote,
                                  size: 100,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isKorean
                                ? '오늘의 생각을 기록하면\nAI가 따뜻한 글귀를 만들어드려요.'
                                : 'Record your thoughts today\nand AI will create a warm quote for you.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
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
