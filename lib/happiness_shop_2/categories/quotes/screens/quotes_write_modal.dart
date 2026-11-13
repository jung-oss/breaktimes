// lib/happiness_shop_2/categories/quotes/screens/quotes_write_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/locale_provider.dart';
import '../services/quotes_service.dart';
import '../models/quote_item.dart';
import '../../../common/services/heart_cost_service.dart';
import '../../../common/widgets/shop_widgets.dart';

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
        // 기존 글귀 수정 (하트 소진 없음)
        await widget.service.updateQuote(
          widget.existingQuote!.id,
          _thoughtController.text.trim(),
        );
      } else {
        // 새 글귀 생성 (하트 소진)
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

        // 하트 부족 오류 처리
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageCode =
        Provider.of<LocaleProvider>(context).locale.languageCode;
    final isKorean = languageCode == 'ko';
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final statusBarHeight = mediaQuery.padding.top;
    final modalHeight = mediaQuery.size.height - statusBarHeight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          height: modalHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal header
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isKorean ? '오늘의 생각 기록하기' : 'Record Today\'s Thought',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isKorean
                          ? '생각을 적으면 AI가 따뜻한 글귀를 만들어드려요.'
                          : 'Write your thoughts and AI will create a warm quote for you.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
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
                            decoration: InputDecoration(
                              hintText: isKorean
                                  ? '오늘 하루 어떤 생각이 들었나요?\n자유롭게 적어보세요...'
                                  : 'What thoughts did you have today?\nWrite freely...',
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
                  top: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitThought,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ))
                      : Text(
                          isKorean ? '저장하기' : 'Save',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
