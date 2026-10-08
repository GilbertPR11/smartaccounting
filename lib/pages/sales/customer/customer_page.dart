import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../components/customer_dialog.dart';
import '../../../components/empty_state.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/search_field.dart';
import '../../../config/layout.dart';
import '../../../theme/colors.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = context.watch<CustomerBloc>().state.customers; // sorted by name
    final invoices = context.watch<InvoiceBloc>().state.invoices;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final customers = q.isEmpty
        ? all
        : all
            .where((c) => c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q))
            .toList();

    Widget body;
    if (all.isEmpty) {
      body = EmptyState(
        icon: Icons.people_outline,
        title: 'No customers yet',
        message: 'Add the people and businesses you send invoices to.',
        actionLabel: 'Add customer',
        onAction: () => showAddCustomerDialog(context),
      );
    } else if (customers.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching customers',
        message: 'Nothing matches "$_query".',
        compact: true,
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: customers.length,
        separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: l.hairline),
        itemBuilder: (context, i) {
          final c = customers[i];
          final theirs = invoices.where((inv) => inv.customerId == c.id).toList();
          final owed = theirs.fold<double>(0, (s, inv) => s + inv.balance);
          return ListTile(
            leading: InitialsAvatar(c.name),
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              c.email.isNotEmpty ? c.email : (c.phone.isNotEmpty ? c.phone : 'No contact details'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: owed > 0.004
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyText(owed),
                      Text('owed', style: text.bodySmall),
                    ],
                  )
                : Text(
                    theirs.isEmpty ? 'No invoices' : 'All paid',
                    style: text.bodySmall,
                  ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddCustomerDialog(context),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add customer'),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final pad = sidePadding(c.maxWidth, maxWidth: 760, min: 0);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            children: [
              if (all.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.sm),
                  child: SearchField(
                    hint: 'Search customers',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        );
      }),
    );
  }
}
