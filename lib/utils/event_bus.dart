import 'dart:async';

/// 이벤트 버스 클래스 - 앱 내 이벤트 통신을 위한 클래스
class EventBus {
  // 이벤트 상수
  static const String entryVisibilityChanged = 'entry_visibility_changed';
  static const String entryDeleted = 'entry_deleted';
  static const String entryUpdated = 'entry_updated';
  static const String publicStatusChangedEvent = 'public_status_changed';
  static const String entryAdded = 'entry_added';
  static const String likeStatusChanged = 'like_status_changed';
  static const String bookmarkStatusChanged = 'bookmark_status_changed';
  static const String notificationClicked = 'notification_clicked';
  static const String onDidReceiveNotificationResponse =
      'on_did_receive_notification_response';
  static const String dataRefreshNeeded =
      'data_refresh_needed'; // 추가: 데이터 새로고침 필요 이벤트

  // 프라이빗 생성자
  EventBus._();

  // 싱글톤 인스턴스
  static final EventBus _instance = EventBus._();

  // 이벤트 스트림 컨트롤러
  final _streamController = StreamController.broadcast();

  // 이벤트 스트림
  Stream get stream => _streamController.stream;

  // 이벤트 발생
  void fire(String eventName, dynamic data) {
    _streamController.add({'event': eventName, 'data': data});
  }

  // 이벤트 구독
  StreamSubscription on(String eventName, Function(dynamic) callback) {
    return _streamController.stream
        .where((event) => event['event'] == eventName)
        .listen((event) {
      callback(event['data']);
    });
  }

  // 리소스 해제
  void dispose() {
    _streamController.close();
  }
}

// 글로벌 이벤트 버스 인스턴스
final eventBus = EventBus._instance;

// 항목 가시성 변경 이벤트
class EntryVisibilityChangedEvent {
  final String entryId;
  final bool isPublic;

  EntryVisibilityChangedEvent(this.entryId, this.isPublic);
}

// 항목 삭제 이벤트 - 개선된 버전, 더 많은 정보 포함
class EntryDeletedEvent {
  final String entryId;
  final dynamic entry; // 삭제된 항목의 데이터

  EntryDeletedEvent(this.entryId, {this.entry});
}

// 항목 업데이트 이벤트 - 개선된 버전
class EntryUpdatedEvent {
  final String entryId;
  final String content;
  final dynamic entry; // 업데이트된 항목의 전체 데이터

  EntryUpdatedEvent(this.entryId, this.content, {this.entry});
}

// 공개 상태 변경 이벤트
class PublicStatusChangedEvent {
  final String entryId;
  final bool isPublic;

  PublicStatusChangedEvent(this.entryId, this.isPublic);
}

// 새 항목 추가 이벤트 - 개선된 버전
class EntryAddedEvent {
  final dynamic entry; // 추가된 항목 데이터

  EntryAddedEvent({this.entry});
}

// 좋아요 상태 변경 이벤트
class LikeStatusChangedEvent {
  final String entryId;
  final bool isLiked;
  final int likeCount;

  LikeStatusChangedEvent(this.entryId, this.isLiked, this.likeCount);
}

// 북마크 상태 변경 이벤트
class BookmarkStatusChangedEvent {
  final String entryId;
  final bool isBookmarked;

  BookmarkStatusChangedEvent(this.entryId, this.isBookmarked);
}

// 할 일 업데이트 이벤트
class TodoUpdatedEvent {
  final dynamic todo; // 필요에 따라 실제 Todo 타입으로 변경
  TodoUpdatedEvent(this.todo);
}

// 알림 클릭 이벤트(notification_clicked)
class NotificationClickedEvent {
  // 필요한 경우 생성자 매개변수 추가
  NotificationClickedEvent();
}

// 데이터 새로고침 필요 이벤트 - 추가
class DataRefreshNeededEvent {
  final List<String> screens; // 새로고침이 필요한 화면 목록

  DataRefreshNeededEvent({this.screens = const []});
}

// 이벤트 상수 추가
class OnDidReceiveNotificationResponseEvent {
  final String actionIdentifier;
  final String notificationRequestIdentifier;

  OnDidReceiveNotificationResponseEvent(
      this.actionIdentifier, this.notificationRequestIdentifier);
}
