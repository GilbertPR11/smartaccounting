import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/setting/setting_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../components/empty_state.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/statement_document.dart';
import '../../../config/layout.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../../utils/statement.dart';
import '../widgets/document_form_parts.dart';

enum _Kind { outstanding, activity }

enum _Period { thisMonth, lastMonth, last3Months, thisYear, custom }

extension _PeriodLabel on _Period {
  String get label => switch (this) {
        _Period.thisMonth => 'This month',
        _Period.lastMonth => 'Last month',
        _Period.last3Months => 'Last 3 months',
        _Period.thisYear => 'This year',
        _Period.custom => 'Custom',
      };
}

/// Customer statements: what a customer owes now (outstanding), or
/// everything that happened in a period (activity).
class StatementPage extends StatefulWidget {
  const StatementPage({super.key, this.customerId});

  final String? customerId;

  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  String? _customerId;
  _Kind _kind = _Kind.outstanding;
  _Period _period = _Period.last3Months;
  DateTimeRange? _custom;

  /// The paper keeps its layout on phones and is scaled down to fit,
  /// like a PDF preview, instead of squeezing the table columns.
  static const double _paperWidth = 600;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customerId;
  }

  DateTimeRange _range(DateTime today) => switch (_period) {
        _Period.thisMonth => DateTimeRange(start: DateTime(today.year, today.month, 1), end: today),
        _Period.lastMonth => DateTimeRange(
            start: DateTime(today.year, today.month - 1, 1),
            end: DateTime(today.year, today.month, 0)),
        _Period.last3Months =>
          DateTimeRange(start: addMonths(today, -3).add(const Duration(days: 1)), end: today),
        _Period.thisYear => DateTimeRange(start: DateTime(today.year, 1, 1), end: today),
        _Period.custom => _custom ??
            DateTimeRange(start: DateTime(today.year, today.month, 1), end: today),
      };

  Future<void> _pickCustom(DateTime today) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: _range(today),
    );
    if (picked != null) {
      setState(() {
        _custom = DateTimeRange(start: dateOnly(picked.start), end: dateOnly(picked.end));
        _period = _Period.custom;
      });
    }
  }

  Future<void> _chooseCustomer() async {
    final id = await pickCustomer(context, selectedId: _customerId);
    if (id != null && mounted) setState(() => _customerId = id);
  }

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final customer = context.watch<CustomerBloc>().state.byId(_customerId);
    final invoices = context.watch<InvoiceBloc>().state.invoices;
    final txns = context.watch<TransactionBloc>().state.transactions;
    final settings = context.watch<SettingBloc>().state;
    final text = Theme.of(context).textTheme;
    final l = context.ledger;
    final range = _range(today);

    final controls = Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Customer', style: text.bodySmall),
            const SizedBox(height: Space.xs),
            OutlinedButton(
              onPressed: _chooseCustomer,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md)),
              child: Row(
                children: [
                  if (customer != null) ...[
                    InitialsAvatar(customer.name, size: 28),
                    const SizedBox(width: Space.sm),
                  ],
                  Expanded(
                    child: Text(customer?.name ?? 'Choose a customer',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            Text('Statement type', style: text.bodySmall),
            const SizedBox(height: Space.xs),
            SegmentedButton<_Kind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Kind.outstanding, label: Text('Outstanding')),
                ButtonSegment(value: _Kind.activity, label: Text('Activity')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: Space.sm),
            Text(
              _kind == _Kind.outstanding
                  ? 'Every unpaid invoice today, with how late each one is.'
                  : 'Invoices and payments in a period, with a running balance.',
              style: text.bodySmall,
            ),
            if (_kind == _Kind.activity) ...[
              const SizedBox(height: Space.lg),
              Text('Period', style: text.bodySmall),
              const SizedBox(height: Space.xs),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  for (final p in _Period.values)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: _period == p,
                      onSelected: (_) {
                        if (p == _Period.custom) {
                          _pickCustom(today);
                        } else {
                          setState(() => _period = p);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text('${fmtDate(range.start)} – ${fmtDate(range.end)}',
                  style: text.bodyMedium?.copyWith(color: l.muted)),
            ],
          ],
        ),
      ),
    );

    Widget document = customer == null
        ? const EmptyState(
            icon: Icons.summarize_outlined,
            title: 'Choose a customer',
            message: 'Their statement will appear here, ready to send.',
            compact: true,
          )
        : StatementDocument(
            customer: customer,
            profile: settings.profile,
            template: settings.template,
            outstanding: _kind == _Kind.outstanding
                ? Statements.outstanding(
                    customerId: customer.id, invoices: invoices, asOf: today)
                : null,
            activity: _kind == _Kind.activity
                ? Statements.activity(
                    customerId: customer.id,
                    invoices: invoices,
                    transactions: txns,
                    from: range.start,
                    to: range.end)
                : null,
          );
    if (customer != null) {
      final paper = document; // capture now: the closure runs later
      document = LayoutBuilder(
        builder: (context, c) => c.maxWidth >= _paperWidth
            ? paper
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(width: _paperWidth, child: paper),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer statement'),
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.ios_share),
            onPressed: customer == null
                ? null
                : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('PDF export & sending come in a later build.'))),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= Breakpoints.twoPane) {
          final pad = sidePadding(c.maxWidth, maxWidth: 1200, min: Space.xl);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, Space.lg, pad, Space.xxl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 340, child: controls),
                const SizedBox(width: Space.xl),
                Expanded(child: document),
              ],
            ),
          );
        }
        final pad = sidePadding(c.maxWidth, maxWidth: 760);
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.xxl),
          children: [controls, const SizedBox(height: Space.lg), document],
        );
      }),
    );
  }
}
