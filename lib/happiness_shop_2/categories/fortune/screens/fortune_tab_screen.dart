import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../services/fortune_service.dart';
import '../models/fortune_item.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/theme/shop_tokens.dart';
import '../../../common/widgets/shop_widgets.dart';
import 'fortune_history_screen.dart';

class FortuneTabScreen extends StatefulWidget {
  const FortuneTabScreen({super.key});

  @override
  State<FortuneTabScreen> createState() => _FortuneTabScreenState();
}

class _FortuneTabScreenState extends State<FortuneTabScreen> {
  final FortuneService _service = FortuneService();
  StreamSubscription<List<FortuneItem>>? _watch;
  FortuneItem? _todayFortune;
  String? _selectedMood;
  bool _isSubmitting = false;

  static const _moodsKo = ['고요', '설렘', '피곤', '응원'];
  static const _moodsEn = ['Calm', 'Excited', 'Tired', 'Cheer'];

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  Future<void> _loadToday() async {
    final item = await _service.getTodayFortune();
    if (mounted) setState(() => _todayFortune = item);
    if (item != null && item.status == 'pending') {
      // 앱이 꺼져 멈춘 운세를 이어서 만듭니다(사랑하기는 완성될 때 빠짐)
      await _service.resumeIfPending(item);
      if (mounted) _watchFortune(item.id);
    }
  }

  Future<void> _receiveFortune({bool regenerate = false}) async {
    final locale =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    final isKorean = locale == 'ko';

    try {
      final ok = await confirmLoveSpend(
        context,
        isKorean: isKorean,
        categoryId: 'fortune',
        title: regenerate
            ? (isKorean ? '운세를 다시 받을까요?' : 'Get a new fortune?')
            : (isKorean ? '운세를 받을까요?' : 'Get your fortune?'),
        subtitle: _selectedMood == null
            ? null
            : (isKorean ? '기분: $_selectedMood' : 'Mood: $_selectedMood'),
        cost: HeartCost.FORTUNE,
        chargeAfterResult: true,
      );
      if (!ok || !mounted) return;

      setState(() => _isSubmitting = true);
      final item = await _service.createTodayFortune(
        locale: locale,
        mood: _selectedMood,
        forceRegenerate: regenerate,
      );
      if (!mounted) return;
      setState(() {
        _todayFortune = item;
        _isSubmitting = false;
      });
      if (item != null) _watchFortune(item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showShopError(context, e, isKorean);
    }
  }

  /// 결과가 바뀌는 것을 지켜봅니다(이전 구독은 정리)
  void _watchFortune(String id) {
    _watch?.cancel();
    _watch = _service.getUserFortunesStream().listen((list) {
      for (final fortune in list) {
        if (fortune.id == id) {
          if (mounted) setState(() => _todayFortune = fortune);
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final t = ShopTokens.of(context);
    final fortune = _todayFortune;
    final hasToday = fortune != null;

    return ColoredBox(
      color: t.ground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isKorean ? '오늘의 운세' : "Today's fortune",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                      ),
                    ),
                  ),
                  LovePriceTag(cost: HeartCost.FORTUNE, isKorean: isKorean),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: ShopShape.minTouch,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FortuneHistoryScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(foregroundColor: t.coralDeep),
                      child: Text(isKorean ? '받은 기록' : 'History'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isKorean ? '오늘 기분은 어때요?' : 'How do you feel today?',
                style: TextStyle(fontSize: 15, color: t.ink2),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_moodsKo.length, (i) {
                  final mood = isKorean ? _moodsKo[i] : _moodsEn[i];
                  final selected = _selectedMood == mood;
                  return ChoiceChip(
                    label: Text(mood),
                    selected: selected,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? t.coralDeep : t.ink,
                    ),
                    backgroundColor: t.surface,
                    selectedColor: t.coralSoft,
                    side: BorderSide(
                      color: selected ? t.coralDeep : t.line,
                      width: selected ? 1.5 : 1,
                    ),
                    shape: const StadiumBorder(),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) {
                      setState(() => _selectedMood = selected ? null : mood);
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: !hasToday
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShopArt.pill('fortune', size: 96, radius: 24),
                            const SizedBox(height: 16),
                            Text(
                              isKorean
                                  ? '오늘의 작은 행운을 편지로 받아 보세요.'
                                  : "Receive today's little luck as a letter.",
                              style: TextStyle(fontSize: 15, color: t.ink2),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _FortuneCard(
                        fortune: fortune,
                        isKorean: isKorean,
                        onRetry: () => _receiveFortune(regenerate: true),
                      ),
              ),
              const SizedBox(height: 12),
              LoveButton(
                isLoading: _isSubmitting,
                onPressed: fortune?.status == 'pending'
                    ? null
                    : () => _receiveFortune(regenerate: hasToday),
                label: hasToday
                    ? (isKorean
                        ? '사랑하기 ${HeartCost.FORTUNE}개로 다시 받기'
                        : 'New fortune for ${HeartCost.FORTUNE} Love')
                    : (isKorean
                        ? '사랑하기 ${HeartCost.FORTUNE}개로 받기'
                        : 'Get it for ${HeartCost.FORTUNE} Love'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FortuneCard extends StatelessWidget {
  final FortuneItem fortune;
  final bool isKorean;
  final VoidCallback onRetry;

  const _FortuneCard({
    required this.fortune,
    required this.isKorean,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (fortune.status == 'pending') {
      return Align(
        alignment: Alignment.topCenter,
        child: ShopStatusView.pending(isKorean: isKorean),
      );
    }
    if (fortune.status == 'failed') {
      return Align(
        alignment: Alignment.topCenter,
        child: ShopStatusView.failed(isKorean: isKorean, onRetry: onRetry),
      );
    }
    final t = ShopTokens.of(context);
    final date = fortune.date;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(ShopShape.card),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.successSoft,
                  borderRadius: BorderRadius.circular(ShopShape.chip),
                ),
                child: Text(
                  isKorean ? '도착했어요' : 'Arrived',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.onSuccessSoft,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                [
                  isKorean
                      ? '${date.month}월 ${date.day}일'
                      : '${date.month}/${date.day}',
                  if (fortune.mood != null) fortune.mood!,
                ].join(' · '),
                style: TextStyle(fontSize: 13, color: t.ink2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                fortune.content,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.75,
                  color: t.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
