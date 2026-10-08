import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/bill/bill_bloc.dart';
import 'bloc/customer/customer_bloc.dart';
import 'bloc/invoice/invoice_bloc.dart';
import 'bloc/product/product_bloc.dart';
import 'bloc/receipt/receipt_bloc.dart';
import 'bloc/setting/setting_bloc.dart';
import 'bloc/transaction/transaction_bloc.dart';
import 'bloc/vendor/vendor_bloc.dart';
import 'config/constants.dart';
import 'databases/local_db.dart';
import 'pages/home/home_page.dart';
import 'repository/bill_repository.dart';
import 'repository/customer_repository.dart';
import 'repository/invoice_repository.dart';
import 'repository/product_repository.dart';
import 'repository/receipt_repository.dart';
import 'repository/setting_repository.dart';
import 'repository/transaction_repository.dart';
import 'repository/vendor_repository.dart';
import 'routes/routes.dart';
import 'theme/theme.dart';

/// Wires the layers together, top to bottom:
///   LocalDb → repositories (RepositoryProvider) → Blocs (BlocProvider) → pages.
///
/// Unlike smartpos, nothing below creates its own dependencies: Blocs get
/// their repository through the constructor, so tests can hand in a seeded
/// [LocalDb] with a fixed date.
class SmartAccountingApp extends StatelessWidget {
  const SmartAccountingApp({super.key, required this.db});

  final LocalDb db;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SettingRepository>(create: (_) => SettingRepository(db)),
        RepositoryProvider<CustomerRepository>(create: (_) => CustomerRepository(db)),
        RepositoryProvider<ProductRepository>(create: (_) => ProductRepository(db)),
        RepositoryProvider<TransactionRepository>(
            create: (_) => TransactionRepository(db)),
        RepositoryProvider<InvoiceRepository>(create: (_) => InvoiceRepository(db)),
        RepositoryProvider<VendorRepository>(create: (_) => VendorRepository(db)),
        RepositoryProvider<BillRepository>(create: (_) => BillRepository(db)),
        RepositoryProvider<ReceiptRepository>(create: (_) => ReceiptRepository(db)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingBloc>(
            lazy: false,
            create: (ctx) => SettingBloc(repository: ctx.read<SettingRepository>())
              ..add(const LoadSettings()),
          ),
          BlocProvider<VendorBloc>(
            lazy: false,
            create: (ctx) => VendorBloc(repository: ctx.read<VendorRepository>())
              ..add(const LoadVendors()),
          ),
          BlocProvider<BillBloc>(
            lazy: false,
            create: (ctx) =>
                BillBloc(repository: ctx.read<BillRepository>())..add(const LoadBills()),
          ),
          BlocProvider<ReceiptBloc>(
            lazy: false,
            create: (ctx) => ReceiptBloc(repository: ctx.read<ReceiptRepository>())
              ..add(const LoadReceipts()),
          ),
          BlocProvider<CustomerBloc>(
            lazy: false,
            create: (ctx) => CustomerBloc(repository: ctx.read<CustomerRepository>())
              ..add(const LoadCustomers()),
          ),
          BlocProvider<ProductBloc>(
            lazy: false,
            create: (ctx) => ProductBloc(repository: ctx.read<ProductRepository>())
              ..add(const LoadProducts()),
          ),
          BlocProvider<TransactionBloc>(
            lazy: false,
            create: (ctx) =>
                TransactionBloc(repository: ctx.read<TransactionRepository>())
                  ..add(const LoadTransactions()),
          ),
          BlocProvider<InvoiceBloc>(
            lazy: false,
            create: (ctx) => InvoiceBloc(repository: ctx.read<InvoiceRepository>())
              ..add(const LoadInvoices()),
          ),
        ],
        child: MaterialApp(
          title: Constants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const HomePage(),
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
  }
}
