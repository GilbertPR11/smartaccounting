part of 'estimate_form_bloc.dart';

sealed class EstimateFormEvent extends Equatable {
  const EstimateFormEvent();

  @override
  List<Object?> get props => [];
}

class SubmitEstimate extends EstimateFormEvent {
  const SubmitEstimate({
    this.estimateId,
    required this.customerId,
    required this.number,
    required this.issueDate,
    required this.expiryDate,
    required this.lines,
    this.notes = '',
  });

  /// Null to create; set to update that estimate.
  final String? estimateId;
  final String customerId;
  final String number;
  final DateTime issueDate;
  final DateTime expiryDate;
  final List<InvoiceLine> lines;
  final String notes;

  @override
  List<Object?> get props =>
      [estimateId, customerId, number, issueDate, expiryDate, lines, notes];
}
