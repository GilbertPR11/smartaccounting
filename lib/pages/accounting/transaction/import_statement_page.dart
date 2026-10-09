import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/money_text.dart';
import '../../../components/section_header.dart';
import '../../../exception/app_exception.dart';
import '../../../models/transaction_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../repository/transaction_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/csv_import.dart';
import '../../../utils/format.dart';

/// Import a bank statement by pasting its CSV. Rows that look like
/// transactions already in the books are flagged and left unticked.
///
/// Pasting is the front-end stand-in for choosing a file; a file picker
/// (and OFX/QIF) can feed the same parser later.
class ImportStatementPage extends StatefulWidget {
  const ImportStatementPage({super.key});

  @override
  State<ImportStatementPage> createState() => _ImportStatementPageState();
}

class _ImportStatementPageState extends State<ImportStatementPage> {
  final _text = TextEditingController();
  late String _account;
  StatementParseResult? _result;
  final Set<int> _ticked = {};
  bool _importing = false;

  static const _example = 'Date,Description,Debit,Credit\n'
      '01/10/2026,IBG CREDIT TAN HARDWARE,,2700.00\n'
      '03/10/2026,BANK SERVICE CHARGE,8.00,\n';

  @override
  void initState() {
    super.initState();
    _account = context.read<SettingRepository>().accounts.first;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool _isDuplicate(StatementLine line, List<BankTransaction> existing) => existing.any((t) =>
      t.account == _account &&
      dateOnly(t.date) == dateOnly(line.date) &&
      (t.amount - line.amount.abs()).abs() < 0.005 &&
      t.isIncome == (line.amount >= 0));

  void _read() {
    final result = parseStatementCsv(_text.text);
    final existing = context.read<TransactionBloc>().state.transactions;
    setState(() {
      _result = result;
      _ticked
        ..clear()
        ..addAll([
          for (var i = 0; i < result.lines.length; i++)
            if (!_isDuplicate(result.lines[i], existing)) i,
        ]);
    });
  }

  Future<void> _import() async {
    final result = _result;
    if (result == null) return;
    final lines = [for (final i in _ticked.toList()..sort()) result.lines[i]];
    setState(() => _importing = true);
    // Direct repository call: one write, and we need the count back.
    try {
      final count = await context.read<TransactionRepository>().importStatement(_account, lines);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imported $count ${count == 1 ? 'transaction' : 'transactions'}. '
              'Categorise them in Transactions.')));
      Navigator.pop(context);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.read<SettingRepository>().accounts;
    final existing = context.watch<TransactionBloc>().state.transactions;
    final result = _result;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import bank statement')),
      bottomNavigationBar: result == null || result.lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
                child: FilledButton.icon(
                  onPressed: _ticked.isEmpty || _importing ? null : _import,
                  icon: const Icon(Icons.download_rounded),
                  label: Text('Import ${_ticked.length} into $_account'),
                ),
              ),
            ),
      body: CenteredListView(
        maxWidth: 760,
        children: [
          Text(
            'Export your statement as CSV from online banking, open it, copy all the rows '
            '(with the header) and paste them here.',
            style: text.bodyMedium?.copyWith(color: l.muted),
          ),
          const SizedBox(height: Space.md),
          DropdownButtonFormField<String>(
            value: _account,
            decoration: const InputDecoration(labelText: 'Import into'),
            items: [for (final a in accounts) DropdownMenuItem(value: a, child: Text(a))],
            onChanged: (v) => setState(() {
              _account = v ?? _account;
              _result = null;
            }),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _text,
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: _example,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Space.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _read,
              icon: const Icon(Icons.table_rows_outlined, size: 18),
              label: const Text('Read rows'),
            ),
          ),
          if (result != null) ...[
            if (result.problems.isNotEmpty) ...[
              const SectionHeader('Skipped'),
              for (final p in result.problems)
                Text(p, style: text.bodySmall?.copyWith(color: l.warning)),
            ],
            SectionHeader('Rows found',
                subtitle: '${_ticked.length} of ${result.lines.length} ticked'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < result.lines.length; i++)
                    Builder(builder: (context) {
                      final line = result.lines[i];
                      final dupe = _isDuplicate(line, existing);
                      return CheckboxListTile(
                        value: _ticked.contains(i),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _ticked.add(i);
                          } else {
                            _ticked.remove(i);
                          }
                        }),
                        title: Text(line.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          dupe ? '${fmtDate(line.date)} · looks like one already in the books' : fmtDate(line.date),
                          style: dupe ? TextStyle(color: l.warning) : null,
                        ),
                        secondary: MoneyText(line.amount,
                            showSign: true, color: line.amount >= 0 ? l.moneyIn : null),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
