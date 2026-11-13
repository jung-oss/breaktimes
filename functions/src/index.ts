// 행복-가게 서버 함수 (기획안 4단계)
//
// 사랑하기를 늘리거나 줄이는 일, AI 결과 만들기, 도감 모으기를 서버에서 처리합니다.
// - AI 키는 앱이 아니라 서버 비밀 저장소(GEMINI_SHOP_API_KEY)에 둡니다.
// - 잔액·결과·기록(love_ledger)을 한 트랜잭션으로 저장합니다.
// - 하루 사용 횟수는 앱이 고칠 수 없는 usage 컬렉션에 셉니다.
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp, Transaction, DocumentReference } from 'firebase-admin/firestore';
import { getRemoteConfig } from 'firebase-admin/remote-config';
import { setGlobalOptions } from 'firebase-functions/v2';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
import * as P from './prompts';
import catalogSeed from './catalog_seed.json';

initializeApp();
const db = getFirestore();

// 서울 지역에서 실행합니다(이미 있는 migrateTopics는 us-central1이며 건드리지 않습니다).
setGlobalOptions({ region: 'asia-northeast3', maxInstances: 10 });

const GEMINI_KEY = defineSecret('GEMINI_SHOP_API_KEY');

// ---------- 값 ----------

const COST: Record<string, number> = {
  fortune: 1, comfort: 1, quote: 1, music: 1, flowers: 1, recipe: 1, travel: 1,
};
const SLOT_PRICE = 5;
const DEFAULT_MAX_SLOTS = 20;
const SET_BONUS = 3;
const MAX_BONUS_SETS = 30;
const DEFAULT_DAILY_LIMIT = 3; // 항목마다 하루 횟수(Remote Config SHOP_DAILY_LIMIT로 바꿈)
const VITAMIN_AI_DAILY_LIMIT = 20; // 비타민 AI 글귀(무료) 하루 횟수
const QUOTE_EDIT_DAILY_LIMIT = 10; // 글귀 수정 후 다시 만들기(무료) 하루 횟수
const CATALOG_CATEGORIES = ['music', 'flowers', 'recipe', 'travel'];

const LEDGER_REASON: Record<string, string> = {
  fortune: 'fortune', comfort: 'comfort', quote: 'quote', music: 'music',
  flowers: 'flowers', recipe: 'recipe', travel: 'travel',
};

// ---------- 공통 도우미 ----------

function requireUid(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'NOT_LOGGED_IN');
  return uid;
}

function fail(code: string): never {
  throw new HttpsError('failed-precondition', code);
}

/** 한국 시간 기준 오늘 'YYYY-MM-DD' */
function kstToday(now = new Date()): string {
  return new Date(now.getTime() + 9 * 3600 * 1000).toISOString().slice(0, 10);
}

/** 한국 시간 기준 오늘 0시~24시 */
function kstDayRange(now = new Date()): { start: Date; end: Date } {
  const start = new Date(`${kstToday(now)}T00:00:00+09:00`);
  return { start, end: new Date(start.getTime() + 24 * 3600 * 1000 - 1) };
}

/** 앱이 보낸 "기기 기준 오늘 0시"를 받아 결과 문서의 date로 씁니다(지금과 36시간 넘게 차이 나면 한국 0시). */
function resultDayStart(raw: unknown): Date {
  if (typeof raw === 'number' && Number.isFinite(raw)) {
    const d = new Date(raw);
    if (Math.abs(Date.now() - d.getTime()) < 36 * 3600 * 1000) return d;
  }
  return kstDayRange().start;
}

function str(raw: unknown, max: number): string {
  if (typeof raw !== 'string') return '';
  return raw.trim().slice(0, max);
}

function heartsOf(data: FirebaseFirestore.DocumentData | undefined): number {
  const v = data?.heartCount;
  return typeof v === 'number' ? Math.trunc(v) : 0;
}

function userRef(uid: string): DocumentReference {
  return db.collection('users').doc(uid);
}

function usageRef(uid: string): DocumentReference {
  // 앱(보안 규칙)에서 쓸 수 없는 곳에 하루 사용 횟수를 셉니다.
  return db.collection('usage').doc(`${uid}_${kstToday()}`);
}

function writeLedger(
  tx: Transaction,
  uid: string,
  entry: { isEarn: boolean; amount: number; reason: string; balanceAfter: number; itemPath?: string },
): void {
  tx.set(userRef(uid).collection('love_ledger').doc(), {
    type: entry.isEarn ? 'earn' : 'spend',
    amount: entry.amount,
    reason: entry.reason,
    balanceAfter: entry.balanceAfter,
    ...(entry.itemPath ? { itemPath: entry.itemPath } : {}),
    source: 'server',
    createdAt: FieldValue.serverTimestamp(),
  });
}

// ---------- Remote Config (모델 이름, 하루 횟수) ----------

let configCache: { at: number; values: Record<string, string> } | null = null;

async function config(): Promise<Record<string, string>> {
  if (configCache && Date.now() - configCache.at < 10 * 60 * 1000) return configCache.values;
  const values: Record<string, string> = {};
  try {
    const template = await getRemoteConfig().getTemplate();
    for (const [key, param] of Object.entries(template.parameters)) {
      const dv = param.defaultValue as { value?: string } | undefined;
      if (dv?.value !== undefined) values[key] = dv.value;
    }
  } catch (e) {
    logger.warn('Remote Config 읽기 실패, 기본값을 씁니다', e);
  }
  configCache = { at: Date.now(), values };
  return values;
}

async function modelName(): Promise<string> {
  return (await config()).GEMINI_MODEL_NAME || 'gemini-2.0-flash';
}

async function dailyLimit(): Promise<number> {
  const n = Number((await config()).SHOP_DAILY_LIMIT);
  return Number.isFinite(n) && n > 0 ? n : DEFAULT_DAILY_LIMIT;
}

// ---------- Gemini ----------

/** AI 문장. 실패하면 null(그때는 기본 문장을 쓰고 사랑하기를 빼지 않습니다). */
async function generate(prompt: string): Promise<{ text: string; model: string } | null> {
  // 시험용: 에뮬레이터에서 SHOP_FAKE_AI=ok|fail 일 때만 가짜 결과를 씁니다(실제 서버에서는 무시).
  if (process.env.FUNCTIONS_EMULATOR === 'true' && process.env.SHOP_FAKE_AI) {
    return process.env.SHOP_FAKE_AI === 'ok' ? { text: `[시험] ${prompt.length}자 프롬프트 결과`, model: 'fake' } : null;
  }
  const key = GEMINI_KEY.value();
  if (!key) {
    logger.error('GEMINI_SHOP_API_KEY가 없습니다');
    return null;
  }
  const model = await modelName();
  const url = `https://generativelanguage.googleapis.com/v1/models/${model}:generateContent`;
  for (let attempt = 0; attempt < 2; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 20000);
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.8, maxOutputTokens: 400 },
        }),
        signal: controller.signal,
      });
      if (res.ok) {
        const json = (await res.json()) as {
          candidates?: { content?: { parts?: { text?: string }[] } }[];
        };
        const text = json.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
        if (text) return { text, model };
      } else {
        logger.warn(`Gemini 응답 ${res.status}`);
      }
    } catch (e) {
      logger.warn('Gemini 호출 실패', e);
    } finally {
      clearTimeout(timer);
    }
  }
  return null;
}

// ---------- 1. 오늘의 비타민 만들기(운세·위로·글귀) ----------

/**
 * 입력: { kind: 'fortune'|'comfort'|'quote', locale, dayStart(ms), mood?, text? }
 * 결과가 나온 뒤에 사랑하기 1개를 뺍니다. AI 실패·위기 안내는 무료입니다.
 */
export const shopCreateResult = onCall(
  { secrets: [GEMINI_KEY], timeoutSeconds: 60 },
  async (req) => {
    const uid = requireUid(req);
    const kind = str(req.data?.kind, 20);
    if (!['fortune', 'comfort', 'quote'].includes(kind)) {
      throw new HttpsError('invalid-argument', 'BAD_KIND');
    }
    const ko = !str(req.data?.locale, 10).startsWith('en');
    const dayStart = resultDayStart(req.data?.dayStart);
    const mood = str(req.data?.mood, 30) || undefined;
    const text = str(req.data?.text, 1000);
    if (kind === 'comfort' && text.length < 10) throw new HttpsError('invalid-argument', 'MESSAGE_TOO_SHORT');
    if (kind === 'quote' && text.length === 0) throw new HttpsError('invalid-argument', 'EMPTY_TEXT');

    const cost = COST[kind];
    const limit = await dailyLimit();

    // 먼저 잔액과 하루 횟수를 확인합니다(빼지는 않음).
    const [userSnap, usageSnap] = await Promise.all([userRef(uid).get(), usageRef(uid).get()]);
    if (heartsOf(userSnap.data()) < cost) fail('INSUFFICIENT_HEARTS');
    if ((usageSnap.data()?.[kind] ?? 0) >= limit) fail('DAILY_LIMIT');

    // AI 결과 만들기
    let content: string;
    let isFallback = false;
    let model = '';
    if (kind === 'comfort' && P.isCrisis(text)) {
      content = P.crisisMessage(ko);
      isFallback = true; // 위기 안내는 무료
    } else {
      const prompt = kind === 'fortune'
        ? P.fortunePrompt(dayStart, ko, mood)
        : kind === 'comfort'
          ? P.comfortPrompt(dayStart, ko, text)
          : P.quotePrompt(dayStart, text);
      const ai = await generate(prompt);
      if (ai) {
        content = ai.text;
        model = ai.model;
      } else {
        content = kind === 'fortune' ? P.fortuneFallback(ko)
          : kind === 'comfort' ? P.comfortFallback(ko) : P.quoteFallback();
        isFallback = true;
      }
    }

    const collection = kind === 'quote' ? 'quotes' : kind === 'comfort' ? 'comforts' : 'fortunes';
    const docRef = userRef(uid).collection(collection).doc();
    const now = Timestamp.now();

    const balanceAfter = await db.runTransaction(async (tx) => {
      const user = await tx.get(userRef(uid));
      const hearts = heartsOf(user.data());
      const charge = isFallback ? 0 : cost;
      if (hearts < charge) fail('INSUFFICIENT_HEARTS');

      const base = {
        userId: uid,
        date: Timestamp.fromDate(dayStart),
        createdAt: now,
        updatedAt: now,
        status: 'generated',
        model,
        isFallback,
        heartCost: cost,
        heartCharged: charge > 0,
        locale: ko ? 'ko' : 'en',
        source: 'server',
      };
      if (kind === 'fortune') {
        tx.set(docRef, { ...base, content, ...(mood ? { mood } : {}) });
      } else if (kind === 'comfort') {
        tx.set(docRef, { ...base, content, userMessage: text });
      } else {
        tx.set(docRef, {
          ...base,
          userThought: text,
          generatedQuote: '',
          comfortMessage: content,
          authorName: P.AUTHORS[Math.floor(Math.random() * P.AUTHORS.length)],
        });
      }
      // 하루 횟수는 실제로 사랑하기를 쓴 결과만 셉니다(AI 실패·위기 안내는 세지 않음).
      if (charge > 0) {
        tx.set(usageRef(uid), { [kind]: FieldValue.increment(1), uid, day: kstToday() }, { merge: true });
        tx.update(userRef(uid), { heartCount: hearts - charge, updatedAt: FieldValue.serverTimestamp() });
        writeLedger(tx, uid, {
          isEarn: false, amount: charge, reason: LEDGER_REASON[kind],
          balanceAfter: hearts - charge, itemPath: docRef.path,
        });
      }
      return hearts - charge;
    });

    return { id: docRef.id, isFallback, charged: !isFallback, balanceAfter };
  },
);

// ---------- 2. 글귀 수정 후 다시 만들기(무료) ----------

/** 입력: { quoteId, text }. 처음에 사랑하기를 낸 글귀는 다시 만들어도 무료입니다. */
export const shopRegenerateQuote = onCall(
  { secrets: [GEMINI_KEY], timeoutSeconds: 60 },
  async (req) => {
    const uid = requireUid(req);
    const quoteId = str(req.data?.quoteId, 200);
    const text = str(req.data?.text, 1000);
    if (!quoteId || !text) throw new HttpsError('invalid-argument', 'BAD_INPUT');

    const ref = userRef(uid).collection('quotes').doc(quoteId);
    const [snap, usage] = await Promise.all([ref.get(), usageRef(uid).get()]);
    if (!snap.exists) throw new HttpsError('not-found', 'NOT_FOUND');
    if ((usage.data()?.quoteEdit ?? 0) >= QUOTE_EDIT_DAILY_LIMIT) fail('DAILY_LIMIT');

    const date = (snap.data()?.date as Timestamp | undefined)?.toDate() ?? new Date();
    const ai = await generate(P.quotePrompt(date, text));
    const content = ai?.text ?? P.quoteFallback();

    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      const data = current.data() ?? {};
      const cost = typeof data.heartCost === 'number' ? data.heartCost : 0;
      const needCharge = cost > 0 && data.heartCharged !== true && ai !== null;
      const updates: Record<string, unknown> = {
        userThought: text,
        comfortMessage: content,
        status: 'generated',
        isFallback: ai === null,
        model: ai?.model ?? '',
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (needCharge) {
        // 예전에 기본 문장으로 받아 무료였던 글귀가 이번에 AI 글이 되면 그때 1개를 뺍니다.
        const user = await tx.get(userRef(uid));
        const hearts = heartsOf(user.data());
        if (hearts < cost) fail('INSUFFICIENT_HEARTS');
        tx.update(userRef(uid), { heartCount: hearts - cost, updatedAt: FieldValue.serverTimestamp() });
        writeLedger(tx, uid, { isEarn: false, amount: cost, reason: 'quote', balanceAfter: hearts - cost, itemPath: ref.path });
        updates.heartCharged = true;
      }
      tx.update(ref, updates);
      tx.set(usageRef(uid), { quoteEdit: FieldValue.increment(1), uid, day: kstToday() }, { merge: true });
    });
    return { id: quoteId, isFallback: ai === null };
  },
);

// ---------- 3. 도감 카드 모으기 ----------

interface CatalogItem {
  id: string;
  titleKo: string; titleEn: string; bodyKo: string; bodyEn: string;
  subtitleKo?: string; subtitleEn?: string;
  setId: string; setNameKo?: string; setNameEn?: string; order?: number;
}

/** Firestore shop_catalog가 있으면 그것을, 없으면 함께 올린 초안 목록을 씁니다(앱과 같은 규칙). */
async function loadCatalog(categoryId: string): Promise<CatalogItem[]> {
  const snap = await db.collection('shop_catalog').doc(categoryId).collection('items')
    .where('isActive', '==', true).get();
  if (!snap.empty) {
    return snap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        titleKo: data.titleKo ?? '', titleEn: data.titleEn ?? '',
        bodyKo: data.bodyKo ?? data.descriptionKo ?? '', bodyEn: data.bodyEn ?? data.descriptionEn ?? '',
        subtitleKo: data.subtitleKo, subtitleEn: data.subtitleEn,
        setId: data.setId ?? 'default', setNameKo: data.setNameKo, setNameEn: data.setNameEn,
        order: data.order ?? 0,
      };
    });
  }
  return ((catalogSeed as Record<string, CatalogItem[]>)[categoryId] ?? []);
}

/** 입력: { categoryId, itemId }. 결과: { balanceAfter, completedSetId?, bonusGranted } */
export const shopCollectCard = onCall(async (req) => {
  const uid = requireUid(req);
  const categoryId = str(req.data?.categoryId, 30);
  const itemId = str(req.data?.itemId, 200);
  if (!CATALOG_CATEGORIES.includes(categoryId) || !itemId) {
    throw new HttpsError('invalid-argument', 'BAD_INPUT');
  }
  const catalog = await loadCatalog(categoryId);
  const item = catalog.find((i) => i.id === itemId);
  if (!item) throw new HttpsError('not-found', 'NO_SUCH_CARD');

  const cost = COST[categoryId];
  const limit = await dailyLimit();
  const setItems = catalog.filter((i) => i.setId === item.setId).map((i) => i.id);
  const bonusKey = `${categoryId}__${item.setId}`;
  const collectionRef = userRef(uid).collection('collection');
  const cardRef = collectionRef.doc(`${categoryId}__${item.id}`);
  const legacyRef = userRef(uid).collection(`${categoryId}_picks`);

  return db.runTransaction(async (tx) => {
    const [user, card, owned, legacy, usage] = await Promise.all([
      tx.get(userRef(uid)),
      tx.get(cardRef),
      tx.get(collectionRef.where('categoryId', '==', categoryId)),
      tx.get(legacyRef),
      tx.get(usageRef(uid)),
    ]);
    const ownedIds = new Set<string>();
    owned.docs.forEach((d) => ownedIds.add(d.data().catalogId));
    legacy.docs.forEach((d) => ownedIds.add(d.data().catalogId));
    if (card.exists || ownedIds.has(item.id)) fail('ALREADY_OWNED');
    if ((usage.data()?.[categoryId] ?? 0) >= limit) fail('DAILY_LIMIT');

    const userData = user.data();
    let hearts = heartsOf(userData);
    if (hearts < cost) fail('INSUFFICIENT_HEARTS');

    hearts -= cost;
    tx.set(cardRef, {
      categoryId, catalogId: item.id, setId: item.setId,
      titleKo: item.titleKo, titleEn: item.titleEn, bodyKo: item.bodyKo, bodyEn: item.bodyEn,
      ...(item.subtitleKo ? { subtitleKo: item.subtitleKo } : {}),
      ...(item.subtitleEn ? { subtitleEn: item.subtitleEn } : {}),
      collectedAt: FieldValue.serverTimestamp(),
      source: 'server',
    });
    writeLedger(tx, uid, { isEarn: false, amount: cost, reason: LEDGER_REASON[categoryId], balanceAfter: hearts, itemPath: cardRef.path });
    tx.set(usageRef(uid), { [categoryId]: FieldValue.increment(1), uid, day: kstToday() }, { merge: true });

    // 묶음을 다 모았는지 서버가 직접 확인합니다.
    ownedIds.add(item.id);
    const complete = setItems.length > 0 && setItems.every((id) => ownedIds.has(id));
    const bonuses = (userData?.collectionBonuses ?? {}) as Record<string, unknown>;
    let bonusGranted = false;
    if (complete && !(bonusKey in bonuses) && Object.keys(bonuses).length < MAX_BONUS_SETS) {
      hearts += SET_BONUS;
      bonusGranted = true;
      writeLedger(tx, uid, { isEarn: true, amount: SET_BONUS, reason: 'collectionBonus', balanceAfter: hearts });
    }
    tx.update(userRef(uid), {
      heartCount: hearts,
      ...(bonusGranted ? { [`collectionBonuses.${bonusKey}`]: kstToday() } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { balanceAfter: hearts, completedSetId: complete ? item.setId : null, bonusGranted };
  });
});

// ---------- 4. 비타민 슬롯 늘리기 ----------

export const shopPurchaseSlot = onCall(async (req) => {
  const uid = requireUid(req);
  return db.runTransaction(async (tx) => {
    const user = await tx.get(userRef(uid));
    if (!user.exists) throw new HttpsError('not-found', 'NO_USER');
    const data = user.data();
    const hearts = heartsOf(data);
    const slots = typeof data?.slotCount === 'number' ? data.slotCount : 1;
    const maxSlots = typeof data?.maxSlots === 'number' ? data.maxSlots : DEFAULT_MAX_SLOTS;
    if (slots >= maxSlots) fail('MAX_SLOTS');
    if (hearts < SLOT_PRICE) fail('INSUFFICIENT_HEARTS');
    tx.update(userRef(uid), {
      heartCount: hearts - SLOT_PRICE,
      slotCount: slots + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
    writeLedger(tx, uid, { isEarn: false, amount: SLOT_PRICE, reason: 'vitaminSlot', balanceAfter: hearts - SLOT_PRICE });
    return { balanceAfter: hearts - SLOT_PRICE, slotCount: slots + 1 };
  });
});

// ---------- 5. 하루 보상 받기(서버가 조건을 확인) ----------

/**
 * 입력: { reason: 'dailyCheckIn'|'mission'|'happyBox' }
 * - mission: 오늘(한국 시간) 할 일이 1개 이상이고 모두 완료
 * - happyBox: 오늘 행복-함 글이 1개 이상
 * 결과: { awarded, balanceAfter }
 */
export const loveClaimDaily = onCall(async (req) => {
  const uid = requireUid(req);
  const reason = str(req.data?.reason, 20);
  if (!['dailyCheckIn', 'mission', 'happyBox'].includes(reason)) {
    throw new HttpsError('invalid-argument', 'BAD_REASON');
  }
  const today = kstToday();

  if (reason === 'mission') {
    const todos = await userRef(uid).collection('todos').where('date', '==', today).get();
    const real = todos.docs.filter((d) => d.data().initialized !== true);
    if (real.length === 0 || !real.every((d) => d.data().isCompleted === true)) fail('NOT_ELIGIBLE');
  } else if (reason === 'happyBox') {
    const { start, end } = kstDayRange();
    const moods = await userRef(uid).collection('moods')
      .where('date', '>=', Timestamp.fromDate(start))
      .where('date', '<=', Timestamp.fromDate(end))
      .limit(1).get();
    if (moods.empty) fail('NOT_ELIGIBLE');
  }

  return db.runTransaction(async (tx) => {
    const user = await tx.get(userRef(uid));
    if (!user.exists) throw new HttpsError('not-found', 'NO_USER');
    const data = user.data();
    const already = reason === 'dailyCheckIn'
      ? data?.lastHeartDate === today
      : (data?.heartRewards ?? {})[reason] === today;
    const hearts = heartsOf(data);
    if (already) return { awarded: false, balanceAfter: hearts };

    tx.update(userRef(uid), {
      heartCount: hearts + 1,
      ...(reason === 'dailyCheckIn' ? { lastHeartDate: today } : { [`heartRewards.${reason}`]: today }),
      updatedAt: FieldValue.serverTimestamp(),
    });
    writeLedger(tx, uid, { isEarn: true, amount: 1, reason, balanceAfter: hearts + 1 });
    return { awarded: true, balanceAfter: hearts + 1 };
  });
});

// ---------- 6. 비타민 슬롯 AI 글귀(무료, 하루 횟수 제한) ----------

/** 입력: { slotId }. 슬롯의 글(content.text)로 AI 글귀를 만들어 슬롯에 저장합니다. */
export const vitaminGenerateQuote = onCall(
  { secrets: [GEMINI_KEY], timeoutSeconds: 60 },
  async (req) => {
    const uid = requireUid(req);
    const slotId = str(req.data?.slotId, 200);
    if (!slotId) throw new HttpsError('invalid-argument', 'BAD_INPUT');

    const ref = db.collection('happiness_slots').doc(slotId);
    const [slot, usage] = await Promise.all([ref.get(), usageRef(uid).get()]);
    if (!slot.exists || slot.data()?.userId !== uid) throw new HttpsError('not-found', 'NOT_FOUND');
    if ((usage.data()?.vitamin ?? 0) >= VITAMIN_AI_DAILY_LIMIT) fail('DAILY_LIMIT');
    const text = str(slot.data()?.content?.text, 1000);
    if (!text) throw new HttpsError('invalid-argument', 'EMPTY_TEXT');

    await ref.update({ 'content.aiQuoteStatus': 'pending', updatedAt: FieldValue.serverTimestamp() });
    const ai = await generate(P.quotePrompt(new Date(), text));
    await ref.update({
      'content.aiQuote': ai?.text ?? P.quoteFallback(),
      'content.aiQuoteGeneratedAt': FieldValue.serverTimestamp(),
      'content.aiQuoteStatus': 'generated',
      'content.aiQuoteModel': ai?.model ?? '',
      updatedAt: FieldValue.serverTimestamp(),
    });
    await usageRef(uid).set({ vitamin: FieldValue.increment(1), uid, day: kstToday() }, { merge: true });
    return { isFallback: ai === null };
  },
);
