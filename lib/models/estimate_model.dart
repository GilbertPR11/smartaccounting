import 'package:equatable/equatable.dart';

import '../utils/format.dart';
import 'invoice_model.dart';

/// What the customer said. Null means no answer yet.
enum EstimateDecision { accepted, declined }

enum EstimateStatus { pending, accepted, declined, expired, converted }

extension EstimateStatusLabel on EstimateStatus {
  String get label => switch (this) {
        EstimateStatus.pending => 'Awaiting reply',
        EstimateStatus.accepted => 'Accepted',
        EstimateStatus.declined => 'Declined',
        EstimateStatus.expired => 'Expired',
        EstimateStatus.converted => 'Invoiced',
      };
}

/// A quote: same lines as an invoice, but no money is owed until it is
/// converted. It never touches transactions or what customers owe you.
class Estimate extends Equatable {
  const Estimate({
    required this.id,
    required this.number,
    required this.customerId,
    required this.issueDate,
    required this.expiryDate,
    required this.lines,
    this.notes = '',
    this.decision,
    this.invoiceId,
  });

  final String id;
  final String number;
  final String customerId;
  final DateTime issueDate;

  /// Last day the prices are valid.
  final DateTime expiryDate;
  final List<InvoiceLine> lines;
  final String notes;
  final EstimateDecision? decision;

  /// The invoice this estimate became. Once set, the estimate is read-only.
  final String? invoiceId;

  double get subtotal => sumSubtotal(lines);
  double get taxTotal => sumTax(lines);
  double get total => round2(subtotal + taxTotal);

  bool get isConverted => invoiceId != null;

  /// A converted or declined estimate is closed; an accepted one still
  /// waits to be invoiced, even after it expires.
  EstimateStatus statusOn(DateTime today) {
    if (invoiceId != null) return EstimateStatus.converted;
    if (decision == EstimateDecision.declined) return EstimateStatus.declined;
    if (decision == EstimateDecision.accepted) return EstimateStatus.accepted;
    if (dateOnly(expiryDate).isBefore(dateOnly(today))) return EstimateStatus.expired;
    return EstimateStatus.pending;
  }

  /// The estimate in the shape the document renderer understands.
  /// The due date carries the expiry date; nothing is paid.
  Invoice asDocument() => Invoice(
        id: id,
        number: number,
        customerId: customerId,
        issueDate: issueDate,
        dueDate: expiryDate,
        lines: lines,
        notes: notes,
      );

  Estimate copyWith({
    String? customerId,
    DateTime? issueDate,
    DateTime? expiryDate,
    List<InvoiceLine>? lines,
    String? notes,
    EstimateDecision? decision,
    bool clearDecision = false,
    String? invoiceId,
  }) =>
      Estimate(
        id: id,
        number: number,
        customerId: customerId ?? this.customerId,
        issueDate: issueDate ?? this.issueDate,
        expiryDate: expiryDate ?? this.expiryDate,
        lines: lines ?? this.lines,
        notes: notes ?? this.notes,
        decision: clearDecision ? null : (decision ?? this.decision),
        invoiceId: invoiceId ?? this.invoiceId,
      );

  @override
  List<Object?> get props =>
      [id, number, customerId, issueDate, expiryDate, lines, notes, decision, invoiceId];
}
