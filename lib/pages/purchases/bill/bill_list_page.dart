import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/bill/bill_bloc.dart';
import '../../../bloc/vendor/vendor_bloc.dart';
import '../../../components/bill_tile.dart';
import '../../../components/empty_state.dart';
import '../../../components/search_field.dart';
import '../../../config/layout.dart';
import '../../../models/invoice_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../purchase_flows.dart';
import 'bill_detail_page.dart';

/// Bills, soonest due first. Optionally just one vendor's.
/// Wide screens: list left, bill right.
class BillListPage extends StatefulWidget {
  const BillListPage({super.key, this.vendorId});

  final String? vendorId;

  @override
  State<BillListPage> createState() => _BillListPageState();
}

class _BillListPageState extends State<BillListPage> {
  // Default to what still needs paying.
  bool _openOnly = true;
  String _query = '';
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final vendors = context.watch<VendorBloc>().state;
    final l = context.ledger;
    final vendorName = vendors.byId(widget.vendorId)?.name;
    final all = context
        .watch<BillBloc>()
        .state
        .bills
        .where((b) => widget.vendorId == null || b.vendorId == widget.vendorId)
        .toList();
    final openCount = all.where((b) => b.statusOn(today) != InvoiceStatus.paid).length;
    final q = _query.trim().toLowerCase();

    final shown = all.where((b) {
      if (_openOnly && b.statusOn(today) == InvoiceStatus.paid) return false;
      if (q.isEmpty) return true;
      final name = vendors.byId(b.vendorId)?.name.toLowerCase() ?? '';
      return name.contains(q) ||
          b.number.toLowerCase().contains(q) ||
          b.total.toStringAsFixed(2).contains(q) ||
          b.lines.any((x) => x.description.toLowerCase().contains(q));
    }).toList();
    // Paid bills: most recent first (open bills stay soonest-due first).
    if (!_openOnly) {
      shown.sort((a, b) {
        final ap = a.statusOn(today) == InvoiceStatus.paid;
        final bp = b.statusOn(today) == InvoiceStatus.paid;
        if (ap != bp) return ap ? 1 : -1;
        return ap ? b.dueDate.compareTo(a.dueDate) : a.dueDate.compareTo(b.dueDate);
      });
    }

    final title = vendorName == null ? 'Bills' : 'Bills from $vendorName';

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= Breakpoints.twoPane;
      final valid = _selectedId != null && shown.any((b) => b.id == _selectedId);
      final String? selected =
          (!wide || valid) ? _selectedId : (shown.isEmpty ? null : shown.first.id);

      final controls = Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.sm),
        child: Column(
          children: [
            SearchField(
              hint: 'Search by vendor, reference or amount',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text('To pay ($openCount)')),
                  ButtonSegment(value: false, label: Text('All (${all.length})')),
                ],
                selected: {_openOnly},
                onSelectionChanged: (s) => setState(() => _openOnly = s.first),
              ),
            ),
          ],
        ),
      );

      final Widget list;
      if (all.isEmpty) {
        list = EmptyState(
          icon: Icons.description_outlined,
          title: 'No bills yet',
          message: 'Add bills from vendors so you know what to pay and when.',
          actionLabel: 'New bill',
          onAction: () => openBillForm(context, vendorId: widget.vendorId),
        );
      } else if (shown.isEmpty) {
        list = EmptyState(
          icon: _openOnly ? Icons.task_alt_rounded : Icons.search_off_rounded,
          title: _openOnly && q.isEmpty ? 'All bills are paid' : 'No matching bills',
          message: _openOnly && q.isEmpty ? 'Nothing to pay right now.' : null,
          compact: true,
        );
      } else {
        list = ListView.separated(
          padding: EdgeInsets.only(bottom: wide ? Space.lg : 88),
          itemCount: shown.length,
          separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: l.hairline),
          itemBuilder: (context, i) {
            final b = shown[i];
            return BillTile(
              bill: b,
              selected: wide && b.id == selected,
              onTap: () {
                if (wide) {
                  setState(() => _selectedId = b.id);
                } else {
                  openBillDetail(context, b.id);
                }
              },
            );
          },
        );
      }

      if (!wide) {
        final pad = sidePadding(c.maxWidth, maxWidth: 760, min: 0);
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openBillForm(context, vendorId: widget.vendorId),
            icon: const Icon(Icons.add),
            label: const Text('New bill'),
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Column(children: [controls, Expanded(child: list)]),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            Center(
              child: FilledButton.icon(
                onPressed: () => openBillForm(context, vendorId: widget.vendorId),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New bill'),
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
              child: Column(
                  children: [controls, Divider(color: l.hairline), Expanded(child: list)]),
            ),
            VerticalDivider(width: 1, color: l.hairline),
            Expanded(
              child: selected == null
                  ? const EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Select a bill',
                      message: 'Its lines, receipts and payments will show here.',
                    )
                  : BillDetailPage(key: ValueKey(selected), billId: selected, embedded: true),
            ),
          ],
        ),
      );
    });
  }
}
