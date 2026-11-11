// lib/happiness_shop_2/common/widgets/pill_button.dart
import 'package:flutter/material.dart';

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
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.orange.shade300,
                                Colors.orange.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: widget.isEmpty
                              ? const Icon(
                                  Icons.add,
                                  color: Colors.white,
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
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
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
                      color: Colors.purple.shade400,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
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
