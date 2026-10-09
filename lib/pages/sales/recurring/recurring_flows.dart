import 'package:flutter/material.dart';

import '../../../models/recurring_invoice_model.dart';
import '../../../routes/routes.dart';

/// Navigation flows for recurring invoices.

Future<void> openRecurringDetail(BuildContext context, String scheduleId) =>
    Navigator.pushNamed(context, PageRoutes.recurringDetail,
        arguments: RecurringDetailArgs(scheduleId));

/// New schedule (or edit [schedule]). A new one opens its page on save;
/// an edit returns to where you were.
Future<void> openRecurringForm(
  BuildContext context, {
  RecurringInvoice? schedule,
  String? customerId,
}) async {
  final saved = await Navigator.pushNamed<RecurringInvoice>(
    context,
    PageRoutes.recurringForm,
    arguments: RecurringFormArgs(schedule: schedule, customerId: customerId),
  );
  if (saved == null || !context.mounted) return;
  if (schedule == null) {
    Navigator.pushNamed(context, PageRoutes.recurringDetail,
        arguments: RecurringDetailArgs(saved.id, justSaved: true));
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Schedule updated')));
  }
}
