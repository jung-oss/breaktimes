import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../core/localization/app_localizations.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../widgets/translation_button.dart';
import 'language_settings_screen.dart';
import 'package:app_settings/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/tutorial_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isUpdatingNotifications = false;
  bool _isUpdatingProfile = false;

  // 번역 테스트용 상태 변수
  String _originalText = '';
  String _displayText = '';
  bool _isTranslated = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();

    // 번역 테스트용 예시 텍스트 설정
    _originalText =
        "This is a sample text to demonstrate the translation functionality. "
        "You can translate this text to Korean and back to English.";
    _displayText = _originalText;
  }

  // 프로필 이미지 선택 및 업로드 메서드
  Future<void> _pickImage() async {
    final localizations = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      // imageQuality 매개변수를 추가하고, maxWidth와 maxHeight 설정
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 0-100 사이의 값, 낮을수록 파일 크기 감소
        maxWidth: 1000, // 최대 너비 제한
        maxHeight: 1000, // 최대 높이 제한
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);

        // 파일 크기 확인 (3MB = 3 * 1024 * 1024 bytes)
        final fileSize = await imageFile.length();
        if (fileSize > 3 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.localeName.startsWith('ko')
                    ? '이미지 크기는 3MB 이하여야 합니다.'
                    : 'Image size must be less than 3MB.'),
              ),
            );
          }
          return;
        }

        setState(() {
          _isUpdatingProfile = true;
        });

        try {
          await _authService.uploadProfileImage(imageFile);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.localeName.startsWith('ko')
                    ? '프로필 이미지가 업데이트되었습니다.'
                    : 'Profile image updated successfully.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.localeName.startsWith('ko')
                    ? '이미지 업로드 실패: $e'
                    : 'Image upload failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isUpdatingProfile = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localizations.localeName.startsWith('ko')
                  ? '이미지 업로드 실패: $e'
                  : 'Image upload failed: $e')),
        );
      }
    }
  }

  // 사용자가 Google 또는 Kakao 사용자인지 확인
  Future<bool> _isGoogleOrKakaoUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Google 제공자 ID 확인
    for (var info in user.providerData) {
      if (info.providerId == 'google.com') {
        return true;
      }
    }

    // Kakao 사용자인지 확인 (Firestore에서 provider 필드 확인)
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final provider = doc.data()!['provider'];
        return provider == 'kakao';
      }
    } catch (e) {
      print('사용자 제공자 정보 확인 오류: $e');
    }

    return false;
  }

  // 사용자 displayName 변경
  Future<void> _showEditDisplayNameDialog() async {
    if (_isUpdatingProfile) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // Google 또는 Kakao 사용자가 아니면 수정 불가
    final canEdit = await _isGoogleOrKakaoUser();
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).localeName.startsWith('ko')
                ? 'Google 또는 Kakao 사용자만 이름을 변경할 수 있습니다.'
                : 'Only Google or Kakao users can edit their display name.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController();
    nameController.text = user.displayName ?? '';

    final localizations = AppLocalizations.of(context);
    final isKorean = localizations.localeName.startsWith('ko');

    // 대화 상자 표시
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isKorean ? '이름 수정' : 'Edit Name'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: isKorean ? '이름' : 'Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text(localizations.cancel),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
            child: Text(localizations.save),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                Navigator.of(ctx).pop();
                return;
              }

              setState(() {
                _isUpdatingProfile = true;
              });

              try {
                // Firebase Auth에서 displayName 업데이트
                await user.updateDisplayName(nameController.text.trim());

                // Firestore에서도 업데이트
                await _firestore
                    .collection('users')
                    .doc(user.uid)
                    .update({'displayName': nameController.text.trim()});

                Navigator.of(ctx).pop();

                // 성공 메시지 표시
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        isKorean ? '이름이 업데이트되었습니다.' : 'Name has been updated.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.of(ctx).pop();

                // 오류 메시지 표시
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isKorean
                        ? '이름 업데이트 실패: $e'
                        : 'Failed to update name: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _isUpdatingProfile = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _initializeNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.init();
    } catch (e) {
      print('알림 초기화 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 여러 Provider 사용
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 프로필 섹션 추가
                _buildSectionTitle(
                    context, isKorean ? '프로필 설정' : 'Profile Settings'),

                // 프로필 카드
                FutureBuilder<bool>(
                  future: _isGoogleOrKakaoUser(),
                  builder: (context, snapshot) {
                    final canEditName = snapshot.data ?? false;
                    final user = _auth.currentUser;

                    return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 프로필 이미지 및 정보
                                Row(
                                  children: [
                                    // 프로필 이미지 (터치 가능)
                                    FutureBuilder<String>(
                                      future: _authService
                                          .getCurrentUserProfileImageUrl(),
                                      builder: (context, snapshot) {
                                        final hasImage = snapshot.hasData &&
                                            snapshot.data!.isNotEmpty;

                                        return GestureDetector(
                                          onTap: _isUpdatingProfile
                                              ? null
                                              : _pickImage,
                                          child: Stack(
                                            children: [
                                              // 프로필 이미지
                                              CircleAvatar(
                                                radius: 40,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                backgroundImage: hasImage
                                                    ? NetworkImage(
                                                        snapshot.data!)
                                                    : null,
                                                child: hasImage
                                                    ? null
                                                    : const Icon(Icons.person,
                                                        size: 40,
                                                        color: Colors.grey),
                                                onBackgroundImageError: hasImage
                                                    ? (_, __) => const Icon(
                                                        Icons.person,
                                                        size: 40,
                                                        color: Colors.grey)
                                                    : null,
                                              ),

                                              // 카메라 아이콘 오버레이
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .primaryColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.camera_alt,
                                                    size: 20,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),

                                              // 로딩 인디케이터 (업데이트 중일 때)
                                              if (_isUpdatingProfile)
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.5),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                                Colors.white),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 16),

                                    // 사용자 정보
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // 이메일은 모든 사용자에게 표시
                                          Text(
                                            user?.email ?? 'Guest',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          // display name과 편집 아이콘을 함께 표시
                                          if (canEditName &&
                                              user?.displayName != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    user!.displayName!,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // 이름 수정 버튼 (Google/Kakao 사용자에게만 표시)
                                    if (canEditName)
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: _isUpdatingProfile
                                            ? null
                                            : _showEditDisplayNameDialog,
                                      ),
                                  ],
                                ),
                              ],
                            )));
                  },
                ),

                // 알림 설정 (최우선 순위로 상단에 배치)
                _buildSectionTitle(
                    context, isKorean ? '알림 설정' : 'Notifications'),
// 안내 문구 추가
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    isKorean
                        ? '누구의 방해도 받지 않는 가장 편안한 시간을 선택하세요.'
                        : 'Choose the most comfortable time without any interruptions.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(isKorean ? '알림 받기' : 'Receive Notifications'),
                  subtitle: Text(
                    isKorean
                        ? settingsProvider.notificationsEnabled
                            ? '${_getFrequencyString(settingsProvider.frequency, isKorean)} ${_formatTimeOfDay(settingsProvider.notificationTime)}'
                            : '알림이 비활성화되어 있습니다.'
                        : settingsProvider.notificationsEnabled
                            ? '${settingsProvider.frequency.toString().split('.').last} at ${_formatTimeOfDay(settingsProvider.notificationTime)}'
                            : 'Notifications are disabled.',
                  ),
                  value: settingsProvider.notificationsEnabled,
                  onChanged: (value) async {
                    if (_isUpdatingNotifications) return;

                    setState(() {
                      _isUpdatingNotifications = true;
                    });

                    await settingsProvider.setNotificationsEnabled(value);

                    // 알림 서비스 설정 업데이트
                    await _updateNotificationSettings(settingsProvider);

                    setState(() {
                      _isUpdatingNotifications = false;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: _buildNotificationPermissionButton(context, isKorean),
                ),
                if (settingsProvider.notificationsEnabled) ...[
                  ListTile(
                    title: Text(isKorean ? '알림 시간' : 'Notification Time'),
                    subtitle: Text(
                        _formatTimeOfDay(settingsProvider.notificationTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _showTimePicker(context, settingsProvider),
                  ),
                  ListTile(
                    title: Text(isKorean ? '알림 빈도' : 'Notification Frequency'),
                    subtitle: Text(
                      _getFrequencyString(settingsProvider.frequency, isKorean),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showFrequencyDialog(
                        context, settingsProvider, isKorean),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      _getTimeUntilNextNotification(
                        settingsProvider.notificationsEnabled,
                        settingsProvider.frequency,
                        settingsProvider.notificationTime,
                        isKorean,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                const Divider(height: 20),

                // 튜토리얼 다시 보기 버튼
                _buildSectionTitle(context, isKorean ? '튜토리얼' : 'Tutorial'),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(isKorean ? '튜토리얼 다시 보기' : 'Show Tutorial Again'),
                  subtitle: Text(isKorean
                      ? '앱 사용 방법을 다시 확인합니다'
                      : 'View the app usage guide again'),
                  onTap: () {
                    // TutorialWidget을 전체 화면 다이얼로그로 표시
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => TutorialWidget(
                        onComplete: () {
                          // 튜토리얼 완료 후 다이얼로그 닫기
                          Navigator.of(context).pop();

                          // 완료 메시지 표시 (선택사항)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isKorean
                                  ? '튜토리얼을 완료했습니다'
                                  : 'Tutorial completed'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                const Divider(height: 20),

                // 테마 설정
                _buildSectionTitle(context, isKorean ? '화면 설정' : 'Display'),
                SwitchListTile(
                  title: Text(isKorean ? '다크 모드' : 'Dark Mode'),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) async {
                    await themeProvider.toggleTheme();
                    // 설정 Provider와 동기화
                    settingsProvider
                        .setDarkMode(themeProvider.themeMode == ThemeMode.dark);
                  },
                ),

                const Divider(height: 20),

                // 언어 설정
                _buildSectionTitle(context, isKorean ? '언어 설정' : 'Language'),
                ListTile(
                  title: Text(isKorean ? '언어 선택' : 'Select Language'),
                  subtitle: Text(localeProvider.locale.languageCode == 'ko'
                      ? '한국어'
                      : 'English'),
                  trailing: const Icon(Icons.language),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LanguageSettingsScreen(),
                      ),
                    );
                  },
                ),

                const Divider(height: 20),

                // 번역 기능 설정
                _buildSectionTitle(context, isKorean ? '번역 설정' : 'Translation'),
                SwitchListTile(
                  title: Text(isKorean ? '번역 기능 활성화' : 'Enable Translation'),
                  subtitle: Text(
                    isKorean
                        ? '활성화하면 글 내용을 번역할 수 있는 버튼이 표시됩니다.'
                        : 'When enabled, translation buttons will be shown for content.',
                  ),
                  value: settingsProvider.translationEnabled,
                  onChanged: (value) {
                    settingsProvider.setTranslationEnabled(value);
                  },
                ),

                // 번역 기능 데모 - 번역 기능이 활성화된 경우에만 표시
                if (settingsProvider.translationEnabled) ...[
                  const SizedBox(height: 16),
                  Card(
                    margin: const EdgeInsets.all(8),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isKorean ? '번역 기능 데모' : 'Translation Demo',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 번역 상태 표시
                          if (_isTranslated)
                            TranslationStatusIndicator(
                              isTranslated: _isTranslated,
                              isKorean: isKorean,
                            ),

                          // 테스트 텍스트
                          Text(_displayText),
                          const SizedBox(height: 8),

                          // 번역 버튼
                          TranslationButton(
                            originalText: _originalText,
                            isKorean: isKorean,
                            onTranslationChanged:
                                (translatedText, isTranslated) {
                              setState(() {
                                _displayText = translatedText;
                                _isTranslated = isTranslated;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  // 빈도를 문자열로 변환
  String _getFrequencyString(NotificationFrequency frequency, bool isKorean) {
    if (isKorean) {
      switch (frequency) {
        case NotificationFrequency.daily:
          return '매일';
        case NotificationFrequency.weekly:
          return '매주';
        case NotificationFrequency.monthly:
          return '매월';
        default:
          return '매일';
      }
    } else {
      return frequency.toString().split('.').last;
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    // 현재 테마의 밝기를 확인
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          // 다크 모드일 때와 라이트 모드일 때 다른 색상 사용
          color: isDarkMode
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  // 시간 선택 다이얼로그
  Future<void> _showTimePicker(
      BuildContext context, SettingsProvider settingsProvider) async {
    if (_isUpdatingNotifications) return;

    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: settingsProvider.notificationTime,
    );

    if (picked != null) {
      setState(() {
        _isUpdatingNotifications = true;
      });

      await settingsProvider.setNotificationTime(picked);
      await _updateNotificationSettings(settingsProvider);

      setState(() {
        _isUpdatingNotifications = false;
      });
    }
  }

  // 알림 빈도 선택 다이얼로그
  Future<void> _showFrequencyDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
    bool isKorean,
  ) async {
    if (_isUpdatingNotifications) return;

    final frequencies = NotificationFrequency.values;

    // 현재 선택된 빈도를 상태 변수로 사용
    NotificationFrequency selectedFrequency = settingsProvider.frequency;
    List<int> selectedWeekdays = List.from(settingsProvider.selectedWeekdays);
    int monthlyDate = settingsProvider.monthlyDate;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isKorean ? '알림 빈도 선택' : 'Select Frequency'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 각 빈도별 라디오 버튼
                    ...frequencies.map((freq) {
                      return RadioListTile<NotificationFrequency>(
                        title: Text(_getFrequencyString(freq, isKorean)),
                        subtitle: Text(
                          _getFrequencyDescription(freq, isKorean),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        value: freq,
                        groupValue: selectedFrequency,
                        onChanged: (value) {
                          if (value != null) {
                            // 다이얼로그 내부 상태 업데이트
                            setDialogState(() {
                              selectedFrequency = value;
                              print('빈도 변경: $selectedFrequency'); // 디버깅용
                            });
                          }
                        },
                      );
                    }).toList(),

                    // 주간 빈도가 선택된 경우 요일 선택기 표시
                    if (selectedFrequency == NotificationFrequency.weekly)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isKorean
                                  ? '알림을 받을 요일'
                                  : 'Select days for notifications',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildWeekdaySelector(
                              context,
                              selectedWeekdays,
                              (newSelectedDays) {
                                setDialogState(() {
                                  selectedWeekdays = newSelectedDays;
                                });
                              },
                              isKorean,
                            ),
                          ],
                        ),
                      ),

                    // 월간 빈도가 선택된 경우 날짜 선택기 표시
                    if (selectedFrequency == NotificationFrequency.monthly)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isKorean ? '매월 알림 날짜' : 'Select day of month',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: monthlyDate.toDouble(),
                                    min: 1,
                                    max: 31,
                                    divisions: 30,
                                    label: monthlyDate.toString(),
                                    onChanged: (value) {
                                      setDialogState(() {
                                        monthlyDate = value.toInt();
                                      });
                                    },
                                  ),
                                ),
                                Container(
                                  width: 40,
                                  alignment: Alignment.center,
                                  child: Text(
                                    monthlyDate.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              isKorean
                                  ? '* 선택한 날짜가 해당 월에 없는 경우, 그 달의 마지막 날에 알림이 발송됩니다.'
                                  : '* If the selected date doesn\'t exist in a month, notification will be sent on the last day.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isKorean ? '취소' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();

                    setState(() {
                      _isUpdatingNotifications = true;
                    });

                    // 빈도 저장
                    await settingsProvider
                        .setNotificationFrequency(selectedFrequency);

                    // 요일 또는 날짜 저장
                    if (selectedFrequency == NotificationFrequency.weekly) {
                      await settingsProvider
                          .setSelectedWeekdays(selectedWeekdays);
                    } else if (selectedFrequency ==
                        NotificationFrequency.monthly) {
                      await settingsProvider.setMonthlyDate(monthlyDate);
                    }

                    // 알림 설정 업데이트
                    await _updateNotificationSettings(settingsProvider);

                    setState(() {
                      _isUpdatingNotifications = false;
                    });
                  },
                  child: Text(isKorean ? '저장' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // TimeOfDay 포맷팅
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$period $hour:$minute';
  }

  /// 요일 선택기 위젯 개선
  Widget _buildWeekdaySelector(BuildContext context, List<int> selectedDays,
      Function(List<int>) onChanged, bool isKorean) {
    // 요일 정보
    final List<Map<String, dynamic>> weekdays = [
      {'value': 1, 'label': isKorean ? '월' : 'Mon'},
      {'value': 2, 'label': isKorean ? '화' : 'Tue'},
      {'value': 3, 'label': isKorean ? '수' : 'Wed'},
      {'value': 4, 'label': isKorean ? '목' : 'Thu'},
      {'value': 5, 'label': isKorean ? '금' : 'Fri'},
      {'value': 6, 'label': isKorean ? '토' : 'Sat'},
      {'value': 7, 'label': isKorean ? '일' : 'Sun'},
    ];

    return Wrap(
      spacing: 8,
      children: weekdays.map((day) {
        final dayValue = day['value'] as int;
        final isSelected = selectedDays.contains(dayValue);

        return InkWell(
          onTap: () {
            List<int> updatedDays = List.from(selectedDays);
            if (isSelected) {
              // 마지막 하나만 남은 경우는 제거 불가
              if (updatedDays.length > 1) {
                updatedDays.remove(dayValue);
              }
            } else {
              updatedDays.add(dayValue);
            }
            // 변경 콜백 호출
            onChanged(updatedDays);
          },
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                day['label'] as String,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 빈도 설명 반환
  String _getFrequencyDescription(
      NotificationFrequency frequency, bool isKorean) {
    if (isKorean) {
      switch (frequency) {
        case NotificationFrequency.daily:
          return '매일 알림을 받습니다.';
        case NotificationFrequency.weekly:
          return '선택한 요일에 알림을 받습니다.';
        case NotificationFrequency.monthly:
          return '매월 선택한 날짜에 알림을 받습니다.';
        default:
          return '';
      }
    } else {
      switch (frequency) {
        case NotificationFrequency.daily:
          return 'Receive notifications every day.';
        case NotificationFrequency.weekly:
          return 'Receive notifications on selected days.';
        case NotificationFrequency.monthly:
          return 'Receive notifications on the 1st of each month.';
        default:
          return '';
      }
    }
  }

  // 알림 설정 업데이트
  Future<void> _updateNotificationSettings(
      SettingsProvider settingsProvider) async {
    try {
      // 알림이 활성화된 경우만 업데이트
      if (settingsProvider.notificationsEnabled) {
        // 알림 서비스 호출
        final success = await _notificationService.saveNotificationSettings(
          enabled: settingsProvider.notificationsEnabled,
          frequency:
              _getNotificationFrequencyString(settingsProvider.frequency),
          time: settingsProvider.notificationTime,
          weekdays: settingsProvider.frequency == NotificationFrequency.weekly
              ? settingsProvider.selectedWeekdays
              : null,
          monthlyDate:
              settingsProvider.frequency == NotificationFrequency.monthly
                  ? settingsProvider.monthlyDate
                  : null,
        );

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).localeName.startsWith('ko')
                    ? '알림 설정 저장 중 오류가 발생했습니다.'
                    : 'Error saving notification settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // 알림 비활성화
        await _notificationService.cancelAllNotifications();
      }
    } catch (e) {
      print('알림 설정 업데이트 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).localeName.startsWith('ko')
                  ? '알림 설정 업데이트 중 오류: $e'
                  : 'Error updating notification settings: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NotificationFrequency를 NotificationService 상수로 변환
  String _getNotificationFrequencyString(NotificationFrequency frequency) {
    switch (frequency) {
      case NotificationFrequency.daily:
        return NotificationService.frequencyDaily;
      case NotificationFrequency.weekly:
        return NotificationService.frequencyWeekly;
      case NotificationFrequency.monthly:
        return 'monthly'; // NotificationService.frequencyMonthly 추가 필요
    }
  }

  // 다음 알림까지 남은 시간 문자열 반환
  String _getTimeUntilNextNotification(
    bool enabled,
    NotificationFrequency frequency,
    TimeOfDay notificationTime,
    bool isKorean,
  ) {
    if (!enabled) {
      return isKorean ? '알림이 비활성화되어 있습니다.' : 'Notifications are disabled.';
    }

    final now = DateTime.now();
    DateTime nextNotification = DateTime(
      now.year,
      now.month,
      now.day,
      notificationTime.hour,
      notificationTime.minute,
    );

    // 이미 오늘 시간이 지났으면 다음 날로 설정
    if (nextNotification.isBefore(now)) {
      nextNotification = nextNotification.add(const Duration(days: 1));
    }

    // 주간 알림이면 다음 선택된 요일로 설정
    if (frequency == NotificationFrequency.weekly) {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final selectedWeekdays = settingsProvider.selectedWeekdays;

      // 다음 알림 요일 찾기
      bool foundNextDay = false;
      for (int i = 0; i < 7; i++) {
        final checkDate = now.add(Duration(days: i));
        if (selectedWeekdays.contains(checkDate.weekday)) {
          if (i == 0 &&
              DateTime(now.year, now.month, now.day, notificationTime.hour,
                      notificationTime.minute)
                  .isBefore(now)) {
            continue; // 오늘이지만 이미 시간이 지났으면 다음 선택된 요일로
          }

          nextNotification = DateTime(
            checkDate.year,
            checkDate.month,
            checkDate.day,
            notificationTime.hour,
            notificationTime.minute,
          );
          foundNextDay = true;
          break;
        }
      }

      // 다음 7일 내에 선택된 요일이 없는 경우
      if (!foundNextDay) {
        // 첫 번째 선택된 요일로 설정
        final firstSelectedDay = selectedWeekdays.first;
        final daysUntilNextOccurrence =
            (firstSelectedDay - now.weekday + 7) % 7;
        nextNotification = DateTime(
          now.year,
          now.month,
          now.day,
          notificationTime.hour,
          notificationTime.minute,
        ).add(Duration(days: daysUntilNextOccurrence));
      }
    }

    // 월간 알림이면 선택된 날짜로 설정
    if (frequency == NotificationFrequency.monthly) {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final selectedDate = settingsProvider.monthlyDate;

      // 이번 달의 선택된 날짜
      DateTime targetDate;
      if (now.day <= selectedDate) {
        // 이번 달에 아직 선택된 날짜가 오지 않았음
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final actualDate =
            selectedDate > daysInMonth ? daysInMonth : selectedDate;

        targetDate = DateTime(
          now.year,
          now.month,
          actualDate,
          notificationTime.hour,
          notificationTime.minute,
        );
      } else {
        // 이미 이번 달의 선택된 날짜는 지남 -> 다음 달로
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final actualDate =
            selectedDate > daysInNextMonth ? daysInNextMonth : selectedDate;

        targetDate = DateTime(
          nextYear,
          nextMonth,
          actualDate,
          notificationTime.hour,
          notificationTime.minute,
        );
      }

      nextNotification = targetDate;
    }

    // 남은 시간 계산
    final difference = nextNotification.difference(now);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (isKorean) {
      if (days > 0) {
        return '다음 알림까지 $days일 $hours시간 남았습니다.';
      } else if (hours > 0) {
        return '다음 알림까지 $hours시간 $minutes분 남았습니다.';
      } else {
        return '다음 알림까지 $minutes분 남았습니다.';
      }
    } else {
      if (days > 0) {
        return 'Next notification in $days days and $hours hours.';
      } else if (hours > 0) {
        return 'Next notification in $hours hours and $minutes minutes.';
      } else {
        return 'Next notification in $minutes minutes.';
      }
    }
  }
}

// Settings 화면의 알림 섹션에 권한 요청 버튼 추가
Widget _buildNotificationPermissionButton(BuildContext context, bool isKorean) {
  final NotificationService _notificationService = NotificationService();

  return ElevatedButton.icon(
    icon: const Icon(Icons.security),
    label: Text(isKorean ? '알림 권한 요청' : 'Request Notification Permission'),
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.blue,
    ),
    onPressed: () async {
      // 먼저 서비스 초기화 확인
      await _notificationService.init();

      // 현재 권한 상태 확인
      final hasPermission = await _notificationService.checkPermissions();

      if (!hasPermission) {
        // 권한이 없는 경우, 권한 요청
        final granted = await _notificationService.requestPermissions();

        if (granted) {
          // 권한 획득 성공
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isKorean
                  ? '알림 권한이 허용되었습니다'
                  : 'Notification permission granted'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // 권한 획득 실패 - 시스템 설정으로 이동 제안
          if (context.mounted) {
            _showPermissionDeniedDialog(context, isKorean);
          }
        }
      } else {
        // 이미 권한이 있는 경우
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isKorean
                ? '이미 알림 권한이 허용되어 있습니다'
                : 'Notification permission is already granted'),
          ),
        );
      }
    },
  );
}

// 권한 거부 시 보여줄 다이얼로그
void _showPermissionDeniedDialog(BuildContext context, bool isKorean) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isKorean ? '알림 권한 필요' : 'Permission Required'),
      content: Text(
        isKorean
            ? '앱 설정에서 알림 권한을 허용해 주세요.'
            : 'Please enable notification permission in app settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isKorean ? '나중에' : 'Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // 시스템 설정 화면으로 이동
            _openSystemSettings();
          },
          child: Text(isKorean ? '설정으로 이동' : 'Open Settings'),
        ),
      ],
    ),
  );
}

// 시스템 설정 열기
void _openSystemSettings() {
  try {
    AppSettings.openAppSettings(); // app_settings 패키지 사용
  } catch (e) {
    print('설정 열기 오류: $e');
  }
}

// 번역 상태 표시 위젯 (누락된 위젯 추가)
class TranslationStatusIndicator extends StatelessWidget {
  final bool isTranslated;
  final bool isKorean;

  const TranslationStatusIndicator({
    super.key,
    required this.isTranslated,
    required this.isKorean,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.translate, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            isKorean ? '번역됨' : 'Translated',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
