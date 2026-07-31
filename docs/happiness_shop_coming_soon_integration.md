# 미완성 행복상점 카테고리 — 연동 구조

## 1. 목적

현재 **Coming soon**인 6개 카테고리(음악·운세·위로·꽃말·레시피·여행)를, 이미 동작 중인 **비타민·글귀**와 동일한 모듈/하트/Firebase/AI 파이프라인에 연결하기 위한 연동 설계서이다.

참고 구현:
- 모듈 골격: `lib/happiness_shop_2/`
- AI+하트 소비 레퍼런스: `categories/quotes/`
- 공통 하트: `common/services/heart_service.dart`, `heart_cost_service.dart`
- 앱 전역 음악 재생: `lib/providers/music_provider.dart`

---

## 2. 현재 상태

| 카테고리 | ID | 탭 등록 | UI | Service/Model | HeartCost | Firestore |
|----------|-----|---------|----|---------------|-----------|-----------|
| 비타민 | `vitamin` | ✅ | ✅ | ✅ | 슬롯 구매(5) | `happinessSlots` / users 슬롯 |
| 글귀 | `quotes` | ✅ | ✅ | ✅ | `QUOTE=1` | `users/{uid}/quotes` |
| 음악 | `music` | ✅ | Coming soon | ❌ | `MUSIC=1` (상수만) | 미연결 (`Storage/music`는 전역 플레이어용) |
| 운세 | `fortune` | ✅ | Coming soon | ❌ | `FORTUNE=1` | 미연결 |
| 위로 | `comfort` | ✅ | Coming soon | ❌ | `COMFORT=1` | 미연결 |
| 꽃말 | `flowers` | ✅ | Coming soon | ❌ | `FLOWERS=1` | 미연결 |
| 레시피 | `recipe` | ✅ | Coming soon | ❌ | `RECIPE=1` | 미연결 |
| 여행 | `travel` | ✅ | Coming soon | ❌ | `TRAVEL=1` | 미연결 |

탭·카테고리 클래스는 `HappinessShopScreen`에 이미 등록되어 있다. **연동 작업 = Service/Model/Screen 구현 + Firestore 스키마 + (필요 시) Gemini/콘텐츠 풀 연결**이다.

---

## 3. 전체 연동 아키텍처

```
MainScreen (Shop 탭)
    │
    ▼
HappinessShopScreen
    ├── HeartService ────────────── users/{uid}.heartCount (표시/스트림)
    ├── TabController (8)
    └── BaseCategory[]
            │
            ├─ VitaminCategory ── VitaminService ── happinessSlots / Storage
            ├─ QuotesCategory ─── QuotesService ─── users/{uid}/quotes + Gemini
            ├─ MusicCategory ──── MusicShopService ── catalog + unlock + MusicProvider
            ├─ FortuneCategory ── FortuneService ─── users/{uid}/fortunes + Gemini
            ├─ ComfortCategory ── ComfortService ─── users/{uid}/comforts + Gemini
            ├─ FlowersCategory ── FlowersService ─── catalog + users/{uid}/flowers
            ├─ RecipeCategory ─── RecipeService ──── catalog + users/{uid}/recipes
            └─ TravelCategory ─── TravelService ──── catalog + users/{uid}/travels
                            │
                            ├── HeartCostService (소비)
                            ├── GeminiShopService (확장 권장: 카테고리별 프롬프트)
                            └── EnvironmentService (GEMIN_API_KEY_SHOP, GEMINI_MODEL_NAME)
```

### 3.1 진입점 (이미 존재)

```
lib/happiness_shop_2/screens/happiness_shop_screen.dart
  → List<BaseCategory> 에 Music~Travel 포함
  → category.buildTabScreen(context)
  → category.initialize()
```

### 3.2 카테고리 계약 (`BaseCategory`)

모든 미완성 카테고리는 이미 구현체를 갖고 있다. 연동 시 **탭 화면만 교체**하면 된다.

| 메서드 | 역할 |
|--------|------|
| `id` | 라우팅·분석·하트 로그 키 |
| `nameKo/nameEn`, `subtitle*`, `icon` | 탭 UI |
| `buildTabScreen` | 실제 기능 화면 |
| `initialize` | 카탈로그 프리페치, Remote Config 등 |

---

## 4. 공통 연동 레이어

### 4.1 하트 소비

```
UI 액션 (열기/뽑기/생성)
    → HeartCostService.checkAndSpendHearts(HeartCost.XXX)
    → HeartService.useHearts (Firestore transaction on users/{uid})
    → 성공 시 콘텐츠 생성/언락
    → 실패 시 INSUFFICIENT_HEARTS → 하트 부족 UI
```

| 상수 (`HeartCost`) | 기본값 | 사용 시점 |
|--------------------|--------|-----------|
| `MUSIC` | 1 | 트랙 언락 또는 오늘의 추천 받기 |
| `FORTUNE` | 1 | 오늘의 운세 생성 |
| `COMFORT` | 1 | 위로 메시지 생성 |
| `FLOWERS` | 1 | 꽃말 카드 뽑기/저장 |
| `RECIPE` | 1 | 레시피 추천 받기 |
| `TRAVEL` | 1 | 여행지 추천 받기 |

> Vitamin 슬롯 구매(5하트)는 `VitaminService` 자체 로직을 유지. 미완성 카테고리는 Quotes와 동일하게 `HeartCostService`를 사용한다.

### 4.2 AI (Gemini)

| 구분 | 경로 |
|------|------|
| API 키 | `EnvironmentService` → `GEMIN_API_KEY_SHOP` |
| 모델 | `GEMINI_MODEL_NAME` (Remote Config) |
| 기존 서비스 | `common/services/gemini_quote_service.dart` (글귀 전용 프롬프트) |

**권장 확장**: `GeminiQuoteService`를 `GeminiShopService`로 일반화하거나, 카테고리별 `*_prompt.dart`를 두고 공통 HTTP/재시도 레이어만 공유한다.

```
generateContent(categoryId, userInput, locale, date)
    → 카테고리별 프롬프트 선택
    → Gemini HTTP (재시도 3회)
    → 파싱 → 카테고리 모델
```

### 4.3 콘텐츠 공급 방식 (카테고리별)

| 유형 | 카테고리 | 소스 |
|------|----------|------|
| A. AI 생성형 | fortune, comfort | Gemini + 사용자 입력/기분 |
| B. 카탈로그 + 하트 언락 | music, flowers, recipe, travel | Firestore 공용 컬렉션 + 사용자 언락 기록 |
| C. 하이브리드 | flowers, recipe, travel | 카탈로그 랜덤 + (선택) AI 한 줄 코멘트 |

Quotes는 **A 유형**(사용자 생각 → AI 글귀)이다. 미완성 중 Fortune/Comfort는 A, Music/Flowers/Recipe/Travel은 B 또는 C를 권장한다.

### 4.4 앱 내 기존 자산 재사용

| 기존 자산 | 연동 포인트 |
|-----------|-------------|
| `MusicProvider` | Storage `music/` + 로컬 assets 재생. Shop Music은 **언락 목록 → MusicProvider 재생 큐 연동** |
| `LocaleProvider` | ko/en 탭·본문 분기 |
| `Theme` (dark/light) | Coming soon 화면과 동일 그라데이션 패턴 유지 |
| Todo/Relax 기분·주제 | Fortune/Comfort 입력 프리필(선택 연동) |

---

## 5. Firestore 연동 스키마

### 5.1 공용 카탈로그 (읽기 전용, 관리자 쓰기)

```
shop_catalog/
  music/{trackId}
  flowers/{flowerId}
  recipes/{recipeId}
  travels/{travelId}
```

공통 필드 예시:
```javascript
{
  id: "...",
  titleKo: "...",
  titleEn: "...",
  subtitleKo: "...",
  subtitleEn: "...",
  imageUrl: "...",          // Storage 또는 HTTPS
  tags: ["calm", "morning"],
  isActive: true,
  sortOrder: 0,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

카테고리별 추가 필드:
- **music**: `storagePath`, `durationSec`, `mood`
- **flowers**: `flowerNameKo/En`, `meaningKo/En`, `colorHint`
- **recipes**: `ingredients[]`, `steps[]`, `timeMinutes`, `difficulty`
- **travels**: `placeKo/En`, `region`, `tipKo/En`, `lat`, `lng` (선택)

### 5.2 사용자 서브컬렉션 (쓰기: 본인만)

```
users/{uid}/
  music_unlocks/{trackId}      // 언락 이력
  fortunes/{docId}             // AI 운세 결과
  comforts/{docId}             // AI 위로 결과
  flowers/{docId}              // 뽑은/저장한 꽃말
  recipes/{docId}              // 받은/저장한 레시피
  travels/{docId}              // 받은/저장한 여행 추천
```

상태 필드 (AI형, Quotes와 동일 패턴):
```javascript
{
  status: "pending" | "generated" | "failed",
  model: "...",
  createdAt: Timestamp,
  updatedAt: Timestamp,
  // 카테고리별 payload
}
```

### 5.3 하트·일일 제한 (권장)

```
users/{uid}/shop_usage/{yyyyMMdd}
{
  music: 0,
  fortune: 0,
  comfort: 0,
  flowers: 0,
  recipe: 0,
  travel: 0,
  updatedAt: Timestamp
}
```

일일 상한은 Remote Config로 조정 (`SHOP_DAILY_LIMIT_*`).

### 5.4 보안 규칙 요지

```
match /shop_catalog/{category}/{docId} {
  allow read: if request.auth != null;
  allow write: if isAdmin();
}

match /users/{userId}/{sub}/{docId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

---

## 6. 카테고리별 연동 상세

### 6.1 Music (행복 음악)

```
MusicTabScreen
  → MusicShopService
       ├─ loadCatalog()           // shop_catalog/music
       ├─ unlockTrack(id)         // HeartCost.MUSIC → music_unlocks
       ├─ getUnlockedTracks()
       └─ play(track)             // MusicProvider.playFromUrl / asset
```

- **연동 핵심**: Shop에서 언락한 트랙만 재생 가능하도록 게이트, 또는 미리듣기 15초 + 언락 후 전체 재생.
- Storage 경로 `music/`은 이미 `MusicProvider`가 사용 중 → 카탈로그 문서는 Storage 경로를 가리키면 됨.

### 6.2 Fortune (행복 운세)

```
FortuneTabScreen
  → FortuneService.createTodayFortune(mood?, birthHint?)
       → HeartCost.FORTUNE
       → users/{uid}/fortunes (pending)
       → Gemini (운세 프롬프트)
       → status=generated
```

- **일 1회** 권장: 같은 날짜 문서가 있으면 재생성에만 하트 추가 소모.
- Relax/Todo의 오늘 기분 필드를 선택적으로 프리필.

### 6.3 Comfort (행복 위로)

```
ComfortTabScreen
  → ComfortService.createComfort(userMessage)
       → HeartCost.COMFORT
       → users/{uid}/comforts
       → Gemini (위로 전용 프롬프트, Quotes와 톤 분리)
```

- Quotes는 “작가 문체 글귀”, Comfort는 “직접적 공감·위로”로 **프롬프트만 분리**하고 HTTP 레이어는 공유.
- 히스토리 리스트 + 상세 화면은 Quotes 패턴 복제.

### 6.4 Flowers (행복 꽃말)

```
FlowersTabScreen
  → FlowersService.drawFlower()
       → HeartCost.FLOWERS
       → shop_catalog/flowers 중 가중 랜덤
       → users/{uid}/flowers 저장
       → (선택) Gemini 한 줄 응원 메시지
```

### 6.5 Recipe (행복 레시피)

```
RecipeTabScreen
  → RecipeService.recommend(mood?, timeBudget?)
       → HeartCost.RECIPE
       → 카탈로그 필터/랜덤 또는 Gemini 간단 레시피
       → users/{uid}/recipes
```

### 6.6 Travel (행복 여행)

```
TravelTabScreen
  → TravelService.recommend(mood?, season?)
       → HeartCost.TRAVEL
       → 카탈로그 또는 Gemini “가까운/상상 여행”
       → users/{uid}/travels
```

---

## 7. 권장 폴더 구조 (구현 시)

```
lib/happiness_shop_2/categories/
  music/
    music_category.dart          # 유지
    models/music_item.dart
    services/music_shop_service.dart
    screens/music_tab_screen.dart # Coming soon → 실화면
    widgets/...
  fortune/
    models/fortune_item.dart
    services/fortune_service.dart
    screens/fortune_tab_screen.dart
    screens/fortune_history_screen.dart
  comfort/  (동일 패턴)
  flowers/  (동일 패턴)
  recipe/   (동일 패턴)
  travel/   (동일 패턴)

common/services/
  gemini_shop_service.dart       # (신규 권장) 카테고리별 프롬프트 디스패치
  heart_cost_service.dart        # 상수 유지, 필요 시 Remote Config 연동
```

---

## 8. UI 연동 패턴 (Quotes 복제)

모든 AI/뽑기형 카테고리 공통 UX:

1. **메인 탭**: 오늘 결과 카드 + CTA(“하트 1개로 받기”)
2. **작성/선택 모달**: 짧은 입력(기분, 메시지, 필터)
3. **로딩**: `status=pending` 스트림 구독
4. **결과**: 본문 + 저장일 + 재시도(실패 시)
5. **히스토리**: 날짜순 리스트
6. **하트 부족**: SnackBar + 하트 획득 안내(로그인/미션 연동은 별도)

Music만 재생 컨트롤(재생/정지/루프)을 `MusicProvider`와 공유.

---

## 9. Remote Config / 환경 키

| 키 | 용도 |
|----|------|
| `GEMIN_API_KEY_SHOP` | Shop AI 공통 |
| `GEMINI_MODEL_NAME` | 모델명 |
| `SHOP_FEATURE_MUSIC` 등 | 카테고리 노출 플래그 (false면 Coming soon 유지) |
| `SHOP_DAILY_LIMIT_FORTUNE` 등 | 일일 횟수 |
| `SHOP_HEART_COST_*` | 하트 비용 오버라이드 (선택) |

피처 플래그로 **카탈로그/서비스 준비된 카테고리만 순차 오픈**할 수 있다.

---

## 10. 구현 시 데이터 흐름 예시 (Fortune)

```
사용자: [오늘의 운세 받기]
  → canAfford(1)? 
  → spendHearts(1)
  → fortunes/{id} set pending
  → Gemini generate
  → update generated | failed
  → Tab StreamBuilder 갱신
  → heartCountStream 헤더 하트 갱신
```

실패 시: 하트 환불 정책은 Quotes와 동일하게 **기본 미환불**(문서에 명시). 필요 시 `failed` + 환불 트랜잭션을 Phase 2에서 추가.

---

## 11. 분석/로깅 이벤트 (권장)

| 이벤트 | 파라미터 |
|--------|----------|
| `shop_category_open` | `category_id` |
| `shop_spend_heart` | `category_id`, `cost`, `success` |
| `shop_generate_start/success/fail` | `category_id`, `latency_ms` |
| `shop_music_unlock` | `track_id` |
| `shop_music_play` | `track_id`, `source=shop` |

---

## 12. 의존 관계 체크리스트

- [ ] `HappinessShopScreen` 탭 등록 (완료)
- [ ] `BaseCategory` 메타데이터 (완료)
- [ ] `HeartCost` 상수 (완료)
- [ ] TabScreen 실기능 UI
- [ ] Service + Model
- [ ] Firestore 컬렉션/규칙/인덱스
- [ ] Gemini 프롬프트 (AI형)
- [ ] 카탈로그 시드 데이터 (카탈로그형)
- [ ] `MusicProvider` 연동 (Music만)
- [ ] Remote Config 피처 플래그
- [ ] ko/en 카피
- [ ] 하트 부족·네트워크 실패 UX

---

## 13. 관련 문서

- 모듈 골격: `docs/happiness_shop_2_structure.md`
- 비타민·슬롯 Firestore: `docs/firebase_structure_happiness_shop.md`
- 글귀/명언: `docs/firebase_structure_daily_quotes.md`
- 비타민 AI 기획: `docs/happiness_vitamin_feature_plan.md`
- **본 카테고리 기획**: `docs/happiness_shop_coming_soon_feature_plan.md`
