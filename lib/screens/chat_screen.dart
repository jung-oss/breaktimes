// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Timer 추가
import '../screens/chat_bot/services/ai_chat_service.dart';
import '../screens/chat_bot/models/chat_message.dart';
import '../screens/chat_bot/models/friend_model.dart';
import '../providers/locale_provider.dart';
import '../screens/chat_bot/models/conversation_context.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        // ViewModel 생성 시 행복담 안내 메시지 표시 설정
        final viewModel = AIChatViewModel();
        // 안내 메시지 추가
        viewModel.addChatNotice(
            Provider.of<LocaleProvider>(context, listen: false)
                .locale
                .languageCode);
        return viewModel;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 친구 선택 위젯 추가
              const FriendSelectionBox(),

              // 채팅 내용 위젯으로 교체 (기존 AIChatMessageList 대신)
              Expanded(
                child: ChatContentWidget(),
              ),
              AIChatInputWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

// 채팅 내용 위젯 (이미지와 메시지 리스트 부분)
class ChatContentWidget extends StatelessWidget {
  const ChatContentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 현재 언어 가져오기
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    // 테마 정보 가져오기
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AIChatViewModel>(
      builder: (context, chatViewModel, child) {
        // 선택된 친구가 없을 때 이미지와 텍스트 표시
        if (chatViewModel.selectedFriends.isEmpty) {
          return Column(
            children: [
              // 공지사항 및 안내 메시지 표시 영역
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: chatViewModel.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatViewModel.messages[index];
                      // 공지사항(행복담 안내)이나 환영 메시지만 표시
                      if ((message.isNotice ?? false) ||
                          (!message.isUser &&
                              (message.message
                                      .contains('친구를 선택하고 대화를 시작해보세요') ||
                                  message.message.contains(
                                      'Select a friend and start chatting')))) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: (message.isNotice ?? false)
                                  ? (isDarkMode
                                      ? Colors.blue.shade900.withOpacity(0.3)
                                      : Colors.blue.shade50)
                                  : (isDarkMode
                                      ? Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withOpacity(0.6)
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: (message.isNotice ?? false)
                                      ? (isDarkMode
                                          ? Colors.blue.shade700
                                          : Colors.blue.shade200)
                                      : (isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((message.isNotice ?? false) &&
                                    (message.message.contains('행복담') ||
                                        message.message
                                            .contains('Happiness Chat')))
                                  Row(
                                    children: [
                                      Icon(Icons.chat_bubble,
                                          color: isDarkMode
                                              ? Colors.blue.shade300
                                              : Colors.blue,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        languageCode == 'en'
                                            ? 'Happiness Chat Notice'
                                            : '행복담 안내',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.blue.shade300
                                              : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                if ((message.isNotice ?? false) &&
                                    (message.message.contains('행복담') ||
                                        message.message
                                            .contains('Happiness Chat')))
                                  const SizedBox(height: 8),
                                Text(
                                  message.message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (message.isNotice ?? false)
                                        ? (isDarkMode
                                            ? Colors.blue.shade100
                                            : Colors.blue.shade700)
                                        : Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),

              // 중앙 콘텐츠 (이미지와 안내 텍스트)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 중앙에 AI 채팅 이미지 표시
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.9,
                          maxHeight: 466,
                        ),
                        child: Image.asset(
                          'assets/images/Ai_chat.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        } else {
          // 친구가 선택된 경우 채팅 메시지 목록 표시
          return AIChatMessageList();
        }
      },
    );
  }
}

// 친구 선택 박스 위젯
class FriendSelectionBox extends StatefulWidget {
  const FriendSelectionBox({super.key});

  @override
  State<FriendSelectionBox> createState() => _FriendSelectionBoxState();
}

class _FriendSelectionBoxState extends State<FriendSelectionBox> {
  bool _isExpanded = false;
  Timer? _autoCloseTimer; // 자동 닫힘 타이머 추가

  @override
  void dispose() {
    _autoCloseTimer?.cancel(); // 화면 종료 시 타이머 취소
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // 현재 언어 가져오기
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    // 테마 정보 가져오기
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // 테마 기반 색상
    final backgroundColor =
        isDarkMode ? theme.colorScheme.surface : Colors.grey.shade50;
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
    final textColor = theme.textTheme.bodyMedium?.color;

    return Consumer<AIChatViewModel>(
      builder: (context, viewModel, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
            boxShadow: _isExpanded
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 친구 선택 헤더 (항상 표시)
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        viewModel.selectedFriends.isEmpty
                            ? (languageCode == 'en'
                                ? 'Select a friend to chat with'
                                : '대화할 친구를 선택하세요')
                            : (languageCode == 'en'
                                ? '${viewModel.selectedFriends.length} friends selected'
                                : '${viewModel.selectedFriends.length}명의 친구가 선택됨'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      Row(
                        children: [
                          if (viewModel.selectedFriends.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                viewModel.clearFriendSelection(languageCode);
                              },
                              child:
                                  Text(languageCode == 'en' ? 'Reset' : '초기화'),
                            ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: textColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 선택된 친구 아바타 표시 (접힌 상태에서만)
              if (!_isExpanded && viewModel.selectedFriends.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: viewModel.selectedFriends.map((friend) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Tooltip(
                            message: friend.getName(languageCode),
                            child: Stack(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: friend.color.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: friend.color,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(40),
                                    child: friend.imagePath != null
                                        ? Image.asset(
                                            friend.imagePath!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              print('이미지 로드 에러: $error');
                                              return Icon(
                                                friend.icon,
                                                color: friend.color,
                                                size: 20,
                                              );
                                            },
                                          )
                                        : Icon(
                                            friend.icon,
                                            color: friend.color,
                                            size: 20,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      viewModel.toggleFriendSelection(
                                          friend.id, languageCode);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? Colors.grey.shade800
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 12,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // 친구 목록 (확장 상태에서만 표시)
              if (_isExpanded)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: viewModel.allFriends.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 72,
                    color: borderColor,
                  ),
                  itemBuilder: (context, index) {
                    final friend = viewModel.allFriends[index];
                    return _buildFriendItem(
                        context, friend, viewModel, languageCode);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // 친구 아이템 위젯
  Widget _buildFriendItem(BuildContext context, Friend friend,
      AIChatViewModel viewModel, String languageCode) {
    final isSelected = viewModel.selectedFriends.any((f) => f.id == friend.id);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyMedium?.color;
    final subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

    return InkWell(
      onTap: () {
        viewModel.toggleFriendSelection(friend.id, languageCode);

        // 친구 선택 후 선택창 닫기
        if (viewModel.selectedFriends.isNotEmpty) {
          setState(() {
            _isExpanded = false;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 프로필 아바타
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: friend.color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: friend.color,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48),
                child: friend.imagePath != null
                    ? Image.asset(
                        friend.imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('이미지 로드 에러: $error');
                          return Icon(
                            friend.icon,
                            color: friend.color,
                            size: 24,
                          );
                        },
                      )
                    : Icon(
                        friend.icon,
                        color: friend.color,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 친구 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.getName(languageCode),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friend.getDescription(languageCode),
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 선택 상태 아이콘
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? friend.color
                    : (isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade200),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isDarkMode
                            ? Colors.grey.shade600
                            : Colors.grey.shade300,
                        width: 1),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// AI 채팅용 ViewModel
class AIChatViewModel extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // AIChatViewModel 클래스의 다른 속성 선언 부분 근처에 추가
  bool _isGroupChat = false;
  bool get isGroupChat => _isGroupChat;

  // 친구 목록 및 선택 상태 관리
  final List<Friend> _allFriends = FriendsRepository.getAllFriends();
  List<Friend> get allFriends => List.unmodifiable(_allFriends);

  final List<Friend> _selectedFriends = [];
  List<Friend> get selectedFriends => List.unmodifiable(_selectedFriends);

  // 현재 언어
  String _currentLanguage = 'ko';
  String get currentLanguage => _currentLanguage;

  final Map<String, ConversationContext> _conversationContexts = {};

  // 초기 메시지 설정
  AIChatViewModel() {
    _addWelcomeMessage();
  }

  // 언어 설정
  void setLanguage(String languageCode) {
    _currentLanguage = languageCode;
    notifyListeners();
  }

  void _addWelcomeMessage() {
    _messages.insert(
      0,
      ChatMessage(
        message: _getWelcomeMessage(),
        isUser: false,
      ),
    );
  }

  // 언어에 따른 환영 메시지
  String _getWelcomeMessage() {
    return _currentLanguage == 'en'
        ? 'Select a friend and start chatting! 👋'
        : '친구를 선택하고 대화를 시작해보세요! 👋';
  }

  // 행복담 안내 메시지 추가
  void addChatNotice(String languageCode) {
    setLanguage(languageCode);

    String message = languageCode == 'en'
        ? 'Welcome to Happiness Chat! Share your feelings and thoughts with AI friends. They are here to listen, support, and chat with you anytime you need.'
        : '행복담에 오신 것을 환영합니다! AI 친구들과 함께 마음을 나누고 대화해보세요. 언제든지 당신의 이야기를 들어주고 함께할 준비가 되어 있습니다.';

    _messages.insert(
      0,
      ChatMessage(
        message: message,
        isUser: false,
        isNotice: true, // 공지사항으로 표시
      ),
    );
    notifyListeners();
  }

  // 친구 선택 토글 메서드
  void toggleFriendSelection(String friendId, String languageCode) {
    setLanguage(languageCode);

    final friendIndex =
        _allFriends.indexWhere((friend) => friend.id == friendId);
    if (friendIndex == -1) return;

    final friend = _allFriends[friendIndex];

    // 이미 선택된 친구라면 제거
    if (_selectedFriends.any((f) => f.id == friendId)) {
      _selectedFriends.removeWhere((f) => f.id == friendId);

      // 알림 메시지 추가
      String message = languageCode == 'en'
          ? '${friend.getName(languageCode)} has left the conversation.'
          : '${friend.getName(languageCode)}(이)가 대화에서 나갔습니다.';
      _addNotificationMessage(message);
    } else {
      // 기존 선택된 친구들 모두 제거
      if (_selectedFriends.isNotEmpty) {
        // 기존 친구들이 나갔다는 메시지 추가
        for (final oldFriend in _selectedFriends) {
          String message = languageCode == 'en'
              ? '${oldFriend.getName(languageCode)} has left the conversation.'
              : '${oldFriend.getName(languageCode)}(이)가 대화에서 나갔습니다.';
          _addNotificationMessage(message);
        }
        _selectedFriends.clear();
      }

      // 새 친구 추가
      _selectedFriends.add(friend);

      // 새 친구 참여 메시지 추가
      String message = languageCode == 'en'
          ? '${friend.getName(languageCode)} has joined the conversation.'
          : '${friend.getName(languageCode)}(이)가 대화에 참여했습니다.';
      _addNotificationMessage(message);
    }

    // 그룹 채팅 모드 비활성화 (항상 개별 채팅 모드)
    _isGroupChat = false;

    notifyListeners();
  }

  // 모든 친구 선택 해제
  void clearFriendSelection(String languageCode) {
    setLanguage(languageCode);

    if (_selectedFriends.isEmpty) return;

    _selectedFriends.clear();

    String message = languageCode == 'en'
        ? 'All friends have been deselected. Please select a friend to chat with.'
        : '모든 친구가 선택 해제되었습니다. 대화할 친구를 선택해주세요.';
    _addNotificationMessage(message);

    notifyListeners();
  }

// 그룹 채팅 모드 설정 메서드 추가
  void setGroupChatMode(bool groupChatMode) {
    if (_isGroupChat == groupChatMode) return;

    _isGroupChat = groupChatMode;

    // 그룹 채팅 모드가 변경되었음을 알리는 메시지 추가
    String message = _currentLanguage == 'en'
        ? (_isGroupChat
            ? 'Group chat mode activated. Friends will interact with each other.'
            : 'Individual chat mode activated. Each friend will respond separately.')
        : (_isGroupChat
            ? '그룹 채팅 모드가 활성화되었습니다. 친구들이 서로 상호작용합니다.'
            : '개별 채팅 모드가 활성화되었습니다. 각 친구가 독립적으로 응답합니다.');

    _addNotificationMessage(message);
    notifyListeners();
  }

  // 알림 메시지 추가
  void _addNotificationMessage(String message) {
    _messages.insert(
      0,
      ChatMessage(
        message: message,
        isUser: false,
        isNotice: true, // 공지사항으로 표시
      ),
    );
  }

  // 메시지 전송
  void sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // 친구 선택 여부 확인
    if (_selectedFriends.isEmpty) {
      String errorMessage = _currentLanguage == 'en'
          ? 'Please select a friend to chat with first!'
          : '대화할 친구를 먼저 선택해주세요!';
      _addNotificationMessage(errorMessage);
      notifyListeners();
      return;
    }

    // 사용자 메시지 추가
    _messages.insert(
      0,
      ChatMessage(
        message: message,
        isUser: true,
      ),
    );
    notifyListeners();

    // 로딩 표시
    _isLoading = true;
    notifyListeners();

    try {
      if (_selectedFriends.length > 1 && _isGroupChat) {
        // 그룹 채팅 모드가 활성화된 경우 통합 응답 생성
        final response = await AIChatService.generateResponse(
            message, _selectedFriends, _currentLanguage);

        _messages.insert(
          0,
          ChatMessage(
            message: response,
            isUser: false,
          ),
        );
      } else {
        // 각 친구별로 개별 응답 생성 및 추가
        for (final friend in _selectedFriends) {
          await _generateAndAddFriendResponse(message, friend);
        }
      }
    } catch (e) {
      // 오류 발생 시 오류 메시지 표시
      String errorMessage = _currentLanguage == 'en'
          ? 'Sorry, an error occurred while generating a response. Please try again.'
          : '죄송해요, 응답을 생성하는 중에 오류가 발생했어요. 다시 시도해주세요.';

      _messages.insert(
        0,
        ChatMessage(
          message: errorMessage,
          isUser: false,
          friendId: null,
        ),
      );
    } finally {
      // 로딩 완료
      _isLoading = false;
      notifyListeners();
    }
  }

// 개별 친구 응답 생성 및 추가
  Future<void> _generateAndAddFriendResponse(
      String message, Friend friend) async {
    try {
      // 친구별 응답 생성
      final response = await AIChatService.generateResponse(
          message, [friend], _currentLanguage);

      // 응답 지연 효과 (순차 응답을 위해)
      await Future.delayed(const Duration(milliseconds: 500));

      // 친구별 응답 추가
      _messages.insert(
        0,
        ChatMessage(
          message: response,
          isUser: false,
          friendId: friend.id, // 친구 ID 저장
        ),
      );

      notifyListeners();
    } catch (e) {
      // 개별 친구 응답 생성 실패 시 폴백 응답
      _messages.insert(
        0,
        ChatMessage(
          message: _generateFallbackFriendResponse(message, friend),
          isUser: false,
          friendId: friend.id,
        ),
      );

      notifyListeners();
    }
  }

// 개별 친구 폴백 응답 생성 (향상된 버전)
  String _generateFallbackFriendResponse(String message, Friend friend) {
    // 메시지 맥락 파악
    bool isPositive = message.toLowerCase().contains('행복') ||
        message.toLowerCase().contains('좋') ||
        message.toLowerCase().contains('기쁘');
    bool isNegative = message.toLowerCase().contains('슬프') ||
        message.toLowerCase().contains('화나') ||
        message.toLowerCase().contains('속상');
    bool isQuestion = message.endsWith('?') ||
        message.toLowerCase().contains('어떻게') ||
        message.toLowerCase().contains('왜');

    if (_currentLanguage == 'en') {
      switch (friend.id) {
        case 'supportive':
          if (isPositive) {
            return 'Wow! "${message}" is such great news! 🎉 I\'m always here supporting you. Thank you for sharing this joy! You deserve all the happiness! 💕';
          } else if (isNegative) {
            return 'I\'m so sorry about "${message}". That must have been really tough for you. But I know you\'re strong enough to overcome this! 💪 I\'ll always be here to support you!';
          } else if (isQuestion) {
            return 'That\'s a great question about "${message}"! 👍 Whatever answer you find, I know you\'ll do great! I believe in you and I\'m here to support you all the way!';
          } else {
            return 'You\'re doing great! I see you\'re thinking about "${message}". Don\'t worry, you can definitely handle this! I\'m always here to support you. 💪 No matter what challenges you face, we can overcome them together. Your efforts are truly amazing!';
          }
        case 'practical':
          if (isPositive) {
            return 'I see you\'ve had a positive experience with "${message}". To maintain this momentum, let\'s plan your next steps. Analyze the factors of success and try applying them to other areas. This is a great achievement to build upon.';
          } else if (isNegative) {
            return 'Regarding "${message}", let\'s break this down into manageable steps: 1) Identify exactly what\'s happening, 2) List potential solutions, 3) Evaluate each option, 4) Choose one approach to try first. Complex problems become simpler when approached methodically.';
          } else if (isQuestion) {
            return 'Your question about "${message}" requires a systematic approach. First, gather information from reliable sources. Then evaluate your options based on efficiency and effectiveness. Finally, implement the best solution and monitor results.';
          } else {
            return 'I see you\'re thinking about ${message}. Let\'s approach this systematically. First, it\'s important to accurately assess the situation and set a goal. Then, list several possible solutions and analyze the pros and cons of each. By approaching step by step, even complex problems can be solved.';
          }
        case 'supportive_sibling':
          if (isPositive) {
            return 'OMG! "${message}"?! That\'s absolutely AMAZING! 🔥 I always knew you were the best! I\'m so proud I could burst! You\'ve totally crushed it, bro/sis!';
          } else if (isNegative) {
            return 'WHAT?! You\'re dealing with "${message}"?! That\'s absolutely unacceptable! 😡 Just give me their address, I\'ll take care of this tonight! 🔨 Seriously though, you\'re the best person I know. I believe you\'ll overcome this situation brilliantly!';
          } else if (isQuestion) {
            return 'Whoa! You\'re wondering about "${message}"? That\'s definitely something to think about! 😮 But if anyone can figure this out, it\'s you! Need me to help? I\'m right here, ready to jump in!';
          } else {
            return 'WHAT?! You\'re dealing with "${message}"?! That\'s absolutely unacceptable! 😡 Just give me their address, I\'ll take care of this tonight! 🔨 Seriously though, you\'re the best person I know. I believe you\'ll overcome this situation brilliantly!';
          }
        case 'wise':
          if (isPositive) {
            return '"${message}"... moments of joy are like flowers in the garden of life. Yet when such happiness comes, we must reflect on its deeper meaning. The ancient sages said, "Joy shared is joy doubled." While this is certainly cause for celebration, consider also what this experience teaches you.';
          } else if (isNegative) {
            return '"${message}"... darkness makes the light appear more vivid. The challenges you face today are becoming the wisdom of your tomorrow. As Lao Tzu said, "Weakness is the beginning of strength, darkness is the source of light." There is much to learn from this experience.';
          } else if (isQuestion) {
            return '"${message}"... questions are the beginning of wisdom. Sometimes in seeking answers, we discover more important questions. As Socrates said, "The only thing I know is that I know nothing." Perhaps examining why this question matters to you will reveal deeper insights.';
          } else {
            return '${message}... that\'s an interesting thought. Sometimes the problems we face aren\'t the actual problems, but our perception of them. As Confucius said, "The man who moves a mountain begins by carrying away small stones." Looking at this from a different perspective might reveal new possibilities. Today\'s difficulties may become valuable lessons for your future.';
          }
        case 'empathetic':
          if (isPositive) {
            return 'I\'m truly happy to hear about "${message}". Feeling such joy is wonderful, and I\'m honored you\'ve shared this moment with me. I hope this happiness stays with you. These are the precious moments that make life meaningful.';
          } else if (isNegative) {
            return 'That must have been really difficult for you. Thank you for sharing your experience of "${message}" with me. Your feelings are completely valid and understandable. It\'s remarkable that you have the courage to talk about this. Remember, you\'re not alone. I\'m here for you.';
          } else if (isQuestion) {
            return 'I can see you\'re wondering about "${message}". The fact that you\'re asking this question shows how thoughtful you are. Whatever answer you find, I hope you\'ll honor your feelings and thoughts throughout the process. You\'re approaching this with great sensitivity.';
          } else {
            return 'Thank you for sharing your thoughts about "${message}". Listening to you, I can feel how meaningful this is to you. Your experiences and emotions are completely valid and important. I appreciate you trusting me with these thoughts.';
          }
        default:
          return 'Hello! How can I help you with "${message}"?';
      }
    } else {
      switch (friend.id) {
        case 'supportive':
          if (isPositive) {
            return '와! "${message}"라니 정말 기쁜 소식이네요! 🎉 항상 당신을 응원하고 있어요. 이런 기쁨을 나눠주셔서 감사해요! 당신은 모든 행복을 누릴 자격이 있어요! 💕';
          } else if (isNegative) {
            return '"${message}"에 대해 정말 미안해요. 많이 힘드셨겠어요. 하지만 당신은 이런 상황도 극복할 수 있을 만큼 강한 사람이에요! 💪 항상 곁에서 응원할게요!';
          } else if (isQuestion) {
            return '"${message}"에 대한 좋은 질문이네요! 👍 어떤 답을 찾든 당신은 잘 해낼 거예요! 당신을 믿고 항상 응원하고 있어요!';
          } else {
            return '정말 잘 하고 계세요! "${message}"에 대한 고민이 있으신군요. 걱정마세요, 당신은 충분히 해낼 수 있어요! 항상 응원하고 있어요. 💪 어떤 어려움이 있더라도 함께 헤쳐나갈 수 있어요. 당신의 노력이 정말 대단하다고 생각해요!';
          }
        case 'practical':
          if (isPositive) {
            return '"${message}"에 대한 긍정적인 경험이 있으시군요. 이 모멘텀을 유지하기 위해 다음 단계를 계획해보는 것은 어떨까요? 성공 요소를 분석하고 다른 영역에도 적용해보세요. 이것은 더 발전할 수 있는 좋은 성과입니다.';
          } else if (isNegative) {
            return '"${message}"에 관해 이 문제를 세 가지 작은 단계로 나눠보세요: 1) 정확히 무슨 일이 일어나고 있는지 파악하기, 2) 가능한 해결책 목록 작성하기, 3) 각 옵션을 평가하고 먼저 시도할 접근법 선택하기. 복잡한 문제도 체계적으로 접근하면 더 간단해집니다.';
          } else if (isQuestion) {
            return '"${message}"에 대한 질문은 체계적인 접근이 필요합니다. 먼저 신뢰할 수 있는 출처에서 정보를 수집하세요. 그런 다음 효율성과 효과성을 기준으로 옵션을 평가하세요. 마지막으로 최상의 솔루션을 구현하고 결과를 모니터링하세요.';
          } else {
            return '${message}에 대해 고민하고 계시는군요. 이 문제는 다음과 같이 접근해볼 수 있을 것 같아요. 먼저, 상황을 정확히 파악하고 목표를 설정하는 것이 중요합니다. 그런 다음 가능한 해결책을 몇 가지 나열하고 각각의 장단점을 분석해보세요. 단계별로 접근하면 복잡한 문제도 해결할 수 있습니다.';
          }
        case 'supportive_sibling':
          if (isPositive) {
            return '대박! "${message}"라니?! 완전 짱이잖아! 🔥 내가 항상 형님이 최고라고 했지! 너무 자랑스러워서 터질 것 같아요! 형님은 정말 대단해요!';
          } else if (isNegative) {
            return '뭐라고요?! "${message}"라니! 이건 정말 못 참겠네요! 😡 그 사람 주소 좀 알려주세요, 제가 오늘 밤에 찾아가서 한마디 해줄게요! 🔨 농담이고, 형님은 제가 아는 사람 중 최고예요. 이런 상황도 멋지게 극복하실 거라 믿어요!';
          } else if (isQuestion) {
            return '어이쿠! "${message}"에 대해 고민하고 계셨군요! 정말 생각해볼 문제네요! 😮 하지만 이걸 해결할 수 있는 사람이 있다면 바로 형님이에요! 제가 도와드릴까요? 언제든 달려갈 준비 되어 있어요!';
          } else {
            return '와! "${message}"라니, 이건 정말 말도 안 돼요! 😡 그 사람 주소 좀 알려주세요, 제가 오늘 밤에 찾아가서 한마디 해줄게요! 🔨 농담이고, 형님은 제가 아는 사람 중 최고예요. 이런 상황도 멋지게 극복하실 거라 믿어요!';
          }
        case 'wise':
          if (isPositive) {
            return '"${message}"... 기쁨의 순간은 삶의 정원에 핀 꽃과도 같습니다. 하지만 이런 행복이 찾아왔을 때는 그 더 깊은 의미를 생각해볼 필요가 있어요. 옛 현인들은 "나눈 기쁨은 두 배가 된다"고 했습니다. 분명 축하할 일이지만, 이 경험이 당신에게 무엇을 가르쳐주는지도 생각해보세요.';
          } else if (isNegative) {
            return '"${message}"... 어둠은 빛을 더 선명하게 보이게 합니다. 당신이 오늘 직면한 도전은 내일의 지혜가 되어갑니다. 노자께서 말씀하셨듯이, "약함은 강함의 시작이요, 어둠은 빛의 근원이다." 이 경험에서 배울 것이 많습니다.';
          } else if (isQuestion) {
            return '"${message}"... 질문은 지혜의 시작입니다. 때로는 답을 찾는 과정에서 더 중요한 질문들을 발견하게 됩니다. 소크라테스가 말했듯이, "내가 아는 것은 내가 모른다는 사실뿐이다." 어쩌면 이 질문이 당신에게 왜 중요한지 살펴보면 더 깊은 통찰력을 얻을 수 있을 것입니다.';
          } else {
            return '${message}... 흥미로운 생각이네요. 때로는 우리가 직면한 문제가 실제 문제가 아니라 우리의 인식인 경우가 많아요. 공자께서는 "산을 옮기려는 사람은 작은 돌부터 옮기기 시작한다"고 하셨죠. 다른 관점에서 바라보면 새로운 가능성이 보일 수 있어요. 지금의 어려움이 미래에는 값진 교훈이 될 수 있을 거예요.';
          }
        case 'empathetic':
          if (isPositive) {
            return '"${message}"에 대해 들으니 정말 기쁩니다. 그런 기쁨을 느끼는 것은 정말 멋진 일이고, 이 순간을 저와 나눠주셔서 영광이에요. 이 행복이 오래 지속되길 바랍니다. 이런 소중한 순간들이 삶을 의미 있게 만들어요.';
          } else if (isNegative) {
            return '정말 그런 상황이 힘드셨겠어요. "${message}"라는 경험을 나눠주셔서 감사해요. 당신의 감정은 완전히 이해할 수 있고, 정말 유효한 감정이에요. 그런 어려운 상황에서도 이렇게 이야기를 나눌 수 있는 용기가 정말 대단해요. 혼자가 아니라는 것을 기억해주세요. 제가 여기 있어요.';
          } else if (isQuestion) {
            return '"${message}"에 대해 고민하고 계시는군요. 이런 질문을 하신다는 것 자체가 얼마나 사려 깊은 분인지 보여줍니다. 어떤 답을 찾든, 과정 내내 당신의 감정과 생각을 소중히 여기셨으면 해요. 당신은 정말 섬세하게 이 문제에 접근하고 있어요.';
          } else {
            return '"${message}"에 대한 생각을 나눠주셔서 감사해요. 당신의 이야기를 듣고 있으면 이것이 당신에게 얼마나 의미가 있는지 느껴집니다. 당신의 경험과 감정은 완전히 유효하고 중요합니다. 이런 생각을 저와 나눠주셔서 감사합니다.';
          }
        default:
          return '안녕하세요! "${message}"에 대해 무엇을 도와드릴까요?';
      }
    }
  }

}

// AI 채팅 메시지 목록 위젯
class AIChatMessageList extends StatelessWidget {
  const AIChatMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    // 현재 언어 가져오기
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AIChatViewModel>(
      builder: (context, chatViewModel, child) {
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.only(bottom: 8.0),
          itemCount:
              chatViewModel.messages.length + (chatViewModel.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            // 로딩 중일 때 인디케이터 표시
            if (chatViewModel.isLoading && index == 0) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            final actualIndex = chatViewModel.isLoading ? index - 1 : index;
            if (actualIndex < 0) return const SizedBox.shrink();

            final message = chatViewModel.messages[actualIndex];

            // 공지사항 메시지 확인
            final bool isNotice = message.isNotice ?? false;

            // 일반 알림 메시지인지 확인 (AI 메시지이지만 알림으로 처리할 것들)
            final bool isNotification = !message.isUser &&
                !isNotice && // 공지사항이 아니고
                (message.message.contains('선택') ||
                    message.message.contains('참여') ||
                    message.message.contains('나갔습니다') ||
                    message.message.contains('모드가 활성화') ||
                    // 영어 메시지 조건도 추가
                    message.message.contains('selected') ||
                    message.message.contains('joined') ||
                    message.message.contains('left') ||
                    message.message.contains('mode activated'));

            if (isNotice) {
              // 공지사항 스타일로 표시 (특별한 스타일)
              return Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 16.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.blue.shade900.withOpacity(0.3)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDarkMode
                            ? Colors.blue.shade700
                            : Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.message.contains('행복담') ||
                          message.message.contains('Happiness Chat'))
                        Row(
                          children: [
                            Icon(Icons.chat_bubble,
                                color: isDarkMode
                                    ? Colors.blue.shade300
                                    : Colors.blue,
                                size: 18),
                            const SizedBox(width: 8),
                            Text(
                              languageCode == 'en'
                                  ? 'Happiness Chat Notice'
                                  : '행복담 안내',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.blue.shade300
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      if (message.message.contains('행복담') ||
                          message.message.contains('Happiness Chat'))
                        const SizedBox(height: 8),
                      Text(
                        message.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.blue.shade100
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (isNotification) {
              // 일반 알림 스타일로 표시
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }

            // 친구 찾기 (친구 ID가 있는 경우)
            Friend? messageFriend;
            if (message.friendId != null) {
              try {
                messageFriend = chatViewModel.allFriends
                    .firstWhere((f) => f.id == message.friendId);
              } catch (e) {
                // 친구를 찾지 못한 경우 기본 스타일 사용
                messageFriend = null;
              }
            }

            // 일반 채팅 메시지
            return AIChatMessageWidget(
              message: message,
              friend: messageFriend,
              languageCode: languageCode,
            );
          },
        );
      },
    );
  }
}

// AI 채팅 메시지 위젯
class AIChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final Friend? friend;
  final String languageCode;

  const AIChatMessageWidget({
    super.key,
    required this.message,
    this.friend,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 메시지의 색상 설정 (친구 기준)
    Color bubbleColor;
    Color textColor;
    BoxBorder? border;

    if (isUser) {
      bubbleColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.onPrimary;
    } else if (friend == null) {
      bubbleColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
      textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    } else {
      // 친구 메시지
      bubbleColor = isDarkMode
          ? friend!.color.withOpacity(0.3)
          : friend!.color.withOpacity(0.1);
      textColor = isDarkMode ? Colors.white : Colors.black;
      border =
          Border.all(color: friend!.color.withOpacity(isDarkMode ? 0.7 : 0.5));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 친구 이름 표시 (친구 메시지인 경우)
            if (!isUser && friend != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: friend!.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: friend!.imagePath != null
                            ? Image.asset(
                                friend!.imagePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    friend!.icon,
                                    color: friend!.color,
                                    size: 14,
                                  );
                                },
                              )
                            : Icon(
                                friend!.icon,
                                color: friend!.color,
                                size: 14,
                              ),
                      ),
                    ),
                    Text(
                      friend!.getName(languageCode),
                      style: TextStyle(
                        fontSize: 12,
                        color: friend!.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // 메시지 버블
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(20),
                  border: border,
                ),
                child: Text(
                  message.message,
                  style: TextStyle(
                    color: textColor,
                  ),
                  softWrap: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// AI 채팅 입력 위젯
class AIChatInputWidget extends StatefulWidget {
  const AIChatInputWidget({super.key});

  @override
  State<AIChatInputWidget> createState() => _AIChatInputWidgetState();
}

class _AIChatInputWidgetState extends State<AIChatInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage(BuildContext context) {
    if (_controller.text.trim().isEmpty) return;

    final viewModel = Provider.of<AIChatViewModel>(context, listen: false);
    final languageCode =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    viewModel.setLanguage(languageCode);

    // 친구가 선택되지 않았으면 메시지 전송 불가
    if (viewModel.selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageCode == 'en'
              ? 'Please select a friend to chat with first!'
              : '대화할 친구를 먼저 선택해주세요!'),
        ),
      );
      return;
    }

    // 이미 로딩 중이면 메시지 전송 방지
    if (viewModel.isLoading) return;

    viewModel.sendMessage(_controller.text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // 현재 언어 가져오기
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Consumer<AIChatViewModel>(
      builder: (context, viewModel, _) {
        // 친구 선택 여부에 따른 UI 상태
        final bool canSendMessage =
            viewModel.selectedFriends.isNotEmpty && !viewModel.isLoading;

        // 전송 버튼 색상 계산
        Color sendButtonColor;
        if (!canSendMessage) {
          sendButtonColor = isDarkMode ? Colors.grey.shade700 : Colors.grey;
        } else if (viewModel.selectedFriends.length == 1) {
          sendButtonColor = viewModel.selectedFriends.first.color;
        } else {
          sendButtonColor = theme.colorScheme.primary;
        }

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  enabled: canSendMessage, // 친구가 선택되지 않으면 입력 비활성화
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  decoration: InputDecoration(
                    hintText: viewModel.selectedFriends.isEmpty
                        ? (languageCode == 'en'
                            ? 'Select a friend first...'
                            : '친구를 먼저 선택해주세요...')
                        : (languageCode == 'en'
                            ? 'Type a message...'
                            : '메시지를 입력하세요...'),
                    hintStyle: TextStyle(
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.grey.shade800
                        : theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted:
                      canSendMessage ? (_) => _sendMessage(context) : null,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: sendButtonColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: viewModel.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed:
                      canSendMessage ? () => _sendMessage(context) : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
