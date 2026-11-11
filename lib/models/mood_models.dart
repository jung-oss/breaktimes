// lib/models/mood_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_model.dart';

/// 주제 모델
class Topic extends BaseModel {
  final String topic;
  final String type; // 'daily', 'weekly', 'monthly'
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy; // admin user id
  final String yearMonth; // '2024-01' 형식의 년월 정보

  Topic({
    required super.id,
    required this.topic,
    required this.type,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    required this.createdBy,
    String? yearMonth,
  })  : createdAt = createdAt ?? DateTime.now(),
        yearMonth = yearMonth ?? _formatYearMonth(createdAt ?? DateTime.now());

  // yearMonth 포맷팅을 위한 정적 메서드
  static String _formatYearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'type': type,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'yearMonth': yearMonth,
    };
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'topic': topic,
      'type': type,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'yearMonth': yearMonth,
    };
  }

  factory Topic.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Topic(
      id: doc.id,
      topic: data['topic'] as String,
      type: data['type'] as String,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String,
      yearMonth: data['yearMonth'] as String?,
    );
  }

  Topic copyWith({
    String? topic,
    String? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? yearMonth,
  }) {
    return Topic(
      id: id,
      topic: topic ?? this.topic,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      yearMonth: yearMonth ?? this.yearMonth,
    );
  }
}

/// 사용자 감정/생각 기록 모델
class MoodEntry extends BaseModel {
  final String content;
  final String mood;
  final DateTime date;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final String userId;
  final String username;
  final String? userPhotoURL;
  final bool isPublic;
  final int likeCount;
  final String topic;
  final String topicId;

  MoodEntry({
    required super.id,
    required this.content,
    required this.mood,
    required this.date,
    this.updatedAt,
    this.createdAt,
    required this.userId,
    required this.username,
    this.userPhotoURL,
    required this.isPublic,
    required this.likeCount,
    required this.topic,
    required this.topicId,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'mood': mood,
      'date': date,
      'updatedAt': updatedAt,
      'createdAt': createdAt,
      'userId': userId,
      'username': username,
      'userPhotoURL': userPhotoURL,
      'isPublic': isPublic,
      'likeCount': likeCount,
      'topic': topic,
      'topicId': topicId,
    };
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'content': content,
      'mood': mood,
      'date': Timestamp.fromDate(date),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'userId': userId,
      'username': username,
      'userPhotoURL': userPhotoURL,
      'isPublic': isPublic,
      'likeCount': likeCount,
      'topic': topic,
      'topicId': topicId,
    };
  }

  factory MoodEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      // 기본값 반환
      return MoodEntry(
        id: doc.id,
        content: '',
        mood: '😐',
        date: DateTime.now(),
        userId: '',
        username: '나비잠',
        isPublic: false,
        likeCount: 0,
        topic: '',
        topicId: '',
      );
    }

    return MoodEntry(
      id: doc.id,
      content: data['content'] ?? '',
      mood: data['mood'] ?? '😐',
      date: (data['date'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp?)?.toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp?)?.toDate()
          : null,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '나비잠',
      userPhotoURL: data['userPhotoURL'],
      isPublic: data['isPublic'] ?? false,
      likeCount: data['likeCount'] ?? 0,
      topic: data['topic'] ?? '',
      topicId: data['topicId'] ?? '',
    );
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : (map['date'] as DateTime? ?? DateTime.now()),
      mood: map['mood'] ?? '😊',
      content: map['content'] ?? '',
      topic: map['topic'] ?? '',
      topicId: map['topicId'] ?? '',
      isPublic: map['isPublic'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] as DateTime?),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : (map['updatedAt'] as DateTime?),
      username: map['username'] ?? '나비잠',
      userPhotoURL: map['userPhotoURL'],
      likeCount: map['likeCount'] ?? 0,
    );
  }

  MoodEntry copyWith({
    String? id,
    String? content,
    String? mood,
    DateTime? date,
    DateTime? updatedAt,
    DateTime? createdAt,
    String? userId,
    String? username,
    String? userPhotoURL,
    bool? isPublic,
    int? likeCount,
    String? topic,
    String? topicId,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      date: date ?? this.date,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userPhotoURL: userPhotoURL ?? this.userPhotoURL,
      isPublic: isPublic ?? this.isPublic,
      likeCount: likeCount ?? this.likeCount,
      topic: topic ?? this.topic,
      topicId: topicId ?? this.topicId,
    );
  }
}

/// 캘린더 진행 상태를 표시하기 위한 모델
class MoodProgress {
  final int completedTodos;
  final int totalTodos;
  final String mood;

  MoodProgress({
    required this.completedTodos,
    required this.totalTodos,
    required this.mood,
  });
}

/// MoodEntry 클래스에 변환 메서드 추가
extension MoodEntryExtension on MoodEntry {
  MoodProgress toMoodProgress() {
    int completedTodos;
    const int totalTodos = 5;

    switch (mood) {
      case '😊': // 행복
        completedTodos = 5;
        break;
      case '😐': // 편안
        completedTodos = 4;
        break;
      case '😩': // 놀람
        completedTodos = 3;
        break;
      case '😢': // 슬픔
        completedTodos = 2;
        break;
      case '😠': // 화남
        completedTodos = 1;
        break;
      default:
        completedTodos = 3;
    }

    return MoodProgress(
      completedTodos: completedTodos,
      totalTodos: totalTodos,
      mood: mood,
    );
  }
}

// 감정 이름 매핑 수정
Map<String, String> getMoodNameMap(String locale) {
  if (locale.startsWith('ko')) {
    return {
      '😊': '행복',
      '😢': '슬픔',
      '😠': '화남',
      '😩': '놀람',
      '😐': '평온',
    };
  } else {
    return {
      '😊': 'Happy',
      '😢': 'Sad',
      '😠': 'Angry',
      '😩': 'Amazed', // Surprised 대신 Amazed 사용
      '😐': 'Calm',
    };
  }
}

// providers/relax_provider.dart 파일 상단에 다음 확장 추가

extension MapCopyWith on Map<String, dynamic> {
  Map<String, dynamic> copyWith({
    String? id,
    String? content,
    String? mood,
    dynamic date,
    dynamic updatedAt,
    dynamic createdAt,
    String? userId,
    String? username,
    String? userPhotoURL,
    bool? isPublic,
    int? likeCount,
    String? topic,
    String? topicId,
    bool? isLiked,
    bool? isBookmarked,
  }) {
    final copy = Map<String, dynamic>.from(this);

    if (id != null) copy['id'] = id;
    if (content != null) copy['content'] = content;
    if (mood != null) copy['mood'] = mood;
    if (date != null) copy['date'] = date;
    if (updatedAt != null) copy['updatedAt'] = updatedAt;
    if (createdAt != null) copy['createdAt'] = createdAt;
    if (userId != null) copy['userId'] = userId;
    if (username != null) copy['username'] = username;
    if (userPhotoURL != null) copy['userPhotoURL'] = userPhotoURL;
    if (isPublic != null) copy['isPublic'] = isPublic;
    if (likeCount != null) copy['likeCount'] = likeCount;
    if (topic != null) copy['topic'] = topic;
    if (topicId != null) copy['topicId'] = topicId;
    if (isLiked != null) copy['isLiked'] = isLiked;
    if (isBookmarked != null) copy['isBookmarked'] = isBookmarked;

    return copy;
  }
}
