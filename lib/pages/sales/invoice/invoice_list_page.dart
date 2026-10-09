import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../components/empty_state.dart';
import '../../../components/invoice_tile.dart';
import '../../../components/search_field.dart';
import '../../../config/layout.dart';
import '../../../models/invoice_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import 'invoice_detail_page.dart';
import 'new_invoice_flow.dart';

/// Invoice list with search and status filters.
/// * Narrow: list only; tapping opens the detail page.
/// * Wide (≥ 900 px available): list on the left, detail on the right.
class InvoiceListPage extends StatefulWidget {
  const InvoiceListPage({super.key});

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  InvoiceStatus? _filter; // null = all
  String _query = '';
  int _searchEpoch = 0; // bump to reset the search box
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final all = context.watch<InvoiceBloc>().state.invoices;
    final customers = context.watch<CustomerBloc>().state;
    final l = context.ledger;
    final q = _query.trim().toLowerCase();

    final shown = all.where((i) {
      if (_filter != null && i.statusOn(today) != _filter) return false;
      if (q.isEmpty) return true;
      final name = customers.byId(i.customerId)?.name.toLowerCase() ?? '';
      return i.number.toLowerCase().contains(q) ||
          name.contains(q) ||
          i.total.toStringAsFixed(2).contains(q);
    }).toList();

    int count(InvoiceStatus s) => all.where((i) => i.statusOn(today) == s).length;

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= Breakpoints.twoPane;

      // In two-pane mode, keep a valid selection (default: first invoice).
      final selectionValid = _selectedId != null && shown.any((i) => i.id == _selectedId);
      final String? selected = (!wide || selectionValid)
          ? _selectedId
          : (shown.isEmpty ? null : shown.first.id);

      final controls = Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, 0),
        child: Column(
          children: [
            SearchField(
              key: ValueKey(_searchEpoch),
              hint: 'Search by customer, number or amount',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'All',
                    count: all.length,
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final s in [
                    InvoiceStatus.overdue,
                    InvoiceStatus.unpaid,
                    InvoiceStatus.partial,
                    InvoiceStatus.paid,
                  ]) ...[
                    const SizedBox(width: Space.sm),
                    _FilterChip(
                      label: s.label,
                      count: count(s),
                      selected: _filter == s,
                      onTap: () => setState(() => _filter = s),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
          ],
        ),
      );

      final Widget list;
      if (all.isEmpty) {
        list = EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No invoices yet',
          message: 'Create one from scratch, or from a payment you already received.',
          actionLabel: 'New invoice',
          onAction: () => showNewInvoiceSheet(context),
        );
      } else if (shown.isEmpty) {
        list = EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matching invoices',
          message: q.isNotEmpty
              ? 'Nothing matches "$_query". Try a customer name or invoice number.'
              : 'No ${_filter?.label.toLowerCase()} invoices right now.',
          actionLabel: 'Show all invoices',
          onAction: () => setState(() {
            _filter = null;
            _query = '';
            _searchEpoch++;
          }),
          compact: true,
        );
      } else {
        list = ListView.separated(
          padding: EdgeInsets.only(bottom: wide ? Space.lg : 88),
          itemCount: shown.length,
          separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: l.hairline),
          itemBuilder: (context, i) {
            final inv = shown[i];
            return InvoiceTile(
              invoice: inv,
              selected: wide && inv.id == selected,
              onTap: () {
                if (wide) {
                  setState(() => _selectedId = inv.id);
                } else {
                  openInvoiceDetail(context, inv.id);
                }
              },
            );
          },
        );
      }

      if (!wide) {
        final pad = sidePadding(c.maxWidth, maxWidth: 760, min: 0);
        return Scaffold(
          appBar: AppBar(title: const Text('Invoices')),
          floatingActionButton: FloatingActionButton(
            tooltip: 'New invoice',
            onPressed: () => showNewInvoiceSheet(context),
            child: const Icon(Icons.add),
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Column(children: [controls, Expanded(child: list)]),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoices'),
          actions: [
            // Center: AppBar would otherwise stretch the button to full height.
            Center(
              child: FilledButton.icon(
                onPressed: () => showNewInvoiceSheet(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New invoice'),
              ),
            ),
            const SizedBox(width: Space.lg),
          ],
        ),
        body: Row(
          children: [
            Container(
              width: c.maxWidth >= 1300 ? 440 : 380,
              color: Theme.of(context).colorScheme.surface,
              child: Column(children: [controls, Divider(color: l.hairline), Expanded(child: list)]),
            ),
            VerticalDivider(width: 1, color: l.hairline),
            Expanded(
              child: selected == null
                  ? const EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Select an invoice',
                      message: 'Its details and payments will show here.',
                    )
                  : InvoiceDetailPage(
                      key: ValueKey(selected),
                      invoiceId: selected,
                      embedded: true,
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Text('$count',
              style: TextStyle(
                  color: selected ? Theme.of(context).colorScheme.primary : l.muted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
