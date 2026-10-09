import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/bill/bill_bloc.dart';
import '../../../bloc/vendor/vendor_bloc.dart';
import '../../../components/empty_state.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/search_field.dart';
import '../../../components/vendor_dialog.dart';
import '../../../config/layout.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';

/// Vendors with what you owe each one. Tap a vendor to see their bills.
class VendorPage extends StatefulWidget {
  const VendorPage({super.key});

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final all = context.watch<VendorBloc>().state.vendors;
    final bills = context.watch<BillBloc>().state.bills;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final vendors = q.isEmpty
        ? all
        : all
            .where((v) =>
                v.name.toLowerCase().contains(q) ||
                (v.defaultCategory ?? '').toLowerCase().contains(q))
            .toList();

    Widget body;
    if (all.isEmpty) {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No vendors yet',
        message: 'Add the businesses you buy from, so bills and receipts are easy to file.',
        actionLabel: 'Add vendor',
        onAction: () => showAddVendorDialog(context),
      );
    } else if (vendors.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching vendors',
        message: 'Nothing matches "$_query".',
        compact: true,
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: vendors.length,
        separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: l.hairline),
        itemBuilder: (context, i) {
          final v = vendors[i];
          final theirs = bills.where((b) => b.vendorId == v.id).toList();
          final owed = theirs.fold<double>(0, (s, b) => s + b.balance);
          final next = theirs.where((b) => b.balance > 0.004).toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return ListTile(
            leading: InitialsAvatar(v.name),
            title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              next.isNotEmpty
                  ? 'Next bill ${relativeDue(next.first.dueDate, today).toLowerCase()}'
                  : (v.defaultCategory ?? 'No category'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: owed > 0.004
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [MoneyText(owed), Text('to pay', style: text.bodySmall)],
                  )
                : Text(theirs.isEmpty ? 'No bills' : 'All paid', style: text.bodySmall),
            onTap: () => Navigator.pushNamed(context, PageRoutes.bills,
                arguments: BillListArgs(vendorId: v.id)),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddVendorDialog(context),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add vendor'),
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
                    hint: 'Search vendors',
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
