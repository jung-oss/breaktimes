/// AI가 만든 문장과, 그것이 기본 문장(AI 실패)인지 여부
class AiResult {
  const AiResult._(this.text, this.isFallback);

  /// AI가 만든 문장
  const AiResult.generated(String text) : this._(text, false);

  /// AI가 실패해 대신 쓰는 기본 문장. 사랑하기를 빼지 않습니다.
  const AiResult.fallback(String text) : this._(text, true);

  final String text;
  final bool isFallback;
}
