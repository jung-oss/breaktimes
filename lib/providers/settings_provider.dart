import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import '../utils/logger.dart';

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
}

class SettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // 알림 설정
  bool _notificationsEnabled = false;
  NotificationFrequency _frequency = NotificationFrequency.daily;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _selectedWeekdays = [7]; // 기본값은 일요일
  int _monthlyDate = 1; // 기본값은 매월 1일

  // 테마 설정
  bool _isDarkMode = false;

  // 언어 설정
  String _language = 'ko';

  // 번역 기능 설정
  bool _translationEnabled = true; // 기본값은 활성화

  // 알림 서비스 인스턴스
  final NotificationService _notificationService = NotificationService();

  // Getters
  bool get isLoading => _isLoading;
  bool get notificationsEnabled => _notificationsEnabled;
  NotificationFrequency get frequency => _frequency;
  TimeOfDay get notificationTime => _notificationTime;
  List<int> get selectedWeekdays => _selectedWeekdays;
  int get monthlyDate => _monthlyDate;
  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get translationEnabled => _translationEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // 알림 활성화 상태 로드
      _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? false;
      debugPrint('알림 활성화 상태 로드: $_notificationsEnabled');

      // 알림 빈도 로드
      final frequencyString =
          _prefs.getString('notification_frequency') ?? 'daily';
      switch (frequencyString) {
        case 'daily':
          _frequency = NotificationFrequency.daily;
          break;
        case 'weekly':
          _frequency = NotificationFrequency.weekly;
          break;
        case 'monthly':
          _frequency = NotificationFrequency.monthly;
          break;
        default:
          _frequency = NotificationFrequency.daily;
      }

      // 이전 방식(index 저장)과의 호환성 유지
      final frequencyIndex = _prefs.getInt('notification_frequency_index');
      if (frequencyIndex != null &&
          frequencyIndex >= 0 &&
          frequencyIndex < NotificationFrequency.values.length) {
        _frequency = NotificationFrequency.values[frequencyIndex];
      }

      debugPrint('알림 빈도 로드: $_frequency (string: $frequencyString)');

      // 알림 시간 로드 - NotificationService와 완전히 동일한 방식 사용
      final timeInMinutes = _prefs.getInt('notification_time');
      if (timeInMinutes != null) {
        _notificationTime = TimeOfDay(
          hour: timeInMinutes ~/ 60,
          minute: timeInMinutes % 60,
        );
        debugPrint(
            '알림 시간 로드 (minutes 방식): ${_notificationTime.hour}:${_notificationTime.minute} ($timeInMinutes분)');

        // 이전 방식과의 호환성을 위해 hour/minute도 저장
        await _prefs.setInt('notification_hour', _notificationTime.hour);
        await _prefs.setInt('notification_minute', _notificationTime.minute);
      } else {
        // 기존 방식으로 시도
        final hour = _prefs.getInt('notification_hour') ?? 9;
        final minute = _prefs.getInt('notification_minute') ?? 0;
        _notificationTime = TimeOfDay(hour: hour, minute: minute);
        debugPrint('알림 시간 로드 (hour/minute 방식): $hour:$minute');

        // NotificationService와 호환되는 방식으로 저장
        final minutes = hour * 60 + minute;
        await _prefs.setInt('notification_time', minutes);
        debugPrint('알림 시간을 minutes 방식으로 동기화: $minutes분');
      }

      // 주간 알림 요일 로드
      final List<String>? weekdayStrings =
          _prefs.getStringList('selected_weekdays');
      if (weekdayStrings != null && weekdayStrings.isNotEmpty) {
        try {
          _selectedWeekdays = weekdayStrings.map((s) => int.parse(s)).toList();
          debugPrint('선택된 요일 로드: $_selectedWeekdays');
        } catch (e) {
          debugPrint('요일 파싱 오류: $e, 기본값 사용');
          _selectedWeekdays = [7]; // 기본값 일요일
        }
      }

      // 월간 알림 날짜 로드
      _monthlyDate = _prefs.getInt('monthly_notification_date') ?? 1;
      // 날짜 범위 확인
      if (_monthlyDate < 1) _monthlyDate = 1;
      if (_monthlyDate > 31) _monthlyDate = 31;
      debugPrint('월간 알림 날짜 로드: $_monthlyDate');

      // 테마 설정 로드
      _isDarkMode = _prefs.getBool('dark_mode') ?? false;

      // 언어 설정 로드
      _language = _prefs.getString('language') ?? 'ko';

      // 번역 기능 설정 로드
      _translationEnabled = _prefs.getBool('translation_enabled') ?? true;

      _isLoading = false;
      notifyListeners();

      debugPrint(
          '설정 로드 완료: 알림=${_notificationsEnabled}, 빈도=${_frequency}, 시간=${_notificationTime.hour}:${_notificationTime.minute}');
      debugPrint('주간 요일: $_selectedWeekdays, 월간 날짜: $_monthlyDate');

      // 알림 서비스 초기화 및 설정 적용 (이미 저장된 설정 확인)
      await _notificationService.init();

      // 알림이 활성화되어 있으면 알림 설정 적용
      if (_notificationsEnabled) {
        await _updateNotificationSettings();
      }
    } catch (e) {
      // 로그 남기기
      debugPrint('설정 로드 오류: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _prefs.setBool('notifications_enabled', value);
    debugPrint('알림 활성화 상태 설정: $value');

    // 알림 설정 업데이트
    await _updateNotificationSettings();

    notifyListeners();
  }

  Future<void> setNotificationFrequency(NotificationFrequency value) async {
    debugPrint('알림 빈도 설정: $value');
    _frequency = value;

    try {
      // 열거형 인덱스 저장 (하위 호환성)
      await _prefs.setInt('notification_frequency_index', value.index);

      // 문자열로 저장 (NotificationService와 일관성)
      String frequencyString;
      switch (value) {
        case NotificationFrequency.daily:
          frequencyString = NotificationService.frequencyDaily;
          break;
        case NotificationFrequency.weekly:
          frequencyString = NotificationService.frequencyWeekly;
          break;
        case NotificationFrequency.monthly:
          frequencyString = 'monthly'; // NotificationService의 상수가 없는 경우
          break;
      }
      await _prefs.setString('notification_frequency', frequencyString);
      debugPrint('알림 빈도 저장 완료: $frequencyString');

      // 빈도별 기본값 설정
      if (value == NotificationFrequency.weekly && _selectedWeekdays.isEmpty) {
        // 주간인데 선택된 요일이 없으면 일요일로 기본 설정
        await setSelectedWeekdays([7]); // DateTime.sunday
      }

      // 알림 설정이 활성화된 경우만 업데이트
      if (_notificationsEnabled) {
        await _updateNotificationSettings();
      }
    } catch (e) {
      debugPrint('알림 빈도 설정 저장 오류: $e');
    }

    notifyListeners();
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    debugPrint('알림 시간 설정: ${time.hour}:${time.minute}');
    _notificationTime = time;
    // 개별 시/분 저장 방식 유지
    await _prefs.setInt('notification_hour', time.hour);
    await _prefs.setInt('notification_minute', time.minute);

    // NotificationService와 일관성을 위해 minutes 방식으로 저장
    final minutes = time.hour * 60 + time.minute;
    await _prefs.setInt('notification_time', minutes);
    debugPrint('알림 시간 저장 (minutes 방식): $minutes분');

    // 하위 호환성을 위해 별도 hour/minute 방식도 저장
    await _prefs.setInt('notification_hour', time.hour);
    await _prefs.setInt('notification_minute', time.minute);
    debugPrint('알림 시간 저장 (hour/minute 방식): ${time.hour}:${time.minute}');

    // 알림 설정이 활성화된 경우만 업데이트
    if (_notificationsEnabled) {
      await _updateNotificationSettings();
    }

    notifyListeners();
  }

  // 선택된 요일 설정 메서드
  Future<void> setSelectedWeekdays(List<int> weekdays) async {
    // 최소한 하나의 요일 선택 보장
    if (weekdays.isEmpty) {
      weekdays = [7]; // 기본값 일요일 (DateTime.sunday)
    }

    debugPrint('선택된 요일 설정: $weekdays');
    _selectedWeekdays = weekdays;

    try {
      // 요일 목록을 문자열 목록으로 변환하여 저장
      await _prefs.setStringList(
          'selected_weekdays', weekdays.map((day) => day.toString()).toList());

      // 알림 설정이 활성화되고 빈도가 주간인 경우에만 업데이트
      if (_notificationsEnabled && _frequency == NotificationFrequency.weekly) {
        await _updateNotificationSettings();
      }
    } catch (e) {
      debugPrint('요일 설정 저장 오류: $e');
    }

    notifyListeners();
  }

  // 월간 알림 날짜 설정 메서드
  Future<void> setMonthlyDate(int date) async {
    // 날짜 범위 확인 (1-31)
    if (date < 1) date = 1;
    if (date > 31) date = 31;

    debugPrint('월간 알림 날짜 설정: $date');
    _monthlyDate = date;

    try {
      await _prefs.setInt('monthly_notification_date', date);

      // 알림 설정이 활성화되고 빈도가 월간인 경우에만 업데이트
      if (_notificationsEnabled &&
          _frequency == NotificationFrequency.monthly) {
        await _updateNotificationSettings();
      }
    } catch (e) {
      debugPrint('월간 날짜 설정 저장 오류: $e');
    }

    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    await _prefs.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs.setString('language', value);
    notifyListeners();
  }

  // 번역 기능 활성화 설정
  Future<void> setTranslationEnabled(bool value) async {
    _translationEnabled = value;
    await _prefs.setBool('translation_enabled', value);
    notifyListeners();
  }

  // 알림 설정 업데이트
  Future<void> _updateNotificationSettings() async {
    try {
      if (_notificationsEnabled) {
        // 알림 빈도 변환 (NotificationFrequency -> NotificationService 상수)
        String notificationFrequency;
        switch (_frequency) {
          case NotificationFrequency.daily:
            notificationFrequency = NotificationService.frequencyDaily;
            break;
          case NotificationFrequency.weekly:
            notificationFrequency = NotificationService.frequencyWeekly;
            break;
          case NotificationFrequency.monthly:
            notificationFrequency =
                'monthly'; // NotificationService의 적절한 상수가 아직 없다면 문자열 직접 사용
            break;
        }

        // 알림 설정 저장 - weekdays 및 monthlyDate 매개변수 포함
        final success = await _notificationService.saveNotificationSettings(
          enabled: _notificationsEnabled,
          frequency: notificationFrequency,
          time: _notificationTime,
          weekdays: _frequency == NotificationFrequency.weekly
              ? _selectedWeekdays
              : null,
          monthlyDate:
              _frequency == NotificationFrequency.monthly ? _monthlyDate : null,
        );

        if (!success) {
          debugPrint('알림 설정 저장 실패');
        } else {
          debugPrint(
              '알림 설정 성공적으로 저장됨: $_frequency / $_selectedWeekdays / $_monthlyDate');

          // 설정이 성공적으로 저장된 후 현재 시간 설정을 다시 확인
          final prefs = await SharedPreferences.getInstance();
          final savedMinutes = prefs.getInt('notification_time');
          debugPrint('설정 후 저장된 알림 시간(분): $savedMinutes');

          if (savedMinutes != null) {
            final savedHour = savedMinutes ~/ 60;
            final savedMinute = savedMinutes % 60;
            debugPrint('저장된 알림 시간: $savedHour:$savedMinute');
          }
        }
      } else {
        // 알림 비활성화
        await _notificationService.cancelAllNotifications();
        debugPrint('알림 비활성화로 인해 모든 알림이 취소되었습니다.');
      }
    } catch (e) {
      debugPrint('알림 설정 업데이트 오류: $e');
    }
  }

  // 사용자별 설정 동기화
  Future<void> syncWithUserSettings(UserModel? user) async {
    if (user?.settings != null) {
      final settings = user!.settings!;

      if (settings['notificationsEnabled'] != null) {
        await setNotificationsEnabled(settings['notificationsEnabled'] as bool);
      }

      if (settings['notificationFrequency'] != null) {
        final frequencyIndex = settings['notificationFrequency'] as int;
        if (frequencyIndex >= 0 &&
            frequencyIndex < NotificationFrequency.values.length) {
          final frequency = NotificationFrequency.values[frequencyIndex];
          await setNotificationFrequency(frequency);
        }
      }

      if (settings['selectedWeekdays'] != null) {
        final weekdays = (settings['selectedWeekdays'] as List<dynamic>)
            .map((day) => day as int)
            .toList();
        if (weekdays.isNotEmpty) {
          await setSelectedWeekdays(weekdays);
        }
      }

      if (settings['monthlyDate'] != null) {
        final date = settings['monthlyDate'] as int;
        if (date >= 1 && date <= 31) {
          await setMonthlyDate(date);
        }
      }

      if (settings['darkMode'] != null) {
        await setDarkMode(settings['darkMode'] as bool);
      }

      if (settings['language'] != null) {
        await setLanguage(settings['language'] as String);
      }

      if (settings['translationEnabled'] != null) {
        await setTranslationEnabled(settings['translationEnabled'] as bool);
      }
    }
  }

  // 테스트 알림 보내기
  Future<void> sendTestNotification(BuildContext context) async {
    await _notificationService.sendDailyReminderNotification(context);
  }

  // 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    await _notificationService.cancelAllNotifications();
  }

  // 현재 설정 상태를 디버그 출력하는 메서드
  void logCurrentSettings() {
    debugPrint('==== 현재 알림 설정 상태 ====');
    debugPrint('알림 활성화: $_notificationsEnabled');
    debugPrint('알림 빈도: $_frequency');
    debugPrint('알림 시간: ${_notificationTime.hour}:${_notificationTime.minute}');
    debugPrint('선택된 요일: $_selectedWeekdays');
    debugPrint('월간 날짜: $_monthlyDate');
    debugPrint('==========================');
  }
}
