import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/todo_models.dart';
import 'todo_history_screen.dart';
import 'todo_analysis_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../utils/firestore_paths.dart';

class TodoMainScreen extends StatefulWidget {
  const TodoMainScreen({super.key});

  @override
  State<TodoMainScreen> createState() => _TodoMainScreenState();
}

class _TodoMainScreenState extends State<TodoMainScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  List<TodoItem> _todos = [];
  bool _isLoading = true;
  Map<DateTime, UserProgress> _progressData = {};
  late DateTime _selectedDate;
  int _selectedIndex = 1;
  final _todoController = TextEditingController();
  late final Map<String, AnimationController> _animationControllers = {};

  // 🆕 오늘 사용된 추천 ID들을 저장할 Set 추가
  Set<String> _todayUsedRecommendations = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _checkAndResetTodos();
    _loadProgressData();
  }

  @override
  void dispose() {
    _todoController.dispose();
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // 🆕 날짜가 바뀔 때 사용된 추천 초기화
  Future<void> _checkAndResetTodos() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      final userTodosRef =
          _firestore.collection('users').doc(_user?.uid).collection('todos');

      final todayTodosQuery = await userTodosRef
          .where('date', isEqualTo: today.toIso8601String().split('T')[0])
          .get();

      if (todayTodosQuery.docs.isEmpty) {
        // 🆕 새로운 날이므로 사용된 추천 목록 초기화
        _todayUsedRecommendations.clear();
        print('새로운 날: 사용된 추천 목록 초기화됨');

        // 기존 로직...
        final oldTodosQuery = await userTodosRef
            .where('date', isLessThan: today.toIso8601String().split('T')[0])
            .get();

        final batch = _firestore.batch();
        for (var doc in oldTodosQuery.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            // isCompleted가 null이거나 false인 경우에만 아카이브
            final isCompleted = data['isCompleted'] as bool? ?? false;
            if (!isCompleted) {
              final archiveData = {
                ...data,
                'archivedAt': FieldValue.serverTimestamp(),
              };
              batch.set(
                userTodosRef.doc('archive_${doc.id}'),
                archiveData,
              );
            }
          }
          batch.delete(userTodosRef.doc(doc.id));
        }
        await batch.commit();
      }

      await _initializeTodos();
    } catch (e) {
      print('Error checking and resetting todos: $e');
    }
  }

  Future<void> _initializeTodos() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = today.toIso8601String().split('T')[0];

      final userTodosRef =
          _firestore.collection('users').doc(_user?.uid).collection('todos');

      final todayTodosQuery =
          await userTodosRef.where('date', isEqualTo: todayStr).get();

      setState(() {
        _todos = todayTodosQuery.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) {
                  print('Warning: Todo document ${doc.id} has null data');
                  return null;
                }
                // doc.id를 data에 추가하여 TodoItem.fromMap에서 사용
                data['id'] = doc.id;
                return TodoItem.fromMap(data);
              } catch (e) {
                print('Error parsing todo ${doc.id}: $e');
                return null;
              }
            })
            .where((todo) => todo != null)
            .cast<TodoItem>()
            .toList();
        _isLoading = false;
      });

      // 완료된 미션에 대해 애니메이션 재생
      for (var todo in _todos) {
        if (todo.isCompleted) {
          _initializeAnimationController(todo.id);
          _playCompletionAnimation(todo.id);
        }
      }

      // 진행 상황 업데이트
      await _updateProgress();
    } catch (e) {
      print('Error initializing todos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTodo(String task) async {
    if (_todos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('하루 최대 5개까지만 미션을 추가할 수 있습니다')),
      );
      return;
    }

    try {
      final todo = TodoItem(
        id: UniqueKey().toString(),
        task: task,
        date: DateTime.now().toIso8601String().split('T')[0],
      );

      await _firestore
          .collection('users')
          .doc(_user?.uid)
          .collection('todos')
          .doc(todo.id)
          .set(todo.toMap());

      await _initializeTodos();
      _todoController.clear();

      // 진행 상황 업데이트
      await _updateProgress();
    } catch (e) {
      print('Error adding todo: $e');
    }
  }

  // 진행 상황 업데이트 메서드 추가
  Future<void> _updateProgress() async {
    try {
      final completedCount = _todos.where((t) => t.isCompleted).length;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // progress 컬렉션에 오늘의 진행 상황 업데이트
      await _firestore
          .collection('users')
          .doc(_user?.uid)
          .collection('progress')
          .doc(today.toIso8601String().split('T')[0])
          .set({
        'date': Timestamp.fromDate(today),
        'completedTodos': completedCount,
        'totalTodos': _todos.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('진행 상황 업데이트 완료: 완료=$completedCount, 전체=${_todos.length}');
    } catch (e) {
      print('진행 상황 업데이트 오류: $e');
    }
  }

  Future<void> _addRecommendedTodo() async {
    if (_todos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).localeName.startsWith('ko')
              ? '하루 최대 5개까지만 미션을 추가할 수 있습니다'
              : 'You can add up to 5 missions per day'),
        ),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final currentLocale =
          AppLocalizations.of(context).localeName.substring(0, 2);

      print('쿼리 경로: topics/todo/items, yearMonth: $yearMonth, isActive: true');

      // topics/todo/items에서 랜덤하게 하나 선택
      var activitiesQuery = await FirestorePaths.todoItems(_firestore)
          .where('yearMonth', isEqualTo: yearMonth)
          .where('isActive', isEqualTo: true)
          .get();

      // 활성화된 항목이 없으면 전체 collection에서 찾기
      if (activitiesQuery.docs.isEmpty) {
        activitiesQuery = await FirestorePaths.todoItems(_firestore)
            .where('isActive', isEqualTo: true)
            .limit(20)
            .get();
      }

      if (activitiesQuery.docs.isNotEmpty) {
        print('추천 미션 후보 ${activitiesQuery.docs.length}개 찾음');

        // 🆕 중복 방지 로직: 이미 사용된 것들 제외
        final availableDocs = activitiesQuery.docs
            .where((doc) => !_todayUsedRecommendations.contains(doc.id))
            .toList();

        print(
            '사용 가능한 추천: ${availableDocs.length}개 (전체: ${activitiesQuery.docs.length}개)');

        if (availableDocs.isEmpty) {
          print('모든 추천을 이미 사용했습니다. 기본 미션을 추가합니다.');
          await _addDefaultMission();
          return;
        }

        // 🆕 개선된 랜덤 선택 (microsecond 사용)
        final random =
            DateTime.now().microsecondsSinceEpoch % availableDocs.length;
        final randomActivity = availableDocs[random];
        final data = randomActivity.data() as Map<String, dynamic>?;

        if (data == null) {
          print('선택된 미션 데이터가 null입니다. 기본 미션을 추가합니다.');
          await _addDefaultMission();
          return;
        }

        print('선택된 미션 데이터: $data (ID: ${randomActivity.id})');
        // 다국어 처리: translations 필드 확인
        String taskContent;

        // 번역 데이터가 있는 경우
        if (data.containsKey('translations') && data['translations'] is Map) {
          final translations = data['translations'] as Map<String, dynamic>;

          // 현재 언어에 맞는 번역이 있는지 확인
          if (translations.containsKey(currentLocale)) {
            taskContent = translations[currentLocale];
          } else if (translations.containsKey('en')) {
            taskContent = translations['en'];
          } else if (translations.containsKey('ko')) {
            taskContent = translations['ko'];
          } else {
            taskContent = data['task'] ?? '새 미션';
          }
        } else {
          taskContent = data['task'] ?? '새 미션';
        }

        // 🆕 현재 Todo 목록과 중복 체크
        final currentTasks =
            _todos.map((todo) => todo.task.toLowerCase().trim()).toSet();
        if (currentTasks.contains(taskContent.toLowerCase().trim())) {
          print('이미 같은 내용의 미션이 있습니다: $taskContent');
          // 다른 추천 시도 (재귀적으로 한 번 더 시도)
          _todayUsedRecommendations.add(randomActivity.id);
          await _addRecommendedTodo();
          return;
        }

        // 🆕 사용된 추천 ID 기록
        _todayUsedRecommendations.add(randomActivity.id);

        await _addTodo(taskContent);

        // 추가 성공 메시지
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context).localeName.startsWith('ko')
                        ? '새로운 추천 미션이 추가되었습니다!'
                        : 'New recommended mission has been added!')),
          );
        }
      } else {
        await _addDefaultMission();
      }
    } catch (e) {
      print('Error adding recommended todo: $e');
      // 오류 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).localeName.startsWith('ko')
                      ? '추천 미션 추가 중 오류가 발생했습니다: $e'
                      : 'Error adding recommended mission: $e')),
        );
      }
    }
  }

  // 기본 미션 추가 메서드
  Future<void> _addDefaultMission() async {
    // 기본 미션 목록
    final defaultMissions = [
      AppLocalizations.of(context).localeName.startsWith('ko')
          ? '물 5잔 마시기'
          : 'Drink 5 glasses of water',
      AppLocalizations.of(context).localeName.startsWith('ko')
          ? '가벼운 스트레칭하기'
          : 'Do light stretching',
      AppLocalizations.of(context).localeName.startsWith('ko')
          ? '3분 명상하기'
          : '3-minute meditation',
      AppLocalizations.of(context).localeName.startsWith('ko')
          ? '감사한 일 적어보기'
          : 'Write down something you are grateful for',
      AppLocalizations.of(context).localeName.startsWith('ko')
          ? '집 정리하기'
          : 'Organize your home',
      AppLocalizations.of(context).localeName.startsWith('ko')
          ? '산책하기'
          : 'Take a walk',
    ];

    // 랜덤하게 하나 선택
    final task = defaultMissions[
        DateTime.now().millisecondsSinceEpoch % defaultMissions.length];
    await _addTodo(task);

    // 추가 성공 메시지
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context).localeName.startsWith('ko')
                    ? '추천 미션이 추가되었습니다'
                    : 'Recommended mission has been added')),
      );
    }
  }

  Future<void> _loadProgressData() async {
    try {
      final progressRef =
          _firestore.collection('users').doc(_user?.uid).collection('progress');

      final startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final snapshot = await progressRef
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final newProgressData = <DateTime, UserProgress>{};

      for (var doc in snapshot.docs) {
        try {
          final progress = UserProgress.fromFirestore(doc);
          final date = DateTime(
            progress.date.year,
            progress.date.month,
            progress.date.day,
          );
          newProgressData[date] = progress;
        } catch (e) {
          print('Error parsing progress data: $e');
        }
      }

      setState(() {
        _progressData = newProgressData;
      });
    } catch (e) {
      print('Error loading progress data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context).localeName.startsWith('ko')
                    ? '진행률 데이터 로드 중 오류가 발생했습니다: $e'
                    : 'An error occurred while loading progress data: $e')),
      );
    }
  }

  void _initializeAnimationController(String todoId) {
    if (!_animationControllers.containsKey(todoId)) {
      _animationControllers[todoId] = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );
    }
  }

  void _playCompletionAnimation(String todoId) {
    _initializeAnimationController(todoId);
    if (!(_animationControllers[todoId]?.isAnimating ?? false)) {
      _animationControllers[todoId]?.forward();
    }
  }

  Future<void> _toggleTodoStatus(TodoItem todo) async {
    try {
      final newIsCompleted = !todo.isCompleted;

      await _firestore
          .collection('users')
          .doc(_user?.uid)
          .collection('todos')
          .doc(todo.id)
          .update({
        'isCompleted': newIsCompleted,
        'completedAt': newIsCompleted ? FieldValue.serverTimestamp() : null,
      });

      setState(() {
        final index = _todos.indexWhere((t) => t.id == todo.id);
        if (index != -1) {
          _todos[index] = TodoItem(
            id: todo.id,
            task: todo.task,
            date: todo.date,
            isCompleted: newIsCompleted,
          );
        }
      });

      // 완료 상태로 변경된 경우 애니메이션 재생
      if (newIsCompleted) {
        _initializeAnimationController(todo.id);
        _playCompletionAnimation(todo.id);
      }

      // 진행 상황 업데이트
      await _updateProgress();

      final completedCount = _todos.where((t) => t.isCompleted).length;
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];

      final todayMoods = await _firestore
          .collection('users')
          .doc(_user?.uid)
          .collection('moods')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(today.year, today.month, today.day)))
          .where('date',
              isLessThanOrEqualTo: Timestamp.fromDate(
                  DateTime(today.year, today.month, today.day, 23, 59, 59)))
          .get();

      String mood = '��';
      if (todayMoods.docs.isNotEmpty) {
        mood = todayMoods.docs.first.data()['mood'] as String;
      }

      double happinessScore =
          _calculateHappinessScore(completedCount, _todos.length, mood);

      await _firestore
          .collection('users')
          .doc(_user?.uid)
          .collection('progress')
          .doc(todayStr)
          .set({
        'date': Timestamp.fromDate(today),
        'completedTodos': completedCount,
        'totalTodos': _todos.length,
        'mood': mood,
        'happinessScore': happinessScore,
        'userId': _user?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadProgressData();
    } catch (e) {
      print('Error toggling todo status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context).localeName.startsWith('ko')
                    ? '오류가 발생했습니다: $e'
                    : 'An error occurred: $e')),
      );
    }
  }

  double _calculateHappinessScore(int completed, int total, String mood) {
    double completionRate = total > 0 ? (completed / total) * 60 : 0;

    double moodScore = 0;
    switch (mood) {
      case '😊':
        moodScore = 40;
        break;
      case '😐':
        moodScore = 30;
        break;
      case '😩':
        moodScore = 20;
        break;
      case '😢':
        moodScore = 10;
        break;
      case '😠':
        moodScore = 0;
        break;
    }

    return completionRate + moodScore;
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)
                                    .localeName
                                    .startsWith('ko')
                                ? '새로운 미션 (${_todos.length}/5)'
                                : 'New mission (${_todos.length}/5)',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: _todoController,
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)
                                            .localeName
                                            .startsWith('ko')
                                        ? '새로운 미션을 입력하세요'
                                        : 'Enter a new mission',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  style: TextStyle(fontSize: 14),
                                  onSubmitted: (value) {
                                    if (value.isNotEmpty) {
                                      _addTodo(value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_todoController.text.isNotEmpty) {
                                        _addTodo(_todoController.text);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppLocalizations.of(context)
                                                .localeName
                                                .startsWith('ko')
                                            ? '입력'
                                            : 'Add',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  child: ElevatedButton(
                                    onPressed: _addRecommendedTodo,
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppLocalizations.of(context)
                                                .localeName
                                                .startsWith('ko')
                                            ? '추천'
                                            : 'Rec',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildMissionBox(),
                  const SizedBox(height: 20),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: todo.isCompleted
                            ? (isDark
                                ? const Color.fromARGB(35, 0, 0, 0)
                                : Colors.green.shade50)
                            : (isDark
                                ? const Color.fromARGB(43, 58, 31, 16)
                                : Colors.orange.shade50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: todo.isCompleted
                                      ? Colors.green.shade200
                                      : Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  todo.task,
                                  style: TextStyle(
                                    decoration: todo.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: todo.isCompleted
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                value: todo.isCompleted,
                                onChanged: (bool? value) {
                                  _toggleTodoStatus(todo);
                                },
                                checkboxShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                activeColor: Colors.green,
                                checkColor: Colors.white,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                            if (todo.isCompleted)
                              Positioned.fill(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    _buildCompletionAnimation(todo.id),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionAnimation(String todoId) {
    _initializeAnimationController(todoId);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final controller = _animationControllers[todoId];
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animation = controller;

        // 애니메이션이 완료되었거나 진행 중일 때의 크기와 투명도
        final size = animation.status == AnimationStatus.completed
            ? 100.0 // 애니메이션 완료 시 고정 크기
            : Tween<double>(begin: 0, end: 100.0)
                .animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
                ))
                .value;

        final opacity = animation.status == AnimationStatus.completed
            ? 1.0 // 애니메이션 완료 시 완전 불투명
            : Tween<double>(begin: 0.0, end: 1.0)
                .animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
                ))
                .value;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: size / 100,
            child: Image.asset(
              'assets/images/mission.png',
              width: screenWidth * 0.75,
              height: screenHeight * 0.75,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMissionBox() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final missionColors = isDarkMode
        ? AppTheme.missionBoxColors['dark']!
        : AppTheme.missionBoxColors['light']!;

    return Container(
      decoration: BoxDecoration(
        color: missionColors['background'],
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        AppLocalizations.of(context).localeName.startsWith('ko')
            ? '오늘의 미션'
            : 'Today\'s mission',
        style: TextStyle(
          color: isDarkMode ? Colors.white : missionColors['text'],
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 🆕 디버그용: 사용된 추천 상태 확인
  void _printRecommendationStats() {
    print('=== 추천 미션 상태 ===');
    print('오늘 사용된 추천 수: ${_todayUsedRecommendations.length}개');
    print('사용된 ID들: $_todayUsedRecommendations');
    print('현재 Todo 수: ${_todos.length}개');
    print('====================');
  }

  @override
  Widget build(BuildContext context) {
    // 언어에 따른 레이블 미리 정의
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');
    final labels = {
      'history': isKorean ? '이전기록' : 'Previous records',
      'goal': isKorean ? '목표설정' : 'Goal setting',
      'chart': isKorean ? '차트' : 'Chart',
    };

    final List<Widget> screens = [
      const TodoHistoryScreen(),
      _buildMainContent(),
      const TodoAnalysisScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: labels['history'],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_task),
            label: labels['goal'],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: labels['chart'],
          ),
        ],
      ),
    );
  }
}
