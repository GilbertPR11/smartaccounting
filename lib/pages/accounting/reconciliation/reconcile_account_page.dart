import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/reconciliation/reconciliation_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/money_text.dart';
import '../../../components/section_header.dart';
import '../../../config/constants.dart';
import '../../../models/transaction_model.dart';
import '../../../repository/reconciliation_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../sales/widgets/document_form_parts.dart';
import '../accounting_flows.dart';

/// Reconcile one account against a statement: enter the statement's date
/// and closing balance, tick what appears on it, finish when the
/// difference is zero.
class ReconcileAccountPage extends StatefulWidget {
  const ReconcileAccountPage({super.key, required this.account});

  final String account;

  @override
  State<ReconcileAccountPage> createState() => _ReconcileAccountPageState();
}

class _ReconcileAccountPageState extends State<ReconcileAccountPage> {
  final _ending = TextEditingController();
  late DateTime _date;
  final Set<String> _ticked = {};
  final Set<String> _seen = {};
  late final double _beginning;
  late final String? _startPending;

  @override
  void initState() {
    super.initState();
    final repo = context.read<ReconciliationRepository>();
    _beginning = repo.beginningBalance(widget.account);
    final last = repo.lastStatementDate(widget.account);
    _startPending = last == null ? null : 'Starts after ${fmtDate(last)}';
    _date = context.read<SettingRepository>().today;
  }

  @override
  void dispose() {
    _ending.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<TransactionBloc>().state.transactions;
    final candidates = all
        .where((t) =>
            t.account == widget.account && !t.reconciled && !dateOnly(t.date).isAfter(_date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // New candidates (e.g. a bank fee just added) start ticked.
    for (final t in candidates) {
      if (_seen.add(t.id)) _ticked.add(t.id);
    }
    final ticked = candidates.where((t) => _ticked.contains(t.id)).toList();
    final deposits = round2(ticked.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount));
    final withdrawals = round2(ticked.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount));
    final cleared = round2(_beginning + deposits - withdrawals);
    final ending = parseAmount(_ending.text);
    final difference = ending == null ? null : round2(ending - cleared);
    final done = difference != null && difference.abs() < 0.005;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    Widget line(String label, double amount, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: text.bodyMedium?.copyWith(
                          fontWeight: bold ? FontWeight.w700 : null, color: color))),
              MoneyText(amount,
                  style: text.bodyMedium
                      ?.copyWith(fontWeight: bold ? FontWeight.w700 : null, color: color)),
            ],
          ),
        );

    return BlocListener<ReconciliationBloc, ReconciliationState>(
      listenWhen: (prev, next) =>
          (next.lastCompletedId != prev.lastCompletedId && next.lastCompletedId != null) ||
          (next.error != null && next.error != prev.error),
      listener: (context, state) {
        final error = state.error;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.account} reconciled to ${fmtDate(_date)}')));
        Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Reconcile ${widget.account}')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
            child: Row(
              children: [
                Expanded(
                  child: difference == null
                      ? Text('Enter the statement balance', style: text.bodyMedium)
                      : done
                          ? Text('Difference is zero', style: text.bodyMedium?.copyWith(color: l.moneyIn))
                          : Row(
                              children: [
                                Text('Difference ', style: text.bodyMedium?.copyWith(color: l.warning)),
                                MoneyText(difference, color: l.warning),
                              ],
                            ),
                ),
                FilledButton.icon(
                  onPressed: !done
                      ? null
                      : () => context.read<ReconciliationBloc>().add(CompleteReconciliation(
                            account: widget.account,
                            statementDate: _date,
                            endingBalance: ending!,
                            transactionIds: ticked.map((t) => t.id).toList(),
                          )),
                  icon: const Icon(Icons.check),
                  label: const Text('Finish'),
                ),
              ],
            ),
          ),
        ),
        body: CenteredListView(
          maxWidth: 760,
          children: [
            const SectionHeader('From your bank statement'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: DateField(label: 'Statement end date', date: _date, onTap: _pickDate)),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: TextField(
                            controller: _ending,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(
                                labelText: 'Closing balance', prefixText: '${Constants.currency} '),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (_startPending != null) ...[
                      const SizedBox(height: Space.sm),
                      Text(_startPending!, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            const SectionHeader('Summary'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  children: [
                    line('Starting balance', _beginning),
                    line('+ Money in ticked', deposits),
                    line('− Money out ticked', withdrawals),
                    const Divider(height: 16),
                    line('Cleared balance', cleared, bold: true),
                    if (ending != null) line('Statement balance', ending),
                  ],
                ),
              ),
            ),
            SectionHeader(
              'Tick what\'s on the statement',
              subtitle: '${ticked.length} of ${candidates.length} ticked',
              action: TextButton.icon(
                onPressed: () => openTransactionForm(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Missing one?'),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: candidates.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Text('No unreconciled transactions up to this date.',
                          style: text.bodyMedium?.copyWith(color: l.muted)),
                    )
                  : Column(
                      children: [
                        for (final t in candidates)
                          CheckboxListTile(
                            value: _ticked.contains(t.id),
                            onChanged: (v) => setState(() {
                              if (v ?? false) {
                                _ticked.add(t.id);
                              } else {
                                _ticked.remove(t.id);
                              }
                            }),
                            title: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${fmtDate(t.date)} · ${t.categoryLabel}'),
                            secondary: MoneyText(
                              t.type == TransactionType.income ? t.amount : -t.amount,
                              showSign: true,
                              color: t.isIncome ? l.moneyIn : null,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
