part of 'estimate_bloc.dart';

class EstimateState extends Equatable {
  const EstimateState({
    this.status = LoadStatus.initial,
    this.estimates = const [],
    this.nextNumber = '',
    this.error,
  });

  final LoadStatus status;

  /// Newest first.
  final List<Estimate> estimates;

  /// Suggested number for the next estimate.
  final String nextNumber;
  final String? error;

  Estimate? byId(String? id) {
    for (final e in estimates) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<Estimate> forCustomer(String customerId) =>
      estimates.where((e) => e.customerId == customerId).toList();

  bool numberExists(String number, {String? exceptId}) => estimates.any((e) =>
      e.id != exceptId && e.number.toLowerCase() == number.trim().toLowerCase());

  EstimateState copyWith({
    LoadStatus? status,
    List<Estimate>? estimates,
    String? nextNumber,
    String? error,
  }) =>
      EstimateState(
        status: status ?? this.status,
        estimates: estimates ?? this.estimates,
        nextNumber: nextNumber ?? this.nextNumber,
        error: error,
      );

  @override
  List<Object?> get props => [status, estimates, nextNumber, error];
}
