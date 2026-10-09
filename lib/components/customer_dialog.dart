import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../exception/app_exception.dart';
import '../models/customer_model.dart';
import '../repository/customer_repository.dart';

/// "New customer" dialog. Returns the created customer, or null.
///
/// Calls the repository directly (not a Bloc event) because callers need the
/// new record back — e.g. the invoice form selects it straight away.
/// CustomerBloc picks the change up through the repository's change stream.
Future<Customer?> showAddCustomerDialog(BuildContext context) async {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New customer'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (ok != true || !context.mounted) return null;
  try {
    return await context.read<CustomerRepository>().addCustomer(
          name: name.text,
          email: email.text,
          phone: phone.text,
          address: address.text,
        );
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return null;
  }
}
