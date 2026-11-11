import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/todo_models.dart';
import '../models/mood_models.dart';

// 공통 인터페이스 정의
abstract class ProgressData {
  int get completedTodos;
  int get totalTodos;
}

// UserProgress와 MoodProgress를 ProgressData로 확장
extension UserProgressExtension on UserProgress {
  ProgressData asProgressData() {
    return _ProgressDataImpl(
      completedTodos: completedTodos,
      totalTodos: totalTodos,
    );
  }
}

extension MoodProgressExtension on MoodProgress {
  ProgressData asProgressData() {
    return _ProgressDataImpl(
      completedTodos: completedTodos,
      totalTodos: totalTodos,
    );
  }
}

// ProgressData 구현체
class _ProgressDataImpl implements ProgressData {
  @override
  final int completedTodos;
  @override
  final int totalTodos;

  _ProgressDataImpl({
    required this.completedTodos,
    required this.totalTodos,
  });
}

class CalendarWidget<T> extends StatefulWidget {
  final Map<DateTime, T> progressData;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;
  final ProgressData Function(T)? progressConverter;

  const CalendarWidget({
    super.key,
    required this.progressData,
    required this.selectedDate,
    required this.onDaySelected,
    this.progressConverter,
  });

  @override
  State<CalendarWidget<T>> createState() => _CalendarWidgetState<T>();
}

class _CalendarWidgetState<T> extends State<CalendarWidget<T>> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDate;
    _selectedDay = widget.selectedDate;
  }

  Color _getProgressColor(double completion) {
    if (completion >= 0.9) return Colors.green.shade500.withOpacity(0.2);
    if (completion >= 0.7) return Colors.lightGreen.shade300.withOpacity(0.2);
    if (completion >= 0.3) return Colors.orange.shade300.withOpacity(0.2);
    return Colors.red.shade300.withOpacity(0.2);
  }

  ProgressData? _getProgressData(DateTime date) {
    final data = widget.progressData[DateTime(date.year, date.month, date.day)];
    if (data == null) return null;

    if (data is UserProgress) {
      return (data).asProgressData();
    } else if (data is MoodProgress) {
      return (data).asProgressData();
    } else if (widget.progressConverter != null) {
      return widget.progressConverter!(data);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TableCalendar(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2025, 12, 31),
        focusedDay: _focusedDay,
        currentDay: DateTime.now(),
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.red[300]),
          holidayTextStyle: TextStyle(color: Colors.red[300]),
          selectedDecoration: BoxDecoration(
            border:
                Border.all(color: Theme.of(context).primaryColor, width: 1.5),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
          ),
          todayDecoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).primaryColor, width: 1),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          widget.onDaySelected(selectedDay);
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final progress = _getProgressData(day);
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: progress != null
                    ? _getProgressColor(
                        progress.completedTodos / progress.totalTodos)
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final progress = _getProgressData(day);
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: progress != null
                    ? _getProgressColor(
                        progress.completedTodos / progress.totalTodos)
                    : null,
                border: Border.all(
                    color: Theme.of(context).primaryColor, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
          todayBuilder: (context, day, focusedDay) {
            final progress = _getProgressData(day);
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: progress != null
                    ? _getProgressColor(
                        progress.completedTodos / progress.totalTodos)
                    : null,
                border:
                    Border.all(color: Theme.of(context).primaryColor, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
