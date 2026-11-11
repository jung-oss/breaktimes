// lib/models/todo_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'base_model.dart';

/// 할일 항목 모델
class TodoItem extends BaseModel {
  final String task;
  final String date;
  final bool isCompleted;
  final String userId;
  final String templateId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  TodoItem({
    required super.id,
    required this.task,
    required this.date,
    this.isCompleted = false,
    this.userId = '',
    this.templateId = 'default',
    DateTime? createdAt,
    this.completedAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task': task,
      'date': date,
      'isCompleted': isCompleted,
      'userId': userId,
      'templateId': templateId,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'metadata': metadata,
    };
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'task': task,
      'date': date,
      'isCompleted': isCompleted,
      'userId': userId,
      'templateId': templateId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'metadata': metadata,
    };
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'] ?? '',
      task: map['task'] ?? '',
      date: map['date'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      userId: map['userId'] ?? '',
      templateId: map['templateId'] ?? 'default',
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      completedAt: map['completedAt'] is DateTime
          ? map['completedAt']
          : map['completedAt'] is Timestamp
              ? (map['completedAt'] as Timestamp).toDate()
              : null,
      metadata: map['metadata'],
    );
  }

  factory TodoItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception('Document data is null');

    // Handle potential null values with null coalescing operators
    return TodoItem(
      id: doc.id,
      task: data['task'] as String? ?? '', // Add null check
      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate().toIso8601String().split('T')[0]
          : data['date'] as String? ?? '', // Add null check for date
      isCompleted: data['isCompleted'] as bool? ?? false,
      userId: data['userId'] as String? ?? '', // Add null check
      templateId: data['templateId'] as String? ?? 'default', // Add null check
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  TodoItem copyWith({
    String? task,
    String? date,
    bool? isCompleted,
    String? userId,
    String? templateId,
    DateTime? createdAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return TodoItem(
      id: id,
      task: task ?? this.task,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// 할일 템플릿 모델
class TodoTemplate extends BaseModel {
  final String task;
  final String category; // 'daily', 'weekly', 'monthly'
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy; // admin user id
  final Map<String, dynamic>? metadata; // 추가 설정 (난이도, 예상소요시간 등)

  TodoTemplate({
    required super.id,
    required this.task,
    required this.category,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    required this.createdBy,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  Map<String, dynamic> toMap() {
    return {
      'task': task,
      'category': category,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'task': task,
      'category': category,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }

  factory TodoTemplate.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TodoTemplate(
      id: doc.id,
      task: data['task'] as String,
      category: data['category'] as String,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  TodoTemplate copyWith({
    String? task,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return TodoTemplate(
      id: id,
      task: task ?? this.task,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// 사용자 진행 상황 모델
class UserProgress extends BaseModel {
  final String userId;
  final DateTime date;
  final int completedTodos;
  final int totalTodos;
  final String mood;
  final double happinessScore; // 0-100
  final DateTime updatedAt;

  UserProgress({
    required super.id,
    required this.userId,
    required this.date,
    required this.completedTodos,
    required this.totalTodos,
    required this.mood,
    required this.happinessScore,
    required this.updatedAt,
  });

  // UI/UX 관련 getter들
  Color get progressColor {
    final ratio = completedTodos / totalTodos;
    if (ratio >= 1.0) return Colors.green;
    if (ratio >= 0.7) return Colors.lightGreen;
    if (ratio >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Color get moodColor {
    switch (mood) {
      case '😊':
        return Colors.green;
      case '😐':
        return Colors.lightGreen;
      case '😩':
        return Colors.orange;
      case '😢':
        return Colors.blue;
      case '😠':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  double get completionRate =>
      totalTodos > 0 ? completedTodos / totalTodos : 0.0;

  String get statusMessage {
    if (completionRate >= 1.0) return '완료';
    if (completionRate >= 0.7) return '순조로움';
    if (completionRate >= 0.4) return '진행중';
    return '시작';
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date,
      'completedTodos': completedTodos,
      'totalTodos': totalTodos,
      'mood': mood,
      'happinessScore': happinessScore,
      'updatedAt': updatedAt,
    };
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'completedTodos': completedTodos,
      'totalTodos': totalTodos,
      'mood': mood,
      'happinessScore': happinessScore,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception('Document data is null');
    // Timestamp null 체크 및 기본값 처리
    final timestamp = data['date'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();

    // 문자열 필드에 대한 null 체크 추가
    final userId = data['userId'] as String? ?? '';
    final mood = data['mood'] as String? ?? '😐';

    // 숫자 필드에 대한 null 체크 추가
    final completedTodos = data['completedTodos'] as int? ?? 0;
    final totalTodos = data['totalTodos'] as int? ?? 0;
    final happinessScore = (data['happinessScore'] as num?)?.toDouble() ?? 0.0;

    // updatedAt 필드도 null 체크
    final updatedTimestamp = data['updatedAt'] as Timestamp?;
    final updatedAt = updatedTimestamp?.toDate() ?? DateTime.now();

    return UserProgress(
      id: doc.id,
      userId: userId,
      date: date,
      completedTodos: completedTodos,
      totalTodos: totalTodos,
      mood: mood,
      happinessScore: happinessScore,
      updatedAt: updatedAt,
    );
  }

  UserProgress copyWith({
    String? userId,
    DateTime? date,
    int? completedTodos,
    int? totalTodos,
    String? mood,
    double? happinessScore,
    DateTime? updatedAt,
  }) {
    return UserProgress(
      id: id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      completedTodos: completedTodos ?? this.completedTodos,
      totalTodos: totalTodos ?? this.totalTodos,
      mood: mood ?? this.mood,
      happinessScore: happinessScore ?? this.happinessScore,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
