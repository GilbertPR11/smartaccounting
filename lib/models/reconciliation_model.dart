import 'package:equatable/equatable.dart';

/// One finished bank reconciliation: on [statementDate] the bank said
/// [account] held [endingBalance], and these transactions made it add up.
class Reconciliation extends Equatable {
  const Reconciliation({
    required this.id,
    required this.account,
    required this.statementDate,
    required this.endingBalance,
    required this.transactionIds,
    required this.completedOn,
  });

  final String id;

  /// Money account name.
  final String account;
  final DateTime statementDate;
  final double endingBalance;
  final List<String> transactionIds;
  final DateTime completedOn;

  @override
  List<Object?> get props =>
      [id, account, statementDate, endingBalance, transactionIds, completedOn];
}
