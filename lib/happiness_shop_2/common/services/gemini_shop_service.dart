import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../services/environment_service.dart';
import '../../../utils/logger.dart';
import 'ai_result.dart';

/// 행복상점 AI 생성 공통 서vice (운세·위로 등)
class GeminiShopService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  String _getModelName() {
    return EnvironmentService.instance.get(
      'GEMINI_MODEL_NAME',
      defaultValue: '',
    );
  }

  Future<AiResult> generateFortune({
    required DateTime date,
    required String locale,
    String? mood,
  }) async {
    final dateStr = locale.startsWith('ko')
        ? DateFormat('yyyy년 MM월 dd일', 'ko').format(date)
        : DateFormat('MMMM dd, yyyy', 'en').format(date);
    final moodLine = mood != null && mood.isNotEmpty
        ? (locale.startsWith('ko') ? '오늘 기분: $mood' : 'Today\'s mood: $mood')
        : '';

    final prompt = locale.startsWith('ko')
        ? '''
당신은 따뜻한 하루 응원 메시지를 전하는 작가입니다.
날짜: $dateStr
$moodLine

오늘의 행복 운세를 작성해주세요. 점술·재물·관계 단정은 금지합니다.

출력 형식 (줄바꿈으로 구분, 설명 없이 본문만):
1줄: 40자 이내 한줄 운세
2줄: 오늘의 키워드 (쉼표로 1~3개)
3줄: 실천 가능한 행운 팁 한 줄
4~5줄: 2~3줄 응원 문장
'''
        : '''
You write gentle daily encouragement messages.
Date: $dateStr
$moodLine

Write today's happiness fortune. Avoid medical, financial, or relationship predictions.

Output format (line breaks only, no extra commentary):
Line 1: One-line fortune (max 40 chars)
Line 2: Keywords (1-3, comma-separated)
Line 3: One practical lucky tip
Lines 4-5: 2-3 lines of encouragement
''';

    return _generate(prompt, locale.startsWith('ko')
        ? '오늘도 작은 행운이 함께하길 바랍니다. 🍀'
        : 'May a little luck stay with you today. 🍀');
  }

  Future<AiResult> generateComfort({
    required String userMessage,
    required DateTime date,
    required String locale,
  }) async {
    final dateStr = locale.startsWith('ko')
        ? DateFormat('yyyy년 MM월 dd일', 'ko').format(date)
        : DateFormat('MMMM dd, yyyy', 'en').format(date);

    final crisisKeywords = [
      '자해',
      '자살',
      '죽고',
      '죽을',
      'suicide',
      'kill myself',
      'self-harm',
    ];
    final lower = userMessage.toLowerCase();
    if (crisisKeywords.any((k) => lower.contains(k))) {
      // 위기 안내는 AI를 부르지 않고, 사랑하기도 빼지 않습니다(무료).
      return AiResult.fallback(locale.startsWith('ko')
          ? '''지금 힘든 마음이 느껴져요.
혼자 견디지 않아도 됩니다.
전국 정신건강 위기상담전화 1577-0199 또는 1393(자살예방)으로 연락해 주세요.
당신의 안전이 가장 중요합니다.'''
          : '''It sounds like you are going through something very difficult.
You do not have to face this alone.
Please reach out to a local crisis helpline or someone you trust right away.
Your safety matters most.''');
    }

    final prompt = locale.startsWith('ko')
        ? '''
당신은 "행복담"이라는 따뜻한 위로 페르소나입니다.
날짜: $dateStr
사용자가 힘든 마음을 적었습니다:
$userMessage

4~8줄의 공감 위로 편지를 작성하세요.
- 1인칭에 가까운 따뜻한 톤
- 문학적 명언 스타일이 아닌, 나에게 말하는 느낌
- 의료·법률 조언 금지
- 설명 없이 편지만 출력
'''
        : '''
You are "Happiness Friend", a warm comfort persona.
Date: $dateStr
The user shared something difficult:
$userMessage

Write a 4-8 line empathetic comfort letter.
- Speak directly and warmly to the reader
- Not literary quotes; feel like a caring friend
- No medical or legal advice
- Output only the letter
''';

    return _generate(prompt, locale.startsWith('ko')
        ? '오늘 하루도 정말 수고 많았어요. 당신은 충분히 잘하고 있어요. 💌'
        : 'You did enough today. Be gentle with yourself. 💌');
  }

  /// AI 문장을 만듭니다. 실패하면 [fallback]을 기본 문장으로 돌려줍니다(isFallback = true).
  Future<AiResult> _generate(String prompt, String fallback) async {
    final apiKey = EnvironmentService.instance.get('GEMIN_API_KEY_SHOP');
    if (apiKey.isEmpty) {
      Logger.warn('GeminiShopService: API key missing');
      return AiResult.fallback(fallback);
    }

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await _callGeminiAPI(apiKey, prompt);
        if (response.isNotEmpty) return AiResult.generated(response);
        if (attempt < _maxRetries - 1) {
          await Future.delayed(_retryDelay * (attempt + 1));
        }
      } catch (e) {
        Logger.error('GeminiShopService: attempt ${attempt + 1} failed: $e');
        if (attempt == _maxRetries - 1) return AiResult.fallback(fallback);
        await Future.delayed(_retryDelay * (attempt + 1));
      }
    }
    return AiResult.fallback(fallback);
  }

  Future<String> _callGeminiAPI(String apiKey, String prompt) async {
    final modelName = _getModelName();
    final url = Uri.parse('$_baseUrl/$modelName:generateContent?key=$apiKey');

    final response = await http.post(
      url,
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
          'temperature': 0.8,
          'maxOutputTokens': 400,
        }
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates != null &&
          candidates.isNotEmpty &&
          candidates[0]['content']?['parts'] != null &&
          (candidates[0]['content']['parts'] as List).isNotEmpty) {
        return (candidates[0]['content']['parts'][0]['text'] as String).trim();
      }
    }
    throw Exception('Gemini API parse failed: ${response.statusCode}');
  }
}
