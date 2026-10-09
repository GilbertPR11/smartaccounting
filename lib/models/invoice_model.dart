import 'package:equatable/equatable.dart';

import '../utils/format.dart';
import 'tax_model.dart';

class InvoiceLine extends Equatable {
  const InvoiceLine({
    this.productId,
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    this.tax,
  });

  final String? productId;
  final String description;
  final double quantity;
  final double unitPrice;

  /// Snapshot of the tax at time of issue. Rates change (SST went 6% → 8%);
  /// an issued invoice must keep the rate it was issued with.
  final Tax? tax;

  double get subtotal => round2(quantity * unitPrice);
  double get taxAmount => round2(subtotal * (tax?.rate ?? 0));
  double get total => round2(subtotal + taxAmount);

  InvoiceLine copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
    Tax? tax,
    bool clearTax = false,
  }) =>
      InvoiceLine(
        productId: productId,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        tax: clearTax ? null : (tax ?? this.tax),
      );

  @override
  List<Object?> get props => [productId, description, quantity, unitPrice, tax];
}

enum InvoiceStatus { unpaid, partial, paid, overdue }

extension InvoiceStatusLabel on InvoiceStatus {
  String get label => switch (this) {
        InvoiceStatus.unpaid => 'Unpaid',
        InvoiceStatus.partial => 'Partial',
        InvoiceStatus.paid => 'Paid',
        InvoiceStatus.overdue => 'Overdue',
      };
}

class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.number,
    required this.customerId,
    required this.issueDate,
    required this.dueDate,
    required this.lines,
    this.notes = '',
    this.sourceTransactionId,
    this.amountPaid = 0,
    this.estimateId,
    this.recurringId,
  });

  final String id;
  final String number;
  final String customerId;
  final DateTime issueDate;
  final DateTime dueDate;
  final List<InvoiceLine> lines;
  final String notes;

  /// Set when this invoice was generated from an existing income transaction.
  final String? sourceTransactionId;
  final double amountPaid;

  /// Set when this invoice was converted from an estimate.
  final String? estimateId;

  /// Set when a recurring schedule issued this invoice.
  final String? recurringId;

  double get subtotal => sumSubtotal(lines);
  double get taxTotal => sumTax(lines);
  double get total => round2(subtotal + taxTotal);
  double get balance => round2(total - amountPaid);
  Map<String, double> get taxBreakdown => taxBreakdownOf(lines);

  InvoiceStatus statusOn(DateTime today) {
    if (balance <= 0.004) return InvoiceStatus.paid;
    if (dateOnly(dueDate).isBefore(dateOnly(today))) return InvoiceStatus.overdue;
    if (amountPaid > 0) return InvoiceStatus.partial;
    return InvoiceStatus.unpaid;
  }

  Invoice copyWith({double? amountPaid}) => Invoice(
        id: id,
        number: number,
        customerId: customerId,
        issueDate: issueDate,
        dueDate: dueDate,
        lines: lines,
        notes: notes,
        sourceTransactionId: sourceTransactionId,
        amountPaid: amountPaid ?? this.amountPaid,
        estimateId: estimateId,
        recurringId: recurringId,
      );

  @override
  List<Object?> get props => [
        id,
        number,
        customerId,
        issueDate,
        dueDate,
        lines,
        notes,
        sourceTransactionId,
        amountPaid,
        estimateId,
        recurringId,
      ];
}

// Line-list helpers, shared by Invoice and the (unsaved) invoice form.

double sumSubtotal(List<InvoiceLine> lines) =>
    round2(lines.fold<double>(0, (s, l) => s + l.subtotal));

double sumTax(List<InvoiceLine> lines) =>
    round2(lines.fold<double>(0, (s, l) => s + l.taxAmount));

double sumTotal(List<InvoiceLine> lines) => round2(sumSubtotal(lines) + sumTax(lines));

Map<String, double> taxBreakdownOf(List<InvoiceLine> lines) {
  final map = <String, double>{};
  for (final l in lines) {
    if (l.tax == null || l.taxAmount == 0) continue;
    map.update(l.tax!.label, (v) => round2(v + l.taxAmount),
        ifAbsent: () => l.taxAmount);
  }
  return map;
}
