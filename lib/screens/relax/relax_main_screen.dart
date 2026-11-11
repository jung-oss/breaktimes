import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'relax_history_screen.dart';
import 'relax_analysis_screen.dart';
import 'bookmarked_screen.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/relax_provider.dart';
import '../../utils/event_bus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/unified_entry_card.dart';
import '../../models/mood_models.dart';
import '../../providers/theme_provider.dart';
import '../../happiness_shop_2/common/services/heart_service.dart';

class RelaxMainScreen extends StatefulWidget {
  const RelaxMainScreen({super.key});

  @override
  State<RelaxMainScreen> createState() => _RelaxMainScreenState();
}

class _RelaxMainScreenState extends State<RelaxMainScreen> with RouteAware {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  String? _expandedEntryId;
  static RouteObserver<PageRoute>? routeObserver;
  bool _initialized = false;
  final FocusNode _contentFocusNode = FocusNode();
  String? _previousLocale;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    // Add focus change listener
    _contentFocusNode.addListener(() {
      if (!_contentFocusNode.hasFocus) {
        // Handle focus lost if needed
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get current locale
    final currentLocale = Localizations.localeOf(context).languageCode;

    // Check if first initialization
    if (!_initialized) {
      // Initialize data
      Future.microtask(() {
        final relaxProvider =
            Provider.of<RelaxProvider>(context, listen: false);
        relaxProvider.initialize();
      });

      _initialized = true;
    }
    // Check if language changed
    // else if (_previousLocale != null && _previousLocale != currentLocale) {
    //  debugPrint(
    //      'Language change detected: $_previousLocale -> $currentLocale');

    // Reload topic on language change
    //  Future.microtask(() {
    //    final relaxProvider =
    //        Provider.of<RelaxProvider>(context, listen: false);
    //    relaxProvider.handleLocaleChanged(currentLocale);
    //  });
    //}

    // Store current locale
    _previousLocale = currentLocale;

    // Register with RouteObserver
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && routeObserver != null) {
      routeObserver!.subscribe(this, modalRoute as PageRoute);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _contentFocusNode.dispose();

    // Unsubscribe from RouteObserver
    if (routeObserver != null) {
      routeObserver!.unsubscribe(this);
    }

    super.dispose();
  }

  // Scroll listener for infinite scrolling
  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);
      if (!relaxProvider.isLoading && relaxProvider.hasMorePublicData) {
        relaxProvider.loadMorePublicEntries();
      }
    }
  }

  // Show write entry modal
  void _showWriteEntryModal() {
    final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);

    if (relaxProvider.dailyTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Loading today\'s topic. Please try again in a moment.')),
      );
      return;
    }

    // Show full-screen modal with animation
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      useSafeArea: true,
      builder: (context) => WriteEntryModal(
        dailyTopic: relaxProvider.dailyTopic!,
        topicId: relaxProvider.topicId ?? '',
      ),
    ).then((result) {
      // Refresh data if entry was added
      if (result == true) {
        relaxProvider.initialize();
        eventBus.fire(EventBus.entryAdded, EntryAddedEvent());
      }
    });
  }

  // Show today's entry
  void _showTodayEntry() {
    final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);
    final todayEntry = relaxProvider.getTodayEntry();

    if (todayEntry != null) {
      // Instead of navigating to a separate screen, expand the card directly
      setState(() {
        _expandedEntryId = todayEntry.id;
      });

      // Scroll to the entry if it's in the public entries list
      final publicEntryIndex = relaxProvider.publicEntries
          .indexWhere((entry) => entry['id'] == todayEntry.id);

      if (publicEntryIndex >= 0) {
        // Find the entry's position and scroll to it with animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final itemPosition =
              150.0 + (publicEntryIndex * 240.0); // Approximate position
          if (_scrollController.hasClients &&
              _scrollController.position.maxScrollExtent > itemPosition) {
            _scrollController.animateTo(
              itemPosition,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        // If not in the public list, show it directly
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              AppLocalizations.of(context).localeName.startsWith('ko')
                  ? '오늘의 기록'
                  : 'Today\'s Entry',
            ),
            content: SingleChildScrollView(
              child: UnifiedEntryCard(
                entry: todayEntry,
                expandable: false,
                onPublicChanged: (id, isPublic) async {
                  Navigator.pop(context);
                  await relaxProvider.updateEntryPublicStatus(id, isPublic);
                  relaxProvider.initialize();
                },
                onDelete: (id) async {
                  Navigator.pop(context);
                  await relaxProvider.deleteMoodEntry(id);
                  relaxProvider.initialize();
                },
                onUpdate: (id, newContent) async {
                  Navigator.pop(context);
                  await relaxProvider.updateMoodEntry(id, newContent);
                  relaxProvider.initialize();
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context).localeName.startsWith('ko')
                      ? '닫기'
                      : 'Close',
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Show message if no entry for today
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).localeName.startsWith('ko')
                ? '오늘 작성한 글이 없습니다.'
                : 'No entry for today.',
          ),
        ),
      );
    }
  }

  // Handle entry expansion
  void _setExpandedEntry(String? entryId) {
    setState(() {
      _expandedEntryId = entryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Main screen (today's topic and public entries)
          Consumer<RelaxProvider>(
            builder: (context, provider, child) {
              return _buildMainContent(provider, isKorean);
            },
          ),
          // History screen
          const RelaxHistoryScreen(),
          // Analysis screen
          const RelaxAnalysisScreen(),
          // Bookmarks screen
          const BookmarkedScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Reset expanded entry when changing tabs
            _expandedEntryId = null;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.topic),
            label: isKorean ? '오늘의 주제' : 'Today\'s Topic',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: isKorean ? '기록 보기' : 'History',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics),
            label: isKorean ? '감정 분석' : 'Analysis',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bookmark),
            label: isKorean ? '저장한 글' : 'Bookmarks',
          ),
        ],
      ),
    );
  }

  // Build main content
  Widget _buildMainContent(RelaxProvider relaxProvider, bool isKorean) {
    if (relaxProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Today's topic card
        _buildTodayTopicCard(relaxProvider, isKorean),

        // Public entries list
        Expanded(
          child: _buildPublicEntriesList(relaxProvider, isKorean),
        ),
      ],
    );
  }

  // Build today's topic card
  Widget _buildTodayTopicCard(RelaxProvider relaxProvider, bool isKorean) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isKorean ? '오늘의 주제' : 'Today\'s Topic',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                // Sort toggle button
                if (relaxProvider.hasWrittenToday)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey[200],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Latest toggle
                        GestureDetector(
                          onTap: relaxProvider.isChangingFilter
                              ? null
                              : () {
                                  relaxProvider.changeSortOption(
                                      PublicEntrySortOption.latest);
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: relaxProvider.sortOption ==
                                      PublicEntrySortOption.latest
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                            ),
                            child: Text(
                              isKorean ? '최근' : 'Latest',
                              style: TextStyle(
                                color: relaxProvider.sortOption ==
                                        PublicEntrySortOption.latest
                                    ? Colors.white
                                    : Colors.grey[800],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        // Popular toggle
                        GestureDetector(
                          onTap: relaxProvider.isChangingFilter
                              ? null
                              : () {
                                  relaxProvider.changeSortOption(
                                      PublicEntrySortOption.popular);
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: relaxProvider.sortOption ==
                                      PublicEntrySortOption.popular
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                            ),
                            child: Text(
                              isKorean ? '공감' : 'Likes',
                              style: TextStyle(
                                color: relaxProvider.sortOption ==
                                        PublicEntrySortOption.popular
                                    ? Colors.white
                                    : Colors.grey[800],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (relaxProvider.dailyTopic != null)
              Text(
                relaxProvider.dailyTopic!,
                style: const TextStyle(fontSize: 16),
              )
            else
              Text(
                isKorean ? '주제를 불러오는 중입니다...' : 'Loading topic...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 12),

            // Write/view entry button
            if (!relaxProvider.hasWrittenToday)
              ElevatedButton(
                onPressed: _showWriteEntryModal,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isKorean ? '오늘의 감정 기록하기' : 'Write Today\'s Entry',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: _showTodayEntry,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isKorean ? '오늘의 기록 보기' : 'View Today\'s Entry',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build public entries list
  Widget _buildPublicEntriesList(RelaxProvider relaxProvider, bool isKorean) {
    if (!relaxProvider.hasWrittenToday) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                'assets/images/breaktime_write_logo.png',
                width: 350,
                height: 350,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isKorean
                  ? '오늘의 주제에 대한 감정을 기록하면\n다른 사용자들의 글을 볼 수 있습니다.'
                  : 'Record your feelings about today\'s topic\nto see entries from other users.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (relaxProvider.isLoading && relaxProvider.publicEntries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (relaxProvider.publicEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.public_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isKorean
                  ? '이 주제에 대한 공개된 글이 없습니다.'
                  : 'No public entries for this topic yet.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter change loading indicator
        if (relaxProvider.isChangingFilter)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isKorean ? '필터 적용 중...' : 'Applying filter...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

        // Public entries list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => relaxProvider.refreshAllData(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: relaxProvider.publicEntries.length +
                  1, // +1 for loading indicator
              itemBuilder: (context, index) {
                if (index == relaxProvider.publicEntries.length) {
                  // Loading indicator at the end
                  if (relaxProvider.hasMorePublicData &&
                      !relaxProvider.isLoading) {
                    // Load more data when reaching end of list
                    Future.microtask(
                        () => relaxProvider.loadMorePublicEntries());
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else {
                    // No more data or already loading
                    return const SizedBox();
                  }
                }

                final entry = relaxProvider.publicEntries[index];
                final entryId = entry['id'] as String;

                // Create unified entry card
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: UnifiedEntryCard(
                    entry: entry,
                    useExpandTracker: true,
                    isTrackedAsExpanded: _expandedEntryId == entryId,
                    onExpand: _setExpandedEntry,
                    onCollapse: (_) => _setExpandedEntry(null),
                    onPublicChanged: (id, isPublic) {
                      // Only available for user's own entries
                      if (entry['userId'] ==
                          FirebaseAuth.instance.currentUser?.uid) {
                        relaxProvider.updateEntryPublicStatus(id, isPublic);
                      }
                    },
                    onDelete: (id) {
                      // Only available for user's own entries
                      if (entry['userId'] ==
                          FirebaseAuth.instance.currentUser?.uid) {
                        relaxProvider.deleteMoodEntry(id);
                      }
                    },
                    onUpdate: (id, newContent) {
                      // Only available for user's own entries
                      if (entry['userId'] ==
                          FirebaseAuth.instance.currentUser?.uid) {
                        relaxProvider.updateMoodEntry(id, newContent);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Called when returning to this screen
  void didPopNext() {
    _checkNotificationTopic();
  }

  // Check for topic from notification
  Future<void> _checkNotificationTopic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final topic = prefs.getString('today_topic');
      final fromNotification =
          prefs.getBool('topic_from_notification') ?? false;

      if (fromNotification && topic != null && topic.isNotEmpty) {
        // Initialize RelaxProvider
        final relaxProvider =
            Provider.of<RelaxProvider>(context, listen: false);

        // Only initialize if topic changed
        if (relaxProvider.dailyTopic != topic) {
          relaxProvider.initialize();
        }

        // Clear notification flags
        await prefs.remove('topic_from_notification');
      }
    } catch (e) {
      print('Error checking notification topic: $e');
    }
  }
}

// WriteEntryModal class
class WriteEntryModal extends StatefulWidget {
  final String dailyTopic;
  final String topicId;

  const WriteEntryModal({
    super.key,
    required this.dailyTopic,
    required this.topicId,
  });

  @override
  State<WriteEntryModal> createState() => _WriteEntryModalState();
}

class _WriteEntryModalState extends State<WriteEntryModal> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _selectedMood = '😊';
  bool _isSubmitting = false;
  bool _isPublic = true; // Default to public

  // Available mood emojis
  final List<String> _moods = ['😊', '😐', '😩', '😢', '😠'];

  // Get mood color based on emotion
  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😊':
        return const Color(0xFFFFD54F); // 행복 - 노란색
      case '😐':
        return const Color(0xFF81C784); // 평온 - 초록색
      case '😩':
        return const Color(0xFF7986CB); // 놀람 - 보라색
      case '😢':
        return const Color(0xFF64B5F6); // 슬픔 - 파란색
      case '😠':
        return const Color(0xFFFF8A65); // 화남 - 빨간색
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _contentFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_contentFocusNode.hasFocus) {
      // Scroll when keyboard appears
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
    _contentController.dispose();
    _contentFocusNode.removeListener(_onFocusChange);
    _contentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Submit entry
  Future<void> _submitEntry() async {
    if (_contentController.text.trim().isEmpty) {
      // Don't submit if content is empty
      _showSnackBar(
        AppLocalizations.of(context).localeName.startsWith('ko')
            ? '내용을 입력해주세요.'
            : 'Please enter content.',
        isError: true,
      );
      return;
    }

    // Close keyboard first
    _contentFocusNode.unfocus();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final relaxProvider = Provider.of<RelaxProvider>(context, listen: false);

      // Call RelaxProvider method
      final success = await relaxProvider.addMoodEntry(
        mood: _selectedMood,
        content: _contentController.text.trim(),
        topicId: widget.topicId,
        topic: widget.dailyTopic,
        isPublic: _isPublic,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (success) {
          // 창을 닫아도 알림을 띄울 수 있도록 미리 잡아 둡니다
          final messenger = ScaffoldMessenger.of(context);
          final isKo = AppLocalizations.of(context).localeName.startsWith('ko');

          // Close modal and show success message
          Navigator.of(context).pop(true);
          _showSnackBar(
            isKo ? '감정이 기록되었습니다' : 'Emotion recorded successfully',
          );

          // 행복-함 작성 보상: 사랑하기 1개 (하루 한 번)
          HeartService()
              .awardDailyHeart(HeartReward.happyBox)
              .then((awarded) {
            if (!awarded) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(isKo
                    ? '행복-함 작성! 사랑하기 1개를 받았어요 ❤'
                    : 'Happy Box written! You got 1 Love ❤'),
              ),
            );
          });
        } else {
          _showSnackBar(
            AppLocalizations.of(context).localeName.startsWith('ko')
                ? '기록 저장 중 오류가 발생했습니다'
                : 'Error saving entry',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showSnackBar(
          '${AppLocalizations.of(context).localeName.startsWith('ko') ? '오류' : 'Error'}: $e',
          isError: true,
        );
      }
    }
  }

  // Show snackbar helper
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
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
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
                          isKorean ? '감정 기록하기' : 'Record Emotion',
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
                      widget.dailyTopic,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
                      // Extra padding when keyboard is up
                      bottom: keyboardHeight > 0 ? keyboardHeight + 100 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mood selection
                        Text(
                          isKorean ? '감정 선택' : 'Select Mood',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _moods.map((mood) {
                            final isSelected = mood == _selectedMood;
                            return GestureDetector(
                              onTap: () async {
                                setState(() {
                                  _selectedMood = mood;
                                });

                                // 감정 테마 변경
                                // try {
                                //   final moodThemeProvider =
                                //       Provider.of<MoodThemeProvider>(context,
                                //           listen: false);
                                //   await moodThemeProvider.setMoodTheme(mood);
                                // } catch (e) {
                                //   debugPrint('테마 변경 중 오류 발생: $e');
                                // }
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _getMoodColor(mood).withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: isSelected
                                        ? _getMoodColor(mood)
                                        : Colors.grey.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    mood,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Public/private setting
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: SwitchListTile(
                            title: Text(isKorean ? '공개 여부' : 'Public'),
                            subtitle: Text(
                              isKorean
                                  ? '공개하면 다른 사용자들이 볼 수 있습니다.'
                                  : 'If public, other users can see your entry.',
                            ),
                            value: _isPublic,
                            onChanged: (value) {
                              setState(() {
                                _isPublic = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Content input
                        Text(
                          isKorean ? '내용 입력' : 'Content',
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
                            // Minimum height to ensure enough space for input
                            minHeight: MediaQuery.of(context).size.height * 0.3,
                          ),
                          child: TextField(
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            maxLines: null,
                            minLines: 10, // Minimum number of lines
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              hintText: isKorean
                                  ? '생각을 자유롭게 적어보세요...'
                                  : 'Write your thoughts...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),

                        // Extra space (to ensure text field is visible when keyboard is up)
                        SizedBox(height: keyboardHeight > 0 ? 200 : 80),
                      ],
                    ),
                  ),
                ),
              ),

              // Save button (always fixed at the bottom)
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
                  onPressed: _isSubmitting ? null : _submitEntry,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _getMoodColor(_selectedMood),
                    foregroundColor: Colors.white,
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
