import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/estimate/estimate_bloc.dart';
import '../../../bloc/estimate_form/estimate_form_bloc.dart';
import '../../../components/section_header.dart';
import '../../../models/estimate_model.dart';
import '../../../models/invoice_model.dart';
import '../../../repository/estimate_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../widgets/document_form_parts.dart';

/// How long a new estimate stays valid (days → label).
const Map<int, String> _validity = {
  7: '7 days',
  14: '14 days',
  30: '30 days',
  60: '60 days',
};

/// New estimate, or edit [estimate]. Pops with the saved [Estimate].
class EstimateFormPage extends StatelessWidget {
  const EstimateFormPage({super.key, this.estimate, this.customerId});

  final Estimate? estimate;
  final String? customerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => EstimateFormBloc(repository: ctx.read<EstimateRepository>()),
      child: _EstimateFormView(estimate: estimate, customerId: customerId),
    );
  }
}

class _EstimateFormView extends StatefulWidget {
  const _EstimateFormView({this.estimate, this.customerId});

  final Estimate? estimate;
  final String? customerId;

  @override
  State<_EstimateFormView> createState() => _EstimateFormViewState();
}

class _EstimateFormViewState extends State<_EstimateFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _notes;

  String? _customerId;
  late DateTime _issueDate;
  late DateTime _expiryDate;
  List<InvoiceLine> _lines = const [];
  bool _showCustomerError = false;
  bool _showLinesError = false;

  bool get _editing => widget.estimate != null;

  @override
  void initState() {
    super.initState();
    final today = context.read<SettingRepository>().today;
    final e = widget.estimate;
    _number = TextEditingController(
        text: e?.number ?? context.read<EstimateBloc>().state.nextNumber);
    _notes = TextEditingController(text: e?.notes ?? '');
    _customerId = e?.customerId ?? widget.customerId;
    _issueDate = e?.issueDate ?? today;
    _expiryDate = e?.expiryDate ?? today.add(const Duration(days: 30));
    _lines = e?.lines ?? const [];
  }

  @override
  void dispose() {
    _number.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _validDays => _expiryDate.difference(_issueDate).inDays;

  Future<void> _pickCustomer() async {
    final id = await pickCustomer(context, selectedId: _customerId);
    if (id != null && mounted) {
      setState(() {
        _customerId = id;
        _showCustomerError = false;
      });
    }
  }

  Future<void> _pickDate({required bool expiry}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: expiry ? _expiryDate : _issueDate,
      firstDate: expiry ? _issueDate : DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (expiry) {
        _expiryDate = dateOnly(picked);
      } else {
        // Keep the same validity period when the start date moves.
        final days = _validDays;
        _issueDate = dateOnly(picked);
        _expiryDate = _issueDate.add(Duration(days: days < 0 ? 0 : days));
      }
    });
  }

  void _save() {
    final formOk = _formKey.currentState!.validate();
    setState(() {
      _showCustomerError = _customerId == null;
      _showLinesError = _lines.isEmpty;
    });
    final customerId = _customerId;
    if (!formOk || customerId == null || _lines.isEmpty) return;
    context.read<EstimateFormBloc>().add(SubmitEstimate(
          estimateId: widget.estimate?.id,
          customerId: customerId,
          number: _number.text,
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          lines: _lines,
          notes: _notes.text,
        ));
  }

  void _onFormState(BuildContext context, EstimateFormState state) {
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
    final estimates = context.watch<EstimateBloc>().state;
    final submitting =
        context.watch<EstimateFormBloc>().state.status == FormSaveStatus.submitting;
    final customer = context.watch<CustomerBloc>().state.byId(_customerId);
    final text = Theme.of(context).textTheme;
    final e = widget.estimate;
    final answered = e != null && e.decision != null;

    final details = <Widget>[
      const SectionHeader('Details'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _number,
                enabled: !_editing, // the number is fixed once saved
                decoration: const InputDecoration(labelText: 'Estimate number'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (estimates.numberExists(v, exceptId: e?.id)) return 'Number already used';
                  return null;
                },
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: DateField(
                        label: 'Date',
                        date: _issueDate,
                        onTap: () => _pickDate(expiry: false)),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: DateField(
                        label: 'Valid until',
                        date: _expiryDate,
                        onTap: () => _pickDate(expiry: true)),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Text('Valid for', style: text.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  for (final v in _validity.entries)
                    ChoiceChip(
                      label: Text(v.value),
                      selected: _validDays == v.key,
                      onSelected: (_) => setState(
                          () => _expiryDate = _issueDate.add(Duration(days: v.key))),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];

    return BlocListener<EstimateFormBloc, EstimateFormState>(
      listener: _onFormState,
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit ${e!.number}' : 'New estimate')),
        bottomNavigationBar: FormSaveBar(
          total: sumTotal(_lines),
          label: _editing ? 'Save changes' : 'Save estimate',
          onSave: submitting ? null : _save,
        ),
        body: Form(
          key: _formKey,
          child: FormColumns(
            top: [
              if (answered)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: context.ledger.warning),
                    title: const Text('The customer already answered this estimate'),
                    subtitle: const Text(
                        'Changing the customer or items resets it to "awaiting reply".'),
                  ),
                ),
            ],
            left: [
              CustomerSection(
                  customer: customer, onTap: _pickCustomer, showError: _showCustomerError),
              ...details,
              NotesSection(
                  controller: _notes, hint: 'Scope, assumptions, deposit terms…'),
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
              TotalsSection(lines: _lines),
            ],
          ),
        ),
      ),
    );
  }
}
