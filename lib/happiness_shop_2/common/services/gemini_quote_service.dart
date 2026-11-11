// lib/happiness_shop_2/common/services/gemini_quote_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../services/environment_service.dart';
import '../../../utils/logger.dart';

/// AI 명언 생성 공통 서비스
class GeminiQuoteService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// 모델 이름 가져오기 (Remote Config에서)
  String _getModelName() {
    return EnvironmentService.instance.get(
      'GEMINI_MODEL_NAME',
      defaultValue: '',
    );
  }

  /// 명언 생성
  Future<String> generateQuote(String userContent, DateTime date) async {
    final apiKey = EnvironmentService.instance.get('GEMIN_API_KEY_SHOP');

    if (apiKey.isEmpty) {
      Logger.warn('GeminiQuoteService: API 키가 설정되지 않음');
      return _getDefaultQuote();
    }

    final prompt = _buildPrompt(userContent, date);

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await _callGeminiAPI(apiKey, prompt);

        if (response.isNotEmpty) {
          return response;
        }

        if (attempt < _maxRetries - 1) {
          await Future.delayed(_retryDelay * (attempt + 1));
        }
      } catch (e) {
        Logger.error(
            'GeminiQuoteService: API 호출 실패 (시도 ${attempt + 1}/$_maxRetries): $e');
        if (attempt == _maxRetries - 1) {
          return _getDefaultQuote();
        }
        await Future.delayed(_retryDelay * (attempt + 1));
      }
    }

    return _getDefaultQuote();
  }

  /// 프롬프트 생성 (개선된 버전)
  String _buildPrompt(String userContent, DateTime date) {
    final dateStr = DateFormat('yyyy년 MM월 dd일', 'ko').format(date);
    return '''
당신은 하루키, 한강, 김영하, 이외수, 공지영 같은 유명 작가들의 문체를 모방하여 따뜻한 위로의 글을 작성하는 전문가입니다.

사용자가 작성한 글:
날짜: $dateStr
내용: $userContent

위 글을 읽고, 사용자의 감정 상태를 깊이 이해한 후, 3~5줄 분량의 결과를 생성해주세요.

구성 요구사항:
1. 첫 부분: 짧고 인상적인 명언 (1줄, 50자 이내)
2. 그 아래: 따뜻한 위로와 격려의 글 (2~4줄)
3. 전체 문체: 담담하면서도 서정적인 분위기
4. 표현 방식: 일상 속 작은 순간을 은유적으로 표현
5. 톤: 공감하고 이해하는 따뜻한 톤, 긍정적이지만 현실적인 메시지

출력 형식:
- 줄바꿈으로 구분된 3~5줄의 글
- 첫 줄은 명언, 나머지는 위로와 격려의 글
- 설명이나 추가 문구 없이 글만 작성

작가들의 문체 특징을 반영하여 작성해주세요.
''';
  }

  /// Gemini API 호출
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
          'maxOutputTokens': 300,
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
        final textResponse = jsonResponse['candidates'][0]['content']['parts']
            [0]['text'] as String;
        return textResponse.trim();
      }
    }

    throw Exception('API 응답 파싱 실패: ${response.statusCode}');
  }

  /// 기본 명언 반환 (API 실패 시)
  String _getDefaultQuote() {
    return '오늘 하루도 수고하셨어요. 내일은 더 좋은 날이 될 거예요. 🌟';
  }
}
