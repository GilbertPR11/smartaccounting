import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/account/account_bloc.dart';
import '../../../bloc/bill/bill_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../bloc/transaction_form/transaction_form_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/section_header.dart';
import '../../../config/constants.dart';
import '../../../exception/app_exception.dart';
import '../../../models/account_model.dart';
import '../../../models/transaction_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../repository/transaction_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../purchases/purchase_flows.dart';
import '../../sales/invoice/new_invoice_flow.dart';
import '../../sales/widgets/document_form_parts.dart';

/// Add or edit a bank/cash transaction: category (or a split across
/// several), tags and notes. Pops with the saved transaction.
class TransactionFormPage extends StatelessWidget {
  const TransactionFormPage({super.key, this.transaction, this.type = TransactionType.expense});

  final BankTransaction? transaction;

  /// Money in or out, for a new transaction.
  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => TransactionFormBloc(repository: ctx.read<TransactionRepository>()),
      child: _TransactionFormView(transaction: transaction, type: type),
    );
  }
}

class _SplitDraft {
  _SplitDraft(this.category, double amount)
      : amount = TextEditingController(text: amount == 0 ? '' : amount.toStringAsFixed(2));

  String? category;
  final TextEditingController amount;
}

class _TransactionFormView extends StatefulWidget {
  const _TransactionFormView({this.transaction, required this.type});

  final BankTransaction? transaction;
  final TransactionType type;

  @override
  State<_TransactionFormView> createState() => _TransactionFormViewState();
}

class _TransactionFormViewState extends State<_TransactionFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late TransactionType _type;
  late DateTime _date;
  late String _account;
  String? _category;
  late List<_SplitDraft> _splits;
  late Set<String> _tagIds;

  BankTransaction? get _existing => widget.transaction;
  bool get _linked => _existing?.isLinked ?? false;
  bool get _moneyLocked => _linked || (_existing?.reconciled ?? false);
  bool get _splitting => _splits.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final t = _existing;
    final settings = context.read<SettingRepository>();
    _type = t?.type ?? widget.type;
    _date = t?.date ?? settings.today;
    _account = t?.account ?? settings.accounts.first;
    _category = (t == null || t.isSplit || t.category.isEmpty) ? null : t.category;
    _description = TextEditingController(text: t?.description ?? '');
    _amount = TextEditingController(text: t == null ? '' : t.amount.toStringAsFixed(2));
    _notes = TextEditingController(text: t?.notes ?? '');
    _splits = [for (final s in t?.splits ?? const <TransactionSplit>[]) _SplitDraft(s.category, s.amount)];
    _tagIds = {...?t?.tagIds};
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    for (final s in _splits) {
      s.amount.dispose();
    }
    super.dispose();
  }

  double get _amountValue => parseAmount(_amount.text) ?? 0;
  double get _splitSum =>
      round2(_splits.fold<double>(0, (s, p) => s + (parseAmount(p.amount.text) ?? 0)));

  void _startSplit() {
    setState(() {
      final total = _amountValue;
      _splits = [_SplitDraft(_category, total), _SplitDraft(null, 0)];
    });
  }

  void _stopSplit() {
    setState(() {
      _category ??= _splits.first.category;
      for (final s in _splits) {
        s.amount.dispose();
      }
      _splits = [];
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _newTag() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. KL office, Project Lim'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Direct repository call: the new tag is selected straight away.
    try {
      final tag = await context.read<TransactionRepository>().addTag(name.text);
      if (mounted) setState(() => _tagIds.add(tag.id));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: Text(_existing!.invoiceId != null || _existing!.billId != null
            ? 'The payment will also be taken off its ${_existing!.invoiceId != null ? 'invoice' : 'bill'}.'
            : 'This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<TransactionBloc>().add(DeleteTransaction(_existing!.id));
    Navigator.pop(context);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final t = _existing;
    context.read<TransactionFormBloc>().add(SubmitTransaction(
          transactionId: t?.id,
          type: _type,
          date: _date,
          description: _description.text,
          amount: _amountValue,
          account: _account,
          category: _category ?? '',
          splits: [
            for (final s in _splits)
              TransactionSplit(
                  category: s.category ?? '', amount: round2(parseAmount(s.amount.text) ?? 0)),
          ],
          tagIds: _tagIds.toList(),
          notes: _notes.text,
        ));
  }

  void _onFormState(BuildContext context, TransactionFormState state) {
    switch (state.status) {
      case FormSaveStatus.success:
        Navigator.pop(context, state.saved);
      case FormSaveStatus.failure:
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.error ?? 'Could not save.')));
      case FormSaveStatus.editing:
      case FormSaveStatus.submitting:
        break;
    }
  }

  /// Category choices for the current direction, plus the current value
  /// even if it's archived or unknown (so the dropdown can show it).
  List<DropdownMenuItem<String>> _categoryItems(AccountState accounts, String? current) {
    final list = _type == TransactionType.income
        ? accounts.incomeCategories
        : accounts.expenseCategories;
    final primary = _type == TransactionType.income ? AccountType.income : AccountType.expense;
    final names = <String>{};
    final items = <DropdownMenuItem<String>>[];
    for (final a in list) {
      if (!names.add(a.name)) continue;
      items.add(DropdownMenuItem(
        value: a.name,
        child: Text(a.type == primary ? a.name : '${a.name}  ·  ${a.type.label}',
            overflow: TextOverflow.ellipsis),
      ));
    }
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      items.insert(0, DropdownMenuItem(value: current, child: Text(current)));
    }
    return items;
  }

  Widget _linkBanner(BuildContext context) {
    final t = _existing!;
    final invoice = context.read<InvoiceBloc>().state.byId(t.invoiceId);
    final bill = context.read<BillBloc>().state.byId(t.billId);
    String text = 'Linked';
    VoidCallback? open;
    if (invoice != null) {
      text = 'Payment for ${invoice.number}';
      open = () => openInvoiceDetail(context, invoice.id);
    } else if (bill != null) {
      text = 'Payment of a bill${bill.number.isEmpty ? '' : ' (${bill.number})'}';
      open = () => openBillDetail(context, bill.id);
    } else if (t.receiptId != null) {
      text = 'Recorded from a receipt';
      open = () => Navigator.pushNamed(context, PageRoutes.receipt, arguments: t.receiptId);
    }
    return Card(
      child: ListTile(
        leading: IconBadge(Icons.link_rounded, color: Theme.of(context).colorScheme.primary),
        title: Text(text),
        subtitle: const Text('Its amount, date and category come from there. '
            'Here you can change the description, notes and tags.'),
        trailing: open == null ? null : TextButton(onPressed: open, child: const Text('Open')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountBloc>().state;
    final tags = context.watch<TransactionBloc>().state.tags;
    final submitting =
        context.watch<TransactionFormBloc>().state.status == FormSaveStatus.submitting;
    final t = _existing;
    final text = Theme.of(context).textTheme;
    final l = context.ledger;
    final remaining = round2(_amountValue - _splitSum);
    final moneyNames = {...accounts.money.map((a) => a.name), _account}.toList();

    return BlocListener<TransactionFormBloc, TransactionFormState>(
      listener: _onFormState,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t == null
              ? (_type == TransactionType.income ? 'Money in' : 'Money out')
              : 'Transaction'),
          actions: [
            if (t != null && !t.reconciled && t.receiptId == null)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
            child: FilledButton.icon(
              onPressed: submitting ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: CenteredListView(
            maxWidth: 720,
            children: [
              if (_linked) _linkBanner(context),
              if (!_linked && (t?.reconciled ?? false))
                Card(
                  child: ListTile(
                    leading: IconBadge(Icons.verified_outlined, color: l.moneyIn),
                    title: const Text('Reconciled'),
                    subtitle: const Text('Date, amount and account are locked. '
                        'You can still change the category, tags and notes.'),
                  ),
                ),
              SegmentedButton<TransactionType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: TransactionType.income,
                      icon: Icon(Icons.south_west_rounded),
                      label: Text('Money in')),
                  ButtonSegment(
                      value: TransactionType.expense,
                      icon: Icon(Icons.north_east_rounded),
                      label: Text('Money out')),
                ],
                selected: {_type},
                onSelectionChanged: _moneyLocked
                    ? null
                    : (s) => setState(() {
                          _type = s.first;
                          _category = null;
                          for (final p in _splits) {
                            p.category = null;
                          }
                        }),
              ),
              const SectionHeader('Details'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _description,
                        decoration: const InputDecoration(labelText: 'Description'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          Expanded(
                            child: DateField(
                                label: 'Date', date: _date, onTap: _moneyLocked ? null : _pickDate),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: TextFormField(
                              controller: _amount,
                              enabled: !_moneyLocked,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Amount', prefixText: '${Constants.currency} '),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final n = parseAmount(v ?? '');
                                return (n == null || n <= 0) ? 'Enter an amount' : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.md),
                      DropdownButtonFormField<String>(
                        value: _account,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText: _type == TransactionType.income ? 'Paid into' : 'Paid from'),
                        items: [
                          for (final name in moneyNames)
                            DropdownMenuItem(value: name, child: Text(name)),
                        ],
                        onChanged: _moneyLocked ? null : (v) => setState(() => _account = v ?? _account),
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader(
                'Category',
                action: _linked
                    ? null
                    : TextButton.icon(
                        onPressed: _splitting ? _stopSplit : _startSplit,
                        icon: Icon(_splitting ? Icons.merge_rounded : Icons.call_split_rounded,
                            size: 18),
                        label: Text(_splitting ? 'Don\'t split' : 'Split'),
                      ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: _linked
                      ? Text(t!.categoryLabel, style: text.bodyLarge)
                      : !_splitting
                          ? DropdownButtonFormField<String>(
                              value: _category,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Category'),
                              items: _categoryItems(accounts, _category),
                              onChanged: (v) => setState(() => _category = v),
                              validator: (v) => v == null ? 'Choose a category' : null,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < _splits.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: Space.md),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<String>(
                                            value: _splits[i].category,
                                            isExpanded: true,
                                            decoration: InputDecoration(labelText: 'Part ${i + 1}'),
                                            items: _categoryItems(accounts, _splits[i].category),
                                            onChanged: (v) => setState(() => _splits[i].category = v),
                                            validator: (v) => v == null ? 'Choose' : null,
                                          ),
                                        ),
                                        const SizedBox(width: Space.sm),
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _splits[i].amount,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(labelText: 'Amount'),
                                            onChanged: (_) => setState(() {}),
                                            validator: (v) {
                                              final n = parseAmount(v ?? '');
                                              return (n == null || n <= 0) ? 'Amount' : null;
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove part',
                                          icon: const Icon(Icons.close, size: 18),
                                          onPressed: _splits.length <= 2
                                              ? null
                                              : () => setState(() {
                                                    _splits.removeAt(i).amount.dispose();
                                                  }),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => setState(() => _splits.add(
                                          _SplitDraft(null, remaining > 0 ? remaining : 0))),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add part'),
                                    ),
                                    const Spacer(),
                                    if (remaining.abs() > 0.004) ...[
                                      Text(remaining > 0 ? 'Left to assign ' : 'Over by ',
                                          style: text.bodySmall?.copyWith(color: l.warning)),
                                      MoneyText(remaining.abs(), color: l.warning),
                                    ] else
                                      Text('Adds up', style: text.bodySmall?.copyWith(color: l.moneyIn)),
                                  ],
                                ),
                              ],
                            ),
                ),
              ),
              const SectionHeader('Tags'),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      label: Text(tag.name),
                      selected: _tagIds.contains(tag.id),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _tagIds.add(tag.id);
                        } else {
                          _tagIds.remove(tag.id);
                        }
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('New tag'),
                    onPressed: _newTag,
                  ),
                ],
              ),
              const SectionHeader('Notes'),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Only you see this'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
