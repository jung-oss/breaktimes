# 행복상점 모듈화 구조 설계서

## 📋 목차
1. [폴더 구조](#폴더-구조)
2. [공통 모듈 (Common)](#공통-모듈-common)
3. [카테고리별 모듈](#카테고리별-모듈)
4. [메인 화면](#메인-화면)
5. [데이터 흐름](#데이터-흐름)

---

## 1. 폴더 구조

```
lib/happiness_shop_2/
├── common/                          # 공통 모듈
│   ├── models/
│   │   ├── base_category.dart      # 카테고리 기본 인터페이스
│   │   ├── category_item.dart      # 카테고리 아이템 모델
│   │   └── heart_info.dart         # 하트 정보 모델
│   ├── services/
│   │   ├── heart_service.dart      # 하트 관리 서비스
│   │   └── gemini_quote_service.dart # AI 명언 생성 서비스
│   └── widgets/
│       ├── pill_button.dart        # 알약 버튼 위젯
│       └── category_header.dart    # 카테고리 헤더
│
├── categories/                      # 카테고리별 모듈
│   ├── vitamin/                    # 행복 비타민 (기록)
│   │   ├── models/
│   │   │   ├── vitamin_slot.dart   # 비타민 슬롯 모델
│   │   │   └── vitamin_content.dart # 비타민 콘텐츠
│   │   ├── screens/
│   │   │   ├── vitamin_tab_screen.dart
│   │   │   ├── vitamin_detail_screen.dart
│   │   │   └── vitamin_add_screen.dart
│   │   ├── services/
│   │   │   └── vitamin_service.dart
│   │   └── widgets/
│   │       ├── vitamin_slot_grid.dart
│   │       └── vitamin_content_type_sheet.dart
│   │
│   ├── quotes/                     # 행복 글귀
│   │   ├── models/
│   │   │   └── quote_item.dart
│   │   ├── screens/
│   │   │   ├── quotes_tab_screen.dart
│   │   │   └── quote_detail_screen.dart
│   │   ├── services/
│   │   │   └── quotes_service.dart
│   │   └── widgets/
│   │       └── quote_card.dart
│   │
│   ├── music/                       # 행복 음악
│   ├── fortune/                     # 행복 운세
│   ├── comfort/                     # 행복 위로
│   ├── flowers/                     # 행복 꽃말
│   ├── recipe/                      # 행복 레시피
│   └── travel/                      # 행복 여행
│
└── screens/
    └── happiness_shop_screen.dart   # 메인 화면 (탭 컨트롤러)
```

---

## 2. 공통 모듈 (Common)

### 2.1 BaseCategory 인터페이스
모든 카테고리가 구현해야 하는 기본 인터페이스

```dart
abstract class BaseCategory {
  String get id;
  String get nameKo;
  String get nameEn;
  String get icon;
  String get subtitleKo;
  String get subtitleEn;
  
  Widget buildTabScreen(BuildContext context);
  Future<void> initialize();
}
```

### 2.2 HeartService
하트 관리 공통 서비스

```dart
class HeartService {
  Future<int> getHeartCount();
  Future<bool> useHearts(int amount);
  Stream<int> heartCountStream();
}
```

### 2.3 GeminiQuoteService
AI 명언 생성 공통 서비스

```dart
class GeminiQuoteService {
  Future<String> generateQuote(String userContent, DateTime date);
}
```

---

## 3. 카테고리별 모듈

### 3.1 Vitamin (행복 비타민)
- **기능**: 기존 슬롯 시스템 (기록 저장)
- **모델**: VitaminSlot, VitaminContent
- **서비스**: VitaminService (기존 HappinessShopService 기반)

### 3.2 Quotes (행복 글귀)
- **기능**: 좋은 글귀/명언 제공
- **모델**: QuoteItem
- **서비스**: QuotesService (Gemini API 활용)

### 3.3 Music (행복 음악)
- **기능**: 행복한 음악 추천
- **모델**: MusicItem
- **서비스**: MusicService

### 3.4 Fortune (행복 운세)
- **기능**: 오늘의 운세 제공
- **모델**: FortuneItem
- **서비스**: FortuneService (Gemini API 활용)

### 3.5 Comfort (행복 위로)
- **기능**: 위로 메시지 제공
- **모델**: ComfortItem
- **서비스**: ComfortService (Gemini API 활용)

### 3.6 Flowers (행복 꽃말)
- **기능**: 꽃과 꽃말 정보
- **모델**: FlowerItem
- **서비스**: FlowersService

### 3.7 Recipe (행복 레시피)
- **기능**: 행복한 레시피 제공
- **모델**: RecipeItem
- **서비스**: RecipeService

### 3.8 Travel (행복 여행)
- **기능**: 여행지 추천
- **모델**: TravelItem
- **서비스**: TravelService

---

## 4. 메인 화면

### 4.1 HappinessShopScreen
- TabController로 8개 카테고리 관리
- 각 카테고리의 buildTabScreen() 호출
- 하트 정보 표시

---

## 5. 데이터 흐름

```
HappinessShopScreen
    ↓
TabController (8개 탭)
    ↓
각 카테고리의 TabScreen
    ↓
카테고리별 Service
    ↓
Firestore / Gemini API
```

---

## 6. 구현 우선순위

1. **Phase 1**: 공통 모듈 + Vitamin 카테고리
2. **Phase 2**: Quotes, Fortune, Comfort (Gemini API 활용)
3. **Phase 3**: Music, Flowers, Recipe, Travel

