import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../services/fortune_service.dart';
import '../models/fortune_item.dart';
import '../../../common/services/heart_cost_service.dart';
import 'fortune_history_screen.dart';

class FortuneTabScreen extends StatefulWidget {
  const FortuneTabScreen({super.key});

  @override
  State<FortuneTabScreen> createState() => _FortuneTabScreenState();
}

class _FortuneTabScreenState extends State<FortuneTabScreen> {
  final FortuneService _service = FortuneService();
  FortuneItem? _todayFortune;
  String? _selectedMood;
  bool _hasEnoughHearts = true;
  bool _isSubmitting = false;

  static const _moodsKo = ['고요', '설렘', '피곤', '응원'];
  static const _moodsEn = ['Calm', 'Excited', 'Tired', 'Cheer'];

  @override
  void initState() {
    super.initState();
    _loadToday();
    _checkHearts();
  }

  Future<void> _loadToday() async {
    final item = await _service.getTodayFortune();
    if (mounted) setState(() => _todayFortune = item);
  }

  Future<void> _checkHearts() async {
    final ok = await HeartCostService().canAfford(HeartCost.FORTUNE);
    if (mounted) setState(() => _hasEnoughHearts = ok);
  }

  Future<void> _receiveFortune({bool regenerate = false}) async {
    final locale =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    final isKorean = locale == 'ko';
    setState(() => _isSubmitting = true);
    try {
      final item = await _service.createTodayFortune(
        locale: locale,
        mood: _selectedMood,
        forceRegenerate: regenerate,
      );
      if (mounted) {
        setState(() {
          _todayFortune = item;
          _isSubmitting = false;
        });
        _checkHearts();
        _watchFortune(item!.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(e, isKorean);
    }
  }

  void _watchFortune(String id) {
    _service.getUserFortunesStream().listen((list) {
      FortuneItem? updated;
      for (final fortune in list) {
        if (fortune.id == id) {
          updated = fortune;
          break;
        }
      }
      if (updated != null && mounted) {
        setState(() => _todayFortune = updated);
      }
    });
  }

  void _showError(Object e, bool isKorean) {
    final msg = e.toString();
    String text;
    if (msg.contains('INSUFFICIENT_HEARTS')) {
      text = isKorean ? '하트가 부족해요.' : 'Insufficient hearts.';
    } else if (msg.contains('NOT_LOGGED_IN')) {
      text = isKorean ? '로그인이 필요합니다.' : 'Please sign in first.';
    } else {
      text = isKorean
          ? '잠시 문제가 생겼어요. 다시 시도해 주세요.'
          : 'Something went wrong. Please try again.';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isKorean =
        Provider.of<LocaleProvider>(context).locale.languageCode == 'ko';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasToday = _todayFortune != null;

    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? LinearGradient(
                colors: [Colors.grey[900]!, Colors.grey[850]!],
              )
            : LinearGradient(
                colors: [Colors.green.shade50, Colors.white],
              ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isKorean ? '🍀 행복 운세' : '🍀 Happiness Fortune',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FortuneHistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(isKorean ? '히스토리' : 'History'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: List.generate(4, (i) {
                  final mood = isKorean ? _moodsKo[i] : _moodsEn[i];
                  final selected = _selectedMood == mood;
                  return FilterChip(
                    label: Text(mood),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedMood = selected ? null : mood;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: hasToday
                    ? _FortuneCard(fortune: _todayFortune!, isKorean: isKorean)
                    : Center(
                        child: Text(
                          isKorean
                              ? '오늘의 작은 행운을 받아보세요.'
                              : 'Receive today\'s gentle fortune.',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
              ),
              if (_isSubmitting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                ),
              ElevatedButton(
                onPressed: _isSubmitting || (!_hasEnoughHearts && !hasToday)
                    ? null
                    : () => _receiveFortune(regenerate: hasToday),
                child: Text(
                  hasToday
                      ? (isKorean
                          ? '다시 받기 (하트 ${HeartCost.FORTUNE}개)'
                          : 'Regenerate (${HeartCost.FORTUNE} Hearts)')
                      : (isKorean
                          ? '오늘의 운세 받기 (하트 ${HeartCost.FORTUNE}개)'
                          : 'Get Fortune (${HeartCost.FORTUNE} Hearts)'),
                ),
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

  const _FortuneCard({required this.fortune, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    if (fortune.status == 'pending') {
      return _StatusBox(
        isKorean
            ? '마음을 담아 준비 중이에요…'
            : 'Preparing your fortune…',
        showProgress: true,
      );
    }
    if (fortune.status == 'failed') {
      return _StatusBox(
        isKorean
            ? '잠시 문제가 생겼어요. 다시 시도해 주세요.'
            : 'Something went wrong. Please try again.',
      );
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Text(
            fortune.content,
            style: const TextStyle(fontSize: 16, height: 1.7),
          ),
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final String text;
  final bool showProgress;

  const _StatusBox(this.text, {this.showProgress = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showProgress) const CircularProgressIndicator(),
          if (showProgress) const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
