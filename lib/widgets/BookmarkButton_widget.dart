import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/relax_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookmarkButton extends StatefulWidget {
  final String entryId;
  final String userId; // Author ID
  final bool initiallyBookmarked;
  final Function(bool isBookmarked)? onBookmarkChanged;

  const BookmarkButton({
    super.key,
    required this.entryId,
    required this.userId,
    this.initiallyBookmarked = false,
    this.onBookmarkChanged,
  });

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton> {
  late bool _isBookmarked;
  bool _isProcessing = false;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.initiallyBookmarked;
  }

  Future<void> _toggleBookmark() async {
    if (_isProcessing || _currentUserId.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Use the centralized RelaxProvider to toggle bookmark
      final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);
      final success = await relaxProvider.toggleBookmark(widget.entryId);

      if (success) {
        // Update local state for immediate UI feedback
        setState(() {
          _isBookmarked = !_isBookmarked;
        });

        // Call the callback if provided
        if (widget.onBookmarkChanged != null) {
          widget.onBookmarkChanged!(_isBookmarked);
        }
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing bookmark: $e'),
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
      onTap: _isProcessing ? null : _toggleBookmark,
      child: Row(
        children: [
          Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            size: 20,
            color: _isBookmarked ? Colors.blue : Colors.grey,
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

// Function to check if an entry is bookmarked by the current user
Future<bool> isEntryBookmarked(String entryId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  try {
    final bookmarkDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .doc(entryId)
        .get();

    return bookmarkDoc.exists;
  } catch (e) {
    debugPrint('Error checking bookmark status: $e');
    return false;
  }
}
