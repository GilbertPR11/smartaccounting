import 'package:flutter/material.dart';

import '../models/estimate_model.dart';
import '../models/invoice_model.dart';
import '../models/recurring_invoice_model.dart';
import '../models/transaction_model.dart';
import '../pages/accounting/accounting_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../models/bill_model.dart';
import '../models/receipt_model.dart';
import '../pages/purchases/bill/bill_detail_page.dart';
import '../pages/purchases/bill/bill_form_page.dart';
import '../pages/purchases/bill/bill_list_page.dart';
import '../pages/purchases/purchases_page.dart';
import '../pages/purchases/receipt/receipt_list_page.dart';
import '../pages/purchases/receipt/receipt_page.dart';
import '../pages/purchases/vendor/vendor_page.dart';
import '../pages/sales/customer/customer_detail_page.dart';
import '../pages/sales/customer/customer_page.dart';
import '../pages/sales/estimate/estimate_detail_page.dart';
import '../pages/sales/estimate/estimate_form_page.dart';
import '../pages/sales/estimate/estimate_list_page.dart';
import '../pages/sales/invoice/invoice_detail_page.dart';
import '../pages/sales/invoice/invoice_form_page.dart';
import '../pages/sales/invoice/invoice_list_page.dart';
import '../pages/sales/invoice/invoice_template_page.dart';
import '../pages/sales/invoice/transaction_picker_page.dart';
import '../pages/sales/product/product_page.dart';
import '../pages/sales/recurring/recurring_detail_page.dart';
import '../pages/sales/recurring/recurring_form_page.dart';
import '../pages/sales/recurring/recurring_list_page.dart';
import '../pages/sales/sales_page.dart';
import '../pages/sales/statement/statement_page.dart';

/// Every page has a name here (smartpos: `Routes/routes.dart`).
/// Names have no leading '/' so a tab's Navigator can start on one directly.
class PageRoutes {
  PageRoutes._();

  // Tab roots.
  static const String dashboard = 'dashboard';
  static const String sales = 'sales';
  static const String purchases = 'purchases';
  static const String accounting = 'accounting';

  // Sales & Payments.
  static const String invoices = 'sales_invoices';
  static const String invoiceDetail = 'sales_invoice_detail'; // args: InvoiceDetailArgs
  static const String invoiceForm = 'sales_invoice_form'; // args: InvoiceFormArgs?
  static const String transactionPicker = 'sales_transaction_picker';
  static const String invoiceTemplate = 'sales_invoice_template';
  static const String customers = 'sales_customers';
  static const String customerDetail = 'sales_customer_detail'; // args: String customerId
  static const String products = 'sales_products';
  static const String estimates = 'sales_estimates';
  static const String estimateDetail = 'sales_estimate_detail'; // args: EstimateDetailArgs
  static const String estimateForm = 'sales_estimate_form'; // args: EstimateFormArgs?
  static const String recurring = 'sales_recurring';
  static const String recurringDetail = 'sales_recurring_detail'; // args: RecurringDetailArgs
  static const String recurringForm = 'sales_recurring_form'; // args: RecurringFormArgs?
  static const String statements = 'sales_statements'; // args: StatementArgs?

  // Purchases.
  static const String bills = 'purchases_bills'; // args: BillListArgs?
  static const String billDetail = 'purchases_bill_detail'; // args: BillDetailArgs
  static const String billForm = 'purchases_bill_form'; // args: BillFormArgs?
  static const String vendors = 'purchases_vendors';
  static const String receipts = 'purchases_receipts';
  static const String receipt = 'purchases_receipt'; // args: String receiptId
}

class BillListArgs {
  const BillListArgs({this.vendorId});

  /// Show only this vendor's bills.
  final String? vendorId;
}

class BillDetailArgs {
  const BillDetailArgs(this.billId, {this.justCreated = false});

  final String billId;
  final bool justCreated;
}

class BillFormArgs {
  const BillFormArgs({this.vendorId, this.receiptId, this.receipt});

  final String? vendorId;

  /// Create the bill from this receipt photo (and attach it).
  final String? receiptId;

  /// The receipt as currently edited (may be newer than the saved copy).
  final Receipt? receipt;
}

class InvoiceDetailArgs {
  const InvoiceDetailArgs(this.invoiceId, {this.justCreated = false});

  final String invoiceId;
  final bool justCreated;
}

class InvoiceFormArgs {
  const InvoiceFormArgs({this.source, this.estimate, this.customerId});

  /// Pre-fill from this income transaction.
  final BankTransaction? source;

  /// Convert this estimate.
  final Estimate? estimate;

  /// Pre-select this customer.
  final String? customerId;
}

class EstimateDetailArgs {
  const EstimateDetailArgs(this.estimateId, {this.justSaved = false});

  final String estimateId;
  final bool justSaved;
}

class EstimateFormArgs {
  const EstimateFormArgs({this.estimate, this.customerId});

  /// Edit this estimate (null = new).
  final Estimate? estimate;

  /// Pre-select this customer on a new estimate.
  final String? customerId;
}

class RecurringDetailArgs {
  const RecurringDetailArgs(this.scheduleId, {this.justSaved = false});

  final String scheduleId;
  final bool justSaved;
}

class RecurringFormArgs {
  const RecurringFormArgs({this.schedule, this.customerId});

  /// Edit this schedule (null = new).
  final RecurringInvoice? schedule;

  /// Pre-select this customer on a new schedule.
  final String? customerId;
}

class StatementArgs {
  const StatementArgs({this.customerId});

  /// Open the statement for this customer.
  final String? customerId;
}

class AppRouter {
  AppRouter._();

  /// Used by the root MaterialApp (phones) and by every tab Navigator
  /// (tablets / desktop), so a page is reachable the same way everywhere.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    Widget page;
    switch (settings.name) {
      case PageRoutes.dashboard:
        page = const DashboardPage();
      case PageRoutes.sales:
        page = const SalesPage();
      case PageRoutes.purchases:
        page = const PurchasesPage();
      case PageRoutes.accounting:
        page = const AccountingPage();
      case PageRoutes.invoices:
        page = const InvoiceListPage();
      case PageRoutes.invoiceDetail:
        final detailArgs = args as InvoiceDetailArgs;
        page = InvoiceDetailPage(
            invoiceId: detailArgs.invoiceId, justCreated: detailArgs.justCreated);
      case PageRoutes.invoiceForm:
        // Typed so `pushNamed<Invoice>` gets the created invoice back.
        final formArgs = args is InvoiceFormArgs ? args : const InvoiceFormArgs();
        return MaterialPageRoute<Invoice>(
          settings: settings,
          builder: (_) => InvoiceFormPage(
              source: formArgs.source,
              estimate: formArgs.estimate,
              customerId: formArgs.customerId),
        );
      case PageRoutes.transactionPicker:
        page = const TransactionPickerPage();
      case PageRoutes.invoiceTemplate:
        page = const InvoiceTemplatePage();
      case PageRoutes.bills:
        page = BillListPage(vendorId: args is BillListArgs ? args.vendorId : null);
      case PageRoutes.billDetail:
        final billArgs = args as BillDetailArgs;
        page = BillDetailPage(billId: billArgs.billId, justCreated: billArgs.justCreated);
      case PageRoutes.billForm:
        final billFormArgs = args is BillFormArgs ? args : const BillFormArgs();
        return MaterialPageRoute<Bill>(
          settings: settings,
          builder: (_) => BillFormPage(
              vendorId: billFormArgs.vendorId,
              receiptId: billFormArgs.receiptId,
              receipt: billFormArgs.receipt),
        );
      case PageRoutes.vendors:
        page = const VendorPage();
      case PageRoutes.receipts:
        page = const ReceiptListPage();
      case PageRoutes.receipt:
        page = ReceiptPage(receiptId: args as String);
      case PageRoutes.customers:
        page = const CustomerPage();
      case PageRoutes.customerDetail:
        page = CustomerDetailPage(customerId: args as String);
      case PageRoutes.estimates:
        page = const EstimateListPage();
      case PageRoutes.estimateDetail:
        final estimateArgs = args as EstimateDetailArgs;
        page = EstimateDetailPage(
            estimateId: estimateArgs.estimateId, justSaved: estimateArgs.justSaved);
      case PageRoutes.estimateForm:
        final estimateFormArgs = args is EstimateFormArgs ? args : const EstimateFormArgs();
        return MaterialPageRoute<Estimate>(
          settings: settings,
          builder: (_) => EstimateFormPage(
              estimate: estimateFormArgs.estimate, customerId: estimateFormArgs.customerId),
        );
      case PageRoutes.recurring:
        page = const RecurringListPage();
      case PageRoutes.recurringDetail:
        final recurringArgs = args as RecurringDetailArgs;
        page = RecurringDetailPage(
            scheduleId: recurringArgs.scheduleId, justSaved: recurringArgs.justSaved);
      case PageRoutes.recurringForm:
        final recurringFormArgs = args is RecurringFormArgs ? args : const RecurringFormArgs();
        return MaterialPageRoute<RecurringInvoice>(
          settings: settings,
          builder: (_) => RecurringFormPage(
              schedule: recurringFormArgs.schedule, customerId: recurringFormArgs.customerId),
        );
      case PageRoutes.statements:
        page = StatementPage(customerId: args is StatementArgs ? args.customerId : null);
      case PageRoutes.products:
        page = const ProductPage();
      default:
        page = Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Page not found: ${settings.name}')),
        );
    }
    return MaterialPageRoute<dynamic>(settings: settings, builder: (_) => page);
  }
}
