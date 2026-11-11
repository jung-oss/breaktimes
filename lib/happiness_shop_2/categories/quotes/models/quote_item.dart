// lib/happiness_shop_2/categories/quotes/models/quote_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class QuoteItem {
  final String id;
  final String userId;
  final String userThought; // 사용자가 작성한 오늘의 생각
  final String generatedQuote; // AI가 생성한 글귀
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? model; // 사용한 AI 모델
  final String? status; // "pending", "generated", "failed"
  final String? comfortMessage; // 통합된 명언과 위로 글 (3~5줄)
  final String? authorName; // 작가 이름

  QuoteItem({
    required this.id,
    required this.userId,
    required this.userThought,
    required this.generatedQuote,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.model,
    this.status,
    this.comfortMessage,
    this.authorName,
  });

  factory QuoteItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuoteItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      userThought: data['userThought'] ?? '',
      generatedQuote: data['generatedQuote'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      model: data['model'],
      status: data['status'],
      comfortMessage: data['comfortMessage'],
      authorName: data['authorName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userThought': userThought,
      'generatedQuote': generatedQuote,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (model != null) 'model': model,
      if (status != null) 'status': status,
      if (comfortMessage != null) 'comfortMessage': comfortMessage,
      if (authorName != null) 'authorName': authorName,
    };
  }

  QuoteItem copyWith({
    String? userThought,
    String? generatedQuote,
    DateTime? updatedAt,
    String? model,
    String? status,
    String? comfortMessage,
    String? authorName,
  }) {
    return QuoteItem(
      id: id,
      userId: userId,
      userThought: userThought ?? this.userThought,
      generatedQuote: generatedQuote ?? this.generatedQuote,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      model: model ?? this.model,
      status: status ?? this.status,
      comfortMessage: comfortMessage ?? this.comfortMessage,
      authorName: authorName ?? this.authorName,
    );
  }
}
