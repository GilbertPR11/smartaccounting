import 'package:equatable/equatable.dart';

import '../utils/format.dart';
import 'invoice_model.dart';
import 'tax_model.dart';

/// One expense line on a bill. Bills are entered from a vendor's paper, so a
/// line is just "what, which category, how much" rather than qty × price.
class BillLine extends Equatable {
  const BillLine({
    required this.description,
    required this.category,
    required this.amount,
    this.tax,
  });

  final String description;
  final String category;

  /// Amount before tax.
  final double amount;
  final Tax? tax;

  double get taxAmount => round2(amount * (tax?.rate ?? 0));
  double get total => round2(amount + taxAmount);

  @override
  List<Object?> get props => [description, category, amount, tax];
}

/// Money you owe a vendor. Status reuses [InvoiceStatus] — the meaning
/// (unpaid / partial / paid / overdue) is the same from either side.
class Bill extends Equatable {
  const Bill({
    required this.id,
    required this.vendorId,
    required this.number,
    required this.issueDate,
    required this.dueDate,
    required this.lines,
    this.notes = '',
    this.amountPaid = 0,
  });

  final String id;
  final String vendorId;

  /// The vendor's own bill / invoice number, as printed on their document.
  final String number;
  final DateTime issueDate;
  final DateTime dueDate;
  final List<BillLine> lines;
  final String notes;
  final double amountPaid;

  double get subtotal => round2(lines.fold<double>(0, (s, l) => s + l.amount));
  double get taxTotal => round2(lines.fold<double>(0, (s, l) => s + l.taxAmount));
  double get total => round2(subtotal + taxTotal);
  double get balance => round2(total - amountPaid);

  /// Main category (largest line) — used for the payment transaction.
  String get mainCategory {
    if (lines.isEmpty) return 'Other';
    return (lines.toList()..sort((a, b) => b.total.compareTo(a.total))).first.category;
  }

  InvoiceStatus statusOn(DateTime today) {
    if (balance <= 0.004) return InvoiceStatus.paid;
    if (dateOnly(dueDate).isBefore(dateOnly(today))) return InvoiceStatus.overdue;
    if (amountPaid > 0) return InvoiceStatus.partial;
    return InvoiceStatus.unpaid;
  }

  Bill copyWith({double? amountPaid}) => Bill(
        id: id,
        vendorId: vendorId,
        number: number,
        issueDate: issueDate,
        dueDate: dueDate,
        lines: lines,
        notes: notes,
        amountPaid: amountPaid ?? this.amountPaid,
      );

  @override
  List<Object?> get props =>
      [id, vendorId, number, issueDate, dueDate, lines, notes, amountPaid];
}
