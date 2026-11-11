// lib/screens/chat_bot/models/conversation_context.dart
import 'dart:math';

class ConversationContext {
  // 기본 컨텍스트 정보
  String lastTopic = 'general';
  List<String> mentionedTopics = [];
  int messageCount = 0;
  DateTime lastInteractionTime = DateTime.now();

  // 응답 패턴 다양화를 위한 추가 필드
  String lastUsedIntro = '';
  String lastUsedContent = '';
  String lastUsedConclusion = '';
  String lastUsedEmoji = '';

  // 최근 응답 관련 정보
  bool lastResponseUsedApi = false;
  bool lastResponseQuotedMessage = false;
  int consecutiveLocalResponses = 0;
  int consecutiveApiResponses = 0;

  // 대화 흐름 관리
  int questionCount = 0;
  int statementCount = 0;
  List<String> recentTopics = [];
  Map<String, int> topicFrequency = {};

  // API 응답 품질 추적
  int apiSuccessCount = 0;
  int apiFailCount = 0;
  double lastApiResponseQuality = 0.5; // 0.0 ~ 1.0

  // 시간 간격에 따른 대화 맥락 파악
  bool isNewConversation() {
    final now = DateTime.now();
    final difference = now.difference(lastInteractionTime);
    return difference.inMinutes > 30; // 30분 이상 지나면 새 대화로 간주
  }

  // 맥락 업데이트
  void updateContext(String message, String detectedTopic, bool isQuestion) {
    if (detectedTopic != 'general' &&
        !mentionedTopics.contains(detectedTopic)) {
      mentionedTopics.add(detectedTopic);
    }

    if (detectedTopic != 'general') {
      lastTopic = detectedTopic;

      // 토픽 빈도 추적
      topicFrequency[detectedTopic] = (topicFrequency[detectedTopic] ?? 0) + 1;

      // 최근 토픽 추적 (최대 5개)
      if (!recentTopics.contains(detectedTopic)) {
        recentTopics.add(detectedTopic);
        if (recentTopics.length > 5) {
          recentTopics.removeAt(0);
        }
      }
    }

    // 질문/진술문 추적
    if (isQuestion) {
      questionCount++;
    } else {
      statementCount++;
    }

    messageCount++;
    lastInteractionTime = DateTime.now();
  }

  // API와 로컬 응답 간의 균형을 위한 결정 로직
  bool shouldUseApiResponse() {
    // 기본적으로 API 사용 확률
    double apiProbability = 0.7;

    // 연속으로 같은 유형의 응답이 사용된 경우 균형 조정
    if (consecutiveApiResponses > 2) {
      apiProbability -= 0.2 * (consecutiveApiResponses - 2);
    } else if (consecutiveLocalResponses > 2) {
      apiProbability += 0.2 * (consecutiveLocalResponses - 2);
    }

    // API 실패율이 높은 경우 API 사용 확률 감소
    if (apiFailCount > 0 && apiSuccessCount > 0) {
      double failRate = apiFailCount / (apiFailCount + apiSuccessCount);
      if (failRate > 0.3) {
        apiProbability -= 0.2;
      }
    }

    // 마지막 API 응답 품질이 낮은 경우 API 사용 확률 감소
    if (lastApiResponseQuality < 0.4) {
      apiProbability -= 0.2;
    }

    // 확률 범위 제한 (0.2 ~ 0.9)
    apiProbability = apiProbability.clamp(0.2, 0.9);

    return Random().nextDouble() < apiProbability;
  }

  // 사용자 메시지를 직접 인용해야 하는지 결정
  bool shouldQuoteMessage() {
    // 직전 응답에서 인용했으면 이번엔 인용 확률 낮춤
    if (lastResponseQuotedMessage) {
      return Random().nextDouble() < 0.2; // 20% 확률로 인용
    }
    return Random().nextDouble() < 0.4; // 기본 40% 확률로 인용
  }

  // 대화 패턴 다양화를 위한 결정 로직
  bool shouldAskQuestion() {
    // 질문이 너무 적으면 질문 확률 높임
    if (questionCount < statementCount / 3) {
      return Random().nextDouble() < 0.4; // 40% 확률로 질문
    }
    return Random().nextDouble() < 0.2; // 기본 20% 확률로 질문
  }

  // API 응답 결과 기록
  void recordApiResponse(bool success, double quality) {
    if (success) {
      apiSuccessCount++;
      lastApiResponseQuality = quality;
      consecutiveApiResponses++;
      consecutiveLocalResponses = 0;
    } else {
      apiFailCount++;
      consecutiveLocalResponses++;
      consecutiveApiResponses = 0;
    }

    lastResponseUsedApi = success;
  }

  // 로컬 응답 결과 기록
  void recordLocalResponse() {
    consecutiveLocalResponses++;
    consecutiveApiResponses = 0;
    lastResponseUsedApi = false;
  }
}
