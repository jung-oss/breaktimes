import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_localizations.dart';
import '../utils/event_bus.dart';
import '../providers/relax_provider.dart';

class LikeToggleButton extends StatefulWidget {
  final String entryId;
  final String authorId;
  final int initialLikeCount;
  final bool initiallyLiked;
  final Function(bool isLiked, int newLikeCount)? onLikeChanged;
  final bool compact;

  const LikeToggleButton({
    super.key,
    required this.entryId,
    required this.authorId,
    required this.initialLikeCount,
    this.initiallyLiked = false,
    this.onLikeChanged,
    this.compact = false,
  });

  @override
  State<LikeToggleButton> createState() => _LikeToggleButtonState();
}

class _LikeToggleButtonState extends State<LikeToggleButton> {
  late bool _isLiked;
  late int _likeCount;
  bool _isProcessing = false;
  bool _isSelfEntry = false;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initiallyLiked;
    _likeCount = widget.initialLikeCount;
    _isSelfEntry = _currentUserId == widget.authorId;
  }

  Future<void> _toggleLike() async {
    if (_isProcessing || _isSelfEntry || _currentUserId.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Use the centralized RelaxProvider to toggle like
      final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);
      final success = await relaxProvider.toggleLike(widget.entryId);

      if (success) {
        // The actual state update will be handled by the event bus,
        // but we can also update the local state for immediate UI feedback
        setState(() {
          _isLiked = !_isLiked;
          _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
        });

        // Call the callback if provided
        if (widget.onLikeChanged != null) {
          widget.onLikeChanged!(_isLiked, _likeCount);
        }
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).localeName.startsWith('ko')
                  ? '좋아요 처리 중 오류가 발생했습니다.'
                  : 'Error processing like.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isProcessing || _isSelfEntry ? null : _toggleLike,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            size: widget.compact ? 20 : 24,
            color: _isSelfEntry
                ? Colors.grey
                : (_isLiked ? Colors.red : Colors.grey),
          ),
          const SizedBox(width: 4),
          Text(
            '$_likeCount',
            style: TextStyle(
              fontSize: widget.compact ? 14 : 16,
              color: _isSelfEntry ? Colors.grey : null,
            ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
