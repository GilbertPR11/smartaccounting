import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/account/account_bloc.dart';
import '../../../bloc/product/product_bloc.dart';
import '../../../components/empty_state.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../config/constants.dart';
import '../../../config/layout.dart';
import '../../../models/product_model.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';

/// Products & services. The same list serves both sides, like Wave:
/// under Sales it shows what you sell, under Purchases what you buy.
class ProductPage extends StatelessWidget {
  const ProductPage({super.key, this.purchases = false});

  /// True when opened from Purchases.
  final bool purchases;

  /// The "new product or service" dialog. Also used by "Create new".
  static Future<void> showAddDialog(BuildContext context, {bool purchases = false}) async {
    final name = TextEditingController();
    final price = TextEditingController();
    final cost = TextEditingController();
    String? taxId = Constants.taxes.first.id;
    var sold = !purchases;
    var bought = purchases;
    final expenseNames = context.read<AccountBloc>().state.expenseNames;
    String? expense = expenseNames.contains('Other')
        ? 'Other'
        : (expenseNames.isEmpty ? null : expenseNames.first);
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New product or service'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: Space.md),
                    DropdownButtonFormField<String?>(
                      value: taxId,
                      decoration: const InputDecoration(labelText: 'Default tax'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('No tax')),
                        for (final t in Constants.taxes)
                          DropdownMenuItem<String?>(value: t.id, child: Text(t.label)),
                      ],
                      onChanged: (v) => setLocal(() => taxId = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('I sell this'),
                      subtitle: const Text('Shows on invoices and estimates'),
                      value: sold,
                      onChanged: (v) => setLocal(() => sold = v),
                    ),
                    if (sold)
                      TextFormField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Selling price', prefixText: '${Constants.currency} '),
                        validator: (v) {
                          final n = parseAmount(v ?? '');
                          return (n == null || n < 0) ? 'Enter a price, e.g. 250.00' : null;
                        },
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('I buy this'),
                      subtitle: const Text('Shows on bills'),
                      value: bought,
                      onChanged: (v) => setLocal(() => bought = v),
                    ),
                    if (bought) ...[
                      TextFormField(
                        controller: cost,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Usual cost', prefixText: '${Constants.currency} '),
                        validator: (v) {
                          final n = parseAmount(v ?? '');
                          return (n == null || n < 0) ? 'Enter a cost, e.g. 45.00' : null;
                        },
                      ),
                      const SizedBox(height: Space.md),
                      DropdownButtonFormField<String>(
                        value: expense,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Expense category'),
                        items: [
                          for (final n in expenseNames) DropdownMenuItem(value: n, child: Text(n)),
                        ],
                        onChanged: (v) => setLocal(() => expense = v),
                        validator: (v) => v == null ? 'Choose a category' : null,
                      ),
                    ],
                    if (!sold && !bought)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.sm),
                        child: Text('Turn on at least one.',
                            style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if ((sold || bought) && key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Add item'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    context.read<ProductBloc>().add(AddProduct(
          name: name.text,
          price: sold ? parseAmount(price.text)! : 0,
          tax: Constants.taxById(taxId),
          sold: sold,
          bought: bought,
          purchasePrice: bought ? parseAmount(cost.text) : null,
          expenseCategory: bought ? expense : null,
        ));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Added ${name.text.trim()}')));
  }

  String _subtitle(Product p) {
    final cost = p.purchasePrice;
    return [
      if (p.sold) 'Sell ${money(p.price)}',
      if (p.bought) 'Buy${cost == null ? '' : ' ${money(cost)}'} → ${p.expenseCategory ?? '—'}',
    ].join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductBloc>().state;
    final products = purchases ? state.bought : state.sold;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(purchases ? 'Products you buy' : 'Products & services')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showAddDialog(context, purchases: purchases),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: purchases ? 'Nothing saved to buy yet' : 'Nothing to sell yet',
              message: purchases
                  ? 'Save things you buy often, with their usual cost and category, '
                      'to fill in bills faster.'
                  : 'Add the products or services you invoice for, with their usual price.',
              actionLabel: 'Add item',
              onAction: () => showAddDialog(context, purchases: purchases),
            )
          : LayoutBuilder(builder: (context, c) {
              final pad = sidePadding(c.maxWidth, maxWidth: 760, min: 0);
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 88),
                itemCount: products.length,
                separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: l.hairline),
                itemBuilder: (context, i) {
                  final p = products[i];
                  final shown = purchases ? (p.purchasePrice ?? 0) : p.price;
                  return ListTile(
                    leading: IconBadge(
                        purchases ? Icons.shopping_cart_outlined : Icons.sell_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(p.name),
                    subtitle: Text(
                      p.description.isNotEmpty ? p.description : _subtitle(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(shown),
                        Text(p.tax?.label ?? 'No tax', style: text.bodySmall),
                      ],
                    ),
                  );
                },
              );
            }),
    );
  }
}
