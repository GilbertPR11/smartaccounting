import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/recurring_form/recurring_form_bloc.dart';
import '../../../components/section_header.dart';
import '../../../config/constants.dart';
import '../../../models/invoice_model.dart';
import '../../../models/recurring_invoice_model.dart';
import '../../../repository/recurring_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../widgets/document_form_parts.dart';

enum _Ends { never, onDate, afterCount }

/// New recurring schedule, or edit [schedule]. Pops with the saved schedule.
class RecurringFormPage extends StatelessWidget {
  const RecurringFormPage({super.key, this.schedule, this.customerId});

  final RecurringInvoice? schedule;
  final String? customerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => RecurringFormBloc(repository: ctx.read<RecurringRepository>()),
      child: _RecurringFormView(schedule: schedule, customerId: customerId),
    );
  }
}

class _RecurringFormView extends StatefulWidget {
  const _RecurringFormView({this.schedule, this.customerId});

  final RecurringInvoice? schedule;
  final String? customerId;

  @override
  State<_RecurringFormView> createState() => _RecurringFormViewState();
}

class _RecurringFormViewState extends State<_RecurringFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notes;
  late final TextEditingController _count;

  String? _customerId;
  late RecurFrequency _frequency;
  late DateTime _startDate;
  late _Ends _ends;
  late DateTime _endDate;
  late int _termsDays;
  List<InvoiceLine> _lines = const [];
  bool _showCustomerError = false;
  bool _showLinesError = false;

  late final DateTime _today;

  bool get _editing => widget.schedule != null;

  /// Once a schedule has issued invoices, its rhythm is fixed.
  bool get _rhythmLocked => (widget.schedule?.issuedCount ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _today = context.read<SettingRepository>().today;
    final r = widget.schedule;
    _customerId = r?.customerId ?? widget.customerId;
    _frequency = r?.frequency ?? RecurFrequency.monthly;
    _startDate = r?.startDate ?? _today;
    _termsDays = r?.termsDays ?? 14;
    _lines = r?.lines ?? const [];
    _notes = TextEditingController(text: r?.notes ?? '');
    final max = r?.maxCount;
    final end = r?.endDate;
    _ends = max != null
        ? _Ends.afterCount
        : end != null
            ? _Ends.onDate
            : _Ends.never;
    _count = TextEditingController(text: '${max ?? 12}');
    _endDate = end ?? addMonths(_startDate, 12);
  }

  @override
  void dispose() {
    _notes.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final id = await pickCustomer(context, selectedId: _customerId);
    if (id != null && mounted) {
      setState(() {
        _customerId = id;
        _showCustomerError = false;
      });
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = dateOnly(picked));
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = dateOnly(picked));
  }

  /// How many invoices a back-dated start would issue on save.
  int get _catchUp {
    if (_startDate.isAfter(_today) || (widget.schedule?.paused ?? false)) return 0;
    final draft = RecurringInvoice(
      id: '',
      customerId: '',
      lines: const [],
      frequency: _frequency,
      startDate: _startDate,
      endDate: _ends == _Ends.onDate ? _endDate : null,
      maxCount: _ends == _Ends.afterCount ? int.tryParse(_count.text) : null,
      issuedCount: widget.schedule?.issuedCount ?? 0,
    );
    var n = draft.issuedCount;
    var due = 0;
    while (!draft.copyWith(issuedCount: n).isFinished && !draft.occurrence(n).isAfter(_today)) {
      n++;
      due++;
      if (due > 99) break;
    }
    return due;
  }

  void _save() {
    final formOk = _formKey.currentState!.validate();
    setState(() {
      _showCustomerError = _customerId == null;
      _showLinesError = _lines.isEmpty;
    });
    final customerId = _customerId;
    if (!formOk || customerId == null || _lines.isEmpty) return;
    context.read<RecurringFormBloc>().add(SubmitRecurring(
          scheduleId: widget.schedule?.id,
          customerId: customerId,
          lines: _lines,
          frequency: _frequency,
          startDate: _startDate,
          endDate: _ends == _Ends.onDate ? _endDate : null,
          maxCount: _ends == _Ends.afterCount ? int.parse(_count.text.trim()) : null,
          termsDays: _termsDays,
          notes: _notes.text,
        ));
  }

  void _onFormState(BuildContext context, RecurringFormState state) {
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
    final submitting =
        context.watch<RecurringFormBloc>().state.status == FormSaveStatus.submitting;
    final customer = context.watch<CustomerBloc>().state.byId(_customerId);
    final text = Theme.of(context).textTheme;
    final l = context.ledger;
    final catchUp = _catchUp;

    final schedule = <Widget>[
      const SectionHeader('Schedule'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Repeat', style: text.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  for (final f in RecurFrequency.values)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: _frequency == f,
                      onSelected:
                          _rhythmLocked ? null : (_) => setState(() => _frequency = f),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              DateField(
                label: 'First invoice on',
                date: _startDate,
                onTap: _rhythmLocked ? null : _pickStart,
              ),
              if (_rhythmLocked) ...[
                const SizedBox(height: Space.xs),
                Text('Fixed: this schedule has already issued invoices.', style: text.bodySmall),
              ],
              const SizedBox(height: Space.lg),
              Text('Ends', style: text.bodySmall),
              const SizedBox(height: 6),
              SegmentedButton<_Ends>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Ends.never, label: Text('Never')),
                  ButtonSegment(value: _Ends.onDate, label: Text('On a date')),
                  ButtonSegment(value: _Ends.afterCount, label: Text('After')),
                ],
                selected: {_ends},
                onSelectionChanged: (s) => setState(() => _ends = s.first),
              ),
              if (_ends == _Ends.onDate) ...[
                const SizedBox(height: Space.md),
                DateField(label: 'Last invoice on or before', date: _endDate, onTap: _pickEnd),
              ],
              if (_ends == _Ends.afterCount) ...[
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _count,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Number of invoices', suffixText: 'invoices'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1) return 'At least 1';
                    final done = widget.schedule?.issuedCount ?? 0;
                    if (n < done) return 'Already issued $done';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: Space.lg),
              Text('Each invoice is due', style: text.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  for (final e in Constants.paymentTerms.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _termsDays == e.key,
                      onSelected: (_) => setState(() => _termsDays = e.key),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (catchUp > 0)
        Padding(
          padding: const EdgeInsets.only(top: Space.md),
          child: Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: l.warning.withOpacity(0.10),
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: l.warning),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    catchUp == 1
                        ? 'Saving issues 1 invoice now, dated ${fmtDate(_startDate)}.'
                        : 'The start date is in the past: saving issues $catchUp '
                            'invoices now, each on its own date.',
                    style: text.bodySmall?.copyWith(color: l.warning),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];

    return BlocListener<RecurringFormBloc, RecurringFormState>(
      listener: _onFormState,
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit schedule' : 'New recurring invoice')),
        bottomNavigationBar: FormSaveBar(
          total: sumTotal(_lines),
          caption: 'Each invoice',
          label: _editing ? 'Save changes' : 'Save schedule',
          onSave: submitting ? null : _save,
        ),
        body: Form(
          key: _formKey,
          child: FormColumns(
            left: [
              CustomerSection(
                  customer: customer, onTap: _pickCustomer, showError: _showCustomerError),
              ...schedule,
              NotesSection(controller: _notes, hint: 'Printed on every invoice'),
            ],
            right: [
              LineItemsSection(
                lines: _lines,
                showError: _showLinesError,
                onChanged: (lines) => setState(() {
                  _lines = lines;
                  _showLinesError = false;
                }),
              ),
              TotalsSection(lines: _lines, totalLabel: 'Each invoice'),
            ],
          ),
        ),
      ),
    );
  }
}
