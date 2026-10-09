import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../components/transaction_tile.dart';
import '../../../config/layout.dart';
import '../../../models/invoice_model.dart';
import '../../../models/transaction_model.dart';
import '../../../routes/routes.dart';
import '../../../components/money_text.dart';
import '../../../theme/colors.dart';
import 'invoice_form_page.dart';
import 'new_invoice_flow.dart';

/// Step 1 of "invoice from transaction": choose an uninvoiced income txn.
class TransactionPickerPage extends StatefulWidget {
  const TransactionPickerPage({super.key});

  @override
  State<TransactionPickerPage> createState() => _TransactionPickerPageState();
}

class _TransactionPickerPageState extends State<TransactionPickerPage> {
  String _query = '';
  String? _selectedId; // wide layout: transaction shown in the form pane

  void _showCreated(Invoice inv) {
    Navigator.pushReplacementNamed(
      context,
      PageRoutes.invoiceDetail,
      arguments: InvoiceDetailArgs(inv.id, justCreated: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerBloc>().state;
    final q = _query.toLowerCase();
    final txns = context.watch<TransactionBloc>().state.invoiceable.where((t) {
      if (q.isEmpty) return true;
      final customer = customers.byId(t.customerId)?.name ?? '';
      return t.description.toLowerCase().contains(q) ||
          customer.toLowerCase().contains(q) ||
          t.amount.toStringAsFixed(2).contains(q);
    }).toList();

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= Breakpoints.twoPane;
      BankTransaction? selected;
      for (final t in txns) {
        if (t.id == _selectedId) selected = t;
      }
      if (wide && selected == null && txns.isNotEmpty) selected = txns.first;

      final listPane = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search description, customer or amount',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Showing money received that has no invoice yet. Owner '
              'contributions, loans and transfers are excluded.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: txns.isEmpty
                ? _Empty(searching: q.isNotEmpty)
                : ListView.separated(
                    itemCount: txns.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final t = txns[i];
                      final customer = customers.byId(t.customerId);
                      return TransactionTile(
                        transaction: t,
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            MoneyText(t.amount, color: context.ledger.moneyIn),
                            Text(customer?.name ?? 'No customer',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        selected: wide && t.id == selected?.id,
                        onTap: () {
                          if (wide) {
                            setState(() => _selectedId = t.id);
                          } else {
                            openInvoiceForm(context, source: t, replace: true);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      );

      if (!wide) {
        final pad = sidePadding(c.maxWidth, maxWidth: 840, min: 0);
        return Scaffold(
          appBar: AppBar(title: const Text('Select a transaction')),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: listPane,
          ),
        );
      }

      final pick = selected;
      return Scaffold(
        appBar: AppBar(title: const Text('Select a transaction')),
        body: Row(
          children: [
            SizedBox(width: c.maxWidth >= 1300 ? 440 : 380, child: listPane),
            const VerticalDivider(width: 1),
            Expanded(
              child: pick == null
                  ? const _Empty(searching: false)
                  : InvoiceFormPage(
                      key: ValueKey(pick.id),
                      source: pick,
                      onSaved: _showCreated,
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt, size: 48),
            const SizedBox(height: 12),
            Text(searching
                ? 'No matching transactions'
                : 'Every payment received already has an invoice.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => openInvoiceForm(context, replace: true),
              child: const Text('Create a blank invoice'),
            ),
          ],
        ),
      ),
    );
  }
}
