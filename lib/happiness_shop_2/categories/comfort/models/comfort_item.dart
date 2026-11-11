import 'package:cloud_firestore/cloud_firestore.dart';

class ComfortItem {
  final String id;
  final String userId;
  final String userMessage;
  final String content;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? model;
  final String? status;

  ComfortItem({
    required this.id,
    required this.userId,
    required this.userMessage,
    required this.content,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.model,
    this.status,
  });

  factory ComfortItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ComfortItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      userMessage: data['userMessage'] ?? '',
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
      'userMessage': userMessage,
      'content': content,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (model != null) 'model': model,
      if (status != null) 'status': status,
    };
  }
}
