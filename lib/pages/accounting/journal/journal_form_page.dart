import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/account/account_bloc.dart';
import '../../../bloc/journal/journal_bloc.dart';
import '../../../bloc/journal_form/journal_form_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/money_text.dart';
import '../../../components/section_header.dart';
import '../../../models/account_model.dart';
import '../../../models/journal_model.dart';
import '../../../repository/journal_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../sales/widgets/document_form_parts.dart';

/// Add or edit a manual journal entry: lines of debits and credits that
/// must balance. Pops with the saved entry.
class JournalFormPage extends StatelessWidget {
  const JournalFormPage({super.key, this.entry});

  final JournalEntry? entry;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => JournalFormBloc(repository: ctx.read<JournalRepository>()),
      child: _JournalFormView(entry: entry),
    );
  }
}

class _LineDraft {
  _LineDraft({this.accountId, double debit = 0, double credit = 0})
      : debit = TextEditingController(text: debit == 0 ? '' : debit.toStringAsFixed(2)),
        credit = TextEditingController(text: credit == 0 ? '' : credit.toStringAsFixed(2));

  String? accountId;
  final TextEditingController debit;
  final TextEditingController credit;

  double get debitValue => parseAmount(debit.text) ?? 0;
  double get creditValue => parseAmount(credit.text) ?? 0;

  void dispose() {
    debit.dispose();
    credit.dispose();
  }
}

class _JournalFormView extends StatefulWidget {
  const _JournalFormView({this.entry});

  final JournalEntry? entry;

  @override
  State<_JournalFormView> createState() => _JournalFormViewState();
}

class _JournalFormViewState extends State<_JournalFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late DateTime _date;
  late List<_LineDraft> _lines;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _description = TextEditingController(text: e?.description ?? '');
    _date = e?.date ?? context.read<SettingRepository>().today;
    _lines = e == null
        ? [_LineDraft(), _LineDraft()]
        : [
            for (final l in e.lines)
              _LineDraft(accountId: l.accountId, debit: l.debit, credit: l.credit),
          ];
  }

  @override
  void dispose() {
    _description.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _debits => round2(_lines.fold<double>(0, (s, l) => s + l.debitValue));
  double get _credits => round2(_lines.fold<double>(0, (s, l) => s + l.creditValue));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this journal entry?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<JournalBloc>().add(DeleteJournal(widget.entry!.id));
    Navigator.pop(context);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.read<JournalFormBloc>().add(SubmitJournal(
          journalId: widget.entry?.id,
          date: _date,
          description: _description.text,
          lines: [
            for (final l in _lines)
              if (l.accountId != null)
                JournalLine(accountId: l.accountId!, debit: l.debitValue, credit: l.creditValue),
          ],
        ));
  }

  void _onFormState(BuildContext context, JournalFormState state) {
    switch (state.status) {
      case FormSaveStatus.success:
        Navigator.pop(context, state.saved);
      case FormSaveStatus.failure:
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.error ?? 'Could not save.')));
      case FormSaveStatus.editing:
      case FormSaveStatus.submitting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountBloc>().state;
    final submitting =
        context.watch<JournalFormBloc>().state.status == FormSaveStatus.submitting;
    final text = Theme.of(context).textTheme;
    final l = context.ledger;
    final diff = round2(_debits - _credits);

    // Every active account, grouped by type, plus any already used here.
    final usedIds = {for (final line in _lines) if (line.accountId != null) line.accountId!};
    final choices = [
      for (final type in AccountType.values)
        for (final a in accounts.accounts.where((a) => a.type == type))
          if (!a.archived || usedIds.contains(a.id)) a,
    ];

    return BlocListener<JournalFormBloc, JournalFormState>(
      listener: _onFormState,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entry == null ? 'New journal entry' : 'Journal entry'),
          actions: [
            if (widget.entry != null)
              IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
            child: Row(
              children: [
                Expanded(
                  child: diff.abs() < 0.005
                      ? Text('Balanced', style: text.bodyMedium?.copyWith(color: l.moneyIn))
                      : Row(
                          children: [
                            Text(diff > 0 ? 'Credits short by ' : 'Debits short by ',
                                style: text.bodyMedium?.copyWith(color: l.warning)),
                            MoneyText(diff.abs(), color: l.warning),
                          ],
                        ),
                ),
                FilledButton.icon(
                  onPressed: submitting ? null : _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: CenteredListView(
            maxWidth: 820,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _description,
                        decoration: const InputDecoration(labelText: 'Description'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: Space.md),
                      DateField(label: 'Date', date: _date, onTap: _pickDate),
                    ],
                  ),
                ),
              ),
              SectionHeader(
                'Lines',
                subtitle: 'Debits on the left, credits on the right',
                action: TextButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add line'),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.md),
                          child: Wrap(
                            spacing: Space.sm,
                            runSpacing: Space.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 280,
                                child: DropdownButtonFormField<String>(
                                  value: _lines[i].accountId,
                                  isExpanded: true,
                                  decoration: InputDecoration(labelText: 'Account ${i + 1}'),
                                  items: [
                                    for (final a in choices)
                                      DropdownMenuItem(
                                        value: a.id,
                                        child: Text('${a.name}  ·  ${a.type.label}',
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() => _lines[i].accountId = v),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  controller: _lines[i].debit,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Debit'),
                                  onChanged: (v) => setState(() {
                                    if (v.isNotEmpty) _lines[i].credit.clear();
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  controller: _lines[i].credit,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Credit'),
                                  onChanged: (v) => setState(() {
                                    if (v.isNotEmpty) _lines[i].debit.clear();
                                  }),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove line',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: _lines.length <= 2
                                    ? null
                                    : () => setState(() => _lines.removeAt(i).dispose()),
                              ),
                            ],
                          ),
                        ),
                      Divider(color: l.hairline),
                      Row(
                        children: [
                          Expanded(child: Text('Totals', style: text.titleSmall)),
                          Text('Debit ', style: text.bodySmall),
                          MoneyText(_debits),
                          const SizedBox(width: Space.lg),
                          Text('Credit ', style: text.bodySmall),
                          MoneyText(_credits),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
