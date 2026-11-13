import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../services/comfort_service.dart';
import '../models/comfort_item.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/theme/shop_tokens.dart';
import '../../../common/widgets/shop_widgets.dart';
import 'comfort_history_screen.dart';

class ComfortTabScreen extends StatefulWidget {
  const ComfortTabScreen({super.key});

  @override
  State<ComfortTabScreen> createState() => _ComfortTabScreenState();
}

class _ComfortTabScreenState extends State<ComfortTabScreen> {
  final ComfortService _service = ComfortService();
  final _controller = TextEditingController();
  StreamSubscription<List<ComfortItem>>? _watch;
  ComfortItem? _latest;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 앱이 꺼져 'pending'에 멈춘 편지를 이어서 만듭니다
    _service.resumePending();
  }

  @override
  void dispose() {
    _watch?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final locale =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    final isKorean = locale == 'ko';
    final text = _controller.text.trim();

    if (text.length < 10) {
      showShopToast(
        context,
        isKorean ? '10자 이상 적어 주세요.' : 'Please write at least 10 characters.',
      );
      return;
    }

    try {
      final ok = await confirmLoveSpend(
        context,
        isKorean: isKorean,
        categoryId: 'comfort',
        title: isKorean ? '위로 편지를 받을까요?' : 'Get a comfort letter?',
        cost: HeartCost.COMFORT,
        chargeAfterResult: true,
      );
      if (!ok || !mounted) return;

      setState(() => _isSubmitting = true);
      final item = await _service.createComfort(
        userMessage: text,
        locale: locale,
      );
      if (!mounted) return;
      setState(() {
        _latest = item;
        _isSubmitting = false;
      });
      if (item != null) _watchComfort(item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showShopError(context, e, isKorean);
    }
  }

  /// 결과가 바뀌는 것을 지켜봅니다(이전 구독은 정리)
  void _watchComfort(String id) {
    _watch?.cancel();
    _watch = _service.getUserComfortsStream().listen((list) {
      for (final comfort in list) {
        if (comfort.id == id) {
          if (mounted) setState(() => _latest = comfort);
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
    final latest = _latest;

    return ColoredBox(
      color: t.ground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isKorean ? '위로 편지' : 'Comfort letter',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                      ),
                    ),
                  ),
                  LovePriceTag(cost: HeartCost.COMFORT, isKorean: isKorean),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: ShopShape.minTouch,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ComfortHistoryScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(foregroundColor: t.coralDeep),
                      child: Text(isKorean ? '받은 기록' : 'History'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLines: 4,
                maxLength: 500,
                style: TextStyle(fontSize: 16, color: t.ink),
                decoration: InputDecoration(
                  hintText: isKorean
                      ? '힘든 마음을 10자 이상 적어 주세요…'
                      : 'Share what weighs on your heart (10+ characters)…',
                  hintStyle: TextStyle(color: t.ink2),
                  filled: true,
                  fillColor: t.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ShopShape.button),
                    borderSide: BorderSide(color: t.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ShopShape.button),
                    borderSide: BorderSide(color: t.coralDeep, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: latest == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShopArt.pill('comfort', size: 80, radius: 20),
                            const SizedBox(height: 12),
                            Text(
                              isKorean
                                  ? '마음을 적으면 따뜻한 편지로 답해요.'
                                  : 'Write your heart and get a warm letter back.',
                              style: TextStyle(fontSize: 15, color: t.ink2),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _ComfortResult(
                        item: latest,
                        isKorean: isKorean,
                        onRetry: _submit,
                      ),
              ),
              const SizedBox(height: 12),
              LoveButton(
                isLoading: _isSubmitting,
                onPressed: latest?.status == 'pending' ? null : _submit,
                label: isKorean
                    ? '사랑하기 ${HeartCost.COMFORT}개로 받기'
                    : 'Get it for ${HeartCost.COMFORT} Love',
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
  final VoidCallback onRetry;

  const _ComfortResult({
    required this.item,
    required this.isKorean,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (item.status == 'pending') {
      return Align(
        alignment: Alignment.topCenter,
        child: ShopStatusView.pending(isKorean: isKorean),
      );
    }
    if (item.status == 'failed') {
      return Align(
        alignment: Alignment.topCenter,
        child: ShopStatusView.failed(isKorean: isKorean, onRetry: onRetry),
      );
    }
    final t = ShopTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(ShopShape.card),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKorean ? '나에게' : 'To you',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.coralDeep,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.content,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.75,
                color: t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
