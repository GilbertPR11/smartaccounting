import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum ReceiptStatus { toReview, recorded, attached }

extension ReceiptStatusLabel on ReceiptStatus {
  String get label => switch (this) {
        ReceiptStatus.toReview => 'To review',
        ReceiptStatus.recorded => 'Recorded',
        ReceiptStatus.attached => 'Attached to bill',
      };
}

/// A photo of something already paid for, plus what we know about it.
///
/// Snapped first, filled in later: everything except the image is optional
/// until the receipt is recorded as an expense or attached to a bill.
class Receipt extends Equatable {
  const Receipt({
    required this.id,
    required this.imageBytes,
    required this.addedOn,
    this.vendorId,
    this.merchant = '',
    this.date,
    this.amount,
    this.category,
    this.account,
    this.note = '',
    this.status = ReceiptStatus.toReview,
    this.transactionId,
    this.billId,
  });

  final String id;

  /// The photo. Not part of equality (it never changes for a given id).
  final Uint8List imageBytes;
  final DateTime addedOn;

  /// A known vendor, or…
  final String? vendorId;

  /// …free-text merchant name for one-off shops ("Petronas Bangsar").
  final String merchant;
  final DateTime? date;
  final double? amount;
  final String? category;

  /// Which account it was paid from.
  final String? account;
  final String note;
  final ReceiptStatus status;

  /// Set when recorded as an expense.
  final String? transactionId;

  /// Set when attached to a bill.
  final String? billId;

  bool get isDone => status != ReceiptStatus.toReview;

  Receipt copyWith({
    String? vendorId,
    bool clearVendor = false,
    String? merchant,
    DateTime? date,
    double? amount,
    String? category,
    String? account,
    String? note,
    ReceiptStatus? status,
    String? transactionId,
    String? billId,
  }) =>
      Receipt(
        id: id,
        imageBytes: imageBytes,
        addedOn: addedOn,
        vendorId: clearVendor ? null : (vendorId ?? this.vendorId),
        merchant: merchant ?? this.merchant,
        date: date ?? this.date,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        account: account ?? this.account,
        note: note ?? this.note,
        status: status ?? this.status,
        transactionId: transactionId ?? this.transactionId,
        billId: billId ?? this.billId,
      );

  @override
  List<Object?> get props => [
        id,
        addedOn,
        vendorId,
        merchant,
        date,
        amount,
        category,
        account,
        note,
        status,
        transactionId,
        billId,
      ];
}
