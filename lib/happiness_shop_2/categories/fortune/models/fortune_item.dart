import 'package:cloud_firestore/cloud_firestore.dart';

class FortuneItem {
  final String id;
  final String userId;
  final String? mood;
  final String content;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? model;
  final String? status;

  FortuneItem({
    required this.id,
    required this.userId,
    this.mood,
    required this.content,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.model,
    this.status,
  });

  factory FortuneItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FortuneItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      mood: data['mood'],
      content: data['content'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      model: data['model'],
      status: data['status'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      if (mood != null) 'mood': mood,
      'content': content,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (model != null) 'model': model,
      if (status != null) 'status': status,
    };
  }
}
