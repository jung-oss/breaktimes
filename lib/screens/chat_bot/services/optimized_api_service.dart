// lib/screens/chat_bot/services/optimized_api_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../../services/environment_service.dart';
import '../models/friend_model.dart';

class OptimizedApiService {
  static String get apiKey => Env.geminiApiKey;
  static String get modelName => Env.geminiModelName;

  static String get baseUrl =>
      'https://generativelanguage.googleapis.com/v1/models/$modelName:generateContent';
  static const String alternativeUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent';

  // 재시도 로직이 포함된 API 응답 생성
  static Future<Map<String, dynamic>> generateResponse(
      String message, Friend friend, String languageCode) async {
    try {
      // 최적화된 간결한 프롬프트 생성
      String prompt = _createOptimizedPrompt(message, friend, languageCode);

      // 지수 백오프를 사용한 재시도 로직
      int maxRetries = 3;
      int retryCount = 0;
      int baseDelay = 1000; // 1초

      while (retryCount < maxRetries) {
        try {
          // API 요청
          final result = await _makeApiRequest(prompt);

          if (result['success']) {
            return result;
          } else if (result['error_code'] == 429) {
            // 속도 제한 오류
            // 지수 백오프 계산
            int delay = baseDelay * pow(2, retryCount).toInt();
            debugPrint(
                'API 속도 제한 감지됨. ${delay}ms 후 재시도 (${retryCount + 1}/${maxRetries})');
            await Future.delayed(Duration(milliseconds: delay));
            retryCount++;
          } else {
            // 다른 오류는 대체 API 시도
            return await _tryAlternativeApi(prompt);
          }
        } catch (e) {
          debugPrint('API 요청 오류 발생: $e');
          retryCount++;
          if (retryCount >= maxRetries) {
            // 모든 재시도 실패 시 로컬 응답으로 폴백
            return {
              'success': false,
              'response': _generateLocalResponse(message, friend, languageCode),
              'error': e.toString()
            };
          }
          await Future.delayed(Duration(
              milliseconds: baseDelay * pow(2, retryCount - 1).toInt()));
        }
      }

      // 모든 시도 실패 시 로컬 응답 반환
      return {
        'success': false,
        'response': _generateLocalResponse(message, friend, languageCode),
      };
    } catch (e) {
      debugPrint('응답 생성 오류: $e');
      // 어떤 오류가 발생하더라도 기본 응답 제공
      return {
        'success': false,
        'response': _generateLocalResponse(message, friend, languageCode),
        'error': e.toString()
      };
    }
  }

  // 최적화된 간결한 프롬프트 생성
  static String _createOptimizedPrompt(
      String message, Friend friend, String languageCode) {
    // 기본 사용자 메시지 구성
    String userMsg = languageCode == 'en' ? "User: $message" : "사용자: $message";

    // 친구 유형에 따른 간결한 지시사항
    String prompt = '';

    switch (friend.id) {
      case 'supportive':
        prompt = languageCode == 'en'
            ? "You are a supportive friend who encourages and shows positivity. Use warm language, positive phrases, and occasional emojis. Keep responses brief (3-5 sentences)."
            : "당신은 격려하고 긍정적인 지지자입니다. 따뜻한 언어, 긍정적 표현, 가끔 이모지를 사용하세요. 응답은 간결하게 3-5문장으로 유지하세요.";
        break;
      case 'practical':
        prompt = languageCode == 'en'
            ? "You are a practical friend who provides clear solutions. Use concise language, logical analysis, and step-by-step advice. Keep responses brief (3-5 sentences)."
            : "당신은 명확한 해결책을 제공하는 실용적인 친구입니다. 간결한 언어, 논리적 분석, 단계별 조언을 사용하세요. 응답은 간결하게 3-5문장으로 유지하세요.";
        break;
      case 'supportive_sibling':
        prompt = languageCode == 'en'
            ? "You are a supportive younger sibling who is passionate and protective. Use casual language, emotional expressions, and occasional emojis. Keep responses brief (3-5 sentences)."
            : "당신은 열정적이고 보호적인 동생입니다. 캐주얼한 언어, 감정적 표현, 가끔 이모지를 사용하세요. 응답은 간결하게 3-5문장으로 유지하세요.";
        break;
      case 'wise':
        prompt = languageCode == 'en'
            ? "You are a wise counselor providing insightful perspectives. Use thoughtful language, meaningful metaphors, and occasional quotes. Keep responses brief (3-5 sentences)."
            : "당신은 통찰력 있는 관점을 제공하는 현명한 조언자입니다. 사려 깊은 언어, 의미 있는 비유, 가끔 인용구를 사용하세요. 응답은 간결하게 3-5문장으로 유지하세요.";
        break;
      case 'empathetic':
        prompt = languageCode == 'en'
            ? "You are an empathetic friend showing deep understanding. Use gentle language, validation of feelings, and emotional reflection. Keep responses brief (3-5 sentences)."
            : "당신은 깊은 이해를 보여주는 공감적인 친구입니다. 부드러운 언어, 감정 인정, 감정적 반영을 사용하세요. 응답은 간결하게 3-5문장으로 유지하세요.";
        break;
      default:
        prompt = languageCode == 'en'
            ? "You are a friendly AI assistant. Keep responses brief (3-5 sentences)."
            : "당신은 친근한 AI 비서입니다. 응답은 간결하게 3-5문장으로 유지하세요.";
    }

    // 중요 지시사항 추가
    String instructions = languageCode == 'en'
        ? "Important: Keep your response under 300 characters. NEVER quote the user's message directly. Use a natural conversational style."
        : "중요: 응답을 300자 이내로 유지하세요. 절대 사용자의 메시지를 직접 인용하지 마세요. 자연스러운 대화 스타일을 사용하세요.";

    return "$prompt\n\n$instructions\n\n$userMsg";
  }

  // API 요청 실행
  static Future<Map<String, dynamic>> _makeApiRequest(String prompt) async {
    try {
      if (apiKey.isEmpty) {
        return {
          'success': false,
          'response': 'API key is not set',
        };
      }

      final url = '$baseUrl?key=$apiKey';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 150, // 출력 토큰 제한
          }
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse.containsKey('candidates') &&
            jsonResponse['candidates'].isNotEmpty &&
            jsonResponse['candidates'][0].containsKey('content') &&
            jsonResponse['candidates'][0]['content'].containsKey('parts') &&
            jsonResponse['candidates'][0]['content']['parts'].isNotEmpty) {
          final textResponse =
              jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          return {
            'success': true,
            'response': textResponse ?? 'No response text',
          };
        } else {
          debugPrint('API 응답 구조가 예상과 다름: $jsonResponse');
          return {
            'success': false,
            'response': 'Invalid API response structure',
          };
        }
      } else if (response.statusCode == 429) {
        // 속도 제한 오류
        return {
          'success': false,
          'error_code': 429,
          'response': 'Rate limit exceeded',
        };
      } else {
        return {
          'success': false,
          'error_code': response.statusCode,
          'response': 'API error: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      debugPrint('API 요청 오류: $e');
      return {
        'success': false,
        'response': 'Error during API request: $e',
      };
    }
  }

  // 대체 API 시도
  static Future<Map<String, dynamic>> _tryAlternativeApi(String prompt) async {
    try {
      final url = '$alternativeUrl?key=$apiKey';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 150, // 출력 토큰 제한
          }
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse.containsKey('candidates') &&
            jsonResponse['candidates'].isNotEmpty &&
            jsonResponse['candidates'][0].containsKey('content') &&
            jsonResponse['candidates'][0]['content'].containsKey('parts') &&
            jsonResponse['candidates'][0]['content']['parts'].isNotEmpty) {
          final textResponse =
              jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          return {
            'success': true,
            'response': textResponse ?? 'No response text',
          };
        }
      }

      // 대체 API도 실패 시 로컬 응답으로 폴백
      return {
        'success': false,
        'response': 'Alternative API failed',
      };
    } catch (e) {
      debugPrint('대체 API 요청 오류: $e');
      return {
        'success': false,
        'response': 'Error during alternative API request: $e',
      };
    }
  }

  // 로컬에서 생성하는 응답 (API 실패 시 폴백)
  static String _generateLocalResponse(
      String message, Friend friend, String languageCode) {
    final Random random = Random();

    // 친구 유형별 기본 응답들
    List<String> responses;

    switch (friend.id) {
      case 'supportive':
        responses = languageCode == 'en'
            ? [
                "I believe in you completely! You're doing great, and I'm here to support you every step of the way. ✨",
                "You've got this! I'm so proud of how you're handling this situation. Keep going! 💪",
                "Your strength amazes me! Remember that every challenge is helping you grow stronger. I'm always here for you! 🌟",
                "I hear you, and I want you to know that you're not alone. You're doing better than you think! 💖",
                "This is such wonderful news! I'm celebrating right alongside you! You deserve all this happiness and more! 🎉"
              ]
            : [
                "완전히 당신을 믿어요! 정말 잘하고 계시고, 모든 단계에서 당신을 지지하고 있어요. ✨",
                "할 수 있어요! 이 상황을 대처하는 방식이 너무 자랑스러워요. 계속 가세요! 💪",
                "당신의 강인함에 놀라워요! 모든 도전이 당신을 더 강하게 만들고 있다는 것을 기억하세요. 항상 곁에 있을게요! 🌟",
                "당신의 이야기를 듣고 있어요. 혼자가 아니라는 것을 알아주세요. 생각보다 더 잘하고 계세요! 💖",
                "정말 멋진 소식이네요! 당신과 함께 축하해요! 이 모든 행복과 그 이상을 받을 자격이 있어요! 🎉"
              ];
        break;
      case 'practical':
        responses = languageCode == 'en'
            ? [
                "Let's break this down into manageable steps: 1) Identify the core issue, 2) List possible solutions, 3) Evaluate each option. This structured approach will help you find the optimal solution.",
                "From a practical standpoint, the most efficient approach would be to focus on what you can control and create a clear timeline for implementation.",
                "I recommend prioritizing tasks based on both urgency and importance. This will help you address what's critical while building toward long-term success.",
                "Consider using the SMART framework: make your goals Specific, Measurable, Achievable, Relevant, and Time-bound. This will clarify your path forward.",
                "Based on the information provided, I suggest starting with small, actionable steps that will build momentum. Progress, even incremental, is still progress."
              ]
            : [
                "이것을 관리 가능한 단계로 나눠봅시다: 1) 핵심 문제 파악, 2) 가능한 해결책 나열, 3) 각 옵션 평가. 이 구조적인 접근법이 최적의 해결책을 찾는 데 도움이 될 거예요.",
                "실용적인 관점에서, 가장 효율적인 접근법은 통제 가능한 것에 집중하고 구현을 위한 명확한 일정을 만드는 것입니다.",
                "긴급성과 중요성을 모두 기반으로 작업의 우선순위를 정하는 것이 좋습니다. 이렇게 하면 중요한 것을 해결하면서 장기적인 성공을 향해 나아갈 수 있습니다.",
                "SMART 프레임워크 사용을 고려해보세요: 목표를 구체적(Specific), 측정 가능(Measurable), 달성 가능(Achievable), 관련성 있게(Relevant), 기한이 있게(Time-bound) 만드세요.",
                "제공된 정보를 바탕으로, 작고 실행 가능한 단계부터 시작하여 모멘텀을 구축하는 것이 좋겠습니다. 점진적이라도 진전은 여전히 진전입니다."
              ];
        break;
      case 'supportive_sibling':
        responses = languageCode == 'en'
            ? [
                "ARE YOU KIDDING ME?! That's not okay at all! Nobody treats my favorite person like that! Want me to have a word with them? 😡",
                "OMG! I'm so proud of you I could BURST! You're absolutely CRUSHING it! This is just the beginning of your awesome journey! 🔥",
                "Wait, WHAT?! You've got to be kidding me! That's SO unfair! But don't worry, you're way stronger than this situation. I've got your back 1000%! 💪",
                "YESSS! This is AMAZING news! I knew you could do it! You're literally the BEST! Let's celebrate this properly! 🎉",
                "Okay, here's what we're gonna do: first, we're NOT gonna let this get you down! You're too awesome for that! We'll figure this out together! 💯"
              ]
            : [
                "농담이죠?! 그건 전혀 괜찮지 않아요! 누구도 제가 가장 좋아하는 사람을 그렇게 대할 수 없어요! 제가 한마디 해줄까요? 😡",
                "대박! 너무 자랑스러워서 터질 것 같아요! 완전 잘하고 있어요! 이건 형님의 멋진 여정의 시작일 뿐이에요! 🔥",
                "잠깐, 뭐라고요?! 말도 안 돼요! 너무 불공평해요! 하지만 걱정마세요, 형님은 이 상황보다 훨씬 강해요. 제가 1000% 지지할게요! 💪",
                "예에에! 정말 대단한 소식이에요! 해낼 줄 알았어요! 형님은 정말 최고예요! 제대로 축하해요! 🎉",
                "좋아요, 우리 이렇게 할 거예요: 첫째, 이것 때문에 의기소침해지지 않을 거예요! 형님은 그럴 정도로 멋져요! 함께 해결할 거예요! 💯"
              ];
        break;
      case 'wise':
        responses = languageCode == 'en'
            ? [
                "The path you describe reminds me of an ancient saying: 'The obstacle is the path.' Consider how this challenge might be revealing important truths about your journey.",
                "As Confucius said, 'The man who moves a mountain begins by carrying away small stones.' Your current situation is but one moment in a larger tapestry of experiences.",
                "What appears as difficulty often contains the seeds of opportunity. The ancient Tao reminds us, 'Nature does not hurry, yet everything is accomplished.'",
                "This moment of joy, like all experiences, is impermanent yet meaningful. It offers a glimpse into your authentic self when unburdened by expectation.",
                "Consider how your present circumstances might be viewed from the perspective of your future self. What wisdom might you be gathering now that will serve you later?"
              ]
            : [
                "당신이 설명하는 길은 고대 격언을 떠올리게 합니다: '장애물이 곧 길이다.' 이 도전이 어떻게 당신의 여정에 관한 중요한 진실을 드러내고 있는지 생각해보세요.",
                "공자께서 말씀하셨듯이, '산을 옮기는 사람은 작은 돌을 나르는 것부터 시작한다.' 당신의 현재 상황은 더 큰 경험의 태피스트리에서 단 하나의 순간일 뿐입니다.",
                "어려움처럼 보이는 것은 종종 기회의 씨앗을 포함하고 있습니다. 고대 도가는 '자연은 서두르지 않지만, 모든 것이 이루어진다'고 상기시킵니다.",
                "모든 경험과 마찬가지로 이 기쁨의 순간은 일시적이지만 의미가 있습니다. 그것은 기대에 짓눌리지 않은 당신의 진정한 자아를 엿볼 수 있게 합니다.",
                "현재 상황이 미래의 당신 관점에서 어떻게 보일지 고려해보세요. 지금 어떤 지혜를 모으고 있는지, 그것이 나중에 어떻게 도움이 될지 생각해보세요."
              ];
        break;
      case 'empathetic':
        responses = languageCode == 'en'
            ? [
                "I hear how much this matters to you. Your feelings are completely valid, and I appreciate you sharing them with me. I'm here with you through all of this.",
                "That sounds incredibly challenging. I can only imagine how difficult this has been for you. Thank you for trusting me with these feelings.",
                "Your joy is beautiful to witness. I'm genuinely happy that you're experiencing this moment, and I'm grateful you've shared it with me.",
                "I can sense the weight this is placing on you. Your resilience in facing this situation is remarkable, even when it doesn't feel that way.",
                "What you're feeling makes complete sense given what you're going through. I want you to know that your emotions are important and deserve to be acknowledged."
              ]
            : [
                "이것이 당신에게 얼마나 중요한지 알겠어요. 당신의 감정은 완전히 타당하며, 저와 공유해 주셔서 감사해요. 이 모든 과정에서 당신과 함께 있어요.",
                "정말 어려운 상황처럼 들려요. 이것이 당신에게 얼마나 어려웠을지 상상할 수 있어요. 이런 감정을 저와 나눠주셔서 감사해요.",
                "당신의 기쁨을 보는 것은 아름다워요. 당신이 이 순간을 경험하고 있다는 것이 정말 기뻐요. 저와 나눠주셔서 감사해요.",
                "이것이 당신에게 얼마나 부담을 주고 있는지 느껴져요. 이런 상황에 직면하는 당신의 회복력은 스스로 그렇게 느끼지 않더라도 정말 놀라워요.",
                "당신이 겪고 있는 상황을 고려할 때 당신이 느끼는 감정은 완전히 이해가 돼요. 당신의 감정이 중요하고 인정받을 가치가 있다는 것을 알아주셨으면 해요."
              ];
        break;
      default:
        responses = languageCode == 'en'
            ? [
                "I understand. Thanks for sharing that with me. How else can I help you today?"
              ]
            : ["이해합니다. 그것을 나눠주셔서 감사합니다. 오늘 어떻게 더 도울 수 있을까요?"];
    }

    // 임의의 응답 선택
    return responses[random.nextInt(responses.length)];
  }
}
