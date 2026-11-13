// AI 프롬프트와 기본 문장 (앱의 gemini_shop_service / gemini_quote_service에서 옮김)

export const AUTHORS = ['하루키', '한강', '김영하', '이외수', '공지영'];

function dateLabel(dayStart: Date, ko: boolean): string {
  // dayStart는 사용자 기기 기준 자정. 한국 시간으로 날짜를 적습니다.
  const k = new Date(dayStart.getTime() + 9 * 3600 * 1000);
  const y = k.getUTCFullYear();
  const m = k.getUTCMonth() + 1;
  const d = k.getUTCDate();
  if (ko) return `${y}년 ${String(m).padStart(2, '0')}월 ${String(d).padStart(2, '0')}일`;
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'];
  return `${months[m - 1]} ${String(d).padStart(2, '0')}, ${y}`;
}

export function fortunePrompt(dayStart: Date, ko: boolean, mood?: string): string {
  const date = dateLabel(dayStart, ko);
  const moodLine = mood ? (ko ? `오늘 기분: ${mood}` : `Today's mood: ${mood}`) : '';
  return ko
    ? `당신은 따뜻한 하루 응원 메시지를 전하는 작가입니다.
날짜: ${date}
${moodLine}

오늘의 행복 운세를 작성해주세요. 점술·재물·관계 단정은 금지합니다.

출력 형식 (줄바꿈으로 구분, 설명 없이 본문만):
1줄: 40자 이내 한줄 운세
2줄: 오늘의 키워드 (쉼표로 1~3개)
3줄: 실천 가능한 행운 팁 한 줄
4~5줄: 2~3줄 응원 문장
`
    : `You write gentle daily encouragement messages.
Date: ${date}
${moodLine}

Write today's happiness fortune. Avoid medical, financial, or relationship predictions.

Output format (line breaks only, no extra commentary):
Line 1: One-line fortune (max 40 chars)
Line 2: Keywords (1-3, comma-separated)
Line 3: One practical lucky tip
Lines 4-5: 2-3 lines of encouragement
`;
}

export function fortuneFallback(ko: boolean): string {
  return ko ? '오늘도 작은 행운이 함께하길 바랍니다.' : 'May a little luck stay with you today.';
}

const CRISIS_KEYWORDS = ['자해', '자살', '죽고', '죽을', 'suicide', 'kill myself', 'self-harm'];

export function isCrisis(text: string): boolean {
  const lower = text.toLowerCase();
  return CRISIS_KEYWORDS.some((k) => lower.includes(k));
}

export function crisisMessage(ko: boolean): string {
  return ko
    ? `지금 힘든 마음이 느껴져요.
혼자 견디지 않아도 됩니다.
전국 정신건강 위기상담전화 1577-0199 또는 1393(자살예방)으로 연락해 주세요.
당신의 안전이 가장 중요합니다.`
    : `It sounds like you are going through something very difficult.
You do not have to face this alone.
Please reach out to a local crisis helpline or someone you trust right away.
Your safety matters most.`;
}

export function comfortPrompt(dayStart: Date, ko: boolean, message: string): string {
  const date = dateLabel(dayStart, ko);
  return ko
    ? `당신은 "행복담"이라는 따뜻한 위로 페르소나입니다.
날짜: ${date}
사용자가 힘든 마음을 적었습니다:
${message}

4~8줄의 공감 위로 편지를 작성하세요.
- 1인칭에 가까운 따뜻한 톤
- 문학적 명언 스타일이 아닌, 나에게 말하는 느낌
- 의료·법률 조언 금지
- 설명 없이 편지만 출력
`
    : `You are "Happiness Friend", a warm comfort persona.
Date: ${date}
The user shared something difficult:
${message}

Write a 4-8 line empathetic comfort letter.
- Speak directly and warmly to the reader
- Not literary quotes; feel like a caring friend
- No medical or legal advice
- Output only the letter
`;
}

export function comfortFallback(ko: boolean): string {
  return ko
    ? '오늘 하루도 정말 수고 많았어요. 당신은 충분히 잘하고 있어요.'
    : 'You did enough today. Be gentle with yourself.';
}

export function quotePrompt(dayStart: Date, content: string): string {
  const date = dateLabel(dayStart, true);
  return `당신은 하루키, 한강, 김영하, 이외수, 공지영 같은 유명 작가들의 문체를 모방하여 따뜻한 위로의 글을 작성하는 전문가입니다.

사용자가 작성한 글:
날짜: ${date}
내용: ${content}

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
`;
}

export function quoteFallback(): string {
  return '오늘 하루도 수고하셨어요. 내일은 더 좋은 날이 될 거예요.';
}
