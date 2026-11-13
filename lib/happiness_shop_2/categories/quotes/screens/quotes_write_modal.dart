// lib/happiness_shop_2/categories/quotes/screens/quotes_write_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../services/quotes_service.dart';
import '../models/quote_item.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/widgets/shop_widgets.dart';
import '../../../common/theme/shop_tokens.dart';

class QuotesWriteModal extends StatefulWidget {
  final QuotesService service;
  final QuoteItem? existingQuote;

  const QuotesWriteModal({
    super.key,
    required this.service,
    this.existingQuote,
  });

  @override
  State<QuotesWriteModal> createState() => _QuotesWriteModalState();
}

class _QuotesWriteModalState extends State<QuotesWriteModal> {
  final TextEditingController _thoughtController = TextEditingController();
  final FocusNode _thoughtFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingQuote != null) {
      _thoughtController.text = widget.existingQuote!.userThought;
    }
    _thoughtFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_thoughtFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _thoughtController.dispose();
    _thoughtFocusNode.removeListener(_onFocusChange);
    _thoughtFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitThought() async {
    final languageCode =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    final isKorean = languageCode == 'ko';

    if (_thoughtController.text.trim().isEmpty) {
      _showSnackBar(
        isKorean ? '생각을 입력해주세요.' : 'Please enter your thought.',
        isError: true,
      );
      return;
    }

    _thoughtFocusNode.unfocus();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // 새 글귀는 사랑하기를 쓰기 전에 확인합니다(수정은 무료)
    if (widget.existingQuote == null) {
      try {
        final ok = await confirmLoveSpend(
          context,
          isKorean: isKorean,
          categoryId: 'quotes',
          title: isKorean ? '글귀를 받을까요?' : 'Get your quote?',
          cost: HeartCost.QUOTE,
          chargeAfterResult: true,
        );
        if (!ok || !mounted) return;
      } catch (e) {
        if (mounted) showShopError(context, e, isKorean);
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.existingQuote != null) {
        // 기존 글귀 수정(사랑하기를 쓰지 않습니다)
        await widget.service.updateQuote(
          widget.existingQuote!.id,
          _thoughtController.text.trim(),
        );
      } else {
        // 새 글귀 생성(사랑하기를 씁니다)
        await widget.service.createQuoteFromThought(
          _thoughtController.text.trim(),
        );
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        Navigator.of(context).pop(true);
        _showSnackBar(
          isKorean
              ? '생각이 기록되었습니다. 글귀를 생성하고 있어요!'
              : 'Thought recorded. Generating quote!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // 사랑하기 부족 오류 처리
        if (e.toString().contains('INSUFFICIENT_HEARTS')) {
          _showSnackBar(
            isKorean
                ? '사랑하기가 모자라요. 행복-미션이나 행복-함으로 모을 수 있어요.'
                : 'Not enough Love. Missions and Happy Box earn more.',
            isError: true,
          );
        } else if (e.toString().contains('NETWORK_ERROR')) {
          _showSnackBar(
            isKorean
                ? '연결이 불안정해요. 사랑하기는 빠지지 않았어요. 잠시 후 다시 시도해 주세요.'
                : 'Connection problem. No Love was used. Please try again shortly.',
            isError: true,
          );
        } else {
          _showSnackBar(
            isKorean
                ? '잠시 문제가 생겼어요. 다시 시도해 주세요.'
                : 'Something went wrong. Please try again.',
            isError: true,
          );
        }
      }
    }
  }


  // 알림은 가게 공통 모양을 씁니다(오류도 빨간색 없이 같은 모양입니다)
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final t = ShopTokens.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? t.surface : t.successSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShopShape.button),
          side: BorderSide(color: isError ? t.line : t.successSoft),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isError ? t.ink2 : t.onSuccessSoft,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    final isKorean = languageCode == 'ko';
    final t = ShopTokens.of(context);
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final statusBarHeight = mediaQuery.padding.top;
    final modalHeight = mediaQuery.size.height - statusBarHeight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          height: modalHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.ground,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ShopShape.sheet)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            isKorean
                                ? '오늘의 생각 기록하기'
                                : 'Record Today\'s Thought',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: t.ink2,
                          constraints: const BoxConstraints(
                            minWidth: ShopShape.minTouch,
                            minHeight: ShopShape.minTouch,
                          ),
                          tooltip: isKorean ? '닫기' : 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        isKorean
                            ? '생각을 적으면 AI가 따뜻한 글귀를 만들어드려요.'
                            : 'Write your thoughts and AI will create a warm quote for you.',
                        style: TextStyle(
                          fontSize: 14,
                          color: t.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: keyboardHeight > 0 ? keyboardHeight + 100 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thought input
                        Text(
                          isKorean ? '오늘의 생각' : 'Today\'s Thought',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius:
                                BorderRadius.circular(ShopShape.button),
                            border: Border.all(
                              color: t.line,
                              width: 1,
                            ),
                          ),
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height * 0.3,
                          ),
                          child: TextField(
                            controller: _thoughtController,
                            focusNode: _thoughtFocusNode,
                            maxLines: null,
                            minLines: 10,
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            cursorColor: t.coralDeep,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: t.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: isKorean
                                  ? '오늘 하루 어떤 생각이 들었나요?\n자유롭게 적어보세요...'
                                  : 'What thoughts did you have today?\nWrite freely...',
                              hintStyle: TextStyle(color: t.ink2),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),

                        SizedBox(height: keyboardHeight > 0 ? 200 : 80),
                      ],
                    ),
                  ),
                ),
              ),

              // Save button
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  top: 12,
                ),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(top: BorderSide(color: t.line)),
                ),
                // 새 글귀는 사랑하기를 쓰고, 수정은 무료입니다
                child: LoveButton(
                  isLoading: _isSubmitting,
                  showHeart: widget.existingQuote == null,
                  onPressed: _submitThought,
                  label: isKorean ? '저장하기' : 'Save',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
