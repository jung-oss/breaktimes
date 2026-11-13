// lib/happiness_shop_2/screens/love_wallet_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';
import '../common/services/love_ledger.dart';
import '../common/theme/shop_tokens.dart';
import '../common/widgets/shop_widgets.dart';

/// 사랑하기 지갑: 잔액, 이번 주 받은·쓴 양, 오늘 받을 수 있는 것, 기록
class LoveWalletScreen extends StatelessWidget {
  const LoveWalletScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const LoveWalletScreen());

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final t = ShopTokens.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(title: Text(isKorean ? '사랑하기 지갑' : 'Love wallet')),
      body: uid == null
          ? _Message(
              text: isKorean ? '로그인이 필요해요.' : 'Please sign in first.',
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: firestore.collection('users').doc(uid).snapshots(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data() ?? const {};
                return StreamBuilder<List<LoveLedgerEntry>>(
                  stream: LoveLedger.stream(firestore, uid),
                  builder: (context, ledgerSnap) {
                    if (ledgerSnap.hasError) {
                      return _Message(
                        text: isKorean
                            ? '기록을 불러오지 못했어요. 잠시 후 다시 열어 주세요.'
                            : 'Could not load your history. Please try again shortly.',
                      );
                    }
                    final entries = ledgerSnap.data;
                    return _WalletBody(
                      isKorean: isKorean,
                      userData: userData,
                      entries: entries,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _WalletBody extends StatelessWidget {
  const _WalletBody({
    required this.isKorean,
    required this.userData,
    required this.entries,
  });

  final bool isKorean;
  final Map<String, dynamic> userData;

  /// null이면 아직 불러오는 중
  final List<LoveLedgerEntry>? entries;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final balance = (userData['heartCount'] as num?)?.toInt() ?? 0;

    // 이번 주(월요일부터) 받은 양·쓴 양
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    var earnedThisWeek = 0;
    var spentThisWeek = 0;
    for (final e in entries ?? const <LoveLedgerEntry>[]) {
      final at = e.createdAt;
      if (at == null || at.isBefore(weekStart)) continue;
      if (e.isEarn) {
        earnedThisWeek += e.amount;
      } else {
        spentThisWeek += e.amount;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _BalanceCard(
          isKorean: isKorean,
          balance: balance,
          earned: earnedThisWeek,
          spent: spentThisWeek,
        ),
        const SizedBox(height: 16),
        TodayLoveCard(isKorean: isKorean, userData: userData),
        const SizedBox(height: 24),
        Text(
          isKorean ? '기록' : 'History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 12),
        if (entries == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (entries!.isEmpty)
          _EmptyHistory(isKorean: isKorean)
        else
          ..._buildGroupedHistory(context, entries!),
        if (entries != null && entries!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            isKorean
                ? '2026년 11월 업데이트 전의 기록은 남아 있지 않아요.'
                : 'History before the November 2026 update is not available.',
            style: TextStyle(fontSize: 13, color: t.ink2),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildGroupedHistory(
      BuildContext context, List<LoveLedgerEntry> list) {
    final widgets = <Widget>[];
    String? currentDay;
    for (final entry in list) {
      final at = entry.createdAt ?? DateTime.now();
      final day = _dayLabel(at);
      if (day != currentDay) {
        currentDay = day;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 16, bottom: 8),
          child: Text(
            day,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ShopTokens.of(context).ink2,
            ),
          ),
        ));
      }
      widgets.add(_HistoryRow(isKorean: isKorean, entry: entry));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  String _dayLabel(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return isKorean ? '오늘' : 'Today';
    if (diff == 1) return isKorean ? '어제' : 'Yesterday';
    return isKorean
        ? '${at.month}월 ${at.day}일'
        : '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.isKorean,
    required this.balance,
    required this.earned,
    required this.spent,
  });

  final bool isKorean;
  final int balance;
  final int earned;
  final int spent;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(ShopShape.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: t.heart, size: 22),
              const SizedBox(width: 8),
              Text(
                isKorean ? '지금 사랑하기' : 'Love now',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.plum,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: isKorean ? '사랑하기 $balance개' : '$balance Love',
            excludeSemantics: true,
            child: Text(
              '$balance',
              // customFontFamily의 800 굵기는 티머니 둥근바람입니다
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: t.plum,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: t.plumSoft,
              borderRadius: BorderRadius.circular(ShopShape.button),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _WeekStat(
                    label: isKorean ? '이번 주 받은 양' : 'Earned this week',
                    value: '+$earned',
                  ),
                ),
                Container(width: 1, height: 32, color: t.line),
                Expanded(
                  child: _WeekStat(
                    label: isKorean ? '이번 주 쓴 양' : 'Used this week',
                    value: '-$spent',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: t.ink2)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: t.plum,
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.isKorean, required this.entry});

  final bool isKorean;
  final LoveLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final at = entry.createdAt ?? DateTime.now();
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final sign = entry.isEarn ? '+' : '-';

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(ShopShape.button + 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.isEarn ? t.sunSoft : t.plumSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              entry.isEarn ? Icons.favorite : Icons.card_giftcard,
              size: 20,
              color: entry.isEarn ? t.heart : t.plum,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.reason.label(isKorean),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isKorean
                      ? '$time · 남은 ${entry.balanceAfter}개'
                      : '$time · ${entry.balanceAfter} left',
                  style: TextStyle(fontSize: 13, color: t.ink2),
                ),
              ],
            ),
          ),
          Semantics(
            label: isKorean
                ? (entry.isEarn
                    ? '${entry.amount}개 받음'
                    : '${entry.amount}개 씀')
                : (entry.isEarn
                    ? 'Earned ${entry.amount}'
                    : 'Used ${entry.amount}'),
            excludeSemantics: true,
            child: Text(
              '$sign${entry.amount}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: entry.isEarn ? t.coralDeep : t.plum,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.isKorean});

  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(ShopShape.card),
      ),
      child: Text(
        isKorean
            ? '아직 기록이 없어요.\n사랑하기를 받거나 쓰면 여기에 남아요.\n(2026년 11월 업데이트 전의 기록은 남아 있지 않아요.)'
            : 'No history yet.\nEarning or using Love will show up here.\n(History before the November 2026 update is not available.)',
        style: TextStyle(fontSize: 14, height: 1.6, color: t.ink2),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: TextStyle(fontSize: 15, color: t.ink2),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
