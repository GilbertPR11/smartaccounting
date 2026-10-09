part of 'bill_bloc.dart';

sealed class BillEvent extends Equatable {
  const BillEvent();

  @override
  List<Object?> get props => [];
}

class LoadBills extends BillEvent {
  const LoadBills();
}

class PayBill extends BillEvent {
  const PayBill({
    required this.billId,
    required this.amount,
    required this.date,
    required this.account,
  });

  final String billId;
  final double amount;
  final DateTime date;
  final String account;

  @override
  List<Object?> get props => [billId, amount, date, account];
}
