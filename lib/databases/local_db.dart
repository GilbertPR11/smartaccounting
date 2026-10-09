import 'dart:async';

import '../models/bill_model.dart';
import '../models/business_profile_model.dart';
import '../models/customer_model.dart';
import '../models/estimate_model.dart';
import '../models/invoice_model.dart';
import '../models/invoice_template_model.dart';
import '../models/product_model.dart';
import '../models/receipt_model.dart';
import '../models/recurring_invoice_model.dart';
import '../models/transaction_model.dart';
import '../models/vendor_model.dart';
import '../utils/format.dart';
import 'seed_data.dart';

enum DbTable {
  customers,
  products,
  transactions,
  invoices,
  settings,
  vendors,
  bills,
  receipts,
  estimates,
  recurring,
}

/// In-memory stand-in for the local database (smartpos: `Databases/db.dart`).
///
/// It deliberately has the shape a sqflite `Db` would have — tables, ids,
/// a [transaction] wrapper and a change stream — so replacing it with real
/// sqflite later touches this folder and the repositories, nothing above.
///
/// Rule: only repositories talk to [LocalDb]. Blocs and pages never do.
class LocalDb {
  LocalDb({DateTime? today, bool seed = true})
      : today = dateOnly(today ?? DateTime.now()) {
    if (seed) SeedData.apply(this);
  }

  /// "Today" for due-date / overdue logic. Injected so tests are deterministic.
  final DateTime today;

  // Settings (single row).
  BusinessProfile profile = const BusinessProfile(name: 'My Business');
  InvoiceTemplate invoiceTemplate = const InvoiceTemplate();
  double openingBalance = 15000;
  final List<String> accounts = ['Maybank Current', 'Cash on Hand'];

  // Tables. Maps keep insertion order.
  final Map<String, Customer> customers = {};
  final Map<String, Product> products = {};
  final Map<String, BankTransaction> transactions = {};
  final Map<String, Invoice> invoices = {};
  final Map<String, Vendor> vendors = {};
  final Map<String, Bill> bills = {};
  final Map<String, Receipt> receipts = {};
  final Map<String, Estimate> estimates = {};
  final Map<String, RecurringInvoice> recurring = {};

  int _seq = 1;
  int invoiceCounter = 1;
  int estimateCounter = 1;

  String newId(String prefix) => '$prefix${_seq++}';

  final _changes = StreamController<DbTable>.broadcast();

  /// Emits the table name after every committed write.
  Stream<DbTable> get changes => _changes.stream;

  /// Runs [body] as one unit and announces the tables it touched once it's
  /// done. Mirrors `db.transaction(...)` in sqflite.
  T transaction<T>(Set<DbTable> touches, T Function() body) {
    final result = body();
    for (final t in touches) {
      if (!_changes.isClosed) _changes.add(t);
    }
    return result;
  }

  Future<void> close() => _changes.close();
}
