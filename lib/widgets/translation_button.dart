import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/environment_service.dart';

/// 텍스트 번역 버튼 위젯
///
/// 한국어 <-> 영어 번역 기능을 제공합니다.
/// 현재 언어가 한국어면 영어로, 영어면 한국어로 번역합니다.
class TranslationButton extends StatefulWidget {
  /// 번역할 원본 텍스트
  final String originalText;

  /// 현재 앱 언어가 한국어인지 여부
  final bool isKorean;

  /// 번역된 텍스트가 변경될 때 호출되는 콜백
  final Function(String translatedText, bool isTranslated) onTranslationChanged;

  /// 컴팩트 모드 여부
  final bool compact;

  const TranslationButton({
    super.key,
    required this.originalText,
    required this.isKorean,
    required this.onTranslationChanged,
    this.compact = false,
  });

  @override
  State<TranslationButton> createState() => _TranslationButtonState();
}

class _TranslationButtonState extends State<TranslationButton> {
  bool _isTranslated = false;
  bool _isTranslating = false;

  /// 텍스트가 비어있는지 확인하는 헬퍼 함수
  bool _isContentEmpty(String content) {
    return content.trim().isEmpty;
  }

  /// 텍스트가 이미 한국어와 영어 모두 포함하고 있는지 확인하는 헬퍼 함수
  bool _isContentInBothLanguages(String content) {
    // 한글 문자 포함 여부 확인 (유니코드 범위: AC00-D7A3)
    final hasKorean = RegExp(r'[\uAC00-\uD7A3]').hasMatch(content);

    // 영어 알파벳 포함 여부 확인
    final hasEnglish = RegExp(r'[a-zA-Z]').hasMatch(content);

    // 한글과 영어가 모두 충분히 포함되어 있는지 확인
    if (hasKorean && hasEnglish) {
      final koreanCharCount =
          RegExp(r'[\uAC00-\uD7A3]').allMatches(content).length;
      final englishCharCount = RegExp(r'[a-zA-Z]').allMatches(content).length;

      // 두 언어가 모두 일정 비율(20%) 이상 포함되어 있으면 이미 번역된 것으로 간주
      final totalLength = content.length;
      return (koreanCharCount / totalLength > 0.2) &&
          (englishCharCount / totalLength > 0.2);
    }

    return false;
  }

  /// 번역 함수
  Future<void> _translateContent() async {
    if (_isTranslating) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final apiKey = Env.geminiApiKey;
      if (apiKey.isEmpty) {
        throw Exception('API key is empty');
      }

      final model = GenerativeModel(
        model: Env.geminiModelName,
        apiKey: apiKey,
      );

      // 콘텐츠 언어 자동 감지 및 번역을 위한 프롬프트
      final targetLang = widget.isKorean ? '한국어' : 'English';
      final prompt = '''
      Translate the following text to $targetLang:
      
      ${widget.originalText}
      
      Only provide the translation without any additional text or explanation.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final translatedText = response.text;

      if (translatedText != null && translatedText.isNotEmpty) {
        setState(() {
          _isTranslated = true;
          _isTranslating = false;
        });
        widget.onTranslationChanged(translatedText, true);
      } else {
        throw Exception('Translation failed');
      }
    } catch (e) {
      print('번역 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isKorean
              ? '번역 중 오류가 발생했습니다.'
              : 'Error occurred during translation.'),
        ),
      );
      setState(() {
        _isTranslating = false;
      });
    }
  }

  /// 원본 텍스트로 복원
  void _restoreOriginalText() {
    setState(() {
      _isTranslated = false;
    });
    widget.onTranslationChanged(widget.originalText, false);
  }

  @override
  Widget build(BuildContext context) {
    // 번역 버튼을 표시할지 여부 결정
    final shouldShowButton = !_isContentEmpty(widget.originalText) &&
        !_isContentInBothLanguages(widget.originalText);

    if (!shouldShowButton) {
      return const SizedBox.shrink();
    }

    if (_isTranslating) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return IconButton(
      icon: Icon(
        _isTranslated ? Icons.language_outlined : Icons.translate,
        size: widget.compact ? 18 : 24,
        // 앱 테마의 기본 색상 적용
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: _isTranslated
          ? (widget.isKorean ? '원본보기' : 'Original')
          : (widget.isKorean ? '번역하기' : 'Translate'),
      onPressed: _isTranslating ? null : _toggleTranslation,
      // 컴팩트 모드일 때 패딩과 크기 조정
      padding: widget.compact ? const EdgeInsets.all(4) : null,
      constraints: widget.compact
          ? const BoxConstraints(minWidth: 32, minHeight: 32)
          : null,
      visualDensity:
          widget.compact ? VisualDensity.compact : VisualDensity.standard,
    );
  }

  void _toggleTranslation() {
    if (_isTranslated) {
      _restoreOriginalText();
    } else {
      _translateContent();
    }
  }
}

/// 번역 상태 표시 위젯
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
    if (!isTranslated) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.translate,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            isKorean ? 'Translated to English' : '한국어 번역됨',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
