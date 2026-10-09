part of 'recurring_bloc.dart';

class RecurringState extends Equatable {
  const RecurringState({
    this.status = LoadStatus.initial,
    this.schedules = const [],
    this.issuedOnStart = 0,
    this.error,
  });

  final LoadStatus status;

  /// Active first, then paused, then ended.
  final List<RecurringInvoice> schedules;

  /// How many invoices the start-up catch-up issued (shown once on the hub).
  final int issuedOnStart;
  final String? error;

  RecurringInvoice? byId(String? id) {
    for (final r in schedules) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<RecurringInvoice> get active =>
      schedules.where((r) => r.status == RecurringStatus.active).toList();

  List<RecurringInvoice> forCustomer(String customerId) =>
      schedules.where((r) => r.customerId == customerId).toList();

  RecurringState copyWith({
    LoadStatus? status,
    List<RecurringInvoice>? schedules,
    int? issuedOnStart,
    String? error,
  }) =>
      RecurringState(
        status: status ?? this.status,
        schedules: schedules ?? this.schedules,
        issuedOnStart: issuedOnStart ?? this.issuedOnStart,
        error: error,
      );

  @override
  List<Object?> get props => [status, schedules, issuedOnStart, error];
}
