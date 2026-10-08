# SmartAccounting architecture

Same layering as **smartpos**, with fixes for the parts of smartpos that made it hard to maintain.

```
lib/
├── main.dart              runApp only
├── app.dart               wires LocalDb → repositories → Blocs → MaterialApp
├── config/                constants.dart (currency, taxes, terms), layout.dart (breakpoints)
├── theme/                 colors.dart, theme.dart
├── routes/                routes.dart — PageRoutes names, typed args, AppRouter
├── models/                one immutable Equatable model per file (*_model.dart)
├── databases/             local_db.dart (in-memory for now), seed_data.dart
├── repository/            *_repository.dart — the ONLY code that touches LocalDb
├── bloc/<feature>/        <feature>_bloc.dart + part files _event.dart / _state.dart
├── components/            reusable widgets (no business rules); invoice_document.dart renders invoices
├── pages/<area>/          screens, grouped like the app's navigation
├── exception/             AppException — user-fixable business errors
└── utils/                 pure functions: format.dart, ledger_summary.dart
```

There is no `api/` folder yet because there is no backend. When one exists, add `api/<feature>_service.dart` (as in smartpos) and let the repository decide between local and remote.

## Rules

1. **Dependencies point down only.** pages → bloc → repository → databases. A page never imports `databases/`. A repository never imports Flutter widgets.
2. **Inject, don't construct.** Blocs receive their repository through the constructor (see `app.dart`). smartpos Blocs do `CustomerRepository()` internally, which is why they can't be tested against fake data.
3. **Models are immutable.** Change a record with `copyWith`/`linkTo`, never by assignment. Equatable compares states by value, so mutating a model in place produces a "new" state that compares equal to the old one, and the UI silently doesn't rebuild.
4. **Reads come from Blocs; Blocs refresh themselves.** Each list Bloc listens to its repository's `changes` stream and reloads. A write anywhere (another page, a dialog, a future sync) shows up everywhere with no manual "refresh" events.
5. **Writes:**
   - If the caller doesn't need a result, send a Bloc event (`RecordInvoicePayment`, `AddProduct`).
   - If the page needs the created record back, use a per-page form Bloc (`InvoiceFormBloc`) whose success state carries it.
   - Small dialogs (`showAddCustomerDialog`) may call the repository directly. This is the only exception; document it at the call site.
6. **Errors:** repositories throw `AppException` for anything the user can fix. Blocs catch only `AppException` and put the message in state. Anything else is a bug and should crash loudly in debug, not be `print`ed and swallowed.
7. **Navigation goes through `routes/routes.dart`.** Use `Navigator.pushNamed(context, PageRoutes.x, arguments: ...)`. The same `AppRouter.onGenerateRoute` serves the phone's root navigator and each tablet/desktop tab navigator.
8. **One page per screen, not one per orientation.** Adapt with `LayoutBuilder` and `config/layout.dart` breakpoints. smartpos's `*_portrait.dart` / `*_landscape.dart` pairs (3,000+ lines each) duplicate every bug fix; don't repeat that here.
9. **No `Classes/` folder.** Every file belongs to a layer above. If it doesn't fit, it's usually a pure function (`utils/`) or a widget (`components/`).
10. **Keep files under ~600 lines.** Past that, split private widgets into their own files in the same folder.

## Adding a feature (e.g. Bills in Purchases)

1. `models/bill_model.dart`: immutable, Equatable.
2. A table in `databases/local_db.dart`, plus seed rows.
3. `repository/bill_repository.dart` with `changes`, `fetchBills`, and write methods that throw `AppException`.
4. `bloc/bill/` with bloc, event and state files; listen to `repository.changes`.
5. Register the repository and Bloc in `app.dart`.
6. Pages in `pages/purchases/bill/`, routes in `routes/routes.dart`.
7. Tests in `test/`: repository rules first, then a widget test for the main flow.

## Moving to a real database

Replace `LocalDb` with a sqflite `Db` (same idea as smartpos `Databases/db.dart`, including its versioned migrations). Repositories keep their public API, which is why every method is already `Future`-returning, and emit on `changes` after each committed write. Nothing in `bloc/` or `pages/` should need to change.
