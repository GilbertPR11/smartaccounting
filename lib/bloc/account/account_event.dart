part of 'account_bloc.dart';

sealed class AccountEvent extends Equatable {
  const AccountEvent();

  @override
  List<Object?> get props => [];
}

class LoadAccounts extends AccountEvent {
  const LoadAccounts();
}

class ArchiveAccount extends AccountEvent {
  const ArchiveAccount(this.accountId, {this.archived = true});

  final String accountId;
  final bool archived;

  @override
  List<Object?> get props => [accountId, archived];
}
