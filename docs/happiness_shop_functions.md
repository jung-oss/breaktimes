# 행복-가게 서버 함수(기획안 4단계)

작성일: 2026-11-14
위치: `functions/` (TypeScript, Node.js 22). 묶음 이름(codebase)은 `shop`이고, 지역은 서울(`asia-northeast3`)입니다.

이미 배포된 `migrateTopics`(us-central1)는 이 저장소에 코드가 없습니다. 그래서 다른 묶음(`shop`)으로 나눠, 이 함수를 배포할 때 `migrateTopics`가 지워지거나 바뀌지 않게 했습니다.

---

## 1. 함수 목록

| 함수 | 하는 일 | 사랑하기 |
| --- | --- | --- |
| `shopCreateResult` | 운세·위로·글귀를 AI로 만들어 저장 | 결과가 나오면 -1. AI 실패·위기 안내는 무료 |
| `shopRegenerateQuote` | 글귀를 고친 뒤 다시 만들기 | 무료(처음에 무료였던 글귀가 이번에 AI 글이 되면 그때 -1) |
| `shopCollectCard` | 도감 카드 모으기, 묶음 완성 확인 | -1, 완성하면 +3 |
| `shopPurchaseSlot` | 비타민 슬롯 늘리기 | -5 |
| `loveClaimDaily` | 하루 보상(출석·미션 100%·행복-함) | +1. 미션·행복-함은 **서버가 조건을 직접 확인** |
| `vitaminGenerateQuote` | 비타민 슬롯 AI 글귀 | 무료(하루 20번) |

**공통 규칙**
- 잔액·결과·기록(`love_ledger`, `source: 'server'`)을 한 트랜잭션으로 저장합니다.
- 하루 횟수는 `usage/{uid}_{날짜}`에 셉니다. 앱이 쓸 수 없는 곳(보안 규칙상 거부)입니다.
  - 운세·위로·글귀·카드: 각각 하루 3번. Remote Config `SHOP_DAILY_LIMIT`로 바꿀 수 있습니다.
  - 글귀 다시 만들기: 하루 10번
  - 비타민 AI 글귀: 하루 20번
- 오류 코드(앱에서 구분): `NOT_LOGGED_IN`, `INSUFFICIENT_HEARTS`, `DAILY_LIMIT`, `ALREADY_OWNED`, `MAX_SLOTS`, `NOT_ELIGIBLE`, `NO_SUCH_CARD`
- AI 키는 서버 비밀 저장소의 `GEMINI_SHOP_API_KEY`에 둡니다. 모델 이름은 Remote Config `GEMINI_MODEL_NAME`에서 읽고, 없으면 `gemini-2.0-flash`를 씁니다.
- 날짜는 한국 시간 기준입니다.

## 2. 시험(에뮬레이터)

2026-11-14에 Auth·Firestore·Functions 에뮬레이터에서 25건을 시험했고, 모두 통과했습니다.
- 로그인 확인
- 하루 보상 조건(할 일이 남아 있거나 오늘 글이 없으면 거부)
- AI 결과 저장과 차감, 위기 안내는 무료
- 하루 횟수 상한, 같은 카드 거부, 묶음 완성 보너스
- 슬롯 늘리기, 부족할 때 거부, 남의 슬롯 거부
- 모든 변화가 기록에 남는지, 앱이 사용 횟수를 고칠 수 없는지

에뮬레이터에서만 쓰는 시험 설정이 있습니다.
- 파일: `functions/.env.local`(`SHOP_FAKE_AI`), `functions/.secret.local`
- 둘 다 `.gitignore`에 들어 있어 저장소와 배포에 포함되지 않습니다.
- 코드도 에뮬레이터가 아닐 때는 이 설정을 무시합니다.

## 3. 전환 순서

옛 앱은 사랑하기를 직접 바꿉니다. 그래서 한 번에 바꾸지 않고 세 단계로 나눕니다.

| 단계 | 할 일 | 누가 |
| --- | --- | --- |
| A | 서버 비밀 저장소에 가게용 Gemini 키 넣기 | **사람**(아래 명령, 키는 직접 붙여 넣기) |
| B | 서버 함수 배포 | 승인 후 진행 |
| C | 앱이 서버 함수를 쓰도록 바꾸고 새 버전 배포 | 개발 → 기기 확인 → 스토어 배포 |
| D | 사용자 대부분이 새 앱으로 바꾸면 보안 규칙 잠그기 | 승인 후 진행 |

D에서 잠그는 것:
- 앱은 `heartCount`·`slotCount`·보상 표시·완성 표시를 직접 바꿀 수 없습니다.
- `love_ledger`·`collection`은 읽기만 합니다.
- 가게 결과(운세·위로·글귀)는 지우기만 할 수 있습니다.

**A 명령**(프로젝트 폴더에서 실행하면 키를 묻습니다. 키는 화면에 남기지 마세요):

```bash
firebase functions:secrets:set GEMINI_SHOP_API_KEY --project breaktime-e7483
```

**함께 할 일:** D가 끝나면 Remote Config의 `GEMIN_API_KEY_SHOP`을 지우고, Google 콘솔에서 그 키를 폐기(새로 발급)합니다. 그동안 앱 안에 있던 키라서 이미 밖으로 새어 나갔을 수 있기 때문입니다.

## 4. 남은 것

- 채팅·번역 화면은 아직 앱이 다른 키(`GEMINI_API_KEY`)로 AI를 직접 부릅니다. 같은 방식으로 옮기는 일은 다음에 합니다.
- App Check 강제는 아직 켜지 않았습니다. 앱 쪽 App Check 설정을 확인한 뒤 함수 옵션 `enforceAppCheck`를 켭니다.
- `migrateTopics`의 코드 위치와 누가 호출할 수 있는지 확인이 필요합니다.
