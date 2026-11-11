import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_models.dart';
import '../utils/firestore_paths.dart';

class TodoProvider with ChangeNotifier {
  final DatabaseService _db;
  final BuildContext context;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<TodoItem> _todos = [];
  bool _isLoading = false;
  DateTime? _lastResetDate;

  TodoProvider({required String userId, required this.context})
      : _db = DatabaseService(userId: userId) {
    _initializeLastResetDate();
  }

  List<TodoItem> get todos => _todos;
  bool get isLoading => _isLoading;

  Future<void> _initializeLastResetDate() async {
    _lastResetDate = await _db.getLastResetDate();
  }

  bool _shouldReset() {
    if (_lastResetDate == null) return true;

    final now = DateTime.now();
    final lastReset = DateTime(
        _lastResetDate!.year, _lastResetDate!.month, _lastResetDate!.day);
    final today = DateTime(now.year, now.month, now.day);

    return today.isAfter(lastReset);
  }

  Future<void> checkAndResetTodos() async {
    try {
      // null 체크 추가 - _shouldReset() 호출 전에 _lastResetDate가 초기화되었는지 확인
      if (_lastResetDate == null) {
        // _lastResetDate가 null이면 먼저 초기화
        await _initializeLastResetDate();
      }

      // shouldReset이 null이 아닌 bool 값을 반환하는지 확인
      final shouldReset = _shouldReset();

      if (shouldReset) {
        await _saveTodoHistory();
        await _resetTodos();
        _lastResetDate = DateTime.now();
        await _db.updateLastResetDate(_lastResetDate!);
      }
    } catch (e) {
      print('Error checking and resetting todos: $e');
      // 오류 발생 시 기본값 설정
      _lastResetDate ??= DateTime.now();
    }
  }

  Future<void> _saveTodoHistory() async {
    if (_todos.isEmpty) return;

    try {
      final completedCount = _todos.where((todo) => todo.isCompleted).length;
      final totalCount = _todos.length;
      final completionRate =
          totalCount > 0 ? (completedCount / totalCount) * 100 : 0;

      await _db.saveTodoHistory(
        date: _lastResetDate ?? DateTime.now(),
        completedCount: completedCount,
        totalCount: totalCount,
        completionRate: completionRate.toDouble(),
        todos: _todos,
      );
    } catch (e) {
      print('Error saving todo history: $e');
    }
  }

  Future<void> _resetTodos() async {
    try {
      // 기존 할일 모두 삭제
      await _db.deleteAllTodos();
      _todos.clear();

      // 새로운 할일 생성
      await _generateDailyTodos();
    } catch (e) {
      print('Error resetting todos: $e');
    }
  }

  Future<void> loadTodayTodos() async {
    try {
      _setLoading(true);
      await checkAndResetTodos();
      _todos = await _db.getTodayTodos();

      // 만약 오늘의 할일이 없다면 자동 생성
      if (_todos.isEmpty) {
        await _generateDailyTodos();
      }

      notifyListeners();
    } catch (e) {
      print('Error loading today todos: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _generateDailyTodos() async {
    try {
      final now = DateTime.now();
      final currentLocale = Localizations.localeOf(context).languageCode;

      final snapshot = await FirestorePaths.todoItems(_firestore)
          .where('isActive', isEqualTo: true)
          .limit(5)
          .get();

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          String taskText;

          if (data.containsKey('translations') && data['translations'] is Map) {
            final translations = data['translations'] as Map<String, dynamic>;

            if (translations.containsKey(currentLocale)) {
              taskText = translations[currentLocale];
            } else if (translations.containsKey('en') &&
                currentLocale == 'en') {
              taskText = translations['en'];
            } else if (translations.containsKey('ko')) {
              taskText = translations['ko'];
            } else {
              taskText = data['task'] ?? '기본 미션';
            }
          } else {
            taskText = data['task'] ?? '기본 미션';
          }

          final todo = TodoItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            task: taskText,
            date: now.toIso8601String(),
            userId: _db.userId,
            templateId: doc.id,
          );

          await _db.addTodo(todo);
          _todos.add(todo);
        }
      } else {
        final defaultMissions = currentLocale == 'en'
            ? [
                "Drink 5 glasses of water",
                "Do light stretching",
                "3-minute meditation",
                "Write down something you are grateful for",
                "Organize your home"
              ]
            : ["물 5잔 마시기", "가벼운 스트레칭하기", "3분 명상하기", "감사한 일 적어보기", "집 정리하기"];

        for (var task in defaultMissions) {
          final todo = TodoItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            task: task,
            date: now.toIso8601String(),
            userId: _db.userId,
            templateId: 'default',
          );

          await _db.addTodo(todo);
          _todos.add(todo);
        }
      }
    } catch (e) {
      print('Error generating daily todos: $e');
      _generateDefaultTodos();
    }
  }

  void _generateDefaultTodos() {
    final currentLocale = Localizations.localeOf(context).languageCode;
    final defaultTasks = currentLocale == 'en'
        ? ["Drink some water", "Take a deep breath", "Stretch your body"]
        : ["물 마시기", "심호흡하기", "스트레칭하기"];

    final now = DateTime.now();

    for (var task in defaultTasks) {
      final todo = TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        task: task,
        date: now.toIso8601String(),
        userId: _db.userId,
        templateId: 'default',
      );

      _db.addTodo(todo);
      _todos.add(todo);
    }
  }

  Future<void> toggleTodoStatus(TodoItem todo) async {
    try {
      await _db.updateTodoStatus(todo.id, !todo.isCompleted);
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index != -1) {
        _todos[index] = todo.copyWith(
          isCompleted: !todo.isCompleted,
          completedAt: !todo.isCompleted ? DateTime.now() : null,
        );
        notifyListeners();
      }

      // 진행 상황 업데이트 추가 - 할일 상태 변경 후 즉시 업데이트
      await _updateProgress();
    } catch (e) {
      print('Error toggling todo status: $e');
      rethrow;
    }
  }

  Future<void> deleteTodo(String todoId) async {
    try {
      await _db.deleteTodo(todoId);
      _todos.removeWhere((todo) => todo.id == todoId);
      notifyListeners();

      // 진행 상황 업데이트 추가 - 할일 삭제 후 즉시 업데이트
      await _updateProgress();
    } catch (e) {
      print('Error deleting todo: $e');
      rethrow;
    }
  }

  Future<void> addTodo(String task) async {
    try {
      final todo = TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        task: task,
        date: DateTime.now().toIso8601String(),
        userId: _db.userId,
        templateId: 'default',
      );

      await _db.addTodo(todo);
      _todos.add(todo);

      // 진행 상황 업데이트
      await _updateProgress();

      notifyListeners();
    } catch (e) {
      print('Error adding todo: $e');
      rethrow;
    }
  }

  Future<void> _updateProgress() async {
    try {
      final completedCount = _todos.where((todo) => todo.isCompleted).length;
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      // 현재 사용자의 mood 정보 가져오기
      String mood = '😊'; // 기본값
      try {
        final todayMoods = await _firestore
            .collection('users')
            .doc(_db.userId)
            .collection('moods')
            .where('date',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(DateTime(now.year, now.month, now.day)))
            .where('date',
                isLessThanOrEqualTo: Timestamp.fromDate(
                    DateTime(now.year, now.month, now.day, 23, 59, 59)))
            .get();

        if (todayMoods.docs.isNotEmpty) {
          mood = todayMoods.docs.first.data()['mood'] as String? ?? '😊';
        }
      } catch (e) {
        print('Error getting mood info: $e');
      }

      // 행복 점수 계산
      double happinessScore =
          _calculateHappinessScore(completedCount, _todos.length, mood);

      // 진행 상황 업데이트 (병합 방식으로 기존 문서 업데이트)
      await _firestore
          .collection('users')
          .doc(_db.userId)
          .collection('progress')
          .doc(todayStr)
          .set({
        'date': Timestamp.fromDate(now),
        'completedTodos': completedCount,
        'totalTodos': _todos.length,
        'mood': mood,
        'happinessScore': happinessScore,
        'userId': _db.userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print(
          'Progress updated - completed: $completedCount, total: ${_todos.length}, date: $todayStr');
    } catch (e) {
      print('Error updating progress: $e');
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
