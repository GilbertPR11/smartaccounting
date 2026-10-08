part of 'customer_bloc.dart';

class CustomerState extends Equatable {
  const CustomerState({
    this.status = LoadStatus.initial,
    this.customers = const [],
    this.error,
  });

  final LoadStatus status;
  final List<Customer> customers;
  final String? error;

  Customer? byId(String? id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  CustomerState copyWith({LoadStatus? status, List<Customer>? customers, String? error}) =>
      CustomerState(
        status: status ?? this.status,
        customers: customers ?? this.customers,
        error: error,
      );

  @override
  List<Object?> get props => [status, customers, error];
}
