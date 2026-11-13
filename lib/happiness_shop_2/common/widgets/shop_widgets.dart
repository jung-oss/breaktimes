// lib/happiness_shop_2/common/widgets/shop_widgets.dart
//
// 행복-가게 공통 부품 (docs/happiness_shop_design_system.md 5장)
// 사랑하기 잔액 칩, 값 표시, 주 버튼, 받기 확인 창, 부족 안내 창, 상태 표시, 알림
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../screens/love_wallet_screen.dart';
import '../services/heart_service.dart';
import '../theme/shop_tokens.dart';

/// 카테고리마다 쓰는 알약 사진 (디자인 시스템 2장 "8가지 비타민")
class ShopArt {
  ShopArt._();

  static const _base = 'assets/images/pill/';

  static String pillFor(String categoryId) {
    switch (categoryId) {
      case 'quotes':
        return '${_base}3_yellow_pill.png';
      case 'music':
        return '${_base}5_blue_pill.png';
      case 'fortune':
        return '${_base}7_purple_pill.png';
      case 'comfort':
        return '${_base}2_orange_pill.png';
      case 'flowers':
        return '${_base}1_red_pill.png';
      case 'recipe':
        return '${_base}4_green_pill.png';
      case 'travel':
        return '${_base}6_navy_pill.png';
      default:
        return '${_base}8_colorfule_pill.png';
    }
  }

  /// 둥근 모서리 알약 사진
  static Widget pill(String categoryId, {double size = 56, double radius = 16}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        pillFor(categoryId),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // 이미지가 크므로 화면 크기에 맞춰 줄여서 읽습니다
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, __, ___) =>
            SizedBox(width: size, height: size),
      ),
    );
  }
}

/// 하트 모양(사랑하기 표시)
class LoveHeartIcon extends StatelessWidget {
  const LoveHeartIcon({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.favorite,
      size: size,
      color: color ?? ShopTokens.of(context).heart,
    );
  }
}

/// 사랑하기 잔액 칩. 누르면 사랑하기 지갑이 열립니다.
class LoveBalanceChip extends StatelessWidget {
  const LoveBalanceChip({super.key, required this.isKorean});

  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return StreamBuilder<int>(
      stream: HeartService().heartCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data;
        final countText = count?.toString() ?? '…';
        return Semantics(
          button: true,
          label: isKorean
              ? '사랑하기 $countText개, 지갑 열기'
              : '$countText Love, open wallet',
          excludeSemantics: true,
          child: Material(
            color: t.plumSoft,
            borderRadius: BorderRadius.circular(ShopShape.chip),
            child: InkWell(
              borderRadius: BorderRadius.circular(ShopShape.chip),
              onTap: () => Navigator.of(context).push(LoveWalletScreen.route()),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: ShopShape.minTouch - 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LoveHeartIcon(size: 18),
                      const SizedBox(width: 6),
                      Text(
                        isKorean ? '사랑하기' : 'Love',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.plum,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        countText,
                        // customFontFamily 800 = 티머니 둥근바람
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: t.plum,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 값 표시: 하트 + 숫자, 또는 "무료"
class LovePriceTag extends StatelessWidget {
  const LovePriceTag({super.key, required this.cost, required this.isKorean});

  /// 0이면 "무료"
  final int cost;
  final bool isKorean;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final free = cost == 0;
    return Semantics(
      label: free
          ? (isKorean ? '무료' : 'Free')
          : (isKorean ? '사랑하기 $cost개' : '$cost Love'),
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: free ? t.successSoft : t.plumSoft,
          borderRadius: BorderRadius.circular(ShopShape.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!free) ...[
              const LoveHeartIcon(size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              free ? (isKorean ? '무료' : 'Free') : '$cost',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: free ? t.onSuccessSoft : t.plum,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 주 버튼: 코랄 바탕 + Cocoa 글자 + 하트
class LoveButton extends StatelessWidget {
  const LoveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showHeart = true,
    this.isLoading = false,
  });

  final String label;

  /// null이면 누를 수 없는 상태(회색)
  final VoidCallback? onPressed;
  final bool showHeart;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    final enabled = onPressed != null && !isLoading;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: t.coral,
          foregroundColor: t.onCoral,
          disabledBackgroundColor: t.line,
          disabledForegroundColor: t.ink2,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShopShape.button),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: t.onCoral,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showHeart && enabled) ...[
                    Icon(Icons.favorite, size: 18, color: t.onCoral),
                    const SizedBox(width: 8),
                  ],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}

/// 보조 버튼: 흰 바탕 + 코랄 테두리
class ShopOutlineButton extends StatelessWidget {
  const ShopOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return SizedBox(
      height: ShopShape.minTouch,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: t.coralDeep,
          side: BorderSide(color: t.coralDeep, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShopShape.button),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// 사랑하기를 쓰기 전에 확인합니다.
///
/// 잔액이 모자라면 부족 안내 창을 띄우고 false를 돌려줍니다.
/// 잔액을 읽지 못하면(연결 문제) NETWORK_ERROR 예외를 던집니다.
/// [chargeAfterResult]가 true면 "결과가 도착한 뒤에 빠져요"를 안내합니다(AI 결과).
Future<bool> confirmLoveSpend(
  BuildContext context, {
  required bool isKorean,
  required String categoryId,
  required String title,
  required int cost,
  String? subtitle,
  String? actionLabel,
  String? note,
  bool chargeAfterResult = false,
}) async {
  final int balance;
  try {
    balance = (await HeartService().getHeartInfo()).heartCount;
  } catch (_) {
    throw Exception('NETWORK_ERROR');
  }
  if (!context.mounted) return false;

  if (balance < cost) {
    await showNotEnoughSheet(
      context,
      isKorean: isKorean,
      needed: cost - balance,
      itemName: title,
      cost: cost,
    );
    return false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SpendConfirmSheet(
      isKorean: isKorean,
      categoryId: categoryId,
      title: title,
      subtitle: subtitle,
      cost: cost,
      balance: balance,
      actionLabel: actionLabel,
      note: note ??
          (chargeAfterResult
              ? (isKorean
                  ? '결과가 도착한 뒤에 빠져요. 만들지 못하면 빠지지 않아요.'
                  : 'Love is used only after it arrives. Nothing is used if it fails.')
              : null),
    ),
  );
  return result == true;
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(ShopShape.sheet)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.line,
                  borderRadius: BorderRadius.circular(ShopShape.chip),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SpendConfirmSheet extends StatelessWidget {
  const _SpendConfirmSheet({
    required this.isKorean,
    required this.categoryId,
    required this.title,
    required this.cost,
    required this.balance,
    this.subtitle,
    this.actionLabel,
    this.note,
  });

  final bool isKorean;
  final String categoryId;
  final String title;
  final String? subtitle;
  final int cost;
  final int balance;
  final String? actionLabel;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return _SheetFrame(
      children: [
        Row(
          children: [
            ShopArt.pill(categoryId, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: TextStyle(fontSize: 14, color: t.ink2)),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.plumSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _BalanceNumber(
                label: isKorean ? '지금' : 'Now',
                value: balance,
                alignEnd: false,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      isKorean ? '사랑하기 $cost개' : '$cost Love',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.plum,
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: t.plum, size: 20),
                  ],
                ),
              ),
              _BalanceNumber(
                label: isKorean ? '받은 뒤' : 'After',
                value: balance - cost,
                alignEnd: true,
              ),
            ],
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 20, color: t.onSuccessSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  note!,
                  style: TextStyle(fontSize: 14, height: 1.5, color: t.ink2),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        LoveButton(
          label: actionLabel ??
              (isKorean ? '사랑하기 $cost개로 받기' : 'Use $cost Love'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: ShopShape.minTouch,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: t.ink2),
            child: Text(
              isKorean ? '다음에 할게요' : 'Not now',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceNumber extends StatelessWidget {
  const _BalanceNumber({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  final String label;
  final int value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: t.ink2)),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: t.plum,
          ),
        ),
      ],
    );
  }
}

/// 사랑하기가 부족할 때: 몇 개 모자란지, 오늘 얻을 수 있는 방법
Future<void> showNotEnoughSheet(
  BuildContext context, {
  required bool isKorean,
  required int needed,
  required String itemName,
  required int cost,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final t = ShopTokens.of(sheetContext);
      return _SheetFrame(
        children: [
          Text(
            isKorean ? '$needed개만 더 모으면 돼요' : 'Just $needed more Love',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isKorean
                ? '$itemName에는 사랑하기 $cost개가 필요해요. 마음을 챙기면 사랑하기가 모여요.'
                : '$itemName needs $cost Love. Taking care of yourself earns Love.',
            style: TextStyle(fontSize: 15, height: 1.5, color: t.ink2),
          ),
          const SizedBox(height: 16),
          TodayLoveCard(isKorean: isKorean),
          const SizedBox(height: 8),
          SizedBox(
            height: ShopShape.minTouch,
            child: TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              style: TextButton.styleFrom(foregroundColor: t.ink2),
              child: Text(
                isKorean ? '닫기' : 'Close',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// 오늘 받을 수 있는 사랑하기 3가지와 받았는지 여부
///
/// [userData]를 주면 그것을 쓰고, 없으면 사용자 문서를 직접 지켜봅니다.
class TodayLoveCard extends StatelessWidget {
  const TodayLoveCard({super.key, required this.isKorean, this.userData});

  final bool isKorean;
  final Map<String, dynamic>? userData;

  @override
  Widget build(BuildContext context) {
    final given = userData;
    if (given != null) return _buildCard(context, given);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _buildCard(context, const {});
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) =>
          _buildCard(context, snap.data?.data() ?? const {}),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data) {
    final t = ShopTokens.of(context);
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final rewards = data['heartRewards'];
    final rewardMap = rewards is Map ? rewards : const {};

    final items = [
      (
        isKorean ? '매일 서랍 열기' : 'Open the drawer daily',
        data['lastHeartDate'] == today,
      ),
      (
        isKorean ? '행복-미션 100%' : 'Complete all missions',
        rewardMap['mission'] == today,
      ),
      (
        isKorean ? '행복-함 쓰기' : 'Write in Happy Box',
        rewardMap['happyBox'] == today,
      ),
    ];
    final doneCount = items.where((i) => i.$2).length;

    return Container(
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  isKorean ? '오늘 받을 수 있는 사랑하기' : "Today's Love",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
              Text(
                '$doneCount / ${items.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.plum,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: ShopShape.minTouch),
              child: Row(
                children: [
                  Icon(
                    item.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 22,
                    color: item.$2 ? t.plum : t.ink2,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: TextStyle(fontSize: 15, color: t.ink),
                    ),
                  ),
                  Text(
                    item.$2 ? (isKorean ? '받았어요' : 'Done') : '+1',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: item.$2 ? t.ink2 : t.coralDeep,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            isKorean
                ? '각 활동은 하루에 한 번 사랑하기 1개를 줘요.'
                : 'Each activity gives 1 Love once a day.',
            style: TextStyle(fontSize: 13, color: t.ink2),
          ),
        ],
      ),
    );
  }
}

/// 결과 상태: 준비 중 / 문제
class ShopStatusView extends StatelessWidget {
  const ShopStatusView.pending({super.key, required this.isKorean})
      : failed = false,
        onRetry = null;

  const ShopStatusView.failed({
    super.key,
    required this.isKorean,
    this.onRetry,
  }) : failed = true;

  final bool isKorean;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = ShopTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(ShopShape.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: failed
                    ? Icon(Icons.sync_problem, color: t.ink2, size: 30)
                    : CircularProgressIndicator(
                        strokeWidth: 3.5,
                        color: t.coral,
                        backgroundColor: t.coralSoft,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failed
                          ? (isKorean
                              ? '잠시 문제가 생겼어요'
                              : 'Something went wrong')
                          : (isKorean
                              ? '마음을 담아 준비 중이에요'
                              : 'Preparing with care'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      failed
                          ? (isKorean
                              ? '사랑하기는 그대로예요.'
                              : 'Your Love was not used.')
                          : (isKorean
                              ? '아직 사랑하기는 빠지지 않았어요. 앱을 닫아도 다시 열면 이어서 만들어요.'
                              : 'No Love used yet. If you close the app, it continues next time.'),
                      style:
                          TextStyle(fontSize: 13, height: 1.45, color: t.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (failed && onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: ShopShape.minTouch,
              child: TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  backgroundColor: t.ground,
                  foregroundColor: t.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShopShape.button),
                  ),
                ),
                child: Text(
                  isKorean ? '다시 시도' : 'Try again',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 사랑하기 오류 메시지(부족·연결·로그인·기타)를 알림으로 보여 줍니다.
void showShopError(BuildContext context, Object error, bool isKorean) {
  final msg = error.toString();
  String text;
  if (msg.contains('INSUFFICIENT_HEARTS')) {
    text = isKorean ? '사랑하기가 모자라요.' : 'Not enough Love.';
  } else if (msg.contains('NETWORK_ERROR')) {
    text = isKorean
        ? '연결이 불안정해요. 사랑하기는 빠지지 않았어요. 잠시 후 다시 시도해 주세요.'
        : 'Connection problem. No Love was used. Please try again shortly.';
  } else if (msg.contains('NOT_LOGGED_IN')) {
    text = isKorean ? '로그인이 필요해요.' : 'Please sign in first.';
  } else {
    text = isKorean
        ? '잠시 문제가 생겼어요. 사랑하기는 그대로예요.'
        : 'Something went wrong. Your Love was not used.';
  }
  showShopToast(context, text);
}

/// 아래쪽 알림. [celebrate]가 true면 받는 순간(해바라기색)
void showShopToast(BuildContext context, String text,
    {bool celebrate = false}) {
  final t = ShopTokens.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: celebrate ? t.sunSoft : const Color(0xFF2C3E50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShopShape.button),
      ),
      content: Row(
        children: [
          Icon(Icons.favorite,
              size: 20,
              color: celebrate ? t.heart : const Color(0xFFFF7A93)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: celebrate ? t.onSunSoft : Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 사랑하기를 쓴 직후 알림 "사랑하기 N개를 썼어요 · 남은 M개"
Future<void> showSpentToast(
    BuildContext context, int spent, bool isKorean) async {
  int? remaining;
  try {
    remaining = (await HeartService().getHeartInfo()).heartCount;
  } catch (_) {}
  if (!context.mounted) return;
  showShopToast(
    context,
    isKorean
        ? '사랑하기 $spent개를 썼어요${remaining != null ? ' · 남은 $remaining개' : ''}'
        : 'Used $spent Love${remaining != null ? ' · $remaining left' : ''}',
  );
}
