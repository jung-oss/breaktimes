// lib/core/localization/app_localizations.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/material.dart';

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  // Common UI strings
  String get appName;
  String get todayTasks;
  String get todayRest;
  String get settings;
  String get signIn;
  String get signUp;
  String get logout;
  String get welcome;
  String get email;
  String get password;
  String get confirmPassword;
  String get forgotPassword;
  String get createAccount;
  String get haveAccount;
  String get continue_with_google;
  String get continue_with_kakao;
  String get error;
  String get success;
  String get cancel;
  String get confirm;
  String get save;
  String get delete;
  String get edit;

  String get enterEmailForPasswordReset;
  String get invalidEmailFormat;
  String get passwordResetEmailSent;
  String get send;

  // Settings
  String get languageSettings;
  String get darkMode;
  String get lightMode;
  String get korean;
  String get english;
  String get notificationSettings;
  String get receiveNotifications;
  String get notificationFrequency;
  String get notificationTime;
  String get daily;
  String get weekly;
  String get monthly;
  String get Homepage;
  String get contact;

  // Todo section
  String get newMission;
  String get suggestedMission;
  String get enterNewMission;
  String get completionRate;
  String get totalTasks;
  String get completedTasks;
  String get averageCompletion;
  String get previousRecords;
  String get analysis;
  String get chart;

  // Relax section
  String get todayThought;
  String get recordThought;
  String get publicThoughts;
  String get privateThoughts;
  String get viewHistory;
  String get emotionAnalysis;
  String get emotionStatistics;
  String get publicEntry;
  String get privateEntry;
  String get noRecordsYet;
  String get writeToday;
  String get selectMood;
  String get todayTopic;
  String get likeCount;
  String get showMore;

  // Messages
  String get taskAdded;
  String get taskCompleted;
  String get taskDeleted;
  String get thoughtSaved;
  String get settingsSaved;
  String get loginRequired;
  String get networkError;
  String get likeAdded;
  String get likeRemoved;

  // Placeholders
  String taskCompletionMessage(int completed, int total);
  String thoughtsCount(int count);
  String lastUpdated(String date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic:
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
