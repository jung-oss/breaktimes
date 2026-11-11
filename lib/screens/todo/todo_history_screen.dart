import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/calendar_widget.dart';
import '../../models/todo_models.dart';
import 'dart:async'; // StreamSubscription을 위한 import 추가
import '../../widgets/todo_widgets.dart';
import '../../widgets/encouragement_message_generator.dart'; // 새로 만든 위젯 import
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

class TodoHistoryScreen extends StatefulWidget {
  const TodoHistoryScreen({super.key});

  @override
  State<TodoHistoryScreen> createState() => _TodoHistoryScreenState();
}

class _TodoHistoryScreenState extends State<TodoHistoryScreen>
    with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;
  late DateTime _selectedDate;
  Map<DateTime, UserProgress> _progressData = {};
  String _encouragementMessage = '';
  late AnimationController _heartController;
  bool _isGenerating = false;
  late AnimationController _messageController;
  late Animation<double> _messageAnimation;
  StreamSubscription? _progressSubscription;
  double _lastCompletionRate = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    // 실시간 데이터 구독 시작
    _progressSubscription = _getProgressStream().listen((data) {
      if (mounted) {
        setState(() {
          _progressData = data;
          _calculateCompletion(); // 달성률 자동 계산 및 메시지 갱신
        });
      }
    });

    _heartController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _messageController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _messageAnimation = CurvedAnimation(
      parent: _messageController,
      curve: Curves.easeOutBack,
    );
    _messageController.forward();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _heartController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Stream<Map<DateTime, UserProgress>> _getProgressStream() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    print(
        'History screen: 진행 상황 데이터 구독 시작 (${startOfMonth.toIso8601String()} - ${endOfMonth.toIso8601String()})');

    return _firestore
        .collection('users')
        .doc(_user?.uid)
        .collection('progress')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .snapshots()
        .map((snapshot) {
      final newProgressData = <DateTime, UserProgress>{};

      for (var doc in snapshot.docs) {
        try {
          final progress = UserProgress.fromFirestore(doc);
          // 날짜를 연, 월, 일만 포함하도록 정규화
          final date = DateTime(
            progress.date.year,
            progress.date.month,
            progress.date.day,
          );
          newProgressData[date] = progress;

          // 오늘 데이터가 업데이트되면 로그 출력
          final today = DateTime(now.year, now.month, now.day);
          if (date.isAtSameMomentAs(today)) {
            print(
                'History screen: 오늘(${date.toIso8601String()})의 진행 상황 업데이트됨 - 완료: ${progress.completedTodos}, 전체: ${progress.totalTodos}');
          }
        } catch (e) {
          print('Error processing document: $e');
        }
      }

      print('History screen: 진행 상황 데이터 업데이트됨 - ${newProgressData.length}개 항목');

      // 오늘 데이터가 있는지 확인하고 로그 출력
      final today = DateTime(now.year, now.month, now.day);
      final todayProgress = newProgressData[today];
      if (todayProgress != null) {
        print(
            'History screen: 오늘의 진행 상황 - 완료: ${todayProgress.completedTodos}, 전체: ${todayProgress.totalTodos}');
      } else {
        print('History screen: 오늘의 진행 상황 데이터 없음');
      }

      return newProgressData;
    });
  }

  double _calculateCompletion() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 오늘의 데이터 찾기 - 정확한 날짜 비교를 위해 year, month, day만 사용
    final todayProgress = _progressData.entries
        .where((entry) {
          final entryDate = entry.key;
          return entryDate.year == today.year &&
              entryDate.month == today.month &&
              entryDate.day == today.day;
        })
        .map((e) => e.value)
        .firstOrNull;

    // 실시간 데이터 반영
    if (todayProgress != null && todayProgress.totalTodos > 0) {
      final completion =
          (todayProgress.completedTodos / todayProgress.totalTodos) * 100;

      print('History screen: 완료율 계산 - ${completion.toStringAsFixed(1)}%');

      // 메시지 갱신이 필요한 경우 새로운 메시지 생성
      if (_lastCompletionRate != completion) {
        _lastCompletionRate = completion;
        _generateEncouragementMessage();
      }
      return completion;
    }

    print('History screen: 오늘 데이터 없음 또는 할 일이 없음');
    return 0.0;
  }

  Color _getCompletionColor(double completion) {
    if (completion >= 90) return Colors.green;
    if (completion >= 70) return Colors.yellow;
    if (completion >= 30) return Colors.orange;
    return Colors.red;
  }

  /// 하드코딩된 격려 메시지를 생성하는 메소드 (Gemini API 대체)
  void _generateEncouragementMessage() {
    if (_isGenerating) return;

    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    setState(() {
      _isGenerating = true;
    });

    try {
      // EncouragementMessageGenerator를 사용하여 메시지 생성
      final message = EncouragementMessageGenerator.generateMessage(
          _lastCompletionRate, isKorean);

      setState(() {
        _encouragementMessage = message;
        _isGenerating = false;
      });

      _messageController.reset();
      _messageController.forward();
    } catch (e) {
      print('Error generating message: $e');
      if (mounted) {
        setState(() {
          _encouragementMessage = isKorean
              ? '오늘도 힘내세요! 완전 럭키비키짱~! 💖'
              : 'Cheer up today! Super lucky viki-chang~! 💖';
          _isGenerating = false;
        });
      }
    }
  }

  Widget _buildProgressIndicator(BoxConstraints constraints) {
    final completion = _calculateCompletion();
    return TodoProgressBar(
      completion: completion,
      constraints: constraints,
    );
  }

  Widget _buildChatBubble(BoxConstraints constraints) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final chatColors = isDarkMode
        ? AppTheme.chatColors['dark']!
        : AppTheme.chatColors['light']!;
    return ChatBubbleWidget(
      message: _encouragementMessage,
      onHeartTap: _onHeartTap,
      messageAnimation: _messageAnimation,
      heartAnimation: Tween<double>(begin: 1.0, end: 1.4).animate(
        CurvedAnimation(
          parent: _heartController,
          curve: Curves.easeInOut,
        ),
      ),
      constraints: constraints,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.all(constraints.maxWidth * 0.04),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CalendarWidget<UserProgress>(
                  progressData: _progressData,
                  selectedDate: _selectedDate,
                  onDaySelected: (day) => setState(() => _selectedDate = day),
                ),
              ),
              _buildProgressIndicator(constraints),
              _buildChatBubble(constraints),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onHeartTap() async {
    if (_isGenerating) return;

    try {
      _heartController.forward().then((_) => _heartController.reverse());
      _generateEncouragementMessage(); // API 호출 제거, 즉시 메시지 생성
    } catch (e) {
      print('Error in heart tap: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}
