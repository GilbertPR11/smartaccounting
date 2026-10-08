import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/product/product_bloc.dart';
import '../../../components/empty_state.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../config/constants.dart';
import '../../../config/layout.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final price = TextEditingController();
    String? taxId = Constants.taxes.first.id;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Price', prefixText: '${Constants.currency} '),
                    validator: (v) {
                      final n = parseAmount(v ?? '');
                      return (n == null || n < 0) ? 'Enter a price, e.g. 250.00' : null;
                    },
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
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
          price: parseAmount(price.text)!,
          tax: Constants.taxById(taxId),
        ));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Added ${name.text.trim()}')));
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductBloc>().state.products;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Products & services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Nothing to sell yet',
              message: 'Add the products or services you invoice for, with their usual price.',
              actionLabel: 'Add item',
              onAction: () => _add(context),
            )
          : LayoutBuilder(builder: (context, c) {
              final pad = sidePadding(c.maxWidth, maxWidth: 760, min: 0);
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 88),
                itemCount: products.length,
                separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: l.hairline),
                itemBuilder: (context, i) {
                  final p = products[i];
                  return ListTile(
                    leading: IconBadge(Icons.sell_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(p.name),
                    subtitle: Text(
                      p.description.isNotEmpty ? p.description : 'No description',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(p.price),
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
