import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/invoice_form/invoice_form_bloc.dart';
import '../../../bloc/product/product_bloc.dart';
import '../../../components/customer_dialog.dart';
import '../../../components/money_text.dart';
import '../../../components/section_header.dart';
import '../../../config/constants.dart';
import '../../../config/layout.dart';
import '../../../models/invoice_model.dart';
import '../../../models/product_model.dart';
import '../../../models/transaction_model.dart';
import '../../../repository/invoice_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../utils/format.dart';
import 'widgets/invoice_form_widgets.dart';

/// Create an invoice — blank, or pre-filled from an income transaction.
/// Pops with the created [Invoice] on save (or calls [onSaved] when embedded).
class InvoiceFormPage extends StatelessWidget {
  const InvoiceFormPage({super.key, this.source, this.onSaved});

  final BankTransaction? source;

  /// When set, the form is embedded in a split view: instead of popping,
  /// it hands the created invoice to this callback.
  final ValueChanged<Invoice>? onSaved;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => InvoiceFormBloc(repository: ctx.read<InvoiceRepository>()),
      child: _InvoiceFormView(source: source, onSaved: onSaved),
    );
  }
}

class _InvoiceFormView extends StatefulWidget {
  const _InvoiceFormView({this.source, this.onSaved});

  final BankTransaction? source;
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
  List<InvoiceLine> _lines = []; // immutable lines; replace, don't mutate
  bool _showCustomerError = false;
  bool _showLinesError = false;

  BankTransaction? get _source => widget.source;
  DateTime get _dueDate => _issueDate.add(Duration(days: _termsDays));

  @override
  void initState() {
    super.initState();
    final today = context.read<SettingRepository>().today;
    _number = TextEditingController(text: context.read<InvoiceBloc>().state.nextNumber);

    final src = _source;
    if (src != null) {
      // Pre-fill from the transaction. Money is already received, so the
      // invoice is dated on the payment date and due on receipt.
      _customerId = src.customerId;
      _issueDate = src.date;
      _termsDays = 0;
      _lines = [InvoiceLine(description: src.description, unitPrice: src.amount)];
      _notes.text =
          'Payment of ${money(src.amount)} received on ${fmtDate(src.date)} '
          'via ${src.account}. Thank you!';
    } else {
      _issueDate = today;
      _termsDays = 30;
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ calculations

  double get _subtotal => sumSubtotal(_lines);
  double get _total => sumTotal(_lines);

  /// Rescales line prices so the invoice total (incl. tax) equals the
  /// transaction amount. Typical case: the RM 1,296 received already included
  /// 8% SST, so the pre-tax price should be RM 1,200.
  void _matchTransactionAmount() {
    final src = _source;
    if (src == null || _total == 0) return;
    final factor = src.amount / _total;
    setState(() {
      _lines = [
        for (final l in _lines) l.copyWith(unitPrice: round2(l.unitPrice * factor)),
      ];
      // Absorb any 1-sen rounding residue on the last single-quantity line.
      final residue = round2(src.amount - _total);
      final last = _lines.last;
      if (residue != 0 && last.quantity == 1) {
        final rate = last.tax?.rate ?? 0;
        _lines[_lines.length - 1] =
            last.copyWith(unitPrice: round2(last.unitPrice + residue / (1 + rate)));
      }
    });
  }

  // ---------------------------------------------------------------- actions

  Future<void> _pickCustomer() async {
    final customers = context.read<CustomerBloc>().state.customers;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, controller) => ListView(
          controller: controller,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('Add new customer'),
              onTap: () => Navigator.pop(ctx, '__new__'),
            ),
            const Divider(height: 1),
            for (final c in customers)
              ListTile(
                leading: CircleAvatar(child: Text(c.name.characters.first)),
                title: Text(c.name),
                subtitle: c.email.isEmpty ? null : Text(c.email),
                trailing: c.id == _customerId ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == '__new__') {
      final c = await showAddCustomerDialog(context);
      if (c != null) setState(() => _customerId = c.id);
    } else {
      setState(() => _customerId = result);
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

  Future<void> _addLine() async {
    final products = context.read<ProductBloc>().state.products;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Custom item'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
            const Divider(height: 1),
            for (final p in products)
              ListTile(
                title: Text(p.name),
                subtitle: Text(p.tax == null ? 'No tax' : p.tax!.label),
                trailing: MoneyText(p.price),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final draft = choice is Product
        ? InvoiceLine(
            productId: choice.id,
            description: choice.name,
            unitPrice: choice.price,
            tax: choice.tax)
        : InvoiceLine(description: '', unitPrice: 0);
    final line = await _editLine(draft, isNew: true);
    if (line != null) {
      setState(() {
        _lines = [..._lines, line];
        _showLinesError = false;
      });
    }
  }

  Future<InvoiceLine?> _editLine(InvoiceLine line, {bool isNew = false}) =>
      showModalBottomSheet<InvoiceLine>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => LineEditorSheet(line: line, isNew: isNew),
      );

  void _save() {
    final formOk = _formKey.currentState!.validate();
    setState(() {
      _showCustomerError = _customerId == null;
      _showLinesError = _lines.isEmpty;
    });
    if (!formOk || _customerId == null || _lines.isEmpty) return;

    context.read<InvoiceFormBloc>().add(SubmitInvoice(
          customerId: _customerId!,
          number: _number.text,
          issueDate: _issueDate,
          dueDate: _dueDate,
          lines: _lines,
          notes: _notes.text,
          sourceTransactionId: _source?.id,
        ));
  }

  void _onFormState(BuildContext context, InvoiceFormState state) {
    switch (state.status) {
      case InvoiceFormStatus.success:
        final invoice = state.created!;
        if (widget.onSaved != null) {
          widget.onSaved!(invoice);
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

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final invoiceState = context.watch<InvoiceBloc>().state;
    final submitting = context.watch<InvoiceFormBloc>().state.status ==
        InvoiceFormStatus.submitting;
    final scheme = Theme.of(context).colorScheme;
    final customer = context.watch<CustomerBloc>().state.byId(_customerId);
    final src = _source;

    return BlocListener<InvoiceFormBloc, InvoiceFormState>(
      listener: _onFormState,
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onSaved == null,
        title: Text(src == null ? 'New invoice' : 'Invoice from transaction'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    MoneyText(_total, emphasis: MoneyEmphasis.large),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: submitting ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Save invoice'),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(builder: (context, c) {
          // Two columns once there's room (tablet landscape, laptop, or the
          // right-hand pane of the transaction picker on a big monitor).
          final wide = c.maxWidth >= 840;
          final pad = sidePadding(c.maxWidth, maxWidth: wide ? 1200 : 720);
          final padding = EdgeInsets.fromLTRB(pad, 8, pad, 24);

          final banner = <Widget>[if (src != null) SourceBanner(txn: src)];
          final customerSection = <Widget>[
            const SectionHeader('Customer'),
            Card(
              shape: _showCustomerError
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: scheme.error))
                  : null,
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(customer?.name ?? 'Choose a customer'),
                subtitle: _showCustomerError
                    ? Text('Customer is required', style: TextStyle(color: scheme.error))
                    : (customer != null && customer.email.isNotEmpty
                        ? Text(customer.email)
                        : null),
                trailing: const Icon(Icons.expand_more),
                onTap: _pickCustomer,
              ),
            ),

            ];
          final detailsSection = <Widget>[
            const SectionHeader('Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DateField(
                              label: 'Issue date',
                              date: _issueDate,
                              onTap: _pickIssueDate),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DateField(label: 'Due date', date: _dueDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Payment terms',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
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
          final itemsSection = <Widget>[
            SectionHeader(
              'Items',
              action: TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add item'),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              shape: _showLinesError
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: scheme.error))
                  : null,
              child: Column(
                children: [
                  if (_lines.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Add your first item'),
                      subtitle: _showLinesError
                          ? Text('At least one item is required',
                              style: TextStyle(color: scheme.error))
                          : null,
                      onTap: _addLine,
                    ),
                  for (var i = 0; i < _lines.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    LineItemTile(
                      line: _lines[i],
                      onTap: () async {
                        final edited = await _editLine(_lines[i]);
                        if (edited != null) setState(() => _lines[i] = edited);
                      },
                      onDelete: () => setState(() => _lines.removeAt(i)),
                    ),
                  ],
                ],
              ),
            ),

            ];
          final summarySection = <Widget>[
            const SectionHeader('Summary'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TotalRow('Subtotal', money(_subtotal)),
                    for (final e in taxBreakdownOf(_lines).entries)
                      TotalRow(e.key, money(e.value)),
                    const Divider(height: 20),
                    TotalRow('Total', money(_total), bold: true),
                    if (src != null) ...[
                      const SizedBox(height: 12),
                      ReconciliationBox(
                        txnAmount: src.amount,
                        invoiceTotal: _total,
                        onMatch: _matchTransactionAmount,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            ];
          final notesSection = <Widget>[
            const SectionHeader('Notes'),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Shown at the bottom of the invoice',
              ),
            ),
];

          if (!wide) {
            return ListView(
              padding: padding,
              children: [
                ...banner,
                ...customerSection,
                ...detailsSection,
                ...itemsSection,
                ...summarySection,
                ...notesSection,
              ],
            );
          }

          return ListView(
            padding: padding,
            children: [
              ...banner,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...customerSection,
                        ...detailsSection,
                        ...notesSection,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...itemsSection, ...summarySection],
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    ),
    );
  }
}
