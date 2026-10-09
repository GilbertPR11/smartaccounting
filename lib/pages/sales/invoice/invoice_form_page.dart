import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/invoice_form/invoice_form_bloc.dart';
import '../../../components/section_header.dart';
import '../../../config/constants.dart';
import '../../../models/estimate_model.dart';
import '../../../models/invoice_model.dart';
import '../../../models/transaction_model.dart';
import '../../../repository/invoice_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../widgets/document_form_parts.dart';
import 'widgets/invoice_form_widgets.dart';

/// Create an invoice: blank, pre-filled from an income transaction
/// ([source]), or converted from an [estimate].
/// Pops with the created [Invoice] on save (or calls [onSaved] when embedded).
class InvoiceFormPage extends StatelessWidget {
  const InvoiceFormPage({
    super.key,
    this.source,
    this.estimate,
    this.customerId,
    this.onSaved,
  });

  final BankTransaction? source;
  final Estimate? estimate;

  /// Pre-select this customer (e.g. "New invoice" on a customer's page).
  final String? customerId;

  /// When set, the form is embedded in a split view: instead of popping,
  /// it hands the created invoice to this callback.
  final ValueChanged<Invoice>? onSaved;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => InvoiceFormBloc(repository: ctx.read<InvoiceRepository>()),
      child: _InvoiceFormView(
          source: source, estimate: estimate, customerId: customerId, onSaved: onSaved),
    );
  }
}

class _InvoiceFormView extends StatefulWidget {
  const _InvoiceFormView({this.source, this.estimate, this.customerId, this.onSaved});

  final BankTransaction? source;
  final Estimate? estimate;
  final String? customerId;
  final ValueChanged<Invoice>? onSaved;

  @override
  State<_InvoiceFormView> createState() => _InvoiceFormViewState();
}

class _InvoiceFormViewState extends State<_InvoiceFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  final _notes = TextEditingController();

  String? _customerId;
  late DateTime _issueDate;
  late int _termsDays;
  List<InvoiceLine> _lines = const []; // immutable; replace, don't mutate
  bool _showCustomerError = false;
  bool _showLinesError = false;

  BankTransaction? get _source => widget.source;
  DateTime get _dueDate => _issueDate.add(Duration(days: _termsDays));

  @override
  void initState() {
    super.initState();
    final today = context.read<SettingRepository>().today;
    _number = TextEditingController(text: context.read<InvoiceBloc>().state.nextNumber);
    _issueDate = today;
    _termsDays = 30;
    _customerId = widget.customerId;

    final src = _source;
    final est = widget.estimate;
    if (src != null) {
      // Money is already received, so the invoice is dated on the payment
      // date and due on receipt.
      _customerId = src.customerId;
      _issueDate = src.date;
      _termsDays = 0;
      _lines = [InvoiceLine(description: src.description, unitPrice: src.amount)];
      _notes.text = 'Payment of ${money(src.amount)} received on ${fmtDate(src.date)} '
          'via ${src.account}. Thank you!';
    } else if (est != null) {
      _customerId = est.customerId;
      _lines = est.lines;
      _notes.text = est.notes;
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _total => sumTotal(_lines);

  /// Rescales line prices so the invoice total (incl. tax) equals the
  /// transaction amount. Typical case: the RM 1,296 received already included
  /// 8% SST, so the pre-tax price should be RM 1,200.
  void _matchTransactionAmount() {
    final src = _source;
    if (src == null || _total == 0) return;
    final factor = src.amount / _total;
    final lines = [
      for (final l in _lines) l.copyWith(unitPrice: round2(l.unitPrice * factor)),
    ];
    // Absorb any 1-sen rounding residue on the last single-quantity line.
    final residue = round2(src.amount - sumTotal(lines));
    final last = lines.last;
    if (residue != 0 && last.quantity == 1) {
      final rate = last.tax?.rate ?? 0;
      lines[lines.length - 1] =
          last.copyWith(unitPrice: round2(last.unitPrice + residue / (1 + rate)));
    }
    setState(() => _lines = lines);
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

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _issueDate = dateOnly(picked));
  }

  void _save() {
    final formOk = _formKey.currentState!.validate();
    setState(() {
      _showCustomerError = _customerId == null;
      _showLinesError = _lines.isEmpty;
    });
    final customerId = _customerId;
    if (!formOk || customerId == null || _lines.isEmpty) return;

    context.read<InvoiceFormBloc>().add(SubmitInvoice(
          customerId: customerId,
          number: _number.text,
          issueDate: _issueDate,
          dueDate: _dueDate,
          lines: _lines,
          notes: _notes.text,
          sourceTransactionId: _source?.id,
          estimateId: widget.estimate?.id,
        ));
  }

  void _onFormState(BuildContext context, InvoiceFormState state) {
    switch (state.status) {
      case InvoiceFormStatus.success:
        final invoice = state.created!;
        final onSaved = widget.onSaved;
        if (onSaved != null) {
          onSaved(invoice);
        } else {
          Navigator.pop(context, invoice);
        }
      case InvoiceFormStatus.failure:
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.error ?? 'Could not save.')));
      case InvoiceFormStatus.editing:
      case InvoiceFormStatus.submitting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = context.watch<InvoiceBloc>().state;
    final submitting =
        context.watch<InvoiceFormBloc>().state.status == InvoiceFormStatus.submitting;
    final customer = context.watch<CustomerBloc>().state.byId(_customerId);
    final src = _source;
    final est = widget.estimate;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    final title = src != null
        ? 'Invoice from transaction'
        : est != null
            ? 'Invoice from ${est.number}'
            : 'New invoice';

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
                decoration: const InputDecoration(labelText: 'Invoice number'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (invoiceState.numberExists(v)) return 'Number already used';
                  return null;
                },
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: DateField(
                        label: 'Issue date', date: _issueDate, onTap: _pickIssueDate),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(child: DateField(label: 'Due date', date: _dueDate)),
                ],
              ),
              const SizedBox(height: Space.md),
              Text('Payment terms', style: text.bodySmall),
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
    ];

    return BlocListener<InvoiceFormBloc, InvoiceFormState>(
      listener: _onFormState,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.onSaved == null,
          title: Text(title),
        ),
        bottomNavigationBar: FormSaveBar(
          total: _total,
          label: 'Save invoice',
          onSave: submitting ? null : _save,
        ),
        body: Form(
          key: _formKey,
          child: FormColumns(
            top: [
              if (src != null) SourceBanner(txn: src),
              if (est != null)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.request_quote_outlined, color: l.muted),
                    title: Text('Converting ${est.number}'),
                    subtitle: const Text(
                        'The estimate will be marked as invoiced when you save.'),
                  ),
                ),
            ],
            left: [
              CustomerSection(
                  customer: customer, onTap: _pickCustomer, showError: _showCustomerError),
              ...details,
              NotesSection(controller: _notes, hint: 'Shown at the bottom of the invoice'),
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
              TotalsSection(
                lines: _lines,
                footer: src == null
                    ? null
                    : ReconciliationBox(
                        txnAmount: src.amount,
                        invoiceTotal: _total,
                        onMatch: _matchTransactionAmount,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
