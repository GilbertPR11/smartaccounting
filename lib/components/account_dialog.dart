import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../exception/app_exception.dart';
import '../models/account_model.dart';
import '../repository/account_repository.dart';
import '../theme/colors.dart';

/// Add an account (or edit [account]). Returns the saved account, or null.
///
/// Calls the repository directly (not a Bloc event) because the caller may
/// need the new account straight away (e.g. to select it in a picker).
/// AccountBloc picks the change up through the repository's change stream.
Future<Account?> showAccountDialog(
  BuildContext context, {
  Account? account,
  AccountType type = AccountType.expense,
}) async {
  final name = TextEditingController(text: account?.name ?? '');
  final code = TextEditingController(text: account?.code ?? '');
  final description = TextEditingController(text: account?.description ?? '');
  var chosenType = account?.type ?? type;
  var isMoney = account?.isMoney ?? false;
  final formKey = GlobalKey<FormState>();
  String? error;
  Account? saved;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(account == null ? 'New account' : 'Edit account'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<AccountType>(
                  value: chosenType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in AccountType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  // The type of an existing account is fixed: its history
                  // was posted on that side of the books.
                  onChanged: account != null
                      ? null
                      : (v) => setLocal(() {
                            chosenType = v ?? chosenType;
                            if (chosenType != AccountType.asset) isMoney = false;
                          }),
                ),
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: name,
                  autofocus: account == null,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Code', helperText: 'Optional, e.g. 5120'),
                ),
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                if (chosenType == AccountType.asset && account == null) ...[
                  const SizedBox(height: Space.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bank or cash account'),
                    subtitle: const Text('Transactions can be paid from and into it'),
                    value: isMoney,
                    onChanged: (v) => setLocal(() => isMoney = v),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = ctx.read<AccountRepository>();
              try {
                saved = account == null
                    ? await repo.addAccount(
                        name: name.text,
                        type: chosenType,
                        code: code.text,
                        description: description.text,
                        isMoney: isMoney,
                      )
                    : await repo.updateAccount(
                        id: account.id,
                        name: name.text,
                        code: code.text,
                        description: description.text,
                      );
                if (ctx.mounted) Navigator.pop(ctx);
              } on AppException catch (e) {
                if (ctx.mounted) setLocal(() => error = e.message);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  return saved;
}
