# Breaktimes

감정 기록·휴식·할 일 관리와 AI 기반 행복상점을 제공하는 Flutter 앱입니다.

## 주요 기능

| 모듈 | 설명 |
|------|------|
| **Relax** | 휴식/감정 기록, 히스토리, 분석, 북마크 |
| **Todo** | 할 일 관리, 히스토리, 분석 |
| **행복상점** | 하트 경제 기반 8개 카테고리 (비타민, 글귀, 음악, 운세, 위로, 꽃말, 레시피, 여행) |
| **Chat** | AI 챗봇 |
| **Settings** | 테마, 언어(ko/en), 알림 설정 |

## 기술 스택

- **Flutter** / Dart 3.6+
- **Firebase** — Auth, Firestore, Storage, Analytics, Remote Config, App Check
- **Google Gemini** — 행복상점 AI 생성 (글귀, 운세, 위로)
- **Provider** + **go_router**

## 프로젝트 구조

```
lib/
├── happiness_shop_2/     # 행복상점 모듈 (카테고리별 models/services/screens)
├── screens/              # Relax, Todo, Chat, Settings 등
├── providers/            # 상태 관리
├── services/             # Firebase, 알림, 환경 변수
└── routes/               # go_router 설정
```

설계 문서는 `docs/` 폴더를 참고하세요.

## 시작하기

### 1. 의존성 설치

```bash
flutter pub get
```

### 2. 환경 변수

프로젝트 루트에 `.env` 파일을 생성합니다 (`.env`는 git에 포함하지 마세요).

```
GEMIN_API_KEY_SHOP=your_gemini_api_key
GEMINI_MODEL_NAME=gemini-2.0-flash
```

Firebase 설정은 `lib/firebase_options.dart` 및 `android/app/google-services.json`을 사용합니다.

### 3. 실행

```bash
flutter run
```

## 행복상점 카테고리

| 카테고리 | 상태 | 비고 |
|----------|------|------|
| 비타민 | ✅ | 슬롯 기록 |
| 글귀 | ✅ | AI + 하트 |
| 운세 | ✅ | AI + 기분 칩 |
| 위로 | ✅ | AI 편지 |
| 음악·꽃말·레시피·여행 | ✅ | 카탈로그 + 로컬 폴백 |

## 테스트

```bash
flutter test
```

## 문서

- `docs/happiness_shop_2_structure.md` — 모듈 구조
- `docs/happiness_shop_coming_soon_integration.md` — 연동 설계
- `docs/happiness_shop_coming_soon_feature_plan.md` — 기능 기획

## 버전

`0.0.1+28` (pubspec.yaml 참고)
