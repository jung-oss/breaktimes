// models/notification_model.dart

/// 알림 빈도 열거형
enum NotificationFrequency {
  daily, // 매일
  weekly, // 매주
  monthly; // 매월

  /// 한국어 표시 문자열 반환
  String toKorean() {
    switch (this) {
      case NotificationFrequency.daily:
        return '매일';
      case NotificationFrequency.weekly:
        return '매주';
      case NotificationFrequency.monthly:
        return '매월';
    }
  }

  /// 설명 반환
  String getDescription(bool isKorean) {
    if (isKorean) {
      switch (this) {
        case NotificationFrequency.daily:
          return '매일 알림을 받습니다.';
        case NotificationFrequency.weekly:
          return '매주 일요일에 알림을 받습니다.';
        case NotificationFrequency.monthly:
          return '매월 1일에 알림을 받습니다.';
      }
    } else {
      switch (this) {
        case NotificationFrequency.daily:
          return 'Receive notifications every day.';
        case NotificationFrequency.weekly:
          return 'Receive notifications every Sunday.';
        case NotificationFrequency.monthly:
          return 'Receive notifications on the 1st of each month.';
      }
    }
  }
}

/// 알림 모델 클래스
class NotificationModel {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final bool repeating;
  final NotificationFrequency frequency;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.repeating = false,
    this.frequency = NotificationFrequency.daily,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'repeating': repeating,
      'frequency': frequency.index,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      scheduledTime: DateTime.parse(map['scheduledTime']),
      repeating: map['repeating'] ?? false,
      frequency: NotificationFrequency.values[map['frequency'] ?? 0],
    );
  }
}
