import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_models.dart';
import '../models/mood_models.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  DatabaseService({required this.userId});

  // Collections
  CollectionReference<Map<String, dynamic>> get _todosCollection =>
      _firestore.collection('users').doc(userId).collection('todos');

  CollectionReference<Map<String, dynamic>> get _moodsCollection =>
      _firestore.collection('users').doc(userId).collection('moods');

  CollectionReference<Map<String, dynamic>> get _progressCollection =>
      _firestore.collection('users').doc(userId).collection('progress');

  // Todos
  Future<List<TodoItem>> getTodayTodos() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final snapshot = await _todosCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs.map((doc) => TodoItem.fromFirestore(doc)).toList();
  }

  Future<void> addTodo(TodoItem todo) async {
    await _todosCollection.doc(todo.id).set(todo.toFirestore());
  }

  Future<void> updateTodoStatus(String todoId, bool isCompleted) async {
    await _todosCollection.doc(todoId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
    await _updateDailyProgress();
  }

  Future<void> deleteTodo(String todoId) async {
    await _todosCollection.doc(todoId).delete();
    await _updateDailyProgress();
  }

  // Moods
  Stream<List<MoodEntry>> getMoodEntries() {
    return _moodsCollection.orderBy('date', descending: true).snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => MoodEntry.fromFirestore(doc)).toList());
  }

  Future<void> addMoodEntry(MoodEntry entry) async {
    await _moodsCollection.doc(entry.id).set(entry.toFirestore());
  }

  Future<void> updateMoodEntry(
    String entryId, {
    String? mood,
    String? content,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (mood != null) updates['mood'] = mood;
    if (content != null) updates['content'] = content;

    await _moodsCollection.doc(entryId).update(updates);
  }

  Future<void> deleteMoodEntry(String entryId) async {
    await _moodsCollection.doc(entryId).delete();
  }

  // Progress
  Future<void> _updateDailyProgress() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todos = await getTodayTodos();

    final completedCount = todos.where((todo) => todo.isCompleted).length;
    final totalCount = todos.length;

    // 오늘의 기분을 가져오기
    final todayMoods = await _moodsCollection
        .where('date', isEqualTo: Timestamp.fromDate(DateTime.parse(today)))
        .get();

    String mood = '😊'; // 기본 기분
    if (todayMoods.docs.isNotEmpty) {
      mood = todayMoods.docs.first.data()['mood'] as String;
    }

    final progress = UserProgress(
      id: today,
      userId: userId,
      date: DateTime.parse(today),
      completedTodos: completedCount,
      totalTodos: totalCount,
      mood: mood,
      happinessScore:
          _calculateHappinessScore(completedCount, totalCount, mood),
      updatedAt: DateTime.now(),
    );

    await _progressCollection.doc(today).set(progress.toFirestore());
  }

  double _calculateHappinessScore(int completed, int total, String mood) {
    // 완료율 계산 (60% 비중)
    double completionRate = total > 0 ? (completed / total) * 60 : 0;

    // 기분 점수 계산 (40% 비중)
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

  Future<Map<DateTime, UserProgress>> getMonthlyProgress(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    final snapshot = await _progressCollection
        .where('id', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('id', isLessThanOrEqualTo: endDate.toIso8601String())
        .get();

    final progressMap = <DateTime, UserProgress>{};
    for (var doc in snapshot.docs) {
      final progress = UserProgress.fromFirestore(doc);
      progressMap[DateTime.parse(progress.id)] = progress;
    }

    return progressMap;
  }

  // Batch operations
  Future<void> clearAllUserData() async {
    final batch = _firestore.batch();

    // Delete all todos
    final todos = await _todosCollection.get();
    for (var doc in todos.docs) {
      batch.delete(doc.reference);
    }

    // Delete all moods
    final moods = await _moodsCollection.get();
    for (var doc in moods.docs) {
      batch.delete(doc.reference);
    }

    // Delete all progress
    final progress = await _progressCollection.get();
    for (var doc in progress.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // 마지막 리셋 날짜 가져오기
  Future<DateTime?> getLastResetDate() async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('todo')
        .get();

    if (!doc.exists) return null;
    return (doc.data()?['lastResetDate'] as Timestamp?)?.toDate();
  }

  // 마지막 리셋 날짜 업데이트
  Future<void> updateLastResetDate(DateTime date) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('todo')
        .set({
      'lastResetDate': Timestamp.fromDate(date),
    }, SetOptions(merge: true));
  }

  // Todo 기록 저장
  Future<void> saveTodoHistory({
    required DateTime date,
    required int completedCount,
    required int totalCount,
    required double completionRate,
    required List<TodoItem> todos,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('todoHistory')
        .doc(dateStr)
        .set({
      'date': Timestamp.fromDate(date),
      'completedCount': completedCount,
      'totalCount': totalCount,
      'completionRate': completionRate,
      'todos': todos.map((todo) => todo.toFirestore()).toList(),
    });
  }

  // 모든 Todo 삭제
  Future<void> deleteAllTodos() async {
    final batch = _firestore.batch();
    final todos = await _firestore
        .collection('users')
        .doc(userId)
        .collection('todos')
        .get();

    for (var doc in todos.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
