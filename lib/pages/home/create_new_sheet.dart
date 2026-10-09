import 'package:flutter/material.dart';

import '../../components/customer_dialog.dart';
import '../../components/vendor_dialog.dart';
import '../../models/transaction_model.dart';
import '../../theme/colors.dart';
import '../accounting/accounting_flows.dart';
import '../purchases/purchase_flows.dart';
import '../sales/estimate/estimate_flows.dart';
import '../sales/invoice/new_invoice_flow.dart';
import '../sales/product/product_page.dart';
import '../sales/recurring/recurring_flows.dart';

/// Everything the "Create new" button can make (like Wave's).
enum CreateAction {
  invoice,
  estimate,
  recurringInvoice,
  customer,
  product,
  bill,
  receipt,
  vendor,
  moneyIn,
  moneyOut,
  journalEntry,
}

extension CreateActionInfo on CreateAction {
  String get label => switch (this) {
        CreateAction.invoice => 'Invoice',
        CreateAction.estimate => 'Estimate',
        CreateAction.recurringInvoice => 'Recurring invoice',
        CreateAction.customer => 'Customer',
        CreateAction.product => 'Product or service',
        CreateAction.bill => 'Bill',
        CreateAction.receipt => 'Receipt',
        CreateAction.vendor => 'Vendor',
        CreateAction.moneyIn => 'Money in',
        CreateAction.moneyOut => 'Money out',
        CreateAction.journalEntry => 'Journal entry',
      };

  IconData get icon => switch (this) {
        CreateAction.invoice => Icons.receipt_long_outlined,
        CreateAction.estimate => Icons.request_quote_outlined,
        CreateAction.recurringInvoice => Icons.autorenew_rounded,
        CreateAction.customer => Icons.person_add_alt_outlined,
        CreateAction.product => Icons.sell_outlined,
        CreateAction.bill => Icons.description_outlined,
        CreateAction.receipt => Icons.document_scanner_outlined,
        CreateAction.vendor => Icons.storefront_outlined,
        CreateAction.moneyIn => Icons.south_west_rounded,
        CreateAction.moneyOut => Icons.north_east_rounded,
        CreateAction.journalEntry => Icons.swap_vert_rounded,
      };

  /// Which main category (0 Dashboard, 1 Sales, 2 Purchases, 3 Accounting)
  /// the result belongs to, so wide layouts open it in that tab.
  int get section => switch (this) {
        CreateAction.invoice ||
        CreateAction.estimate ||
        CreateAction.recurringInvoice ||
        CreateAction.customer ||
        CreateAction.product =>
          1,
        CreateAction.bill || CreateAction.receipt || CreateAction.vendor => 2,
        CreateAction.moneyIn || CreateAction.moneyOut || CreateAction.journalEntry => 3,
      };
}

/// Shows the grouped "Create new" menu and returns the choice.
Future<CreateAction?> showCreateNewSheet(BuildContext context) {
  const groups = <(String, List<CreateAction>)>[
    ('Sales', [
      CreateAction.invoice,
      CreateAction.estimate,
      CreateAction.recurringInvoice,
      CreateAction.customer,
      CreateAction.product,
    ]),
    ('Purchases', [CreateAction.bill, CreateAction.receipt, CreateAction.vendor]),
    ('Accounting', [CreateAction.moneyIn, CreateAction.moneyOut, CreateAction.journalEntry]),
  ];
  return showModalBottomSheet<CreateAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final text = Theme.of(ctx).textTheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
            children: [
              Text('Create new', style: text.titleLarge),
              for (final (title, actions) in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm),
                  child: Text(title.toUpperCase(),
                      style: text.labelMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary, letterSpacing: 0.8)),
                ),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final a in actions)
                      ActionChip(
                        avatar: Icon(a.icon, size: 18),
                        label: Text(a.label),
                        onPressed: () => Navigator.pop(ctx, a),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Starts [action] from [context]. On wide layouts the caller passes a
/// context inside the right category's navigator.
Future<void> runCreateAction(BuildContext context, CreateAction action) async {
  switch (action) {
    case CreateAction.invoice:
      await openInvoiceForm(context);
    case CreateAction.estimate:
      await openEstimateForm(context);
    case CreateAction.recurringInvoice:
      await openRecurringForm(context);
    case CreateAction.customer:
      await showAddCustomerDialog(context);
    case CreateAction.product:
      await ProductPage.showAddDialog(context);
    case CreateAction.bill:
      await openBillForm(context);
    case CreateAction.receipt:
      await captureReceipt(context);
    case CreateAction.vendor:
      await showAddVendorDialog(context);
    case CreateAction.moneyIn:
      await openTransactionForm(context, type: TransactionType.income);
    case CreateAction.moneyOut:
      await openTransactionForm(context, type: TransactionType.expense);
    case CreateAction.journalEntry:
      await openJournalForm(context);
  }
}
