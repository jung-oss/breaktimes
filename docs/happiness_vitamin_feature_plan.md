# 행복 비타민 - AI 명언/글귀 생성 기능 기획서

## 📋 목차
1. [기능 개요](#기능-개요)
2. [사용자 플로우](#사용자-플로우)
3. [기술 구조](#기술-구조)
4. [데이터 모델](#데이터-모델)
5. [API 호출 구조](#api-호출-구조)
6. [UI/UX 디자인](#uiux-디자인)
7. [구현 단계](#구현-단계)
8. [에러 처리 및 예외 상황](#에러-처리-및-예외-상황)

---

## 1. 기능 개요

### 1.1 핵심 기능
- 사용자가 오늘의 기분을 기록하면, AI(Gemini)가 해당 글을 분석하여 맞춤형 명언/글귀/문구를 생성
- 생성된 명언은 해당 날짜의 기록과 함께 저장되어 나중에 다시 볼 수 있음
- 행복 비타민 탭에서 알약 형태로 표시되며, 탭하면 상세 내용(원본 글 + AI 생성 명언) 확인 가능

### 1.2 목표
- 사용자의 감정 상태에 맞는 개인화된 위로와 격려 제공
- 긍정적인 메시지를 통해 사용자의 행복감 증진
- 기록을 다시 볼 때마다 새로운 관점과 인사이트 제공

---

## 2. 사용자 플로우

### 2.1 글 작성 플로우
```
1. 사용자가 "행복 비타민" 탭에서 빈 알약 슬롯 탭
2. 콘텐츠 타입 선택 (사진/영상/음악/명언 등)
3. 오늘의 기분/감정을 텍스트로 작성
4. 저장 버튼 클릭
   ↓
5. Firestore에 사용자 글 저장
   ↓
6. 백그라운드에서 Gemini API 호출
   - 입력: 날짜, 사용자 작성 글
   - 출력: 맞춤형 명언/글귀/문구
   ↓
7. 생성된 명언을 Firestore에 저장 (원본 글과 연결)
   ↓
8. UI 업데이트 (알약에 명언 아이콘 표시)
```

### 2.2 명언 확인 플로우
```
1. 사용자가 알약 슬롯 탭
2. 상세 화면 표시
   - 원본 글 (사용자가 작성한 내용)
   - AI 생성 명언 (Gemini가 생성한 내용)
   - 날짜 정보
3. 명언을 좋아요/공유 가능
```

### 2.3 히스토리 확인 플로우
```
1. 사용자가 "기록 보기" 탭 이동
2. 날짜별로 작성한 글과 명언 목록 표시
3. 각 항목을 탭하면 상세 내용 확인
```

---

## 3. 기술 구조

### 3.1 아키텍처
```
┌─────────────────────────────────────────┐
│         HappinessShopScreen             │
│  (행복 비타민 탭 - 알약 그리드)          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│      HappinessSlot (모델)               │
│  - 원본 글 (content)                    │
│  - AI 명언 (aiQuote)                    │
│  - 생성 날짜 (createdAt)                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│    HappinessShopService                 │
│  - 슬롯 저장/로드                       │
│  - Gemini API 호출                      │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│    GeminiQuoteService (신규)            │
│  - Gemini API 통신                      │
│  - 프롬프트 생성                        │
│  - 응답 파싱                             │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│    EnvironmentService                   │
│  - GEMIN_API_KEY_SHOP 가져오기           │
└─────────────────────────────────────────┘
```

### 3.2 주요 컴포넌트

#### 3.2.1 GeminiQuoteService (신규 생성)
- **역할**: Gemini API와의 통신 담당
- **주요 메서드**:
  - `generateQuote(String userContent, DateTime date)`: 명언 생성
  - `_buildPrompt(String userContent, DateTime date)`: 프롬프트 생성
  - `_parseResponse(String response)`: 응답 파싱

#### 3.2.2 HappinessSlot 모델 확장
- **기존 필드**: id, userId, slotIndex, type, title, isEmpty, content, colorIndex, createdAt, updatedAt
- **추가 필드**:
  - `aiQuote`: String? (AI가 생성한 명언)
  - `aiQuoteGeneratedAt`: DateTime? (명언 생성 시간)
  - `aiQuoteStatus`: String? ('pending', 'generated', 'failed')

#### 3.2.3 HappinessShopService 확장
- **추가 메서드**:
  - `generateQuoteForSlot(String slotId)`: 슬롯에 대한 명언 생성
  - `_saveQuoteToSlot(String slotId, String quote)`: 생성된 명언 저장

---

## 4. 데이터 모델

### 4.1 Firestore 구조

#### 4.1.1 happinessSlots 컬렉션
```javascript
{
  id: "slot_123",
  userId: "user_abc",
  slotIndex: 0,
  type: "quote", // 또는 "photo", "video", "music" 등
  title: "오늘의 감정",
  isEmpty: false,
  content: {
    text: "오늘은 정말 힘든 하루였다...",
    // 기타 타입별 데이터
  },
  colorIndex: 0,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  
  // AI 명언 관련 필드 (추가)
  aiQuote: "힘든 날에도 작은 행복이 있다는 것을 기억하세요. 🌟",
  aiQuoteGeneratedAt: Timestamp,
  aiQuoteStatus: "generated", // "pending", "generated", "failed"
  aiQuoteModel: "gemini-2.0-flash-lite", // 사용한 모델 정보
}
```

### 4.2 SlotContent 모델 확장
```dart
class SlotContent {
  final String? text;
  final String? imageUrl;
  final String? videoUrl;
  final String? musicUrl;
  // ... 기타 필드
  
  // AI 명언 필드 추가
  final String? aiQuote;
  final DateTime? aiQuoteGeneratedAt;
  final String? aiQuoteStatus;
}
```

---

## 5. API 호출 구조

### 5.1 Gemini API 호출 흐름

#### 5.1.1 프롬프트 템플릿
```
당신은 따뜻하고 긍정적인 명언을 만드는 전문가입니다.

사용자가 작성한 글:
날짜: {날짜}
내용: {사용자 작성 글}

위 글을 읽고, 사용자의 감정 상태를 이해한 후, 
따뜻하고 위로가 되는 명언이나 글귀를 한 문장으로 작성해주세요.

요구사항:
1. 사용자의 감정을 공감하고 이해하는 톤
2. 긍정적이지만 현실적인 메시지
3. 한 문장 (최대 100자)
4. 이모지 1-2개 포함 가능
5. 격려와 희망의 메시지

명언만 작성해주세요. 설명이나 추가 문구는 필요 없습니다.
```

#### 5.1.2 API 호출 코드 구조
```dart
class GeminiQuoteService {
  final String _apiKey;
  
  Future<String> generateQuote(
    String userContent,
    DateTime date,
  ) async {
    // 1. API 키 가져오기
    final apiKey = EnvironmentService.instance.get('GEMIN_API_KEY_SHOP');
    
    // 2. 프롬프트 생성
    final prompt = _buildPrompt(userContent, date);
    
    // 3. Gemini API 호출
    final response = await _callGeminiAPI(apiKey, prompt);
    
    // 4. 응답 파싱 및 반환
    return _parseResponse(response);
  }
  
  String _buildPrompt(String userContent, DateTime date) {
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(date);
    return '''
당신은 따뜻하고 긍정적인 명언을 만드는 전문가입니다.

사용자가 작성한 글:
날짜: $dateStr
내용: $userContent

위 글을 읽고, 사용자의 감정 상태를 이해한 후, 
따뜻하고 위로가 되는 명언이나 글귀를 한 문장으로 작성해주세요.

요구사항:
1. 사용자의 감정을 공감하고 이해하는 톤
2. 긍정적이지만 현실적인 메시지
3. 한 문장 (최대 100자)
4. 이모지 1-2개 포함 가능
5. 격려와 희망의 메시지

명언만 작성해주세요. 설명이나 추가 문구는 필요 없습니다.
''';
  }
}
```

### 5.2 에러 처리
- API 키 없음: 명언 생성 건너뛰기, 사용자에게 알림
- API 호출 실패: 재시도 로직 (최대 3회)
- 응답 파싱 실패: 기본 명언 제공 또는 재시도
- 네트워크 오류: 오프라인 상태 표시, 나중에 재시도

---

## 6. UI/UX 디자인

### 6.1 알약 슬롯 표시

#### 6.1.1 빈 슬롯
- 기존과 동일: 반투명 오버레이 + "+" 아이콘

#### 6.1.2 내용이 있는 슬롯
- 하단에 타입 아이콘 표시 (기존)
- **추가**: AI 명언이 생성된 경우 작은 별(⭐) 아이콘 표시

### 6.2 상세 화면 (SlotDetailScreen)

#### 6.2.1 레이아웃 구조
```
┌─────────────────────────────────┐
│  [뒤로가기]  슬롯 상세           │
├─────────────────────────────────┤
│                                 │
│  📅 2024년 1월 15일             │
│                                 │
│  ┌─────────────────────────┐   │
│  │  오늘의 기록             │   │
│  │                         │   │
│  │  [사용자가 작성한 글]    │   │
│  │  오늘은 정말 힘든...    │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  ✨ AI가 추천한 명언     │   │
│  │                         │   │
│  │  [AI 생성 명언]          │   │
│  │  힘든 날에도 작은 행복이 │   │
│  │  있다는 것을 기억하세요.🌟│   │
│  │                         │   │
│  │  [좋아요] [공유]         │   │
│  └─────────────────────────┘   │
│                                 │
│  [편집] [삭제]                  │
└─────────────────────────────────┘
```

#### 6.2.2 명언 생성 중 상태
- 로딩 인디케이터 표시
- "명언을 생성하고 있어요... ✨" 메시지

#### 6.2.3 명언 생성 실패 상태
- "명언 생성에 실패했습니다" 메시지
- "다시 시도" 버튼 제공

### 6.3 히스토리 화면 통합

#### 6.3.1 UnifiedEntryCard 확장
- AI 명언이 있는 경우 카드 하단에 명언 섹션 표시
- 접기/펼치기 가능

---

## 7. 구현 단계

### Phase 1: 기본 구조 설정
1. ✅ HappinessSlot 모델에 AI 명언 필드 추가
2. ✅ SlotContent 모델 확장
3. ✅ Firestore 스키마 업데이트

### Phase 2: Gemini API 통신
1. GeminiQuoteService 클래스 생성
2. EnvironmentService에서 GEMIN_API_KEY_SHOP 가져오기
3. 프롬프트 템플릿 작성
4. API 호출 및 응답 파싱 구현
5. 에러 처리 및 재시도 로직

### Phase 3: 서비스 통합
1. HappinessShopService에 명언 생성 메서드 추가
2. 슬롯 저장 시 백그라운드에서 명언 생성 트리거
3. 명언 저장 로직 구현

### Phase 4: UI 업데이트
1. SlotDetailScreen에 명언 섹션 추가
2. 알약 슬롯에 명언 아이콘 표시
3. 로딩/에러 상태 UI 구현
4. 히스토리 화면에 명언 통합

### Phase 5: 최적화 및 테스트
1. 성능 최적화 (캐싱, 배치 처리)
2. 사용자 테스트
3. 버그 수정 및 개선

---

## 8. 에러 처리 및 예외 상황

### 8.1 API 키 없음
- **상황**: GEMIN_API_KEY_SHOP이 설정되지 않음
- **처리**: 명언 생성 건너뛰기, 슬롯은 정상 저장
- **사용자 알림**: 없음 (백그라운드 처리)

### 8.2 API 호출 실패
- **상황**: 네트워크 오류, API 오류 등
- **처리**: 
  - 최대 3회 재시도 (지수 백오프)
  - 실패 시 `aiQuoteStatus: "failed"` 저장
  - 사용자에게 "다시 시도" 옵션 제공

### 8.3 응답 파싱 실패
- **상황**: Gemini 응답 형식이 예상과 다름
- **처리**: 
  - 기본 명언 제공: "오늘 하루도 수고하셨어요. 내일은 더 좋은 날이 될 거예요. 🌟"
  - 또는 재시도

### 8.4 오프라인 상태
- **상황**: 네트워크 연결 없음
- **처리**: 
  - 슬롯은 로컬에 저장
  - 명언 생성은 네트워크 복구 시 자동 재시도

### 8.5 사용자 글 없음
- **상황**: 텍스트 타입이 아닌 슬롯 (사진만, 영상만 등)
- **처리**: 
  - 텍스트가 있는 경우에만 명언 생성
  - 텍스트 없으면 명언 생성 건너뛰기

---

## 9. 추가 고려사항

### 9.1 프라이버시
- 사용자의 개인적인 감정 기록이므로 API 호출 시 민감 정보 처리 주의
- Gemini API 사용 약관 확인

### 9.2 비용 관리
- API 호출 횟수 모니터링
- 캐싱을 통한 불필요한 호출 방지
- 사용자당 일일 호출 제한 고려

### 9.3 사용자 경험
- 명언 생성은 백그라운드에서 비동기 처리
- 생성 완료 시 푸시 알림 (선택사항)
- 명언 재생성 기능 제공

### 9.4 다국어 지원
- 한국어/영어 프롬프트 분리
- 생성된 명언도 사용자 언어에 맞게

---

## 10. 성공 지표

1. **명언 생성 성공률**: 95% 이상
2. **API 응답 시간**: 평균 3초 이내
3. **사용자 만족도**: 명언 유용성 평가
4. **재방문율**: 명언을 다시 보기 위한 재방문 증가

---

## 11. 향후 확장 가능성

1. **명언 스타일 선택**: 격려형, 위로형, 동기부여형 등
2. **명언 공유 기능**: 다른 사용자와 명언 공유
3. **명언 컬렉션**: 좋아하는 명언 모아보기
4. **명언 통계**: 어떤 감정일 때 어떤 명언이 생성되었는지 분석

---

## 📝 참고사항

- Gemini API 문서: https://ai.google.dev/docs
- 기존 코드베이스 구조 참고: `lib/happiness_shop/`
- 디자인 참고: `lib/screens/relax/relax_main_screen.dart`, `relax_history_screen.dart`

