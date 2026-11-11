// lib/happiness_shop_2/categories/vitamin/widgets/vitamin_random_slot_widget.dart
import 'package:flutter/material.dart';
import '../models/vitamin_slot.dart';
import '../services/vitamin_service.dart';
import '../../../common/widgets/pill_button.dart';

class VitaminRandomSlotWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final VitaminService service;

  const VitaminRandomSlotWidget({
    super.key,
    this.onTap,
    required this.service,
  });

  @override
  State<VitaminRandomSlotWidget> createState() =>
      _VitaminRandomSlotWidgetState();
}

class _VitaminRandomSlotWidgetState extends State<VitaminRandomSlotWidget> {
  VitaminSlot? _randomSlot;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRandomSlot();
  }

  Future<void> _loadRandomSlot() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final slot = await widget.service.getRandomSlot();
      if (mounted) {
        setState(() {
          _randomSlot = slot;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getPillImagePath() {
    if (_randomSlot == null) {
      return 'assets/images/pill/8_colorfule_pill.png';
    }
    final index = _randomSlot!.slotIndex % 8;
    switch (index) {
      case 0:
        return 'assets/images/pill/1_red_pill.png';
      case 1:
        return 'assets/images/pill/2_orange_pill.png';
      case 2:
        return 'assets/images/pill/3_yellow_pill.png';
      case 3:
        return 'assets/images/pill/4_green_pill.png';
      case 4:
        return 'assets/images/pill/5_blue_pill.png';
      case 5:
        return 'assets/images/pill/6_navy_pill.png';
      case 6:
        return 'assets/images/pill/7_purple_pill.png';
      case 7:
        return 'assets/images/pill/8_colorfule_pill.png';
      default:
        return 'assets/images/pill/1_red_pill.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: 100,
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(50),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_randomSlot == null) {
      return Container(
        width: 100,
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(50),
        ),
        child: const Center(
          child: Icon(Icons.refresh, color: Colors.grey),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        _loadRandomSlot();
      },
      child: PillButton(
        imagePath: _getPillImagePath(),
        onTap: () {
          widget.onTap?.call();
          _loadRandomSlot();
        },
        isEmpty: _randomSlot!.isEmpty,
        showBadge: true,
      ),
    );
  }
}

