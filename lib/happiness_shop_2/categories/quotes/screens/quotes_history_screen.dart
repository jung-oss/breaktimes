// lib/happiness_shop_2/categories/quotes/screens/quotes_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../providers/locale_provider.dart';
import '../services/quotes_service.dart';
import '../models/quote_item.dart';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isKorean ? '글귀 기록' : 'Quote History'),
      ),
      body: StreamBuilder<List<QuoteItem>>(
        stream: _service.getUserQuotesStream(),
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

          final quotes = snapshot.data ?? [];

          if (quotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.format_quote, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    isKorean ? '아직 기록이 없습니다.' : 'No quotes yet.',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
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
              return _buildQuoteCard(quote, isKorean, isDarkMode);
            },
          );
        },
      ),
    );
  }

  Widget _buildQuoteCard(QuoteItem quote, bool isKorean, bool isDarkMode) {
    final dateFormat = DateFormat(
      isKorean ? 'yyyy년 MM월 dd일' : 'MMMM dd, yyyy',
      isKorean ? 'ko' : 'en',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showQuoteDetail(quote, isKorean),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  // 삭제 버튼
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _showDeleteDialog(quote, isKorean),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 사용자의 생각 (개선된 디자인)
              Container(
                padding: const EdgeInsets.all(16),
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
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.psychology,
                            size: 16,
                            color: isDarkMode
                                ? Colors.blue[200]
                                : Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isKorean ? '오늘의 생각' : 'Today\'s Thought',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.blue[100]
                                : Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      quote.userThought,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 통합된 명언과 위로 글 (개선된 디자인)
              if (quote.status == 'generated' &&
                  quote.comfortMessage != null &&
                  quote.comfortMessage!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
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
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.purple,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (quote.authorName != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      color: Colors.purple,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${quote.authorName} 작가 스타일',
                                        style: TextStyle(
                                          fontSize: 11,
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
                      if (quote.authorName != null) const SizedBox(height: 16),
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
                                index < lines - 1 ? (isFirstLine ? 14 : 10) : 0,
                          ),
                          child: Container(
                            padding: isFirstLine
                                ? const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10)
                                : EdgeInsets.zero,
                            decoration: isFirstLine
                                ? BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
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
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                                height: isFirstLine ? 1.5 : 1.6,
                                letterSpacing: isFirstLine ? 0.2 : 0.05,
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
              else if (quote.status == 'pending')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode ? Colors.grey[800] : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isKorean ? '글귀 생성 중...' : 'Generating...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                )
              else if (quote.status == 'failed')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isKorean ? '생성 실패' : 'Generation failed',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuoteDetail(QuoteItem quote, bool isKorean) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isKorean ? '글귀 상세' : 'Quote Detail'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 사용자의 생각
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKorean ? '오늘의 생각' : 'Today\'s Thought',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white70 : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quote.userThought,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 통합된 명언과 위로 글
              if (quote.status == 'generated' &&
                  quote.comfortMessage != null &&
                  quote.comfortMessage!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDarkMode
                          ? [
                              Colors.grey[800]!,
                              Colors.grey[850]!,
                            ]
                          : [
                              Colors.purple.shade50,
                              Colors.pink.shade50,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작가 이름 표시
                      if (quote.authorName != null)
                        Row(
                          children: [
                            const Icon(Icons.person,
                                color: Colors.purple, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '${quote.authorName} 작가 스타일',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.purple.shade700,
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
                              color: isDarkMode ? Colors.white : Colors.black87,
                              height: isFirstLine ? 1.4 : 1.6,
                            ),
                            textAlign:
                                isFirstLine ? TextAlign.center : TextAlign.left,
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
                    color:
                        isDarkMode ? Colors.grey[800] : Colors.orange.shade50,
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
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.orange.shade700,
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isKorean ? '닫기' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(QuoteItem quote, bool isKorean) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isKorean ? '삭제 확인' : 'Delete Confirmation'),
        content: Text(
          isKorean
              ? '이 글귀를 삭제하시겠습니까?'
              : 'Are you sure you want to delete this quote?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _service.deleteQuote(quote.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isKorean ? '삭제되었습니다' : 'Deleted',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isKorean ? '삭제 실패' : 'Delete failed',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              isKorean ? '삭제' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
