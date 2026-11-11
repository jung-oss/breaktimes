import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';
import '../../models/todo_models.dart';
import '../../widgets/todo_widgets.dart';
import '../../core/localization/app_localizations.dart';

class TodoAnalysisScreen extends StatefulWidget {
  const TodoAnalysisScreen({super.key});
  @override
  State<TodoAnalysisScreen> createState() => _TodoAnalysisScreenState();
}

class _TodoAnalysisScreenState extends State<TodoAnalysisScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  String _selectedPeriod = '전체';
  List<UserProgress> _progressData = [];
  bool _isLoading = true;
  StreamSubscription? _progressSubscription;

  // 통계 데이터
  List<PeriodSummary> _summaryData = [];

  final List<String> _periodOptions = ['전체', '주간', '월간', '년간'];

  @override
  void initState() {
    super.initState();
    _selectedPeriod = '전체';
    _subscribeToProgressData();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToProgressData() {
    _progressSubscription?.cancel();
    setState(() => _isLoading = true);
    _progressSubscription = _getProgressStream().listen((data) {
      if (mounted) {
        setState(() {
          _progressData = data;
          _prepareSummaryData(); // 요약 데이터 준비
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('Progress stream error: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  // 필터에 따른 시작 날짜 계산
  DateTime _getStartDate(DateTime now, String period) {
    switch (period) {
      case '전체':
        return DateTime(2000, 1, 1);
      case '년간':
        return DateTime(now.year, 1, 1);
      case '월간':
        return DateTime(now.year, now.month, 1);
      case '주간':
        return now.subtract(Duration(days: now.weekday - 1));
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  // 필터에 따른 종료 날짜 계산
  DateTime _getEndDate(DateTime now, String period) {
    switch (period) {
      case '전체':
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case '년간':
        return DateTime(now.year, 12, 31, 23, 59, 59);
      case '월간':
        // 현재 월의 마지막 날 계산
        final lastDay = DateTime(now.year, now.month + 1, 0);
        return DateTime(now.year, now.month, lastDay.day, 23, 59, 59);
      case '주간':
        // 주의 시작일(월요일)로부터 6일 후(일요일)
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return startOfWeek
            .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      default:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  // 요약 데이터 준비 (월별, 연도별 등 기간에 따라 그룹화)
  void _prepareSummaryData() {
    // 요약 데이터 초기화
    _summaryData = [];

    if (_progressData.isEmpty) return;

    if (_selectedPeriod == '전체') {
      // 전체 데이터는 월별로 그룹화
      _prepareMonthlySummary();
    } else if (_selectedPeriod == '년간') {
      // 년간 데이터는 월별로 그룹화
      _prepareMonthlySummary();
    } else if (_selectedPeriod == '월간') {
      // 월간 데이터는 주별로 그룹화
      _prepareWeeklySummary();
    } else {
      // 주간 데이터는 일별 그대로 사용
      _prepareDailySummary();
    }
  }

  // 월별 요약 데이터 준비
  void _prepareMonthlySummary() {
    // 월별로 그룹화
    Map<String, PeriodSummary> monthlySummary = {};

    for (var progress in _progressData) {
      final date = progress.date;
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      if (!monthlySummary.containsKey(monthKey)) {
        monthlySummary[monthKey] = PeriodSummary(
          period: DateFormat('yyyy년 MM월').format(date),
          startDate: DateTime(date.year, date.month, 1),
          totalTasks: 0,
          completedTasks: 0,
        );
      }

      monthlySummary[monthKey]!.totalTasks += progress.totalTodos;
      monthlySummary[monthKey]!.completedTasks += progress.completedTodos;
    }

    // 날짜순으로 정렬
    _summaryData = monthlySummary.values.toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  // 주별 요약 데이터 준비
  void _prepareWeeklySummary() {
    // 주별로 그룹화 (해당 월의 각 주)
    Map<int, PeriodSummary> weeklySummary = {};

    for (var progress in _progressData) {
      final date = progress.date;
      // 해당 월의 몇 번째 주인지 계산
      final firstDayOfMonth = DateTime(date.year, date.month, 1);
      final daysSinceFirstDay = date.difference(firstDayOfMonth).inDays;
      final weekNumber = (daysSinceFirstDay / 7).floor() + 1;

      if (!weeklySummary.containsKey(weekNumber)) {
        final weekStart =
            firstDayOfMonth.add(Duration(days: (weekNumber - 1) * 7));
        final weekLabel = '${weekNumber}주차';

        weeklySummary[weekNumber] = PeriodSummary(
          period: weekLabel,
          startDate: weekStart,
          totalTasks: 0,
          completedTasks: 0,
        );
      }

      weeklySummary[weekNumber]!.totalTasks += progress.totalTodos;
      weeklySummary[weekNumber]!.completedTasks += progress.completedTodos;
    }

    // 주차 순으로 정렬
    _summaryData = weeklySummary.values.toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  // 일별 요약 데이터 준비 (원본 데이터 그대로 사용)
  void _prepareDailySummary() {
    for (var progress in _progressData) {
      _summaryData.add(PeriodSummary(
        period: DateFormat('MM/dd (E)').format(progress.date),
        startDate: progress.date,
        totalTasks: progress.totalTodos,
        completedTasks: progress.completedTodos,
      ));
    }

    // 날짜순으로 정렬
    _summaryData.sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      return _buildContent(constraints, theme);
    });
  }

  Widget _buildContent(BoxConstraints constraints, ThemeData theme) {
    final spacing = constraints.maxWidth * 0.04;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primary,
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(constraints, theme),
            SizedBox(height: spacing),
            _buildSummaryCards(constraints, theme),
            SizedBox(height: spacing),
            _buildChartSection(constraints, theme),
            SizedBox(height: spacing),
            _buildLegend(constraints, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BoxConstraints constraints, ThemeData theme) {
    final textSize = constraints.maxWidth * 0.04;
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isKorean ? '할일 분석' : 'Todo Analysis',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            DropdownButton<String>(
              value: _selectedPeriod,
              items: _periodOptions.map((String value) {
                final label = isKorean ? value : _getEnglishPeriodLabel(value);
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(label, style: TextStyle(fontSize: textSize)),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPeriod = newValue;
                    _subscribeToProgressData();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // 영어 필터 레이블 가져오기
  String _getEnglishPeriodLabel(String koreanLabel) {
    switch (koreanLabel) {
      case '전체':
        return 'All';
      case '주간':
        return 'Weekly';
      case '월간':
        return 'Monthly';
      case '년간':
        return 'Yearly';
      default:
        return koreanLabel;
    }
  }

  Widget _buildSummaryCards(BoxConstraints constraints, ThemeData theme) {
    if (_progressData.isEmpty) return const SizedBox.shrink();

    final stats = _calculateStats();
    final cardSpacing = constraints.maxWidth * 0.02;
    final cardWidth = (constraints.maxWidth - 4 * cardSpacing) / 2;
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StatCard(
              width: cardWidth,
              constraints: constraints,
              title: isKorean ? '총 할일' : 'Total Tasks',
              value: stats.totalTasks.toString(),
              icon: Icons.assignment,
              color: Colors.blue,
            ),
            StatCard(
              width: cardWidth,
              constraints: constraints,
              title: isKorean ? '완료한 할일' : 'Completed Tasks',
              value: stats.completedTasks.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),
          ],
        ),
        SizedBox(height: cardSpacing),
        StatCard(
          width: constraints.maxWidth,
          constraints: constraints,
          title: isKorean ? '평균 달성률' : 'Average Completion Rate',
          value: stats.avgCompletion,
          icon: Icons.trending_up,
          color: Colors.orange,
        ),
      ],
    );
  }

  _Stats _calculateStats() {
    int totalTasks = 0;
    int completedTasks = 0;
    for (var progress in _progressData) {
      totalTasks += progress.totalTodos;
      completedTasks += progress.completedTodos;
    }
    final avgCompletion = totalTasks > 0
        ? (completedTasks / totalTasks * 100).toStringAsFixed(1)
        : '0';
    return _Stats(totalTasks, completedTasks, avgCompletion);
  }

  Widget _buildChartSection(BoxConstraints constraints, ThemeData theme) {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    if (_summaryData.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
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
        child: Column(
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              isKorean ? '차트 데이터가 없습니다' : 'No chart data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    // 선택한 기간에 따른 메시지 추가
    final periodMessage = isKorean
        ? '선택 기간: $_selectedPeriod (${_summaryData.length}개 데이터)'
        : 'Selected period: ${_getEnglishPeriodLabel(_selectedPeriod)} (${_summaryData.length} records)';

    // 차트 너비 계산 수정 - 스크롤 가능하도록 최소 너비 설정
    final chartWidth = max(constraints.maxWidth, _summaryData.length * 100.0);
    final chartHeight = constraints.maxHeight * 0.4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isKorean ? '달성률 추이' : 'Completion Rate Trend',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          periodMessage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SizedBox(height: constraints.maxHeight * 0.02),
        SizedBox(
          height: chartHeight,
          width: constraints.maxWidth,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                  child: LineChart(_createChartData(constraints)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  LineChartData _createChartData(BoxConstraints constraints) {
    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: _summaryData.asMap().entries.map((entry) {
            // 달성률 계산
            final summary = entry.value;
            final completionRate = summary.totalTasks > 0
                ? (summary.completedTasks / summary.totalTasks * 100)
                : 0.0;
            return FlSpot(entry.key.toDouble(), completionRate);
          }).toList(),
          isCurved: true,
          color: Theme.of(context).primaryColor,
          barWidth: 3,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
        ),
      ],
      minY: 0,
      maxY: 100,
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= _summaryData.length) return const Text('');

              final periodLabel = _summaryData[value.toInt()].period;

              // 라벨 크기에 따라 회전 각도 조정
              final rotationAngle =
                  _selectedPeriod == '년간' || _selectedPeriod == '전체'
                      ? -0.5
                      : 0.0;

              return Transform.rotate(
                angle: rotationAngle,
                child: Text(
                  periodLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 20,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.2),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  Widget _buildLegend(BoxConstraints constraints, ThemeData theme) {
    final isKorean = AppLocalizations.of(context).localeName.startsWith('ko');

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(constraints.maxWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKorean ? '달성률 기준' : 'Completion Rate Baseline',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: constraints.maxHeight * 0.01),
            _buildLegendItem(
              isKorean ? '90% 이상' : '90% or more',
              Colors.green.shade500,
              constraints,
            ),
            _buildLegendItem(isKorean ? '70-89%' : '70-89%',
                Colors.lightGreen.shade300, constraints),
            _buildLegendItem(isKorean ? '30-69%' : '30-69%',
                Colors.orange.shade300, constraints),
            _buildLegendItem(isKorean ? '30% 미만' : 'Less than 30%',
                Colors.red.shade300, constraints),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
      String text, Color color, BoxConstraints constraints) {
    final size = constraints.maxWidth * 0.05;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size * 0.2),
      child: Row(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          SizedBox(width: size * 0.4),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Stream<List<UserProgress>> _getProgressStream() {
    final now = DateTime.now();
    final startDate = _getStartDate(now, _selectedPeriod);
    final endDate = _getEndDate(now, _selectedPeriod);

    print(
        'Progress data subscription: from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
    print('Selected period: $_selectedPeriod');

    return _firestore
        .collection('users')
        .doc(_user?.uid)
        .collection('progress')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      // 각 문서를 안전하게 변환하고 유효한 데이터만 반환
      final validData = snapshot.docs
          .map((doc) {
            try {
              return UserProgress.fromFirestore(doc);
            } catch (e) {
              print('Error parsing document ${doc.id}: $e');
              return null;
            }
          })
          .where((progress) => progress != null)
          .cast<UserProgress>()
          .toList();

      print('Progress data updated: ${validData.length} records');

      // 정렬 (날짜 오름차순)
      validData.sort((a, b) => a.date.compareTo(b.date));

      return validData;
    });
  }
}

// 통계 기간별 요약 데이터 클래스
class PeriodSummary {
  final String period; // 표시될 기간 라벨 (예: "2023년 5월", "1주차" 등)
  final DateTime startDate; // 정렬용 시작 날짜
  int totalTasks; // 총 할일 수
  int completedTasks; // 완료한 할일 수

  PeriodSummary({
    required this.period,
    required this.startDate,
    this.totalTasks = 0,
    this.completedTasks = 0,
  });

  // 달성률 계산
  double get completionRate =>
      totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;
}

class _Stats {
  final int totalTasks;
  final int completedTasks;
  final String avgCompletion;

  _Stats(this.totalTasks, this.completedTasks, this.avgCompletion);
}
