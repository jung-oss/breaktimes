# Firebase 구조 - 오늘의 명언 (Daily Quotes)

## 컬렉션: `daily_quotes`

관리자가 오늘의 명언을 관리하는 컬렉션입니다.

### 문서 구조

```json
{
  "id": "auto-generated-id",
  "quote": "오늘 하루도 수고하셨어요. 내일은 더 좋은 날이 될 거예요.",
  "author": "나비잠",
  "source": "나비잠 앱",
  "date": "2024-01-15T00:00:00Z", // Timestamp
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z", // Timestamp
  "updatedAt": "2024-01-15T10:00:00Z", // Timestamp
  "createdBy": "admin-user-id",
  "language": "ko" // "ko" 또는 "en"
}
```

### 필드 설명

- `quote` (string, required): 명언/글귀 내용
- `author` (string, required): 작가 이름
- `source` (string, optional): 출처
- `date` (Timestamp, optional): 표시할 날짜 (오늘 날짜와 매칭). 없으면 최신 명언 표시
- `isActive` (boolean, required): 활성화 여부 (false면 표시 안 함)
- `createdAt` (Timestamp, required): 생성 시간
- `updatedAt` (Timestamp, required): 수정 시간
- `createdBy` (string, optional): 생성한 관리자 ID
- `language` (string, optional): 언어 코드 ("ko" 또는 "en")

**중요**: `date` 필드가 없으면 가장 최근에 생성된 활성 명언이 표시됩니다.

### Firestore 인덱스

다음 인덱스가 필요합니다 (선택사항):

1. `date` (Ascending) + `isActive` (Ascending) - date 필드를 사용하는 경우
2. `isActive` (Ascending) + `createdAt` (Descending) - date 필드가 없는 경우

**참고**: `date` 필드 없이도 작동하지만, 특정 날짜에 특정 명언을 표시하려면 `date` 필드를 추가하세요.

### 보안 규칙 예시

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // daily_quotes 컬렉션
    match /daily_quotes/{quoteId} {
      // 모든 사용자가 읽기 가능
      allow read: if request.auth != null;
      
      // 관리자만 쓰기 가능 (admin 역할 체크)
      allow write: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 관리자 관리 방법

1. Firebase Console에서 `daily_quotes` 컬렉션에 문서 추가
2. `date` 필드에 오늘 날짜 설정
3. `isActive`를 `true`로 설정
4. `quote`와 `author` 필드 작성

### 예시 문서

**date 필드 포함 (특정 날짜에 표시):**
```json
{
  "quote": "작은 행복을 모으면 큰 행복이 됩니다.",
  "author": "나비잠",
  "source": "나비잠 앱",
  "date": "2024-01-15T00:00:00Z",
  "isActive": true,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-01-15T10:00:00Z",
  "language": "ko"
}
```

**date 필드 없음 (항상 최신 명언 표시):**
```json
{
  "quote": "어영부영 하다가 내 그럴 줄 알았다.",
  "author": "조지버나드쇼",
  "source": "명언",
  "isActive": true,
  "createdAt": "2025-11-27T06:47:28Z",
  "updatedAt": "2025-11-27T06:47:43Z",
  "createdBy": "admin-user-id",
  "language": "ko"
}
```

**참고**: `date` 필드가 없으면 가장 최근에 생성된 활성 명언이 표시됩니다.

