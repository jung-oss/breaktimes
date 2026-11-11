// lib/core/localization/app_localizations_ko.dart
import 'app_localizations.dart';

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([super.locale = 'ko']);

  @override
  String get appName => 'Break time';

  @override
  String get todayTasks => '행복-미션';

  @override
  String get todayRest => '행복 함';

  @override
  String get settings => 'Break time 설정';

  @override
  String get signIn => '로그인';

  @override
  String get signUp => '회원가입';

  @override
  String get logout => '로그아웃';

  @override
  String get welcome => '환영합니다';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get confirmPassword => '비밀번호 확인';

  @override
  String get forgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get createAccount => '계정 만들기';

  @override
  String get haveAccount => '이미 계정이 있으신가요? 로그인';

  @override
  String get continue_with_google => 'Google로 계속하기';

  @override
  String get continue_with_kakao => '카카오로 계속하기';

  @override
  String get error => '오류';

  @override
  String get success => '성공';

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get edit => '수정';

  @override
  String get languageSettings => '언어 설정';

  @override
  String get darkMode => '다크 모드';

  @override
  String get lightMode => '라이트 모드';

  @override
  String get korean => '한국어';

  @override
  String get english => 'English';

  @override
  String get notificationSettings => '알림 설정';

  @override
  String get receiveNotifications => '알림 받기';

  @override
  String get notificationFrequency => '알림 주기';

  @override
  String get notificationTime => '알림 시간';

  @override
  String get daily => '매일';

  @override
  String get weekly => '매주';

  @override
  String get monthly => '매월';

  @override
  String get Homepage => '홈페이지';

  @override
  String get contact => '문의하기';

  @override
  String get newMission => '새로운 미션';

  @override
  String get suggestedMission => '추천 미션';

  @override
  String get enterNewMission => '새로운 미션을 입력하세요';

  @override
  String get completionRate => '달성률';

  @override
  String get totalTasks => '총 할일';

  @override
  String get completedTasks => '완료한 할일';

  @override
  String get averageCompletion => '평균 달성률';

  @override
  String get previousRecords => '이전 기록';

  @override
  String get analysis => '분석';

  @override
  String get chart => '차트';

  @override
  String get todayThought => '오늘의 생각';

  @override
  String get recordThought => '생각 기록하기';

  @override
  String get publicThoughts => '공개된 생각';

  @override
  String get privateThoughts => '비공개 생각';

  @override
  String get viewHistory => '기록 보기';

  @override
  String get emotionAnalysis => '감정 분석';

  @override
  String get emotionStatistics => '감정 통계';

  @override
  String get publicEntry => '공개';

  @override
  String get privateEntry => '비공개';

  @override
  String get noRecordsYet => '아직 기록이 없습니다';

  @override
  String get writeToday => '오늘의 생각 기록하기';

  @override
  String get selectMood => '감정 선택';

  @override
  String get todayTopic => '오늘의 주제';

  @override
  String get likeCount => '공감수';

  @override
  String get showMore => '더보기';

  @override
  String get taskAdded => '할일이 추가되었습니다';

  @override
  String get taskCompleted => '할일이 완료되었습니다';

  @override
  String get taskDeleted => '할일이 삭제되었습니다';

  @override
  String get thoughtSaved => '생각이 저장되었습니다';

  @override
  String get settingsSaved => '설정이 저장되었습니다';

  @override
  String get loginRequired => '로그인이 필요합니다';

  @override
  String get networkError => '네트워크 오류가 발생했습니다. 다시 시도해주세요.';

  @override
  String get likeAdded => '공감했습니다';

  @override
  String get likeRemoved => '공감을 취소했습니다';

  @override
  String taskCompletionMessage(int completed, int total) =>
      '$total개 중 $completed개의 할일을 완료했습니다';

  @override
  String thoughtsCount(int count) => '생각 $count개';

  @override
  String lastUpdated(String date) => '마지막 업데이트: $date';

  @override
  String get enterEmailForPasswordReset => '비밀번호 재설정을 위한 이메일을 입력해주세요.';

  @override
  String get invalidEmailFormat => '유효한 이메일 형식이 아닙니다.';

  @override
  String get passwordResetEmailSent =>
      '비밀번호 재설정 링크가 이메일로 발송되었습니다. 이메일을 확인해주세요.';

  @override
  String get send => '보내기';
}
