part of 'bill_bloc.dart';

class BillState extends Equatable {
  const BillState({this.status = LoadStatus.initial, this.bills = const [], this.error});

  final LoadStatus status;

  /// Soonest due first.
  final List<Bill> bills;
  final String? error;

  Bill? byId(String? id) {
    for (final b in bills) {
      if (b.id == id) return b;
    }
    return null;
  }

  BillState copyWith({LoadStatus? status, List<Bill>? bills, String? error}) => BillState(
        status: status ?? this.status,
        bills: bills ?? this.bills,
        error: error,
      );

  @override
  List<Object?> get props => [status, bills, error];
}
