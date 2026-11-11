import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../core/localization/app_localizations.dart';
import '../utils/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:breaktimes/main.dart' show alarmCallback;
import '../services/topic_service.dart';
import '../utils/event_bus.dart';

/// 알림 관련 기능을 제공하는 서비스 클래스
///
/// 앱의 알림 기능을 담당하며, 알림 설정, 스케줄링, 권한 요청 등의 기능을 제공합니다.
class NotificationService {
  // 싱글톤 패턴 구현
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // 플러그인 및 컨트롤러 초기화
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // RxDart를 사용한 알림 상태 스트림
  final BehaviorSubject<NotificationStatus> _statusController =
      BehaviorSubject<NotificationStatus>();

  // 상수 정의
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyNotificationFrequency = 'notification_frequency';
  static const String keyNotificationTime = 'notification_time';
  static const String keyLastNotificationDate = 'last_notification_date';
  static const String keyScheduledNotifications = 'scheduled_notifications';
  static const int dailyNotificationId = 1;
  static const int weeklyNotificationId = 2;

  // AlarmManager 콜백 ID
  static const int dailyAlarmId = 100;
  static const int weeklyAlarmId = 101;

  // 알림 채널 설정
  static const String channelId = 'breaktimes_notifications';
  static const String channelName = 'Break Times Notifications';
  static const String channelDescription = 'Notifications for Break Times app';

  // 알림 빈도 타입
  static const String frequencyDaily = 'daily';
  static const String frequencyWeekly = 'weekly';
  static const String frequencyMonthly = 'monthly';

  // Android 특정 알림 권한 요청을 위한 메서드 채널
  static const platform =
      MethodChannel('com.gemma.breaktimes.breaktimes/alarm_permissions');

  // 초기화 완료 여부
  bool _initialized = false;

  // 알림 상태
  bool _permissionsGranted = false;
  List<PendingNotificationRequest> _pendingNotifications = [];
  int _retryCount = 0;
  static const int maxRetries = 3;

  // 내부 생성자
  NotificationService._internal();

  // 스트림 게터
  Stream<NotificationStatus> get statusStream => _statusController.stream;

  // 권한 상태 게터
  bool get permissionsGranted => _permissionsGranted;

  // 초기화 메서드
  Future<bool> init() async {
    if (_initialized) return true;

    Logger.info('NotificationService: 초기화 시작');

    try {
      // 타임존 데이터 초기화
      tz_data.initializeTimeZones();

      // Android 설정
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/notification_icon');

      // iOS 설정
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      // 초기화 설정 생성
      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // 플러그인 초기화
      bool? initialized = false;
      try {
        initialized = await flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        );
      } catch (e) {
        Logger.error('NotificationService: 플러그인 초기화 중 예외 발생: $e');
        // 초기화 실패해도 계속 진행
      }

      if (initialized != true) {
        Logger.warn('NotificationService: 플러그인 초기화가 성공하지 못했지만 계속 진행합니다.');
      }

      // Android Alarm Manager 초기화 (Android 전용)
      if (Platform.isAndroid) {
        try {
          final alarmInitialized = await AndroidAlarmManager.initialize();
          if (!alarmInitialized) {
            Logger.warn('NotificationService: 알람 매니저 초기화 실패, 계속 진행합니다.');
          } else {
            Logger.debug('NotificationService: 알람 매니저 초기화 성공');
          }
        } catch (e) {
          Logger.error('NotificationService: 알람 매니저 초기화 오류: $e');
          // 알람 매니저 초기화 실패해도 계속 진행
        }
      }

      // 현재 예약된 알림 로드
      await _loadPendingNotifications();

      // 권한 상태 확인
      _permissionsGranted = await checkPermissions();

      _initialized = true;
      Logger.info('NotificationService: 초기화 완료, 권한 상태: $_permissionsGranted');

      // 상태 업데이트
      _updateStatus(
          isInitialized: true,
          permissionsGranted: _permissionsGranted,
          pendingNotifications: _pendingNotifications);

      return true;
    } catch (e) {
      Logger.error('NotificationService: 초기화 오류 - $e');
      _updateStatus(
          isInitialized: false,
          hasError: true,
          errorMessage: '알림 시스템 초기화 중 오류: $e');
      return false;
    }
  }

  // 알림 권한 확인 메서드
  Future<bool> checkPermissions() async {
    try {
      if (Platform.isAndroid) {
        return await _checkAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _checkIOSPermissions();
      }
      return false;
    } catch (e) {
      Logger.error('권한 확인 중 오류: $e');
      return false;
    }
  }

  // Android 권한 확인
  Future<bool> _checkAndroidPermissions() async {
    try {
      // Android SDK 버전 체크
      int? sdkVersion;
      try {
        sdkVersion = await platform.invokeMethod('getAndroidSdkVersion');
        Logger.debug('Android SDK 버전: $sdkVersion');
      } catch (e) {
        Logger.warn('Android SDK 버전 확인 실패: $e');
        // SDK 버전 확인 실패 시 권한이 있다고 가정하고 진행
        return true;
      }

      // Android 13 이상 (API 레벨 33+)에서는 POST_NOTIFICATIONS 권한 확인
      if (sdkVersion != null && sdkVersion >= 33) {
        try {
          final androidPlugin = flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          final granted =
              await androidPlugin?.areNotificationsEnabled() ?? false;

          Logger.debug('POST_NOTIFICATIONS 권한: $granted');
          return granted;
        } catch (e) {
          Logger.warn('알림 권한 확인 실패: $e, 권한이 있다고 가정하고 진행합니다.');
          return true;
        }
      }

      // Android 12 이상 (API 레벨 31+)에서는 정확한 알람 권한 확인
      if (sdkVersion != null && sdkVersion >= 31) {
        try {
          final hasExactAlarmPermission =
              await platform.invokeMethod('checkExactAlarmPermission') ?? false;

          Logger.debug('정확한 알람 권한: $hasExactAlarmPermission');
          return hasExactAlarmPermission;
        } catch (e) {
          Logger.warn('정확한 알람 권한 확인 실패: $e, 권한이 있다고 가정하고 진행합니다.');
          return true;
        }
      }

      // 이전 버전의 Android에서는 기본적으로 권한 있음
      return true;
    } catch (e) {
      Logger.error('Android 권한 확인 오류: $e');
      // 오류 발생 시 권한이 있다고 가정하고 진행
      return true;
    }
  }

  // iOS 권한 확인
  Future<bool> _checkIOSPermissions() async {
    try {
      // iOS에서는 알림 초기화 시 권한을 요청하므로,
      // 여기서는 단순히 true 반환 (실제 권한은 requestPermissions에서 확인)
      return true;
    } catch (e) {
      Logger.error('iOS 권한 확인 오류: $e');
      return false;
    }
  }

  // 권한 요청 메서드
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        return await _requestAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _requestIOSPermissions();
      }
      return false;
    } catch (e) {
      Logger.error('권한 요청 중 오류: $e');
      return false;
    }
  }

  // Android 권한 요청
  Future<bool> _requestAndroidPermissions() async {
    try {
      int? sdkVersion;
      try {
        sdkVersion = await platform.invokeMethod('getAndroidSdkVersion');
      } catch (e) {
        Logger.warn('Android SDK 버전 확인 실패: $e, 권한 요청을 건너뜁니다.');
        // SDK 버전 확인 실패 시 권한이 있다고 가정하고 진행
        return true;
      }

      bool permissionGranted = true;

      // Android 13 이상에서 알림 권한 요청
      if (sdkVersion != null && sdkVersion >= 33) {
        try {
          final androidPlugin = flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          final granted =
              await androidPlugin?.requestNotificationsPermission() ?? false;

          permissionGranted = permissionGranted && granted;
          Logger.debug('POST_NOTIFICATIONS 권한 요청 결과: $granted');
        } catch (e) {
          Logger.warn('알림 권한 요청 실패: $e, 계속 진행합니다.');
        }
      }

      // Android 12 이상에서 정확한 알람 권한 요청
      if (sdkVersion != null && sdkVersion >= 31) {
        try {
          final hasPermission =
              await platform.invokeMethod('checkExactAlarmPermission') ?? false;

          if (!hasPermission) {
            await platform.invokeMethod('requestExactAlarmPermission');
            final granted =
                await platform.invokeMethod('checkExactAlarmPermission') ??
                    false;
            permissionGranted = permissionGranted && granted;
            Logger.debug('정확한 알람 권한 요청 결과: $granted');
          }
        } catch (e) {
          Logger.warn('정확한 알람 권한 요청 실패: $e, 계속 진행합니다.');
        }
      }

      // 권한 상태 업데이트
      _permissionsGranted = permissionGranted;
      _updateStatus(permissionsGranted: permissionGranted);

      return permissionGranted;
    } catch (e) {
      Logger.error('Android 권한 요청 오류: $e');
      // 오류 발생 시 권한이 있다고 가정하고 진행
      return true;
    }
  }

  // iOS 권한 요청
  Future<bool> _requestIOSPermissions() async {
    try {
      final iosPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      final bool? granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      final permissionGranted = granted ?? false;

      // 권한 상태 업데이트
      _permissionsGranted = permissionGranted;
      _updateStatus(permissionsGranted: permissionGranted);

      Logger.debug('iOS 알림 권한 요청 결과: $permissionGranted');
      return permissionGranted;
    } catch (e) {
      Logger.error('iOS 권한 요청 오류: $e');
      return false;
    }
  }

  // 현재 예약된 알림 로드
  Future<void> _loadPendingNotifications() async {
    try {
      _pendingNotifications =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      Logger.debug('예약된 알림 수: ${_pendingNotifications.length}');
    } catch (e) {
      Logger.error('예약된 알림 로드 오류: $e');
      _pendingNotifications = [];
    }
  }

  // 알림 설정 저장
  Future<bool> saveNotificationSettings({
    required bool enabled,
    required String frequency,
    required TimeOfDay time,
    List<int>? weekdays,
    int? monthlyDate,
  }) async {
    try {
      Logger.info(
          '알림 설정 저장: 활성화=$enabled, 빈도=$frequency, 시간=${time.hour}:${time.minute}, 요일=$weekdays, 날짜=$monthlyDate');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyNotificationsEnabled, enabled);
      await prefs.setString(keyNotificationFrequency, frequency);

      // TimeOfDay를 분 단위로 변환하여 저장 (예: 13:30 -> 810분)
      final minutes = time.hour * 60 + time.minute;
      await prefs.setInt(keyNotificationTime, minutes);

      // 요일 및 월간 날짜 저장 (새로 추가)
      if (weekdays != null && weekdays.isNotEmpty) {
        await prefs.setStringList('notification_weekdays',
            weekdays.map((day) => day.toString()).toList());
      }

      if (monthlyDate != null) {
        await prefs.setInt('notification_monthly_date', monthlyDate);
      }

      // 사용자가 로그인 중이면 Firestore에도 저장
      try {
        await _saveSettingsToFirestore(
            enabled, frequency, time, weekdays, monthlyDate);
      } catch (e) {
        Logger.error('Firestore 설정 저장 오류: $e');
        // Firestore 저장 실패해도 계속 진행
      }

      // 알림 설정 저장 후 알림 스케줄링
      if (enabled) {
        final success = await scheduleNotifications();
        if (!success) {
          Logger.warn('알림 스케줄링 실패했지만 설정은 저장되었습니다.');
        }
      } else {
        await cancelAllNotifications();
      }

      return true;
    } catch (e) {
      Logger.error('알림 설정 저장 오류: $e');
      return false;
    }
  }

  // Firestore에 설정 저장
  Future<void> _saveSettingsToFirestore(bool enabled, String frequency,
      TimeOfDay time, List<int>? weekdays, int? monthlyDate) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final Map<String, dynamic> data = {
        'enabled': enabled,
        'frequency': frequency,
        'timeHour': time.hour,
        'timeMinute': time.minute,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 주간 알림인 경우 요일 정보 추가
      if (weekdays != null && weekdays.isNotEmpty) {
        data['weekdays'] = weekdays;
      }

      // 월간 알림인 경우 날짜 정보 추가
      if (monthlyDate != null) {
        data['monthlyDate'] = monthlyDate;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .set(data, SetOptions(merge: true));

      Logger.debug('Firestore에 알림 설정 저장됨');
    } catch (e) {
      Logger.error('Firestore 설정 저장 오류: $e');
      throw e; // 오류 재전파
    }
  }

  // 저장된 알림 설정 로드
  Future<Map<String, dynamic>> loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 기본값 설정
      final bool enabled = prefs.getBool(keyNotificationsEnabled) ?? true;
      final String frequency =
          prefs.getString(keyNotificationFrequency) ?? frequencyDaily;

      // 저장된 분 값을 TimeOfDay로 변환 (기본값: 20:00)
      final int timeInMinutes = prefs.getInt(keyNotificationTime) ?? (20 * 60);
      final TimeOfDay time = TimeOfDay(
        hour: timeInMinutes ~/ 60,
        minute: timeInMinutes % 60,
      );

      // 추가: 요일 정보 로드
      List<int>? weekdays;
      final weekdaysStrings = prefs.getStringList('notification_weekdays');
      if (weekdaysStrings != null && weekdaysStrings.isNotEmpty) {
        weekdays = weekdaysStrings.map((s) => int.parse(s)).toList();
      }

      // 추가: 월간 알림 날짜 로드
      final int? monthlyDate = prefs.getInt('notification_monthly_date');

      Logger.debug(
          '알림 설정 로드됨: 활성화=$enabled, 빈도=$frequency, 시간=${time.hour}:${time.minute}, 요일=$weekdays, 날짜=$monthlyDate');

      return {
        'enabled': enabled,
        'frequency': frequency,
        'time': time,
        'weekdays': weekdays,
        'monthlyDate': monthlyDate,
      };
    } catch (e) {
      Logger.error('알림 설정 로드 오류: $e');

      // 오류 발생 시 기본값 반환
      return {
        'enabled': true,
        'frequency': frequencyDaily,
        'time': const TimeOfDay(hour: 20, minute: 0),
        'weekdays': null,
        'monthlyDate': null,
      };
    }
  }

  // 수정된 scheduleNotifications 메서드
  Future<bool> scheduleNotifications() async {
    if (!_initialized) {
      Logger.warn('알림 서비스가 초기화되지 않았습니다.');
      return false;
    }

    // 권한이 없어도 설정은 저장
    if (!_permissionsGranted) {
      Logger.warn('알림 권한이 없습니다. 설정은 저장됩니다.');
    }

    // 먼저 기존 알림 취소
    try {
      await cancelAllNotifications();
    } catch (e) {
      Logger.warn('기존 알림 취소 중 오류 발생: $e, 계속 진행합니다.');
    }

    try {
      // 알림 설정 로드
      final settings = await loadNotificationSettings();
      if (!settings['enabled']) {
        Logger.info('알림이 비활성화되어 있어 스케줄링을 건너뜁니다.');
        return true;
      }

      final frequency = settings['frequency'];
      final TimeOfDay notificationTime = settings['time'];
      final List<int>? weekdays = settings['weekdays']; // 요일 정보 가져오기
      final int? monthlyDate = settings['monthlyDate']; // 월간 날짜 정보 가져오기

      Logger.debug(
          '알림 스케줄링 시작: 빈도=$frequency, 시간=${notificationTime.hour}:${notificationTime.minute}, 요일=$weekdays, 날짜=$monthlyDate');

      // 현재 사용자가 선택한 언어 확인
      final currentLocale = await _getCurrentLocale();
      final isKorean = currentLocale.startsWith('ko');

      // 오늘의 주제 가져오기
      String topicContent = '';
      try {
        final topicService = TopicService();
        final topicData = await topicService.loadDailyTopic(currentLocale);
        if (topicData.containsKey('content')) {
          topicContent = topicData['content'] ?? '';

          // 주제를 SharedPreferences에 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('today_topic', topicContent);
          Logger.debug('오늘의 주제 저장됨: $topicContent');
        }
      } catch (e) {
        Logger.error('주제 가져오기 오류: $e');
        // 주제 가져오기 실패해도 계속 진행
        topicContent = isKorean
            ? '오늘의 생각을 기록할 시간입니다!'
            : 'Time to write your daily thoughts!';
      }

      // 알림 제목 및 본문 설정
      final String title = isKorean ? 'Breaktime' : 'Breaktime';
      String body;

      if (topicContent.isNotEmpty) {
        // 주제가 있는 경우
        body = isKorean
            ? '오늘의 주제: $topicContent'
            : 'Today\'s topic: $topicContent';
      } else {
        // 주제가 없는 경우 기본 메시지
        body = isKorean
            ? '오늘의 생각을 기록할 시간입니다!'
            : 'Time to write your daily thoughts!';
      }

      // 알림 정보 SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarm_title', title);
      await prefs.setString('alarm_body', body);

      // 플랫폼별 알림 스케줄링
      if (Platform.isAndroid) {
        return await _scheduleAndroidAlarm(
            frequency, notificationTime, title, body, weekdays, monthlyDate);
      }
      // iOS에서는 Flutter Local Notifications 사용
      else if (Platform.isIOS) {
        return await _scheduleIOSNotification(
            frequency, notificationTime, title, body, weekdays, monthlyDate);
      }

      return false;
    } catch (e) {
      Logger.error('알림 스케줄링 오류: $e');
      _updateStatus(hasError: true, errorMessage: '알림 스케줄링 중 오류가 발생했습니다: $e');
      return false;
    }
  }

  // 오늘의 주제를 알림 내용에 포함하는 메서드 - 새 구현으로 대체
  Future<bool> scheduleNotificationsWithTopic() async {
    return scheduleNotifications();
  }

  // Android용 알람 스케줄링 메서드 (수정됨)
  Future<bool> _scheduleAndroidAlarm(
      String frequency,
      TimeOfDay notificationTime,
      String title,
      String body,
      List<int>? weekdays,
      int? monthlyDate) async {
    try {
      // 알림 정보 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarm_title', title);
      await prefs.setString('alarm_body', body);

      Logger.debug(
          '알람 예약 시도 - 시간: ${_getAlarmTime(notificationTime).toString()}, 제목: $title, 내용: $body');

      // 빈도별 처리
      if (frequency == frequencyDaily) {
        Logger.debug('매일 알림 설정 시작');
        // 매일 알림 (기존 코드 유지)
        final alarmTime = _getAlarmTime(notificationTime);
        await prefs.setInt('alarm_id', dailyAlarmId);

        // 기존 알람 취소 후 새로 설정
        try {
          await AndroidAlarmManager.cancel(dailyAlarmId);
        } catch (e) {
          Logger.warn('기존 알람 취소 실패: $e, 계속 진행합니다.');
        }

        // 알람 설정
        bool success;
        try {
          success = await AndroidAlarmManager.oneShotAt(
            alarmTime,
            dailyAlarmId,
            alarmCallback, // main.dart에 정의된 최상위 콜백 함수 사용
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
            allowWhileIdle: true,
          );
        } catch (e) {
          Logger.error('매일 알람 예약 오류: $e');
          return false;
        }

        if (success) {
          Logger.debug('매일 알람 예약됨: ${alarmTime.toString()}');
          // 다음 알림 시간 저장
          await prefs.setString('next_alarm_time', alarmTime.toIso8601String());
          return true;
        } else {
          Logger.error('매일 알람 예약 실패');
          return false;
        }
      } else if (frequency == frequencyWeekly &&
          weekdays != null &&
          weekdays.isNotEmpty) {
        Logger.debug('주간 알림 설정 시작: 요일=$weekdays');

        // 주간 알림 - 선택된 요일에 알림 설정 (개선된 코드)
        final now = DateTime.now();
        Logger.debug('주간 알림 설정 시작: 요일=$weekdays');
        Logger.debug('주간 알림 설정 - 선택된 요일: $weekdays');

        // 다음 알람 시간 계산 (선택된 요일 중 가장 가까운 미래 날짜)
        DateTime? nextAlarmTime;
        int minDays = 8; // 최대 7일보다 큰 값으로 초기화

        for (final weekday in weekdays) {
          // 현재 요일부터 선택된 요일까지의 일수 계산
          int daysUntil = (weekday - now.weekday);

          // 오늘인 경우 (daysUntil = 0)
          if (daysUntil == 0) {
            final todayAlarm = DateTime(now.year, now.month, now.day,
                notificationTime.hour, notificationTime.minute);

            // 오늘이지만 이미 시간이 지났으면 다음 주로
            if (todayAlarm.isBefore(now)) {
              daysUntil = 7;
            }
            // 그렇지 않으면 오늘 알람 유지 (daysUntil = 0)
          }
          // 과거 요일인 경우 (daysUntil < 0)
          else if (daysUntil < 0) {
            daysUntil += 7; // 다음 주로
          }
          // 미래 요일인 경우 (daysUntil > 0)는 그대로 유지

          // 가장 빠른 날짜 선택
          if (daysUntil < minDays) {
            minDays = daysUntil;
            nextAlarmTime = now.add(Duration(days: daysUntil));
            nextAlarmTime = DateTime(
              nextAlarmTime.year,
              nextAlarmTime.month,
              nextAlarmTime.day,
              notificationTime.hour,
              notificationTime.minute,
            );

            Logger.debug(
                '후보 알람 날짜: ${nextAlarmTime.toString()}, 요일: $weekday, daysUntil: $daysUntil');
          }
        }

        // 기본값 설정 (선택된 요일이 없거나 계산 중 오류 발생 시)
        if (nextAlarmTime == null) {
          nextAlarmTime = _getAlarmTime(notificationTime, isWeekly: true);
          Logger.debug('기본 알람 시간으로 설정: ${nextAlarmTime.toString()}');
        }

        await prefs.setInt('alarm_id', weeklyAlarmId);
        Logger.debug(
            '주간 알람 예약 시도 - 시간: ${nextAlarmTime.toString()}, 제목: $title');

        // 기존 알람 취소 후 새로 설정
        try {
          await AndroidAlarmManager.cancel(weeklyAlarmId);
        } catch (e) {
          Logger.warn('기존 주간 알람 취소 실패: $e, 계속 진행합니다.');
        }

        // 알람 설정
        bool success;
        try {
          success = await AndroidAlarmManager.oneShotAt(
            nextAlarmTime,
            weeklyAlarmId,
            alarmCallback, // main.dart에 정의된 최상위 콜백 함수 사용
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
            allowWhileIdle: true,
          );
        } catch (e) {
          Logger.error('매주 알람 예약 오류: $e');
          return false;
        }

        if (success) {
          Logger.debug('매주 알람 예약됨: ${nextAlarmTime.toString()}, 요일: $weekdays');
          // 다음 알림 시간 저장
          await prefs.setString(
              'next_alarm_time', nextAlarmTime.toIso8601String());

          // 선택된 요일 저장 (나중에 알람 재예약할 때 필요)
          await prefs.setStringList('selected_weekdays',
              weekdays.map((day) => day.toString()).toList());

          return true;
        } else {
          Logger.error('매주 알람 예약 실패');
          return false;
        }
      } else if (frequency == 'monthly' && monthlyDate != null) {
        // 매월 알림 (선택된 날짜에) - 개선된 코드
        final now = DateTime.now();

        // 로그 추가
        Logger.debug('월간 알림 설정 - 선택된 날짜: $monthlyDate');

        // 이번 달의 선택된 날짜 (또는 다음 달)
        DateTime targetDate;

        // 현재 날짜가 선택된 날짜보다 이전인 경우 (이번 달)
        if (now.day < monthlyDate) {
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          final actualDate =
              monthlyDate > daysInMonth ? daysInMonth : monthlyDate;

          targetDate = DateTime(
            now.year,
            now.month,
            actualDate,
            notificationTime.hour,
            notificationTime.minute,
          );
        }
        // 이미 이번 달의 선택된 날짜가 지났거나 오늘인데 시간이 지난 경우 (다음 달)
        else {
          // 오늘이 선택된 날짜인 경우, 시간 비교
          if (now.day == monthlyDate) {
            final todayAlarm = DateTime(now.year, now.month, now.day,
                notificationTime.hour, notificationTime.minute);

            // 아직 오늘의 알람 시간이 지나지 않았으면 오늘 설정
            if (todayAlarm.isAfter(now)) {
              targetDate = todayAlarm;
            }
            // 이미 지났으면 다음 달로
            else {
              final nextMonth = now.month == 12 ? 1 : now.month + 1;
              final nextYear = now.month == 12 ? now.year + 1 : now.year;
              final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
              final actualDate =
                  monthlyDate > daysInNextMonth ? daysInNextMonth : monthlyDate;

              targetDate = DateTime(
                nextYear,
                nextMonth,
                actualDate,
                notificationTime.hour,
                notificationTime.minute,
              );
            }
          }
          // 오늘이 선택된 날짜보다 이후인 경우 (다음 달)
          else {
            final nextMonth = now.month == 12 ? 1 : now.month + 1;
            final nextYear = now.month == 12 ? now.year + 1 : now.year;
            final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
            final actualDate =
                monthlyDate > daysInNextMonth ? daysInNextMonth : monthlyDate;

            targetDate = DateTime(
              nextYear,
              nextMonth,
              actualDate,
              notificationTime.hour,
              notificationTime.minute,
            );
          }
        }

        // 월간도 주간과 같은 ID 사용 (기존 코드 유지)
        await prefs.setInt('alarm_id', weeklyAlarmId);
        Logger.debug(
            '월간 알람 예약 시도 - 시간: ${targetDate.toString()}, 제목: $title, 날짜: $monthlyDate');

        // 기존 알람 취소 후 새로 설정
        try {
          await AndroidAlarmManager.cancel(weeklyAlarmId);
        } catch (e) {
          Logger.warn('기존 월간 알람 취소 실패: $e, 계속 진행합니다.');
        }

        // 알람 설정
        bool success;
        try {
          success = await AndroidAlarmManager.oneShotAt(
            targetDate,
            weeklyAlarmId,
            alarmCallback, // main.dart에 정의된 최상위 콜백 함수 사용
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
            allowWhileIdle: true,
          );
        } catch (e) {
          Logger.error('매월 알람 예약 오류: $e');
          return false;
        }

        if (success) {
          Logger.debug('매월 알람 예약됨: ${targetDate.toString()}, 날짜: $monthlyDate');
          // 다음 알림 시간 저장
          await prefs.setString(
              'next_alarm_time', targetDate.toIso8601String());

          // 선택된 월간 날짜 저장 (나중에 알람 재예약할 때 필요)
          await prefs.setInt('monthly_notification_date', monthlyDate);

          return true;
        } else {
          Logger.error('매월 알람 예약 실패');
          return false;
        }
      } else {
        // 비정상적인 상태 - 기본값으로 매일 알림 설정 (로그 개선)
        Logger.warn(
            '지원되지 않는 알림 빈도: $frequency, 주간/월간 알림 매개변수: weekdays=$weekdays, monthlyDate=$monthlyDate');
        Logger.warn('매일 알림으로 대체합니다.');
        return await _scheduleAndroidAlarm(
            frequencyDaily, notificationTime, title, body, null, null);
      }
    } catch (e) {
      Logger.error('Android 알람 예약 오류: $e');
      return false;
    }
  }

  // iOS용 알림 스케줄링 메서드 (수정됨)
  Future<bool> _scheduleIOSNotification(
      String frequency,
      TimeOfDay notificationTime,
      String title,
      String body,
      List<int>? weekdays,
      int? monthlyDate) async {
    try {
      // 알림 세부 정보 생성
      final NotificationDetails notificationDetails = NotificationDetails(
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final now = DateTime.now();

      try {
        if (frequency == frequencyDaily) {
          // 매일 알림
          DateTime scheduledDate = DateTime(
            now.year,
            now.month,
            now.day,
            notificationTime.hour,
            notificationTime.minute,
          );

          // 현재 시간보다 이전이면 다음 날로 설정
          if (scheduledDate.isBefore(now)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          await flutterLocalNotificationsPlugin.zonedSchedule(
            dailyNotificationId,
            title,
            body,
            tz.TZDateTime.from(scheduledDate, tz.local),
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          Logger.debug('매일 알림 예약됨: ${scheduledDate.toString()}');
          return true;
        } else if (frequency == frequencyWeekly &&
            weekdays != null &&
            weekdays.isNotEmpty) {
          // 매주 알림 (선택된 요일에)
          bool anyScheduled = false;

          // 각 선택된 요일마다 알림 예약
          for (int weekday in weekdays) {
            // 현재 요일부터 선택된 요일까지의 일수 계산
            int daysUntil = (weekday - now.weekday);
            if (daysUntil < 0) daysUntil += 7; // 이번 주가 지난 경우 다음 주로

            // 같은 날이라면 이미 시간이 지났는지 확인
            if (daysUntil == 0) {
              final todayTime = DateTime(now.year, now.month, now.day,
                  notificationTime.hour, notificationTime.minute);
              if (todayTime.isBefore(now)) {
                daysUntil = 7; // 이미 오늘의 알람 시간이 지났으면 다음 주로
              }
            }

            DateTime scheduledDate = DateTime(
              now.year,
              now.month,
              now.day,
              notificationTime.hour,
              notificationTime.minute,
            ).add(Duration(days: daysUntil));

            await flutterLocalNotificationsPlugin.zonedSchedule(
              weeklyNotificationId + weekday, // 요일별로 고유 ID 부여
              title,
              body,
              tz.TZDateTime.from(scheduledDate, tz.local),
              notificationDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
            Logger.debug(
                '요일별 알림 예약됨: ${scheduledDate.toString()} (요일: $weekday)');
            anyScheduled = true;
          }

          return anyScheduled;
        } else if (frequency == frequencyMonthly && monthlyDate != null) {
          // 매월 알림 (선택된 날짜에)

          // 이번 달 또는 다음 달에 예약
          DateTime targetDate;

          // 이번 달에 아직 선택 날짜가 오지 않았으면 이번 달로 설정
          if (now.day < monthlyDate) {
            final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
            final actualDate =
                monthlyDate > daysInMonth ? daysInMonth : monthlyDate;

            targetDate = DateTime(
              now.year,
              now.month,
              actualDate,
              notificationTime.hour,
              notificationTime.minute,
            );
          }
          // 이미 이번 달의 선택 날짜가 지났거나 오늘인데 시간이 지난 경우 다음 달로
          else {
            // 오늘이 선택된 날짜인 경우, 시간 비교
            if (now.day == monthlyDate) {
              final todayAlarm = DateTime(now.year, now.month, now.day,
                  notificationTime.hour, notificationTime.minute);

              // 아직 오늘의 알람 시간이 지나지 않았으면 오늘 설정
              if (todayAlarm.isAfter(now)) {
                targetDate = todayAlarm;
              }
              // 이미 지났으면 다음 달로
              else {
                final nextMonth = now.month == 12 ? 1 : now.month + 1;
                final nextYear = now.month == 12 ? now.year + 1 : now.year;
                final daysInNextMonth =
                    DateTime(nextYear, nextMonth + 1, 0).day;
                final actualDate = monthlyDate > daysInNextMonth
                    ? daysInNextMonth
                    : monthlyDate;

                targetDate = DateTime(
                  nextYear,
                  nextMonth,
                  actualDate,
                  notificationTime.hour,
                  notificationTime.minute,
                );
              }
            }
            // 오늘이 선택된 날짜보다 이후인 경우 (다음 달)
            else {
              final nextMonth = now.month == 12 ? 1 : now.month + 1;
              final nextYear = now.month == 12 ? now.year + 1 : now.year;
              final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
              final actualDate =
                  monthlyDate > daysInNextMonth ? daysInNextMonth : monthlyDate;

              targetDate = DateTime(
                nextYear,
                nextMonth,
                actualDate,
                notificationTime.hour,
                notificationTime.minute,
              );
            }
          }

          await flutterLocalNotificationsPlugin.zonedSchedule(
            weeklyNotificationId, // 월간 알림도 weekly ID 사용
            title,
            body,
            tz.TZDateTime.from(targetDate, tz.local),
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          );
          Logger.debug(
              '매월 알림 예약됨: ${targetDate.toString()} (날짜: $monthlyDate)');
          return true;
        } else {
          // 비정상적인 상태 - 기본값으로 매일 알림 설정
          Logger.warn(
              '지원되지 않는 알림 빈도: $frequency 또는 필요한 매개변수 누락. 매일 알림으로 대체합니다.');
          return await _scheduleIOSNotification(
              frequencyDaily, notificationTime, title, body, null, null);
        }
      } catch (e) {
        Logger.error(
            'iOS 알림 스케줄링 오류: $e - $frequency, $weekdays, $monthlyDate');
        return false;
      }
    } catch (e) {
      Logger.error('iOS 알림 예약 오류: $e');
      return false;
    }
  }

  // 다음 알람 시간 계산
  DateTime _getAlarmTime(TimeOfDay time, {bool isWeekly = false}) {
    DateTime now = DateTime.now();
    DateTime alarmTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // 현재 시간보다 이전이면 다음 날로 설정
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }

    // 주간 알람인 경우 다음 일요일로 설정
    if (isWeekly) {
      while (alarmTime.weekday != DateTime.sunday) {
        alarmTime = alarmTime.add(const Duration(days: 1));
      }
    }

    return alarmTime;
  }

  // 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    try {
      // Flutter Local Notifications 취소
      await flutterLocalNotificationsPlugin.cancelAll();

      // Android Alarm Manager 취소 (Android 전용)
      if (Platform.isAndroid) {
        try {
          await AndroidAlarmManager.cancel(dailyAlarmId);
          await AndroidAlarmManager.cancel(weeklyAlarmId);
        } catch (e) {
          Logger.warn('Android 알람 취소 실패: $e');
          // 취소 실패해도 계속 진행
        }
      }

      Logger.debug('모든 알림이 취소됨');

      // 예약된 알림 목록 업데이트
      await _loadPendingNotifications();
      _updateStatus(pendingNotifications: _pendingNotifications);
    } catch (e) {
      Logger.error('알림 취소 오류: $e');
    }
  }

  // 특정 ID의 알림 취소
  Future<void> cancelNotification(int id) async {
    try {
      // Flutter Local Notifications 취소
      await flutterLocalNotificationsPlugin.cancel(id);

      // Android Alarm Manager 취소 (Android 전용)
      if (Platform.isAndroid && (id == dailyAlarmId || id == weeklyAlarmId)) {
        try {
          await AndroidAlarmManager.cancel(id);
        } catch (e) {
          Logger.warn('Android 알람 취소 실패: $e');
          // 취소 실패해도 계속 진행
        }
      }

      Logger.debug('알림 ID $id 취소됨');

      // 예약된 알림 목록 업데이트
      await _loadPendingNotifications();
      _updateStatus(pendingNotifications: _pendingNotifications);
    } catch (e) {
      Logger.error('알림 취소 오류: $e');
    }
  }

  // 현재 사용자 로케일 가져오기
  Future<String> _getCurrentLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('app_locale') ?? 'ko';
    } catch (e) {
      Logger.error('로케일 가져오기 오류: $e');
      return 'ko'; // 기본값으로 한국어 반환
    }
  }

  // 즉시 알림 전송 - 오늘의 주제가 있으면 포함하도록 수정
  Future<bool> showInstantNotification({
    required String title,
    required String body,
    String? payload,
    bool includeTopicIfAvailable = true,
  }) async {
    if (!_initialized) {
      Logger.warn('알림 서비스가 초기화되지 않았습니다.');
      return false;
    }

    if (!_permissionsGranted) {
      Logger.warn('알림 권한이 없습니다.');
      // 권한이 없어도 설정은 저장하고 계속 진행
    }

    try {
      // 오늘의 주제를 포함하려는 경우
      if (includeTopicIfAvailable) {
        final prefs = await SharedPreferences.getInstance();
        final savedTopic = prefs.getString('today_topic');

        // 저장된 주제가 없는 경우 현재 시점에서 주제 가져오기 시도
        if (savedTopic == null || savedTopic.isEmpty) {
          try {
            final currentLocale = await _getCurrentLocale();
            final topicService = TopicService();
            final topicData = await topicService.loadDailyTopic(currentLocale);

            if (topicData.containsKey('content') &&
                topicData['content'] != null) {
              final newTopic = topicData['content']!;
              // 본문에 주제 추가
              if (newTopic.isNotEmpty) {
                body += '\n주제: $newTopic';
                // 추후 사용을 위해 저장
                await prefs.setString('today_topic', newTopic);
              }
            }
          } catch (e) {
            Logger.debug('즉시 알림을 위한 주제 가져오기 실패: $e');
          }
        } else {
          // 이미 저장된 주제가 있으면 사용
          body += '\n주제: $savedTopic';
        }
      }

      final NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          fullScreenIntent: true, // 잠금 화면에서도 알림 표시
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final id = DateTime.now().millisecond; // 고유한 ID 생성
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      Logger.debug('즉시 알림 전송됨: $title, $body');
      return true;
    } catch (e) {
      Logger.error('즉시 알림 전송 오류: $e');
      return false;
    }
  }

  // 알림 응답 처리 향상
  void onDidReceiveNotificationResponse(NotificationResponse response) async {
    Logger.debug(
        'onDidReceiveNotificationResponse: id=${response.id}, payload=${response.payload}');

    try {
      // 앱이 이미 실행 중일 때도 RelaxMainScreen으로 이동하도록 처리
      final prefs = await SharedPreferences.getInstance();

      // 알림 클릭 정보 저장 - 더 명확한 플래그 사용
      await prefs.setBool('force_navigate_to_relax', true); // 이름 변경으로 의도 명확화
      await prefs.setBool('launched_from_notification', true);

      // 페이로드에서 주제 추출 (있는 경우)
      final payload = response.payload;
      if (payload != null && payload.startsWith('topic:')) {
        final topic = payload.substring(6); // 'topic:' 이후 부분
        if (topic.isNotEmpty) {
          await prefs.setString('today_topic', topic);
          await prefs.setBool('topic_from_notification', true);
          Logger.debug('알림 클릭에서 주제 추출: $topic');
        }
      }

      // RelaxMainScreen으로 이동하기 위한 설정
      await prefs.setInt('initial_tab_index', 1); // RelaxMainScreen 탭 인덱스

      // 이벤트 발생 - 앱에서 감지할 수 있도록
      try {
        eventBus.fire(EventBus.notificationClicked, NotificationClickedEvent());
      } catch (e) {
        Logger.warn('이벤트 발생 오류: $e');
      }

      Logger.info('알림 클릭 처리됨 - RelaxMainScreen으로 이동 예정');
    } catch (e) {
      Logger.error('알림 응답 처리 오류: $e');
    }
  }

  // 상태 업데이트 메서드
  void _updateStatus({
    bool? isInitialized,
    bool? permissionsGranted,
    List<PendingNotificationRequest>? pendingNotifications,
    bool? hasError,
    String? errorMessage,
    Map<String, dynamic>? lastReceivedNotification,
  }) {
    final currentStatus = _statusController.valueOrNull ?? NotificationStatus();

    final updatedStatus = NotificationStatus(
      isInitialized: isInitialized ?? currentStatus.isInitialized,
      permissionsGranted:
          permissionsGranted ?? currentStatus.permissionsGranted,
      pendingNotifications:
          pendingNotifications ?? currentStatus.pendingNotifications,
      hasError: hasError ?? currentStatus.hasError,
      errorMessage: errorMessage ?? currentStatus.errorMessage,
      lastReceivedNotification:
          lastReceivedNotification ?? currentStatus.lastReceivedNotification,
      updatedAt: DateTime.now(),
    );

    _statusController.add(updatedStatus);
  }

  // FireStore에 알림 토큰 저장
  Future<void> saveNotificationToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('notifications')
            .set({
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
        }, SetOptions(merge: true));
        Logger.debug('알림 토큰 저장됨: $token');
      }
    } catch (e) {
      Logger.error('알림 토큰 저장 오류: $e');
    }
  }

  // 텍스트 미리 알림 전송 (기록 알림) - 오늘의 주제 포함하도록 수정
  Future<bool> sendDailyReminderNotification(BuildContext context) async {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    final title = isKorean ? 'Breaktime' : 'Breaktime';

    // SharedPreferences에서 오늘의 주제 가져오기
    final prefs = await SharedPreferences.getInstance();
    final savedTopic = prefs.getString('today_topic');

    String body;
    if (savedTopic != null && savedTopic.isNotEmpty) {
      body = isKorean ? '오늘의 주제: $savedTopic' : 'Today\'s topic: $savedTopic';
    } else {
      body =
          isKorean ? '오늘의 생각을 기록해보세요.' : 'Write down your thoughts for today.';
    }

    return showInstantNotification(
      title: title,
      body: body,
      // 이미 주제를 포함했으므로 다시 포함하지 않음
      includeTopicIfAvailable: false,
    );
  }

  // 자원 해제
  void dispose() {
    _statusController.close();
  }
}

/// 알림 상태 클래스
class NotificationStatus {
  final bool isInitialized;
  final bool permissionsGranted;
  final List<PendingNotificationRequest> pendingNotifications;
  final bool hasError;
  final String? errorMessage;
  final Map<String, dynamic>? lastReceivedNotification;
  final DateTime updatedAt;

  NotificationStatus({
    this.isInitialized = false,
    this.permissionsGranted = false,
    this.pendingNotifications = const [],
    this.hasError = false,
    this.errorMessage,
    this.lastReceivedNotification,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}
