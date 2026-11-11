import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../services/comfort_service.dart';
import '../models/comfort_item.dart';
import '../../../common/services/heart_cost_service.dart';
import 'comfort_history_screen.dart';

class ComfortTabScreen extends StatefulWidget {
  const ComfortTabScreen({super.key});

  @override
  State<ComfortTabScreen> createState() => _ComfortTabScreenState();
}

class _ComfortTabScreenState extends State<ComfortTabScreen> {
  final ComfortService _service = ComfortService();
  final _controller = TextEditingController();
  ComfortItem? _latest;
  bool _hasEnoughHearts = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkHearts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkHearts() async {
    final ok = await HeartCostService().canAfford(HeartCost.COMFORT);
    if (mounted) setState(() => _hasEnoughHearts = ok);
  }

  Future<void> _submit() async {
    final locale =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    final isKorean = locale == 'ko';
    final text = _controller.text.trim();

    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKorean ? '10자 이상 적어 주세요.' : 'Please write at least 10 characters.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final item = await _service.createComfort(
        userMessage: text,
        locale: locale,
      );
      if (mounted) {
        setState(() {
          _latest = item;
          _isSubmitting = false;
        });
        _checkHearts();
        _watchComfort(item!.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(e, isKorean);
    }
  }

  void _watchComfort(String id) {
    _service.getUserComfortsStream().listen((list) {
      ComfortItem? updated;
      for (final comfort in list) {
        if (comfort.id == id) {
          updated = comfort;
          break;
        }
      }
      if (updated != null && mounted) {
        setState(() => _latest = updated);
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

    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? LinearGradient(
                colors: [Colors.grey[900]!, Colors.grey[850]!],
              )
            : LinearGradient(
                colors: [Colors.pink.shade50, Colors.white],
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
                    isKorean ? '💌 행복 위로' : '💌 Happiness Comfort',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComfortHistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(isKorean ? '히스토리' : 'History'),
                  ),
                ],
              ),
              TextField(
                controller: _controller,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: isKorean
                      ? '힘든 마음을 짧게 적어 주세요…'
                      : 'Share what weighs on your heart…',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _latest == null
                    ? Center(
                        child: Text(
                          isKorean
                              ? '따뜻한 위로 편지를 받아보세요.'
                              : 'Receive a warm comfort letter.',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      )
                    : _ComfortResult(item: _latest!, isKorean: isKorean),
              ),
              if (_isSubmitting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                ),
              ElevatedButton(
                onPressed:
                    _isSubmitting || !_hasEnoughHearts ? null : _submit,
                child: Text(
                  isKorean
                      ? '위로 받기 (하트 ${HeartCost.COMFORT}개)'
                      : 'Get Comfort (${HeartCost.COMFORT} Hearts)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComfortResult extends StatelessWidget {
  final ComfortItem item;
  final bool isKorean;

  const _ComfortResult({required this.item, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    if (item.status == 'pending') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(isKorean ? '마음을 담아 준비 중이에요…' : 'Preparing your letter…'),
          ],
        ),
      );
    }
    if (item.status == 'failed') {
      return Center(
        child: Text(
          isKorean
              ? '잠시 문제가 생겼어요. 다시 시도해 주세요.'
              : 'Something went wrong. Please try again.',
        ),
      );
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKorean ? '나에게' : 'To you',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.content,
                style: const TextStyle(fontSize: 16, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
