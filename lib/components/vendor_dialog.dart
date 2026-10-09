import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/constants.dart';
import '../exception/app_exception.dart';
import '../models/vendor_model.dart';
import '../repository/vendor_repository.dart';
import '../theme/colors.dart';

/// "New vendor" dialog. Returns the created vendor, or null.
/// Calls the repository directly because callers (the bill form) need the
/// new vendor back to select it; VendorBloc refreshes via the change stream.
Future<Vendor?> showAddVendorDialog(BuildContext context, {String initialName = ''}) async {
  final name = TextEditingController(text: initialName);
  final email = TextEditingController();
  final phone = TextEditingController();
  String? category;
  final formKey = GlobalKey<FormState>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('New vendor'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: Space.md),
                  DropdownButtonFormField<String?>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Usual category',
                      helperText: 'Pre-fills new bills from this vendor',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None')),
                      for (final c in Constants.expenseCategories)
                        DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setLocal(() => category = v),
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email (optional)'),
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone (optional)'),
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
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Add vendor'),
          ),
        ],
      ),
    ),
  );

  if (ok != true || !context.mounted) return null;
  try {
    return await context.read<VendorRepository>().addVendor(
          name: name.text,
          email: email.text,
          phone: phone.text,
          defaultCategory: category,
        );
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return null;
  }
}
