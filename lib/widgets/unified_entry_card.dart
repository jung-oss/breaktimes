// lib/widgets/unified_entry_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/like_toggle_button.dart';
import '../widgets/BookmarkButton_widget.dart';
import '../widgets/translation_button.dart';
import '../providers/settings_provider.dart';
import '../models/mood_models.dart';

/// A unified card widget for displaying entries consistently across the app
class UnifiedEntryCard extends StatefulWidget {
  // The entry to display - can be a Map (from Firestore) or a MoodEntry object
  final dynamic entry;

  // Callbacks for various actions
  final Function()? onTap;
  final Function(String, bool)? onPublicChanged;
  final Function(String)? onDelete;
  final Function(String, String)? onUpdate;

  // UI configuration options
  final bool compact;
  final bool expandable;
  final bool showBookmark;
  final bool isInitiallyExpanded;
  final bool showTopicBadge;

  // Whether to register the card with a list of expanded cards
  final bool useExpandTracker;
  final Function(String)? onExpand;
  final Function(String)? onCollapse;
  final bool isTrackedAsExpanded;

  const UnifiedEntryCard({
    Key? key,
    required this.entry,
    this.onTap,
    this.onPublicChanged,
    this.onDelete,
    this.onUpdate,
    this.compact = false,
    this.expandable = true,
    this.showBookmark = true,
    this.isInitiallyExpanded = false,
    this.showTopicBadge = true,
    this.useExpandTracker = false,
    this.onExpand,
    this.onCollapse,
    this.isTrackedAsExpanded = false,
  }) : super(key: key);

  @override
  State<UnifiedEntryCard> createState() => _UnifiedEntryCardState();
}

class _UnifiedEntryCardState extends State<UnifiedEntryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  String _displayContent = '';
  bool _isTranslated = false;
  TextEditingController? _editController;
  bool _isEditing = false;

  // Animation-related variables
  late Animation<double> _elevationAnimation;
  late Animation<double> _borderRadiusAnimation;
  late Animation<Color?> _backgroundColorAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize expansion state
    _isExpanded = widget.useExpandTracker
        ? widget.isTrackedAsExpanded
        : widget.isInitiallyExpanded;

    // Initialize display content
    if (widget.entry is Map<String, dynamic>) {
      _displayContent = widget.entry['content'] ?? '';
    } else if (widget.entry is MoodEntry) {
      _displayContent = widget.entry.content;
    }

    // Setup animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _elevationAnimation =
        Tween<double>(begin: 2, end: 6).animate(_expandAnimation);
    _borderRadiusAnimation =
        Tween<double>(begin: 12, end: 16).animate(_expandAnimation);

    // Set initial animation state
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set background color animation based on theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startColor = isDark ? Colors.grey.shade800 : Colors.white;
    final endColor = isDark
        ? Color.lerp(Colors.grey.shade800, Theme.of(context).primaryColor, 0.05)
        : Color.lerp(Colors.white, Theme.of(context).primaryColor, 0.03);

    _backgroundColorAnimation = ColorTween(
      begin: startColor,
      end: endColor,
    ).animate(_expandAnimation);
  }

  @override
  void didUpdateWidget(UnifiedEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update display content if entry changed
    String newContent = '';
    if (widget.entry is Map<String, dynamic>) {
      newContent = widget.entry['content'] ?? '';
    } else if (widget.entry is MoodEntry) {
      newContent = widget.entry.content;
    }

    if (newContent != _displayContent && !_isTranslated && !_isEditing) {
      setState(() {
        _displayContent = newContent;
      });
    }

    // Update expansion state if tracking changed
    if (widget.useExpandTracker &&
        widget.isTrackedAsExpanded != oldWidget.isTrackedAsExpanded) {
      setState(() {
        _isExpanded = widget.isTrackedAsExpanded;
        if (_isExpanded) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _editController?.dispose();
    super.dispose();
  }

  // Toggle the expansion state of the card
  void _toggleExpanded() {
    if (!widget.expandable) return;

    final newExpanded = !_isExpanded;
    setState(() {
      _isExpanded = newExpanded;
      if (_isExpanded) {
        _controller.forward();
        if (widget.useExpandTracker && widget.onExpand != null) {
          widget.onExpand!(getEntryId());
        }
      } else {
        _controller.reverse();
        if (widget.useExpandTracker && widget.onCollapse != null) {
          widget.onCollapse!(getEntryId());
        }
      }
    });
  }

  // Toggle edit mode
  void _toggleEdit() {
    if (_isEditing) {
      // Save changes
      final newContent = _editController!.text.trim();
      String currentContent = '';

      if (widget.entry is Map<String, dynamic>) {
        currentContent = widget.entry['content'] ?? '';
      } else if (widget.entry is MoodEntry) {
        currentContent = widget.entry.content;
      }

      if (newContent != currentContent && widget.onUpdate != null) {
        widget.onUpdate!(getEntryId(), newContent);
        setState(() {
          _displayContent = newContent;
        });
      }

      setState(() {
        _isEditing = false;
        _isTranslated = false; // Reset translation state after editing
      });

      _editController?.dispose();
      _editController = null;
    } else {
      // Start editing
      String content = '';
      if (widget.entry is Map<String, dynamic>) {
        content = widget.entry['content'] ?? '';
      } else if (widget.entry is MoodEntry) {
        content = widget.entry.content;
      }

      _editController = TextEditingController(text: content);
      setState(() {
        _isEditing = true;
        _isTranslated = false; // Reset translation state when starting edit
      });
    }
  }

  // Cancel editing
  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });
    _editController?.dispose();
    _editController = null;
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmDialog() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isKorean ? '글 삭제' : 'Delete Entry'),
        content: Text(
          isKorean
              ? '정말 이 글을 삭제하시겠습니까?'
              : 'Are you sure you want to delete this entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.onDelete != null) {
                widget.onDelete!(getEntryId());
              }
            },
            child: Text(
              isKorean ? '삭제' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Get the entry ID regardless of entry type
  String getEntryId() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['id'] ?? '';
    } else if (widget.entry is MoodEntry) {
      return widget.entry.id;
    }
    return '';
  }

  // Get author ID regardless of entry type
  String getAuthorId() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['userId'] ?? '';
    } else if (widget.entry is MoodEntry) {
      return widget.entry.userId;
    }
    return '';
  }

  // Check if the entry is owned by the current user
  bool isOwnEntry() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return currentUserId == getAuthorId();
  }

  // Get like count regardless of entry type
  int getLikeCount() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['likeCount'] ?? 0;
    } else if (widget.entry is MoodEntry) {
      return widget.entry.likeCount ?? 0;
    }
    return 0;
  }

  // Get is liked status regardless of entry type
  bool getIsLiked() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['isLiked'] ?? false;
    }
    return false; // MoodEntry doesn't typically store isLiked
  }

  // Get is bookmarked status regardless of entry type
  bool getIsBookmarked() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['isBookmarked'] ?? false;
    }
    return false; // MoodEntry doesn't typically store isBookmarked
  }

  // Get is public status regardless of entry type
  bool getIsPublic() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['isPublic'] ?? false;
    } else if (widget.entry is MoodEntry) {
      return widget.entry.isPublic;
    }
    return false;
  }

  // Get mood emoji regardless of entry type
  String getMood() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['mood'] ?? '😊';
    } else if (widget.entry is MoodEntry) {
      return widget.entry.mood;
    }
    return '😊';
  }

  // Get username regardless of entry type
  String getUsername() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['username'] ?? 'Anonymous';
    } else if (widget.entry is MoodEntry) {
      return widget.entry.username;
    }
    return 'Anonymous';
  }

  // Get photo URL regardless of entry type
  String? getPhotoURL() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['userPhotoURL'];
    } else if (widget.entry is MoodEntry) {
      return widget.entry.userPhotoURL;
    }
    return null;
  }

  // Get the topic regardless of entry type
  String getTopic() {
    if (widget.entry is Map<String, dynamic>) {
      return widget.entry['topic'] ?? '';
    } else if (widget.entry is MoodEntry) {
      return widget.entry.topic;
    }
    return '';
  }

  // Get the date regardless of entry type
  DateTime getDate() {
    if (widget.entry is Map<String, dynamic>) {
      if (widget.entry['date'] is Timestamp) {
        return (widget.entry['date'] as Timestamp).toDate();
      } else if (widget.entry['createdAt'] is Timestamp) {
        return (widget.entry['createdAt'] as Timestamp).toDate();
      }
    } else if (widget.entry is MoodEntry) {
      return widget.entry.date;
    }
    return DateTime.now();
  }

  // Format the date based on language and relative time
  String getFormattedDate(bool isKorean) {
    final date = getDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    // Less than an hour ago
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return isKorean
          ? '$minutes분 전'
          : '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    // Less than a day ago
    else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return isKorean
          ? '$hours시간 전'
          : '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    // Less than a week ago
    else if (difference.inDays < 7) {
      final days = difference.inDays;
      return isKorean ? '$days일 전' : '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    // More than a week ago - show full date
    else {
      return isKorean
          ? DateFormat('yyyy년 MM월 dd일').format(date)
          : DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final translationEnabled = settingsProvider.translationEnabled;

    final formattedDate = getFormattedDate(isKorean);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Card(
          margin: EdgeInsets.only(bottom: widget.compact ? 8 : 16),
          elevation: widget.expandable ? _elevationAnimation.value : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                widget.expandable ? _borderRadiusAnimation.value : 12),
            side: BorderSide(
              color: _isExpanded
                  ? Theme.of(context).primaryColor.withOpacity(0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          color: widget.expandable ? _backgroundColorAnimation.value : null,
          child: InkWell(
            onTap: widget.onTap ?? (widget.expandable ? _toggleExpanded : null),
            borderRadius: BorderRadius.circular(
                widget.expandable ? _borderRadiusAnimation.value : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section (author, mood, date)
                _buildHeader(isKorean, formattedDate),

                // Content section
                _buildContent(isKorean, translationEnabled),

                // Actions when collapsed
                if (widget.expandable && !_isExpanded)
                  _buildCollapsedActions(isKorean),

                // Additional actions when expanded
                if ((!widget.expandable) || _isExpanded)
                  _buildExpandedActions(isKorean),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isKorean, String formattedDate) {
    return Padding(
      padding: EdgeInsets.all(widget.compact ? 12.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic badge (if enabled and topic exists)
          if (widget.showTopicBadge && getTopic().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  getTopic(),
                  style: TextStyle(
                    fontSize: widget.compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),

          // Author info row
          Row(
            children: [
              // Profile image (if available)
              if (getPhotoURL() != null)
                CircleAvatar(
                  radius: widget.compact ? 14 : 16,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: NetworkImage(getPhotoURL()!),
                  onBackgroundImageError: (_, __) =>
                      const Icon(Icons.person, color: Colors.grey),
                ),

              // Mood emoji
              Container(
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  getMood(),
                  style: TextStyle(fontSize: widget.compact ? 16 : 20),
                ),
              ),

              // Username
              Expanded(
                child: Text(
                  getUsername(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: widget.compact ? 13 : 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Date
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: widget.compact ? 11 : 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isKorean, bool translationEnabled) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 12.0 : 16.0,
        vertical: widget.compact ? 4.0 : 8.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Translation status indicator
          if (_isTranslated)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.translate,
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isKorean ? '번역됨' : 'Translated',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Content display (edit mode or normal mode)
          if (_isEditing)
            TextField(
              controller: _editController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: isKorean ? '내용을 입력하세요...' : 'Enter content...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            )
          else
            Text(
              _displayContent,
              style: TextStyle(
                fontSize: widget.compact ? 14 : 16,
                height: 1.5,
              ),
              maxLines: (_isExpanded || !widget.expandable) ? null : 3,
              overflow: (_isExpanded || !widget.expandable)
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),

          // Translation button (only in expanded state and if enabled)
          if ((_isExpanded || !widget.expandable) &&
              translationEnabled &&
              !_isEditing)
            Align(
              alignment: Alignment.centerRight,
              child: TranslationButton(
                originalText: _displayContent,
                isKorean: isKorean,
                onTranslationChanged: (translatedText, isTranslated) {
                  setState(() {
                    _displayContent = translatedText;
                    _isTranslated = isTranslated;
                  });
                },
                compact: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedActions(bool isKorean) {
    return Column(
      children: [
        // Divider
        const Divider(height: 1),

        // Owner-specific actions (edit/delete/visibility)
        if (isOwnEntry() &&
            (widget.onDelete != null || widget.onUpdate != null))
          Padding(
            padding: EdgeInsets.fromLTRB(widget.compact ? 12.0 : 16.0, 8,
                widget.compact ? 12.0 : 16.0, 8),
            child: Row(
              children: [
                // Edit button
                if (widget.onUpdate != null)
                  TextButton.icon(
                    onPressed: _toggleEdit,
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.edit,
                      size: 16,
                    ),
                    label: Text(
                      _isEditing
                          ? (isKorean ? '저장' : 'Save')
                          : (isKorean ? '편집' : 'Edit'),
                      style: TextStyle(fontSize: widget.compact ? 12 : 14),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                // Cancel button (when editing)
                if (_isEditing)
                  TextButton.icon(
                    onPressed: _cancelEdit,
                    icon: const Icon(
                      Icons.cancel,
                      size: 16,
                    ),
                    label: Text(
                      isKorean ? '취소' : 'Cancel',
                      style: TextStyle(fontSize: widget.compact ? 12 : 14),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                // Delete button
                if (!_isEditing && widget.onDelete != null)
                  TextButton.icon(
                    onPressed: _showDeleteConfirmDialog,
                    icon: const Icon(
                      Icons.delete,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: Text(
                      isKorean ? '삭제' : 'Delete',
                      style: TextStyle(
                        fontSize: widget.compact ? 12 : 14,
                        color: Colors.red,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                // Spacer
                const Spacer(),

                // Public/private toggle
                if (widget.onPublicChanged != null)
                  TextButton.icon(
                    onPressed: () {
                      final newIsPublic = !getIsPublic();
                      widget.onPublicChanged!(getEntryId(), newIsPublic);
                    },
                    icon: Icon(
                      getIsPublic() ? Icons.public : Icons.lock,
                      size: 16,
                      color: getIsPublic() ? Colors.green : Colors.grey,
                    ),
                    label: Text(
                      getIsPublic()
                          ? (isKorean ? '공개' : 'Public')
                          : (isKorean ? '비공개' : 'Private'),
                      style: TextStyle(
                        fontSize: widget.compact ? 11 : 12,
                        color: getIsPublic() ? Colors.green : Colors.grey,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

        // Divider between owner actions and common actions
        if ((_isExpanded || !widget.expandable) &&
            isOwnEntry() &&
            (widget.onDelete != null || widget.onUpdate != null))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(),
          ),

        // Common actions (like, bookmark, expand/collapse)
        Padding(
          padding: EdgeInsets.fromLTRB(widget.compact ? 12.0 : 16.0, 0,
              widget.compact ? 12.0 : 16.0, widget.compact ? 12.0 : 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like button
              LikeToggleButton(
                entryId: getEntryId(),
                authorId: getAuthorId(),
                initialLikeCount: getLikeCount(),
                initiallyLiked: getIsLiked(),
                onLikeChanged: (isLiked, newLikeCount) {
                  // Update the entry with new like status
                  if (widget.entry is Map<String, dynamic>) {
                    widget.entry['isLiked'] = isLiked;
                    widget.entry['likeCount'] = newLikeCount;
                  }
                },
                compact: widget.compact,
              ),

              // Bookmark button (if enabled)
              if (widget.showBookmark)
                BookmarkButton(
                  entryId: getEntryId(),
                  userId: getAuthorId(),
                  initiallyBookmarked: getIsBookmarked(),
                  onBookmarkChanged: (isBookmarked) {
                    // Update the entry with new bookmark status
                    if (widget.entry is Map<String, dynamic>) {
                      widget.entry['isBookmarked'] = isBookmarked;
                    }
                  },
                ),

              // Collapse button (if expandable)
              if (widget.expandable)
                TextButton(
                  onPressed: _toggleExpanded,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isKorean ? '접기' : 'Collapse',
                    style: TextStyle(
                      fontSize: widget.compact ? 12 : 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedActions(bool isKorean) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final likeCount = getLikeCount();
    final isLiked = getIsLiked();
    final isBookmarked = getIsBookmarked();

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.compact ? 12.0 : 16.0, 2,
          widget.compact ? 12.0 : 16.0, widget.compact ? 12.0 : 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Read more button
          ElevatedButton(
            onPressed: _toggleExpanded,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              foregroundColor: Theme.of(context).primaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, size: widget.compact ? 14 : 16),
                const SizedBox(width: 4),
                Text(isKorean ? '더 보기' : 'Read more',
                    style: TextStyle(fontSize: widget.compact ? 11 : 12)),
              ],
            ),
          ),

          // Like and bookmark indicators
          Row(
            children: [
              // Like count indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLiked
                      ? Colors.red.withOpacity(0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: widget.compact ? 12 : 14,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$likeCount',
                      style: TextStyle(
                        fontSize: widget.compact ? 11 : 12,
                        color: isLiked ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Bookmark indicator
              if (widget.showBookmark && isBookmarked) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bookmark,
                    size: widget.compact ? 12 : 14,
                    color: Colors.blue,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
