import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/account/account_bloc.dart';
import '../../bloc/bill/bill_bloc.dart';
import '../../bloc/invoice/invoice_bloc.dart';
import '../../bloc/journal/journal_bloc.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../repository/setting_repository.dart';
import '../../utils/ledger.dart';

/// Builds the ledger from the current Bloc states, and rebuilds the calling
/// widget whenever any of them changes. Cheap enough for an in-memory
/// database; with a backend, reports would come from the server instead.
Ledger watchLedger(BuildContext context) => Ledger.build(
      accounts: context.watch<AccountBloc>().state.accounts,
      invoices: context.watch<InvoiceBloc>().state.invoices,
      bills: context.watch<BillBloc>().state.bills,
      transactions: context.watch<TransactionBloc>().state.transactions,
      journals: context.watch<JournalBloc>().state.journals,
      openingBalance: context.read<SettingRepository>().openingBalance,
      openingAccountId: context.read<SettingRepository>().openingAccountId,
    );
