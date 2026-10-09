import 'package:flutter/material.dart';

import '../../../models/estimate_model.dart';
import '../../../models/invoice_model.dart';
import '../../../routes/routes.dart';

/// Navigation flows for estimates, shared by every button that starts one.

Future<void> openEstimateDetail(BuildContext context, String estimateId) =>
    Navigator.pushNamed(context, PageRoutes.estimateDetail,
        arguments: EstimateDetailArgs(estimateId));

/// New estimate (or edit [estimate]). A new one opens its page on save;
/// an edit returns to where you were.
Future<void> openEstimateForm(
  BuildContext context, {
  Estimate? estimate,
  String? customerId,
}) async {
  final saved = await Navigator.pushNamed<Estimate>(
    context,
    PageRoutes.estimateForm,
    arguments: EstimateFormArgs(estimate: estimate, customerId: customerId),
  );
  if (saved == null || !context.mounted) return;
  if (estimate == null) {
    Navigator.pushNamed(context, PageRoutes.estimateDetail,
        arguments: EstimateDetailArgs(saved.id, justSaved: true));
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${saved.number} updated')));
  }
}

/// Opens the invoice form pre-filled from [estimate]; on save, shows the
/// new invoice. The estimate is marked as invoiced by the same save.
Future<void> convertEstimateToInvoice(BuildContext context, Estimate estimate) async {
  final invoice = await Navigator.pushNamed<Invoice>(
    context,
    PageRoutes.invoiceForm,
    arguments: InvoiceFormArgs(estimate: estimate),
  );
  if (invoice == null || !context.mounted) return;
  Navigator.pushNamed(context, PageRoutes.invoiceDetail,
      arguments: InvoiceDetailArgs(invoice.id, justCreated: true));
}
