/// Formatting helpers (pure functions, no widgets, no state).
/// Swap for `intl` once you need multi-currency / locale support.
library;

import '../config/constants.dart';

String money(double value, {String symbol = Constants.currency}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '${negative ? '-' : ''}$symbol $buf.${parts[1]}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String monthShort(DateTime d) => _months[d.month - 1];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Round to 2 decimal places (sen). All money math should pass through this.
double round2(double v) => (v * 100).roundToDouble() / 100;

/// Parses user input like "1,250.50". Returns null if invalid.
double? parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', ''));

String fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "8 Oct" — compact, for lists.
String fmtDateShort(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "Wednesday, 8 October"
String fmtLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_monthsLong[d.month - 1]}';

/// "October 2026" — month group headers.
String fmtMonthYear(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Plain-language due state: "Due today", "Due in 5 days", "12 days overdue".
String relativeDue(DateTime due, DateTime today) {
  final days = dateOnly(due).difference(dateOnly(today)).inDays;
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days > 1) return 'Due in $days days';
  if (days == -1) return '1 day overdue';
  return '${-days} days overdue';
}

/// "Tan Hardware Sdn Bhd" → "TH"
String initialsOf(String name) {
  final words = name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(w[0]))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}
