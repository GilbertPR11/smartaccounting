import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/product/product_bloc.dart';
import '../../../components/customer_dialog.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/section_header.dart';
import '../../../config/constants.dart';
import '../../../config/layout.dart';
import '../../../models/customer_model.dart';
import '../../../models/invoice_model.dart';
import '../../../models/product_model.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';

// Form parts shared by invoices, estimates and recurring invoices: they all
// have a customer, line items and totals. Each form page adds its own
// "Details" section (dates, numbers, schedule).

// ---------------------------------------------------------------- customer

/// Bottom sheet to choose a customer, with "Add new customer" on top.
/// Returns the chosen customer's id, or null if dismissed.
Future<String?> pickCustomer(BuildContext context, {String? selectedId}) async {
  final customers = context.read<CustomerBloc>().state.customers;
  final result = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (ctx, controller) => ListView(
        controller: controller,
        children: [
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Add new customer'),
            onTap: () => Navigator.pop(ctx, '__new__'),
          ),
          const Divider(height: 1),
          for (final c in customers)
            ListTile(
              leading: InitialsAvatar(c.name),
              title: Text(c.name),
              subtitle: c.email.isEmpty ? null : Text(c.email),
              trailing: c.id == selectedId ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, c.id),
            ),
        ],
      ),
    ),
  );
  if (result != '__new__' || !context.mounted) return result;
  final created = await showAddCustomerDialog(context);
  return created?.id;
}

/// "Customer" section: the chosen customer, or a prompt to choose one.
class CustomerSection extends StatelessWidget {
  const CustomerSection({
    super.key,
    required this.customer,
    required this.onTap,
    this.showError = false,
  });

  final Customer? customer;
  final VoidCallback onTap;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = customer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Customer'),
        Card(
          shape: showError
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.container),
                  side: BorderSide(color: scheme.error))
              : null,
          child: ListTile(
            leading: c == null ? const Icon(Icons.person_outline) : InitialsAvatar(c.name),
            title: Text(c?.name ?? 'Choose a customer'),
            subtitle: showError
                ? Text('Customer is required', style: TextStyle(color: scheme.error))
                : (c != null && c.email.isNotEmpty ? Text(c.email) : null),
            trailing: const Icon(Icons.expand_more),
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ items

/// "Items" section with add / edit / remove. Lines are immutable: every
/// change hands a NEW list to [onChanged].
class LineItemsSection extends StatelessWidget {
  const LineItemsSection({
    super.key,
    required this.lines,
    required this.onChanged,
    this.showError = false,
  });

  final List<InvoiceLine> lines;
  final ValueChanged<List<InvoiceLine>> onChanged;
  final bool showError;

  Future<InvoiceLine?> _edit(BuildContext context, InvoiceLine line, {bool isNew = false}) =>
      showModalBottomSheet<InvoiceLine>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => LineEditorSheet(line: line, isNew: isNew),
      );

  Future<void> _add(BuildContext context) async {
    final products = context.read<ProductBloc>().state.sold;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Custom item'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
            const Divider(height: 1),
            for (final p in products)
              ListTile(
                title: Text(p.name),
                subtitle: Text(p.tax == null ? 'No tax' : p.tax!.label),
                trailing: MoneyText(p.price),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final draft = choice is Product
        ? InvoiceLine(
            productId: choice.id,
            description: choice.name,
            unitPrice: choice.price,
            tax: choice.tax)
        : const InvoiceLine(description: '', unitPrice: 0);
    final line = await _edit(context, draft, isNew: true);
    if (line != null) onChanged([...lines, line]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Items',
          action: TextButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          shape: showError
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.container),
                  side: BorderSide(color: scheme.error))
              : null,
          child: Column(
            children: [
              if (lines.isEmpty)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Add your first item'),
                  subtitle: showError
                      ? Text('At least one item is required',
                          style: TextStyle(color: scheme.error))
                      : null,
                  onTap: () => _add(context),
                ),
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) Divider(height: 1, color: l.hairline),
                LineItemTile(
                  line: lines[i],
                  onTap: () async {
                    final edited = await _edit(context, lines[i]);
                    if (edited != null) onChanged([...lines]..[i] = edited);
                  },
                  onDelete: () => onChanged([...lines]..removeAt(i)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- totals

/// "Summary" section: subtotal, each tax, total; [footer] goes underneath.
class TotalsSection extends StatelessWidget {
  const TotalsSection({super.key, required this.lines, this.footer, this.totalLabel = 'Total'});

  final List<InvoiceLine> lines;
  final Widget? footer;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final f = footer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Summary'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              children: [
                TotalRow('Subtotal', money(sumSubtotal(lines))),
                for (final e in taxBreakdownOf(lines).entries) TotalRow(e.key, money(e.value)),
                const Divider(height: 20),
                TotalRow(totalLabel, money(sumTotal(lines)), bold: true),
                if (f != null) ...[const SizedBox(height: Space.md), f],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Notes" section.
class NotesSection extends StatelessWidget {
  const NotesSection({super.key, required this.controller, this.hint});

  final TextEditingController controller;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Notes'),
        TextFormField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint ?? 'Shown at the bottom of the document'),
        ),
      ],
    );
  }
}

/// Sticky bottom bar: the running total and the save button.
class FormSaveBar extends StatelessWidget {
  const FormSaveBar({
    super.key,
    required this.total,
    required this.label,
    required this.onSave,
    this.caption = 'Total',
  });

  final double total;
  final String label;
  final String caption;

  /// Null while saving (disables the button).
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption, style: Theme.of(context).textTheme.bodySmall),
                  MoneyText(total, emphasis: MoneyEmphasis.large),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.check),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays the form sections out in one column, or two once there's room:
/// [left] (customer, details, notes) beside [right] (items, summary).
class FormColumns extends StatelessWidget {
  const FormColumns({super.key, required this.left, required this.right, this.top = const []});

  final List<Widget> top;
  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 840;
      final pad = sidePadding(c.maxWidth, maxWidth: wide ? 1200 : 720);
      final padding = EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.xl);
      if (!wide) {
        return ListView(padding: padding, children: [...top, ...left, ...right]);
      }
      return ListView(
        padding: padding,
        children: [
          ...top,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
              ),
              const SizedBox(width: Space.xl),
              Expanded(
                flex: 6,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
              ),
            ],
          ),
        ],
      );
    });
  }
}

// ------------------------------------------------------------ small parts

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
