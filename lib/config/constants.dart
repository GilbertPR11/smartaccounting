import '../models/tax_model.dart';

/// App-wide constants. No logic here.
class Constants {
  Constants._();

  static const String appName = 'SmartAccounting';
  static const String currency = 'RM';

  /// Payment-term presets offered on the invoice form (days → label).
  static const Map<int, String> paymentTerms = {
    0: 'On receipt',
    7: '7 days',
    14: '14 days',
    30: '30 days',
    60: '60 days',
  };

  /// Malaysian SST rates. Confirm against what your users charge.
  static const List<Tax> taxes = [
    Tax(id: 'sst8', name: 'Service Tax', rate: 0.08),
    Tax(id: 'sst6', name: 'Service Tax', rate: 0.06),
    Tax(id: 'sales10', name: 'Sales Tax', rate: 0.10),
  ];

  static Tax? taxById(String? id) {
    for (final t in taxes) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Accent colours offered in the invoice designer (ARGB).
  static const List<int> invoiceAccentColors = [
    0xFF0F766E, // teal
    0xFF1D4ED8, // blue
    0xFF4338CA, // indigo
    0xFF7E22CE, // purple
    0xFFBE123C, // rose
    0xFFC2410C, // orange
    0xFF15803D, // green
    0xFF334155, // slate
    0xFF111827, // black
  ];

  /// Uploaded logos are resized on pick; this is a safety cap.
  static const int maxLogoBytes = 2 * 1024 * 1024;

  /// Expense categories for bills and receipts.
  static const List<String> expenseCategories = [
    'Rent',
    'Utilities',
    'Software',
    'Office Supplies',
    'Professional Fees',
    'Travel',
    'Meals & Entertainment',
    'Inventory',
    'Marketing',
    'Repairs & Maintenance',
    'Other',
  ];

  /// Bill payment terms (days → label).
  static const Map<int, String> billTerms = {
    0: 'On receipt',
    14: '14 days',
    30: '30 days',
    60: '60 days',
  };

  /// Receipts are resized on pick; this is a safety cap.
  static const int maxReceiptBytes = 4 * 1024 * 1024;

  /// Income categories that are NOT sales and must never be invoiced.
  static const Set<String> nonSalesIncomeCategories = {
    'Owner Investment',
    'Loan',
    'Transfer',
  };
}
