// lib/happiness_shop_2/categories/quotes/models/daily_quote.dart

/// 오늘의 명언/글귀 모델
class DailyQuote {
  final String quote;
  final String author;
  final String? source;

  DailyQuote({
    required this.quote,
    required this.author,
    this.source,
  });
}

/// 따뜻한 작가 모델
class WarmAuthor {
  final String name;
  final String description;
  final String? imageUrl;
  final List<String> famousQuotes;

  WarmAuthor({
    required this.name,
    required this.description,
    this.imageUrl,
    required this.famousQuotes,
  });
}

