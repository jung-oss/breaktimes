# Firebase Firestore 구조 - 행복상점 (Happiness Shop)

## 📋 목차
1. [컬렉션 구조](#컬렉션-구조)
2. [데이터 모델 상세](#데이터-모델-상세)
3. [보안 규칙](#보안-규칙)
4. [인덱스 설정](#인덱스-설정)
5. [마이그레이션 가이드](#마이그레이션-가이드)

---

## 1. 컬렉션 구조

### 1.1 happinessSlots 컬렉션

**경로**: `/happinessSlots/{slotId}`

**설명**: 사용자의 행복 슬롯 정보를 저장하는 컬렉션

**문서 구조**:
```javascript
{
  // 기본 정보
  id: "slot_abc123",                    // 문서 ID (자동 생성)
  userId: "user_xyz789",                // 사용자 ID
  slotIndex: 0,                         // 슬롯 인덱스 (0-19)
  type: "quote",                        // 슬롯 타입: "music", "photo", "video", "videoUrl", "quote", "empty"
  title: "오늘의 감정",                  // 슬롯 제목
  isEmpty: false,                       // 빈 슬롯 여부
  colorIndex: 0,                        // 색상 인덱스 (0-7, 알약 이미지 매핑)
  
  // 콘텐츠 정보
  content: {
    // 공통 필드
    url: "https://...",                  // 음악/영상 URL
    text: "오늘은 정말 힘든 하루였다...", // 명언/텍스트 내용
    author: "작성자명",                  // 명언 출처
    
    // 사진 관련
    storageUrl: "gs://...",              // Firebase Storage 경로
    thumbnailUrl: "https://...",         // 썸네일 URL
    imageUrl: "https://...",            // 이미지 URL
    
    // 영상 관련
    compressedUrl: "https://...",        // 압축 영상 URL
    duration: 120,                       // 재생 시간 (초)
    width: 1920,                         // 너비 (픽셀)
    height: 1080,                        // 높이 (픽셀)
    fileSize: 5242880,                   // 파일 크기 (bytes)
    
    // AI 명언 관련 (신규 추가)
    aiQuote: "힘든 날에도 작은 행복이 있다는 것을 기억하세요. 🌟",  // AI 생성 명언
    aiQuoteGeneratedAt: Timestamp,      // 명언 생성 시간
    aiQuoteStatus: "generated",          // 명언 상태: "pending", "generated", "failed"
    aiQuoteModel: "gemini-2.0-flash-lite" // 사용한 AI 모델
  },
  
  // 타임스탬프
  createdAt: Timestamp,                 // 생성 시간
  updatedAt: Timestamp                   // 수정 시간
}
```

### 1.2 사용자별 서브컬렉션 구조 (선택사항)

**경로**: `/users/{userId}/happinessSlots/{slotId}`

**설명**: 사용자별로 슬롯을 관리하는 대안 구조 (현재는 루트 컬렉션 사용)

---

## 2. 데이터 모델 상세

### 2.1 SlotType Enum

```dart
enum SlotType {
  music,      // 음악
  photo,      // 사진
  video,      // 영상 파일
  videoUrl,   // 영상 URL
  quote,      // 명언/글귀
  empty,      // 빈 슬롯
}
```

### 2.2 AI 명언 상태 (aiQuoteStatus)

- `"pending"`: 명언 생성 대기 중
- `"generated"`: 명언 생성 완료
- `"failed"`: 명언 생성 실패

### 2.3 색상 인덱스 (colorIndex) → 알약 이미지 매핑

| colorIndex | 알약 이미지 파일 |
|------------|-----------------|
| 0 | `1_red_pill.png` |
| 1 | `2_orange_pill.png` |
| 2 | `3_yellow_pill.png` |
| 3 | `4_green_pill.png` |
| 4 | `5_blue_pill.png` |
| 5 | `6_navy_pill.png` |
| 6 | `7_purple_pill.png` |
| 7 | `8_colorfule_pill.png` |

---

## 3. 보안 규칙

### 3.1 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 행복 슬롯 컬렉션
    match /happinessSlots/{slotId} {
      // 읽기: 본인만 읽기 가능
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // 생성: 인증된 사용자만, 본인 ID로만 생성 가능
      allow create: if request.auth != null && 
                      request.resource.data.userId == request.auth.uid &&
                      request.resource.data.slotIndex is int &&
                      request.resource.data.slotIndex >= 0 &&
                      request.resource.data.slotIndex < 20;
      
      // 수정: 본인만 수정 가능
      allow update: if request.auth != null && 
                      resource.data.userId == request.auth.uid &&
                      // userId 변경 불가
                      request.resource.data.userId == resource.data.userId &&
                      // slotIndex 변경 불가
                      request.resource.data.slotIndex == resource.data.slotIndex;
      
      // 삭제: 본인만 삭제 가능
      allow delete: if request.auth != null && 
                      resource.data.userId == request.auth.uid;
    }
    
    // 사용자별 서브컬렉션 (선택사항)
    match /users/{userId}/happinessSlots/{slotId} {
      allow read, write: if request.auth != null && 
                            userId == request.auth.uid;
    }
  }
}
```

---

## 4. 인덱스 설정

### 4.1 복합 인덱스

Firebase Console에서 다음 인덱스를 생성해야 합니다:

#### 4.1.1 사용자별 슬롯 조회
```
컬렉션: happinessSlots
필드:
  - userId (Ascending)
  - slotIndex (Ascending)
```

#### 4.1.2 사용자별 최신 슬롯 조회
```
컬렉션: happinessSlots
필드:
  - userId (Ascending)
  - updatedAt (Descending)
```

#### 4.1.3 AI 명언 생성 상태별 조회 (선택사항)
```
컬렉션: happinessSlots
필드:
  - userId (Ascending)
  - content.aiQuoteStatus (Ascending)
  - updatedAt (Descending)
```

---

## 5. 마이그레이션 가이드

### 5.1 기존 데이터에 AI 명언 필드 추가

기존 슬롯 데이터에 AI 명언 필드를 추가하는 마이그레이션 스크립트:

```javascript
// Firebase Functions 또는 Admin SDK 사용
const admin = require('firebase-admin');
admin.initializeApp();

async function migrateSlots() {
  const db = admin.firestore();
  const slotsSnapshot = await db.collection('happinessSlots').get();
  
  const batch = db.batch();
  let count = 0;
  
  slotsSnapshot.forEach((doc) => {
    const data = doc.data();
    
    // content 객체에 AI 명언 필드가 없으면 추가
    if (!data.content.aiQuote) {
      const updatedContent = {
        ...data.content,
        aiQuote: null,
        aiQuoteGeneratedAt: null,
        aiQuoteStatus: data.content.text ? 'pending' : null,
        aiQuoteModel: null
      };
      
      batch.update(doc.ref, {
        content: updatedContent
      });
      count++;
    }
  });
  
  if (count > 0) {
    await batch.commit();
    console.log(`마이그레이션 완료: ${count}개 슬롯 업데이트`);
  } else {
    console.log('마이그레이션할 데이터가 없습니다.');
  }
}

migrateSlots();
```

### 5.2 Dart 코드에서 마이그레이션

```dart
// lib/happiness_shop/services/migration_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationService {
  static Future<void> migrateSlotsForUser(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final slotsSnapshot = await firestore
        .collection('happinessSlots')
        .where('userId', isEqualTo: userId)
        .get();
    
    final batch = firestore.batch();
    
    for (var doc in slotsSnapshot.docs) {
      final data = doc.data();
      final content = data['content'] as Map<String, dynamic>? ?? {};
      
      // AI 명언 필드가 없으면 추가
      if (!content.containsKey('aiQuote')) {
        final updatedContent = Map<String, dynamic>.from(content);
        updatedContent['aiQuote'] = null;
        updatedContent['aiQuoteGeneratedAt'] = null;
        updatedContent['aiQuoteStatus'] = 
            (content['text'] != null && content['text'].toString().isNotEmpty)
                ? 'pending'
                : null;
        updatedContent['aiQuoteModel'] = null;
        
        batch.update(doc.reference, {'content': updatedContent});
      }
    }
    
    await batch.commit();
  }
}
```

---

## 6. 쿼리 예시

### 6.1 사용자의 모든 슬롯 조회
```dart
final slotsSnapshot = await FirebaseFirestore.instance
    .collection('happinessSlots')
    .where('userId', isEqualTo: userId)
    .orderBy('slotIndex')
    .get();
```

### 6.2 사용자의 빈 슬롯 조회
```dart
final emptySlotsSnapshot = await FirebaseFirestore.instance
    .collection('happinessSlots')
    .where('userId', isEqualTo: userId)
    .where('isEmpty', isEqualTo: true)
    .get();
```

### 6.3 AI 명언 생성 대기 중인 슬롯 조회
```dart
final pendingSlotsSnapshot = await FirebaseFirestore.instance
    .collection('happinessSlots')
    .where('userId', isEqualTo: userId)
    .where('content.aiQuoteStatus', isEqualTo: 'pending')
    .get();
```

### 6.4 특정 슬롯 업데이트 (AI 명언 저장)
```dart
await FirebaseFirestore.instance
    .collection('happinessSlots')
    .doc(slotId)
    .update({
      'content.aiQuote': generatedQuote,
      'content.aiQuoteGeneratedAt': FieldValue.serverTimestamp(),
      'content.aiQuoteStatus': 'generated',
      'content.aiQuoteModel': 'gemini-2.0-flash-lite',
      'updatedAt': FieldValue.serverTimestamp(),
    });
```

---

## 7. 데이터 검증

### 7.1 필수 필드
- `userId`: 반드시 존재해야 함
- `slotIndex`: 0-19 범위 내
- `type`: 유효한 SlotType 값
- `isEmpty`: boolean
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

### 7.2 선택 필드
- `content.text`: 명언 타입일 때 권장
- `content.aiQuote`: AI 명언 생성 시 자동 추가
- `content.aiQuoteStatus`: AI 명언 생성 시 자동 설정

### 7.3 데이터 무결성
- `slotIndex`는 사용자당 고유해야 함 (중복 방지)
- `userId`는 생성 후 변경 불가
- `content.aiQuote`가 있으면 `content.text`도 있어야 함

---

## 8. 성능 최적화

### 8.1 캐싱 전략
- 사용자 슬롯 목록은 메모리 캐시 사용
- 캐시 유효 시간: 5분
- 슬롯 업데이트 시 캐시 무효화

### 8.2 배치 처리
- 여러 슬롯 업데이트 시 배치 쓰기 사용
- AI 명언 생성은 백그라운드에서 비동기 처리

### 8.3 인덱스 활용
- 자주 사용하는 쿼리에 대한 인덱스 생성
- 불필요한 쿼리 최소화

---

## 9. 모니터링 및 로깅

### 9.1 추적할 메트릭
- 슬롯 생성 수
- AI 명언 생성 성공률
- API 호출 실패율
- 평균 응답 시간

### 9.2 로깅 포인트
- 슬롯 생성/수정/삭제
- AI 명언 생성 시작/완료/실패
- API 호출 시도/성공/실패

---

## 10. 참고사항

- 모든 Timestamp는 서버 시간 사용 (`FieldValue.serverTimestamp()`)
- 사용자 ID는 Firebase Auth의 UID 사용
- 슬롯 인덱스는 0부터 시작하여 최대 19까지
- AI 명언은 최대 100자로 제한
- 이미지/영상 파일은 Firebase Storage에 저장

