// lib/happiness_shop_2/common/widgets/pill_button.dart
import 'package:flutter/material.dart';

import '../theme/shop_tokens.dart';

/// 알약 버튼 위젯 (공통)
class PillButton extends StatefulWidget {
  final String imagePath;
  final VoidCallback onTap;
  final bool isEmpty;
  final Widget? overlay;
  final bool showBadge;

  const PillButton({
    super.key,
    required this.imagePath,
    required this.onTap,
    this.isEmpty = false,
    this.overlay,
    this.showBadge = false,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 알약 이미지
              Container(
                width: 100,
                height: 140,
                decoration: const BoxDecoration(
                  color: Colors.transparent, // 배경 투명 처리
                ),
                child: Stack(
                  children: [
                    // 그림자 효과를 위한 Container (배경 없음)
                    Container(
                      width: 100,
                      height: 140,
                    ),
                    // 알약 PNG 이미지
                    Image.asset(
                      widget.imagePath,
                      width: 100,
                      height: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // 알약 사진을 못 읽으면 코랄 빈 알약으로 대신합니다
                        return Container(
                          decoration: BoxDecoration(
                            color: t.coralSoft,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: t.line),
                          ),
                          child: widget.isEmpty
                              ? Icon(
                                  Icons.add,
                                  color: t.coralDeep,
                                  size: 40,
                                )
                              : const SizedBox(),
                        );
                      },
                    ),
                    // 빈 슬롯일 때 반투명 오버레이
                    if (widget.isEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: t.ground.withAlpha(166),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add_circle_outline,
                            color: t.coralDeep,
                            size: 48,
                          ),
                        ),
                      ),
                    // 커스텀 오버레이
                    if (widget.overlay != null) widget.overlay!,
                  ],
                ),
              ),
              // 배지 표시
              if (widget.showBadge)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: t.coral,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: t.onCoral,
                      size: 18,
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
