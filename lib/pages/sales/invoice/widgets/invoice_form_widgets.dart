import 'package:flutter/material.dart';

import '../../../../config/constants.dart';
import '../../../../models/invoice_model.dart';
import '../../../../models/transaction_model.dart';
import '../../../../components/initials_avatar.dart';
import '../../../../components/money_text.dart';
import '../../../../theme/colors.dart';
import '../../../../utils/format.dart';

// Building blocks of the invoice form page.


class SourceBanner extends StatelessWidget {
  const SourceBanner({super.key, required this.txn});

  final BankTransaction txn;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    return Card(
      child: ListTile(
        leading: IconBadge(Icons.south_west_rounded, color: l.moneyIn),
        title: Text('Received ${fmtDate(txn.date)} into ${txn.account}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(txn.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: MoneyText(txn.amount, color: l.moneyIn),
      ),
    );
  }
}

class ReconciliationBox extends StatelessWidget {
  const ReconciliationBox({
    super.key,
    required this.txnAmount,
    required this.invoiceTotal,
    required this.onMatch,
  });

  final double txnAmount;
  final double invoiceTotal;
  final VoidCallback onMatch;

  @override
  Widget build(BuildContext context) {
    final diff = round2(invoiceTotal - txnAmount);
    final matched = diff.abs() < 0.005;
    final l = context.ledger;

    final (Color bg, Color fg, IconData icon, String msg) = matched
        ? (l.moneyIn.withOpacity(0.10), l.moneyIn, Icons.check_circle_outline,
            'Matches the transaction. Invoice will be marked paid.')
        : diff > 0
            ? (l.warning.withOpacity(0.10), l.warning, Icons.info_outline,
                '${money(diff)} more than received. Invoice will be partially '
                    'paid with ${money(diff)} still due.')
            : (l.moneyOut.withOpacity(0.10), l.moneyOut, Icons.warning_amber_rounded,
                '${money(-diff)} less than received. The excess payment will '
                    'stay unapplied.');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TotalRow('Transaction amount', money(txnAmount), color: fg),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(child: Text(msg, style: TextStyle(color: fg, fontSize: 13))),
            ],
          ),
          if (!matched) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onMatch,
                style: TextButton.styleFrom(foregroundColor: fg),
                child: const Text('Adjust prices to match (tax-inclusive)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TotalRow extends StatelessWidget {
  const TotalRow(this.label, this.value, {super.key, this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.date, this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: onTap != null,
          suffixIcon: onTap != null ? const Icon(Icons.calendar_today, size: 18) : null,
        ),
        child: Text(fmtDate(date)),
      ),
    );
  }
}

class LineItemTile extends StatelessWidget {
  const LineItemTile({super.key, required this.line, required this.onTap, required this.onDelete});

  final InvoiceLine line;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(line.description.isEmpty ? '(no description)' : line.description,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(line.tax == null
          ? '${fmtQty(line.quantity)} × ${money(line.unitPrice)}'
          : '${fmtQty(line.quantity)} × ${money(line.unitPrice)}, ${line.tax!.label}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(line.subtotal),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet editor for one line item. Pops with the edited line.
class LineEditorSheet extends StatefulWidget {
  const LineEditorSheet({super.key, required this.line, required this.isNew});

  final InvoiceLine line;
  final bool isNew;

  @override
  State<LineEditorSheet> createState() => _LineEditorSheetState();
}

class _LineEditorSheetState extends State<LineEditorSheet> {
  final _key = GlobalKey<FormState>();
  late final _desc = TextEditingController(text: widget.line.description);
  late final _qty = TextEditingController(text: fmtQty(widget.line.quantity));
  late final _price = TextEditingController(
      text: widget.line.unitPrice == 0 ? '' : widget.line.unitPrice.toStringAsFixed(2));
  late String? _taxId = widget.line.tax?.id;

  @override
  void dispose() {
    _desc.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  void _done() {
    if (!_key.currentState!.validate()) return;
    final tax = Constants.taxById(_taxId);
    final line = widget.line.copyWith(
      description: _desc.text.trim(),
      quantity: parseAmount(_qty.text)!,
      unitPrice: round2(parseAmount(_price.text)!),
      tax: tax,
      clearTax: tax == null,
    );
    Navigator.pop(context, line);
  }

  @override
  Widget build(BuildContext context) {
    final qty = parseAmount(_qty.text) ?? 0;
    final price = parseAmount(_price.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.isNew ? 'Add item' : 'Edit item',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _desc,
              autofocus: widget.line.description.isEmpty,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qty'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = parseAmount(v ?? '');
                      return (n == null || n <= 0) ? 'Must be > 0' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Unit price', prefixText: '${Constants.currency} '),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = parseAmount(v ?? '');
                      return (n == null || n < 0) ? 'Invalid amount' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _taxId,
              decoration: const InputDecoration(labelText: 'Tax'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('No tax')),
                for (final t in Constants.taxes)
                  DropdownMenuItem<String?>(value: t.id, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _taxId = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Amount: ${money(round2(qty * price))}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                FilledButton(onPressed: _done, child: Text(widget.isNew ? 'Add' : 'Update')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
