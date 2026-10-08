import 'package:flutter/material.dart';

import '../../../../config/constants.dart';
import '../../../../models/bill_model.dart';
import '../../../../theme/colors.dart';
import '../../../../utils/format.dart';

/// Bottom sheet to add or edit one bill line. Pops with the line.
Future<BillLine?> showBillLineEditor(
  BuildContext context, {
  BillLine? line,
  String? defaultCategory,
}) =>
    showModalBottomSheet<BillLine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BillLineEditor(line: line, defaultCategory: defaultCategory),
    );

class _BillLineEditor extends StatefulWidget {
  const _BillLineEditor({this.line, this.defaultCategory});

  final BillLine? line;
  final String? defaultCategory;

  @override
  State<_BillLineEditor> createState() => _BillLineEditorState();
}

class _BillLineEditorState extends State<_BillLineEditor> {
  final _key = GlobalKey<FormState>();
  late final _desc = TextEditingController(text: widget.line?.description ?? '');
  late final _amount = TextEditingController(
      text: widget.line == null ? '' : widget.line!.amount.toStringAsFixed(2));
  late String _category =
      widget.line?.category ?? widget.defaultCategory ?? Constants.expenseCategories.last;
  late String? _taxId = widget.line?.tax?.id;

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _done() {
    if (!_key.currentState!.validate()) return;
    Navigator.pop(
      context,
      BillLine(
        description: _desc.text.trim(),
        category: _category,
        amount: round2(parseAmount(_amount.text)!),
        tax: Constants.taxById(_taxId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.line == null;
    final categories = {...Constants.expenseCategories, _category}.toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          Space.lg, 0, Space.lg, MediaQuery.of(context).viewInsets.bottom + Space.lg),
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isNew ? 'Add line' : 'Edit line', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _desc,
              autofocus: isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What is it for?'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe the expense' : null,
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Amount before tax', prefixText: '${Constants.currency} '),
                    validator: (v) {
                      final n = parseAmount(v ?? '');
                      return (n == null || n <= 0) ? 'Enter an amount' : null;
                    },
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _taxId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tax'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No tax')),
                      for (final t in Constants.taxes)
                        DropdownMenuItem<String?>(value: t.id, child: Text(t.label)),
                    ],
                    onChanged: (v) => setState(() => _taxId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in categories) DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: Space.lg),
            FilledButton(onPressed: _done, child: Text(isNew ? 'Add line' : 'Update line')),
          ],
        ),
      ),
    );
  }
}
