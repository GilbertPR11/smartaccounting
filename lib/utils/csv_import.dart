import 'format.dart';

// Reads a bank statement exported as CSV (pasted as text). Pure functions,
// tested in test/accounting_test.dart.
//
// Handles what Malaysian bank exports usually look like:
// * a header row naming the columns (any order), or no header at all
//   (then: date, description, amount);
// * one signed "Amount" column, or separate "Debit"/"Credit"
//   (or "Withdrawal"/"Deposit", "Money out"/"Money in") columns;
// * amounts like "1,234.50", "RM 12.00", "(45.00)", "45.00 DR" / "45.00 CR";
// * dates like 31/10/2026, 31-10-2026, 2026-10-31, 31 Oct 2026, 31-Oct-26.

class StatementLine {
  const StatementLine({required this.date, required this.description, required this.amount});

  final DateTime date;
  final String description;

  /// Positive = money in, negative = money out.
  final double amount;
}

class StatementParseResult {
  const StatementParseResult(this.lines, this.problems);

  final List<StatementLine> lines;

  /// "Row 4: couldn't read the date '31/13/2026'".
  final List<String> problems;
}

/// Splits one CSV row, honouring double quotes ("a, b" stays one field).
List<String> splitCsvRow(String row, String delimiter) {
  final fields = <String>[];
  final buf = StringBuffer();
  var quoted = false;
  for (var i = 0; i < row.length; i++) {
    final c = row[i];
    if (c == '"') {
      if (quoted && i + 1 < row.length && row[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == delimiter && !quoted) {
      fields.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  fields.add(buf.toString().trim());
  return fields;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// Day-first dates (as Malaysian banks use) and ISO dates.
DateTime? parseStatementDate(String text) {
  final s = text.trim();
  DateTime? build(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    return date.month == m ? date : null; // rejects 31 Feb
  }

  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m != null) return build(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})').firstMatch(s);
  if (m != null) return build(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  m = RegExp(r'^(\d{1,2})[ -]([A-Za-z]{3})[A-Za-z]*[ -](\d{2,4})').firstMatch(s);
  if (m != null) {
    final month = _months[m[2]!.toLowerCase()];
    if (month == null) return null;
    return build(int.parse(m[3]!), month, int.parse(m[1]!));
  }
  return null;
}

/// Signed amount, or null if the text isn't a number. Empty → 0.
double? parseStatementAmount(String text) {
  var s = text.trim().toUpperCase().replaceAll('RM', '').replaceAll(',', '').replaceAll(' ', '');
  if (s.isEmpty || s == '-') return 0;
  var sign = 1.0;
  if (s.startsWith('(') && s.endsWith(')')) {
    sign = -1;
    s = s.substring(1, s.length - 1);
  }
  if (s.endsWith('DR')) {
    sign = -1;
    s = s.substring(0, s.length - 2);
  } else if (s.endsWith('CR')) {
    s = s.substring(0, s.length - 2);
  }
  if (s.endsWith('-')) {
    sign = -sign;
    s = s.substring(0, s.length - 1);
  }
  final v = double.tryParse(s);
  return v == null ? null : round2(sign * v);
}

StatementParseResult parseStatementCsv(String text) {
  final rows = text
      .split(RegExp(r'\r?\n'))
      .map((r) => r.trimRight())
      .where((r) => r.trim().isNotEmpty)
      .toList();
  if (rows.isEmpty) return const StatementParseResult([], ['Paste the rows of your statement.']);

  final first = rows.first;
  final delimiter = [',', ';', '\t']
      .reduce((a, b) => first.split(a).length >= first.split(b).length ? a : b);

  // Header? Any cell with letters and no digits that looks like a name.
  final head = splitCsvRow(first, delimiter).map((c) => c.toLowerCase()).toList();
  final hasHeader =
      head.any((c) => c.contains('date')) && parseStatementDate(head.first) == null;

  // Keys in priority order; a column is used once.
  final used = <int>{};
  int find(List<String> keys) {
    for (final k in keys) {
      for (var i = 0; i < head.length; i++) {
        if (!used.contains(i) && head[i].contains(k)) {
          used.add(i);
          return i;
        }
      }
    }
    return -1;
  }

  var dateCol = 0, descCol = 1, amountCol = 2, debitCol = -1, creditCol = -1;
  if (hasHeader) {
    dateCol = find(['date']);
    debitCol = find(['debit', 'withdraw', 'money out', 'paid out']);
    creditCol = find(['credit', 'deposit', 'money in', 'paid in']);
    // Separate debit and credit columns win over a signed amount column.
    amountCol = (debitCol >= 0 && creditCol >= 0) ? -1 : find(['amount']);
    descCol = find(['description', 'details', 'narration', 'particular', 'memo', 'reference', 'transaction']);
    if (dateCol < 0 || descCol < 0 || (amountCol < 0 && debitCol < 0 && creditCol < 0)) {
      return const StatementParseResult([], [
        'Couldn\'t find the Date, Description and Amount (or Debit/Credit) columns in the header.'
      ]);
    }
  }

  final lines = <StatementLine>[];
  final problems = <String>[];
  for (var r = hasHeader ? 1 : 0; r < rows.length; r++) {
    final cells = splitCsvRow(rows[r], delimiter);
    String cell(int i) => i >= 0 && i < cells.length ? cells[i] : '';
    final rowNo = r + 1;

    final date = parseStatementDate(cell(dateCol));
    if (date == null) {
      problems.add('Row $rowNo: couldn\'t read the date "${cell(dateCol)}".');
      continue;
    }
    double? amount;
    if (amountCol >= 0 && cell(amountCol).isNotEmpty) {
      amount = parseStatementAmount(cell(amountCol));
    } else {
      final out = parseStatementAmount(cell(debitCol));
      final inn = parseStatementAmount(cell(creditCol));
      amount = (out == null || inn == null) ? null : round2(inn.abs() - out.abs());
    }
    if (amount == null) {
      problems.add('Row $rowNo: couldn\'t read the amount.');
      continue;
    }
    if (amount == 0) continue; // balance-only rows
    final description = cell(descCol).isEmpty ? 'Imported transaction' : cell(descCol);
    lines.add(StatementLine(date: date, description: description, amount: amount));
  }
  return StatementParseResult(lines, problems);
}
