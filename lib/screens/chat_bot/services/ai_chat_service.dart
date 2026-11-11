// lib/screens/chat_bot/services/ai_chat_service.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/friend_model.dart';
import '../models/conversation_context.dart';
import './optimized_api_service.dart';

class AIChatService {
  // 대화 컨텍스트를 저장하기 위한 맵 (친구 ID별로 관리)
  static final Map<String, ConversationContext> _conversationContexts = {};

  // 친구 성격에 따른 응답 생성 - 단일 친구 최적화 버전
  static Future<String> generateResponse(
      String message, List<Friend> selectedFriends, String languageCode) async {
    try {
      // 친구가 없을 경우 기본 메시지 반환
      if (selectedFriends.isEmpty) {
        return languageCode == 'en'
            ? 'Please select a friend to chat with first!'
            : '대화할 친구를 먼저 선택해주세요!';
      }

      // 여러 친구 선택 확인 - 첫 번째 친구만 사용
      Friend selectedFriend = selectedFriends.first;
      String friendId = selectedFriend.id;

      // 컨텍스트 가져오기
      if (!_conversationContexts.containsKey(friendId)) {
        _conversationContexts[friendId] = ConversationContext();
      }

      // 최적화된 API 서비스를 통한 응답 생성 시도
      final apiResult = await OptimizedApiService.generateResponse(
          message, selectedFriend, languageCode);

      if (apiResult['success']) {
        return apiResult['response'];
      } else {
        debugPrint(
            'API 응답 실패, 로컬 응답 사용: ${apiResult['error'] ?? "Unknown error"}');
        return apiResult['response']; // 최적화된 서비스에서 제공하는 폴백 응답
      }
    } catch (e) {
      debugPrint('응답 생성 오류: $e');
      // 어떤 오류가 발생하더라도 기본 응답 제공
      return _generateEmergencyResponse(
          message, selectedFriends.first, languageCode);
    }
  }

  // 비상 응답 생성 (모든 다른 방법이 실패했을 때)
  static String _generateEmergencyResponse(
      String message, Friend friend, String languageCode) {
    final responses = languageCode == 'en'
        ? [
            "I hear you. Let's talk more about this.",
            "That's interesting. Tell me more?",
            "I understand. How are you feeling about this?",
            "I'm here for you. What would help right now?",
            "I appreciate you sharing that with me.",
          ]
        : [
            "말씀하신 내용 들었습니다. 더 이야기해볼까요?",
            "흥미로운 내용이네요. 더 알려주실래요?",
            "이해합니다. 이것에 대해 어떻게 느끼고 계신가요?",
            "항상 여기 있어요. 지금 어떤 도움이 필요하신가요?",
            "그것을 저와 공유해 주셔서 감사합니다.",
          ];

    return responses[Random().nextInt(responses.length)];
  }
}
