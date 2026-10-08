part of 'bill_form_bloc.dart';

sealed class BillFormEvent extends Equatable {
  const BillFormEvent();

  @override
  List<Object?> get props => [];
}

class SubmitBill extends BillFormEvent {
  const SubmitBill({
    required this.vendorId,
    required this.number,
    required this.issueDate,
    required this.dueDate,
    required this.lines,
    this.notes = '',
    this.receiptId,
  });

  final String vendorId;
  final String number;
  final DateTime issueDate;
  final DateTime dueDate;
  final List<BillLine> lines;
  final String notes;
  final String? receiptId;

  @override
  List<Object?> get props => [vendorId, number, issueDate, dueDate, lines, notes, receiptId];
}
