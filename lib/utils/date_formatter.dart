import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(DateTime date, String locale) {
    // 로케일에 맞는 기본 날짜 형식 사용
    try {
      if (locale.startsWith('ko')) {
        return DateFormat('yyyy년 MM월 dd일').format(date);
      } else {
        // 더 짧은 영어 형식 사용
        return DateFormat('MMM d, yyyy').format(date); // 'Sep 15, 2023'
        // 또는 더 짧게:
        // return DateFormat('M/d/yy').format(date);  // '9/15/23'
      }
    } catch (e) {
      return DateFormat('M/d/yy').format(date);
    }
  }

  static String formatTime(DateTime time, String locale) {
    if (locale.startsWith('ko')) {
      return DateFormat('a h시 mm분').format(time);
    } else {
      return DateFormat('h:mm a').format(time);
    }
  }

  static String formatDateTime(DateTime dateTime, String locale) {
    if (locale.startsWith('ko')) {
      return DateFormat('yyyy년 MM월 dd일 a h시 mm분').format(dateTime);
    } else {
      return DateFormat('MMM dd, yyyy h:mm a').format(dateTime);
    }
  }
}
