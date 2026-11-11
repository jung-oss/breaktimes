import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/locale_provider.dart';
import 'core/localization/app_localizations.dart';
import 'services/notification_service.dart';
import 'services/environment_service.dart';
import 'services/remote_config_setup_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as local;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'providers/relax_provider.dart';
import 'providers/todo_provider.dart';
import 'routes/app_router.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'utils/logger.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/settings_provider.dart';
import 'services/topic_service.dart';
import 'providers/music_provider.dart';
import 'providers/like_provider.dart';
import 'providers/bookmark_provider.dart';
import 'utils/notification_content_manager.dart';
import 'dart:io' show Platform;

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

// 최상위 콜백 함수 - 반드시 main.dart에 정의해야 함
@pragma('vm:entry-point')
void alarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 로깅을 위한 메시지 출력
  print('알람 콜백이 실행되었습니다: ${DateTime.now()}');

  try {
    // Firebase 초기화 - 알람 콜백에서 필요
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('알람 콜백에서 Firebase 초기화 성공');
    } catch (e) {
      print('Firebase 초기화 오류: $e');
      // Firebase 초기화가 실패해도 계속 진행 (SharedPreferences는 사용 가능)
    }

    // 모든 기존 알림 취소 (중요!)
    final local.FlutterLocalNotificationsPlugin
        flutterLocalNotificationsPlugin =
        local.FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.cancelAll();

    // 현재 언어 설정 가져오기
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString('app_locale') ?? 'ko';

    // 휴식 메시지 사용으로 변경
    String relaxMessage = '';
    String messageId = '';

    // 메시지 인덱스 가져오기 (순차적으로 메시지 사용)
    final messageIndex = await NotificationContentManager.getNextMessageIndex();
    relaxMessage = NotificationContentManager.getMessageByIndex(
      locale,
      messageIndex,
    );
    messageId = 'relaxation_message_$messageIndex';

    // 오늘의 주제로 설정 (기존 기능과의 호환성 유지)
    await prefs.setString('today_topic', relaxMessage);
    await prefs.setString('today_topic_id', messageId);

    // 알림 내용
    final String title = locale.startsWith('ko') ? 'Breaktime' : 'Breaktime';
    final String body = relaxMessage;

    // 알림 초기화 설정
    const local.AndroidInitializationSettings initializationSettingsAndroid =
        local.AndroidInitializationSettings('@mipmap/launcher_icon');

    const local.InitializationSettings initializationSettings =
        local.InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (local.NotificationResponse response) {
        // 알림 클릭 처리 - RelaxMainScreen으로 이동 설정
        SharedPreferences.getInstance().then((prefs) {
          // RelaxMainScreen으로 바로 이동하기 위한 플래그 설정
          prefs.setBool('launched_from_notification', true);
          prefs.setBool('open_relax_screen', true);
          prefs.setInt('initial_tab_index', 1); // RelaxMainScreen은 index 1

          // 주제 정보 저장
          prefs.setString('today_topic', relaxMessage);
          prefs.setString('today_topic_id', messageId);
          prefs.setBool('topic_from_notification', true);

          print('알림 클릭 처리 설정 완료: $relaxMessage');
        });
      },
    );

    // Android 설정
    const local.AndroidNotificationDetails androidPlatformChannelSpecifics =
        local.AndroidNotificationDetails(
      NotificationService.channelId,
      NotificationService.channelName,
      channelDescription: NotificationService.channelDescription,
      importance: local.Importance.max,
      priority: local.Priority.high,
      fullScreenIntent: true,
      visibility: local.NotificationVisibility.public,
    );

    // 알림 세부 정보
    const local.NotificationDetails platformChannelSpecifics =
        local.NotificationDetails(android: androidPlatformChannelSpecifics);

    // 알림 표시
    final alarmId = NotificationService.dailyAlarmId;
    final payload = 'topic:$relaxMessage';
    await flutterLocalNotificationsPlugin.show(
      alarmId,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );

    print('알림이 성공적으로 표시되었습니다! 제목: $title, 내용: $body');

    // 마지막 알림 날짜 저장
    await prefs.setString(
      NotificationService.keyLastNotificationDate,
      DateTime.now().toIso8601String(),
    );

    // 다음 알람 예약 (자동 재예약)
    await _scheduleNextAlarm();
  } catch (e, stackTrace) {
    print('알람 콜백 오류: $e');
    print('스택 트레이스: $stackTrace');
  }
}

// 다음 알람 자동 예약 함수
@pragma('vm:entry-point')
Future<void> _scheduleNextAlarm() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // 알림 설정 확인
    final notificationEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!notificationEnabled) {
      print('알림이 비활성화되어 있어 다음 알람을 예약하지 않습니다.');
      return;
    }

    // 알림 설정 불러오기
    final frequency = prefs.getString('notification_frequency') ?? 'daily';
    final notificationTimeMinutes =
        prefs.getInt('notification_time') ?? (20 * 60); // 기본값 20:00

    final hour = notificationTimeMinutes ~/ 60;
    final minute = notificationTimeMinutes % 60;

    // 다음 알람 시간 계산
    final now = DateTime.now();
    DateTime nextAlarmTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 이미 지난 시간이면 다음 날로 설정
    if (nextAlarmTime.isBefore(now)) {
      nextAlarmTime = nextAlarmTime.add(const Duration(days: 1));
    }

    // 주간 알림이면 선택된 요일 확인
    if (frequency == 'weekly') {
      // 선택된 요일 가져오기
      final List<String>? weekdayStrings = prefs.getStringList(
        'selected_weekdays',
      );
      final List<int> weekdays = [];

      if (weekdayStrings != null && weekdayStrings.isNotEmpty) {
        weekdays.addAll(weekdayStrings.map((s) => int.parse(s)).toList());
      } else {
        // 기본값 일요일
        weekdays.add(DateTime.sunday);
      }

      print('선택된 요일: $weekdays');

      // 가장 가까운 선택된 요일 찾기
      DateTime? nextSelectedDay;
      int minDays = 8; // 최대 7일보다 큰 값으로 초기화

      for (final weekday in weekdays) {
        // 현재 요일부터 선택된 요일까지의 일수 계산
        int daysUntil = (weekday - now.weekday);
        if (daysUntil <= 0) daysUntil += 7; // 이번 주가 지난 경우 다음 주로

        // 가장 빠른 날짜 선택
        if (daysUntil < minDays) {
          minDays = daysUntil;
          nextSelectedDay = now.add(Duration(days: daysUntil));
        }
      }

      if (nextSelectedDay != null) {
        nextAlarmTime = DateTime(
          nextSelectedDay.year,
          nextSelectedDay.month,
          nextSelectedDay.day,
          hour,
          minute,
        );
      }
    }
    // 월간 알림이면 선택된 날짜 확인
    else if (frequency == 'monthly') {
      // 선택된 날짜 가져오기 (기본값 1일)
      final monthlyDate = prefs.getInt('monthly_notification_date') ?? 1;
      print('선택된 월간 날짜: $monthlyDate');

      // 현재 날짜가 선택된 날짜보다 이전인 경우 (이번 달)
      if (now.day < monthlyDate) {
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final actualDate =
            monthlyDate > daysInMonth ? daysInMonth : monthlyDate;

        nextAlarmTime = DateTime(now.year, now.month, actualDate, hour, minute);
      }
      // 이미 이번 달의 선택된 날짜가 지난 경우 (다음 달)
      else {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final actualDate =
            monthlyDate > daysInNextMonth ? daysInNextMonth : monthlyDate;

        nextAlarmTime = DateTime(nextYear, nextMonth, actualDate, hour, minute);
      }
    }

    print('다음 알람 시간 계산됨: ${nextAlarmTime.toString()}, 빈도: $frequency');

    // 알람 예약
    bool success = await AndroidAlarmManager.oneShotAt(
      nextAlarmTime,
      NotificationService.dailyAlarmId,
      alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );

    if (success) {
      print('다음 알람이 성공적으로 예약되었습니다: ${nextAlarmTime.toString()}');

      // 다음 알람 시간 저장
      await prefs.setString('next_alarm_time', nextAlarmTime.toIso8601String());
    } else {
      print('다음 알람 예약 실패');
    }
  } catch (e) {
    print('다음 알람 예약 오류: $e');
  }
}

Future<void> main() async {
  try {
    // Flutter 바인딩 초기화
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

    // Android Alarm Manager 초기화
    await AndroidAlarmManager.initialize();

    // 통신 포트 초기화 추가
    FlutterForegroundTask.initCommunicationPort();

    // 기본적인 FlutterForegroundTask 초기화 (패키지 버전에 맞게 수정)
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_task_channel',
        channelName: 'Breaktime',
        channelDescription: '백그라운드 작업 알림',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWifiLock: false,
        allowWakeLock: true,
      ),
    );

    // Logger 초기화
    await Logger.initialize(saveToStorage: true);
    Logger.info('앱 시작: 초기화 작업 시작');

    // 🎨 Android 15 Edge-to-Edge 지원을 위한 시스템 UI 설정
    if (!kIsWeb && Platform.isAndroid) {
      Logger.debug('Android Edge-to-Edge 설정 적용');
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // Edge-to-Edge 모드 활성화
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    // Firebase 초기화 - 웹 플랫폼 명시적 처리
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      Logger.debug('Firebase 웹 초기화 완료');
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      Logger.debug('Firebase 모바일 초기화 완료');
    }

    // App Check 초기화 (개발 환경에서는 비활성화)
    if (!kDebugMode) {
      // 프로덕션 환경에서만 App Check 활성화
      try {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
        Logger.debug('Firebase App Check 초기화 완료 (프로덕션)');
      } catch (e) {
        Logger.warn('Firebase App Check 초기화 실패: $e');
        Logger.info('프로덕션 환경에서 App Check 오류를 무시하고 계속 진행합니다.');
      }
    } else {
      // 디버그 모드에서는 App Check 완전 비활성화
      Logger.debug('개발 환경에서는 App Check를 비활성화합니다.');
      Logger.info('개발 중에는 App Check 없이 Firebase 서비스를 사용합니다.');
    }

    // 환경 변수 서비스 초기화 (Firebase Remote Config + .env 파일)
    await EnvironmentService.instance.initialize();
    Logger.debug('환경 변수 서비스 초기화 완료');

    // Firebase Remote Config 설정 가이드 출력 (디버그 모드에서만)
    if (kDebugMode) {
      RemoteConfigSetupHelper.printSetupGuide();
    }

    // 알림 서비스 초기화
    final notificationService = NotificationService();
    final notificationInitialized = await notificationService.init();
    if (notificationInitialized) {
      Logger.debug('알림 서비스 초기화 완료');
    } else {
      Logger.warn('알림 서비스 초기화 실패 - 제한된 기능으로 계속 진행');
    }

    // 오늘의 주제 미리 로드 - 알림에서 바로 사용할 수 있도록
    try {
      final prefs = await SharedPreferences.getInstance();
      final locale = prefs.getString('app_locale') ?? 'ko';

      // TopicService를 사용하여 오늘의 주제 미리 로드
      final topicService = TopicService();
      final topicData = await topicService.loadDailyTopic(locale);

      if (topicData.containsKey('content') && topicData['content'] != null) {
        // 주제가 성공적으로 로드됨
        Logger.debug('앱 시작 시 오늘의 주제 미리 로드 완료: ${topicData['content']}');
      }
    } catch (e) {
      Logger.error('오늘의 주제 미리 로드 실패: $e');
    }

    // Kakao SDK 초기화
    KakaoSdk.init(nativeAppKey: Env.kakaoApiKey);
    Logger.debug('Kakao SDK 초기화 완료');

    // 백그라운드 서비스 초기화
    // 앱 시작 시 로케일 정보 출력
    final systemLocale = WidgetsBinding.instance.window.locale;
    Logger.info(
      '시스템 로케일: ${systemLocale.languageCode}-${systemLocale.countryCode}',
    );

    // 알림에서 앱이 시작되었는지 확인 바로 후에 추가하세요
    await _checkAppLaunchedByNotification();

    // 설정 동기화 함수 호출 추가
    await _setupNotificationsSync();

    // 앱 실행
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          // RelaxProvider를 ChangeNotifierProxyProvider로 변경하여 LocaleProvider와 연동
          ChangeNotifierProxyProvider<LocaleProvider, RelaxProvider>(
            create: (_) => RelaxProvider(),
            update: (context, localeProvider, previous) {
              // 기존 RelaxProvider가 있으면 재사용, 없으면 새로 생성
              final relaxProvider = previous ?? RelaxProvider();

              // LocaleProvider에서 주제 정보 업데이트
              relaxProvider.updateFromLocaleProvider(
                localeProvider.dailyTopic,
                localeProvider.topicId,
                localeProvider.locale.languageCode,
              );

              return relaxProvider;
            },
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => LikeProvider()),
          ChangeNotifierProvider(create: (_) => BookmarkProvider()),
          ChangeNotifierProvider(create: (_) => MusicProvider()),
          // Add TodoProvider with ProxyProvider since it depends on the user ID
          ProxyProvider0<TodoProvider>(
            update: (context, _) {
              // Get current user ID safely
              final uid = FirebaseAuth.instance.currentUser?.uid;
              // Only create provider if user is logged in
              if (uid != null) {
                return TodoProvider(userId: uid, context: context);
              }
              // Return a dummy provider if no user is logged in
              // This will be updated after login
              return TodoProvider(userId: 'guest', context: context);
            },
            // Dispose the provider properly when it's updated
            dispose: (_, provider) => provider.dispose(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    Logger.info('앱 실행 완료');
  } catch (e, stackTrace) {
    // 초기화 중 예외 발생 시 로깅
    Logger.error('앱 초기화 중 오류 발생: $e', stackTrace: stackTrace);

    // 에러가 발생해도 앱은 실행
    runApp(const ErrorApp());
  }
}

// 오류 발생 시 표시할 앱
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Error',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                '앱 초기화 중 오류가 발생했습니다.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('앱을 다시 시작하거나 개발자에게 문의하세요.'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // 앱 다시 시작 - 실제로는 시스템에 따라 다르게 구현 필요
                  main();
                },
                child: const Text('다시 시작'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 앱이 알림으로 실행되었는지 확인하는 함수
Future<void> _checkAppLaunchedByNotification() async {
  try {
    Logger.info('앱 실행 시 알림 실행 여부 확인 중...');

    // 앱이 알림으로 실행되었는지 확인
    final local.NotificationAppLaunchDetails? launchDetails =
        await NotificationService()
            .flutterLocalNotificationsPlugin
            .getNotificationAppLaunchDetails();

    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      Logger.info('앱이 알림에 의해 실행되었습니다.');

      // 공유 환경설정 인스턴스
      final prefs = await SharedPreferences.getInstance();

      // 알림에서 실행되었음을 표시하는 플래그 설정 - 앱 시작 시 확인용
      await prefs.setBool('launched_from_notification', true);
      // RelaxMainScreen으로 바로 이동하기 위한 플래그 설정
      await prefs.setBool('open_relax_screen', true);

      // 알림 페이로드 처리 (오늘의 주제가 포함될 수 있음)
      final String? payload = launchDetails.notificationResponse?.payload;
      if (payload != null) {
        Logger.debug('알림 페이로드: $payload');

        // 페이로드에서 주제 추출
        if (payload.startsWith('topic:')) {
          final topic = payload.substring(6); // 'topic:' 이후 부분이 주제
          if (topic.isNotEmpty) {
            // 주제를 저장하여 RelaxMainScreen에서 사용할 수 있도록 함
            await prefs.setString('today_topic', topic);

            // 주제가 있음을 표시하는 플래그 설정
            await prefs.setBool('topic_from_notification', true);

            Logger.info('알림에서 주제를 추출했습니다: $topic');
          }
        }
      }

      // RelaxMainScreen으로 이동하기 위한 설정
      await prefs.setInt('initial_tab_index', 1); // RelaxMainScreen은 index 1

      Logger.info('알림 클릭 시 RelaxMainScreen으로 이동하도록 설정되었습니다.');
    } else {
      Logger.debug('앱이 일반적인 방법으로 실행되었습니다.');
    }
  } catch (e) {
    Logger.error('알림 실행 확인 오류: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 앱 시작 시 알림 설정 확인 및 스케줄링
    _setupNotifications();

    // 알림으로 시작했을 때의 이동은 AppNavigation.handleNotificationRouting이
    // 'launched_from_notification'·'initial_tab_index' 키로 처리합니다.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 재개될 때 알림 스케줄링 확인
    if (state == AppLifecycleState.resumed) {
      Logger.debug('앱이 포그라운드로 돌아옴, 알림 설정 확인');
      _setupNotifications();
    } else if (state == AppLifecycleState.paused) {
      Logger.debug('앱이 백그라운드로 전환됨');
    }
  }

  // 알림 설정
  Future<void> _setupNotifications() async {
    try {
      // 알림 설정 로드
      final notificationService = NotificationService();
      final settings = await notificationService.loadNotificationSettings();

      if (settings['enabled']) {
        // 알림 권한 확인
        final hasPermission = await notificationService.checkPermissions();

        if (hasPermission) {
          // 예약된 알림이 있는지 확인
          final pendingNotifications = await notificationService
              .flutterLocalNotificationsPlugin
              .pendingNotificationRequests();

          if (pendingNotifications.isEmpty) {
            // 알림 스케줄링 (예약된 알림이 없는 경우에만)
            final scheduled = await notificationService.scheduleNotifications();
            if (scheduled) {
              Logger.info('알림이 성공적으로 예약되었습니다.');
            } else {
              Logger.warn('알림 예약 실패');
            }
          } else {
            Logger.debug('이미 ${pendingNotifications.length}개의 알림이 예약되어 있습니다.');
          }
        } else {
          Logger.warn('알림 권한이 없습니다. 설정에서 권한을 허용해주세요.');
        }
      } else {
        Logger.debug('알림이 비활성화되어 있습니다.');
      }
    } catch (e) {
      Logger.error('알림 설정 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp.router(
          title: 'Breaktime',
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: appRouter,
          // 여기서 언어 변경 감지 처리 추가
          builder: (context, child) {
            // 앱이 처음 빌드될 때 알림 라우팅 처리 시도
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                AppNavigation.handleNotificationRouting(context);

                // 언어 변경 감지를 위한 추가 처리
                _handleLocaleChange(context, localeProvider);
              }
            });
            return child!;
          },
        );
      },
    );
  }

  // 언어 변경 감지 및 처리
  String? _previousLocale;
  void _handleLocaleChange(
    BuildContext context,
    LocaleProvider localeProvider,
  ) {
    final currentLocale = localeProvider.locale.languageCode;

    // 이전 언어와 다른 경우 처리
    if (_previousLocale != null && _previousLocale != currentLocale) {
      Logger.info('MyApp: 언어 변경 감지됨 - $_previousLocale -> $currentLocale');
    }

    _previousLocale = currentLocale;
  }
}

// main.dart 파일에 다음 함수 추가
Future<void> _setupNotificationsSync() async {
  try {
    Logger.info('알림 설정 동기화 시작...');

    final prefs = await SharedPreferences.getInstance();

    // notification_time 키가 있는지 확인 (NotificationService 방식)
    final notificationTimeMinutes = prefs.getInt('notification_time');

    // notification_hour, notification_minute 키가 있는지 확인 (SettingsProvider 방식)
    final hasHour = prefs.containsKey('notification_hour');
    final hasMinute = prefs.containsKey('notification_minute');

    // 두 방식 간에 동기화 필요
    if (notificationTimeMinutes != null && (!hasHour || !hasMinute)) {
      // NotificationService에서 설정한 값을 SettingsProvider 방식으로 저장
      final hour = notificationTimeMinutes ~/ 60;
      final minute = notificationTimeMinutes % 60;

      await prefs.setInt('notification_hour', hour);
      await prefs.setInt('notification_minute', minute);

      Logger.info('알림 시간이 SettingsProvider 형식으로 동기화됨: $hour:$minute');
    } else if (hasHour && hasMinute && notificationTimeMinutes == null) {
      // SettingsProvider에서 설정한 값을 NotificationService 방식으로 저장
      final hour = prefs.getInt('notification_hour') ?? 9;
      final minute = prefs.getInt('notification_minute') ?? 0;
      final minutes = hour * 60 + minute;

      await prefs.setInt('notification_time', minutes);

      Logger.info(
        '알림 시간이 NotificationService 형식으로 동기화됨: $minutes분 ($hour:$minute)',
      );
    }

    Logger.info('알림 설정 동기화 완료');
  } catch (e) {
    Logger.error('알림 설정 동기화 오류: $e');
  }
}
