// lib/core/localization/app_localizations_en.dart
import 'app_localizations.dart';

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn() : super('en');

  @override
  String get appName => 'Break time';

  @override
  String get todayTasks => 'Happy mission';

  @override
  String get todayRest => 'Happy Box';

  @override
  String get settings => 'Break time settings';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get logout => 'Logout';

  @override
  String get welcome => 'Welcome';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get createAccount => 'Create Account';

  @override
  String get haveAccount => 'Already have an account? Sign In';

  @override
  String get continue_with_google => 'Continue with Google';

  @override
  String get continue_with_kakao => 'Continue with Kakao';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get korean => 'Korean';

  @override
  String get english => 'English';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get receiveNotifications => 'Receive Notifications';

  @override
  String get notificationFrequency => 'Notification Frequency';

  @override
  String get notificationTime => 'Notification Time';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get Homepage => 'Homepage';

  @override
  String get contact => 'Contact Us';

  @override
  String get newMission => 'New Mission';

  @override
  String get suggestedMission => 'Suggested Mission';

  @override
  String get enterNewMission => 'Enter a new mission';

  @override
  String get completionRate => 'Completion Rate';

  @override
  String get totalTasks => 'Total Tasks';

  @override
  String get completedTasks => 'Completed Tasks';

  @override
  String get averageCompletion => 'Average Completion';

  @override
  String get previousRecords => 'Previous Records';

  @override
  String get analysis => 'Analysis';

  @override
  String get chart => 'Chart';

  @override
  String get todayThought => 'Today\'s Thought';

  @override
  String get recordThought => 'Record Thought';

  @override
  String get publicThoughts => 'Public Thoughts';

  @override
  String get privateThoughts => 'Private Thoughts';

  @override
  String get viewHistory => 'View History';

  @override
  String get emotionAnalysis => 'Emotion Analysis';

  @override
  String get emotionStatistics => 'Emotion Statistics';

  @override
  String get publicEntry => 'Public';

  @override
  String get privateEntry => 'Private';

  @override
  String get noRecordsYet => 'No records yet';

  @override
  String get writeToday => 'Write Today\'s Thought';

  @override
  String get selectMood => 'Select Mood';

  @override
  String get todayTopic => 'Write about a moment you\'re grateful for today';

  @override
  String get likeCount => 'Likes';

  @override
  String get showMore => 'Show More';

  @override
  String get taskAdded => 'Task added successfully';

  @override
  String get taskCompleted => 'Task completed';

  @override
  String get taskDeleted => 'Task deleted';

  @override
  String get thoughtSaved => 'Thought saved successfully';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get loginRequired => 'Login required';

  @override
  String get networkError => 'A network error has occurred';

  @override
  String get likeAdded => 'Liked';

  @override
  String get likeRemoved => 'Like removed';

  @override
  String taskCompletionMessage(int completed, int total) =>
      'You have completed $completed of $total tasks';

  @override
  String thoughtsCount(int count) => '$count thoughts';

  @override
  String lastUpdated(String date) => 'Last updated: $date';

  @override
  String get enterEmailForPasswordReset =>
      'Enter your email to reset password.';

  @override
  String get invalidEmailFormat => 'Invalid email format.';

  @override
  String get passwordResetEmailSent =>
      'Password reset link has been sent to your email.';

  @override
  String get send => 'Send';
}
