import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/account_model.dart';
import '../../repository/account_repository.dart';
import '../load_status.dart';

part 'account_event.dart';
part 'account_state.dart';

/// The chart of accounts. Adding and editing go through the account
/// dialog, which calls the repository directly (it needs the result).
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc({required AccountRepository repository})
      : _repository = repository,
        super(const AccountState()) {
    on<LoadAccounts>(_onLoad);
    on<ArchiveAccount>(_onArchive);
    _changes = _repository.changes.listen((_) => add(const LoadAccounts()));
  }

  final AccountRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadAccounts event, Emitter<AccountState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final accounts = await _repository.fetchAccounts();
      emit(state.copyWith(status: LoadStatus.success, accounts: accounts));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onArchive(ArchiveAccount event, Emitter<AccountState> emit) async {
    try {
      await _repository.setArchived(event.accountId, event.archived);
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
