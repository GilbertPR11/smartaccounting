import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/initials_avatar.dart';
import '../../config/layout.dart';
import '../../bloc/setting/setting_bloc.dart';
import '../../routes/routes.dart';
import '../../theme/colors.dart';
import '../accounting/accounting_page.dart';
import '../dashboard/dashboard_page.dart';
import '../purchases/purchases_page.dart';
import '../sales/invoice/new_invoice_flow.dart';
import '../sales/sales_page.dart';

/// Root scaffold with the 4 main categories.
///
/// * Phone (compact): bottom NavigationBar; detail pages open full-screen.
/// * Tablet (medium): NavigationRail; each tab has its own navigator so the
///   rail stays visible while you drill into invoices.
/// * Laptop/monitor (expanded): labelled sidebar + "New invoice" button.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  // Phone: tab roots are built directly; pushes go to the root navigator.
  static const _pages = <Widget>[
    DashboardPage(),
    SalesPage(),
    PurchasesPage(),
    AccountingPage(),
  ];

  // Tablet/desktop: each tab gets its own navigator starting at this route.
  static const _tabRoutes = <String>[
    PageRoutes.dashboard,
    PageRoutes.sales,
    PageRoutes.purchases,
    PageRoutes.accounting,
  ];

  static const _dests = <(IconData, IconData, String)>[
    (Icons.insights_outlined, Icons.insights, 'Dashboard'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Sales'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag, 'Purchases'),
    (Icons.account_balance_outlined, Icons.account_balance, 'Accounting'),
  ];

  void _select(int i) {
    // Re-tapping the active tab returns to its root (wide layouts only).
    if (i == _index) _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    setState(() => _index = i);
  }

  void _newInvoiceFromRail() {
    setState(() => _index = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navKeys[1].currentContext;
      if (ctx != null) showNewInvoiceSheet(ctx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;

    if (size == WindowSize.compact) {
      return Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final (icon, selected, label) in _dests)
              NavigationDestination(
                  icon: Icon(icon), selectedIcon: Icon(selected), label: label),
          ],
        ),
      );
    }

    final extended = size == WindowSize.expanded;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: 232,
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(0, Space.md, 0, Space.lg),
                child: Column(
                  crossAxisAlignment:
                      extended ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    _BusinessBadge(extended: extended),
                    const SizedBox(height: Space.lg),
                    extended
                        ? FloatingActionButton.extended(
                            heroTag: null,
                            elevation: 0,
                            onPressed: _newInvoiceFromRail,
                            icon: const Icon(Icons.add),
                            label: const Text('New invoice'),
                          )
                        : FloatingActionButton(
                            heroTag: null,
                            elevation: 0,
                            tooltip: 'New invoice',
                            onPressed: _newInvoiceFromRail,
                            child: const Icon(Icons.add),
                          ),
                  ],
                ),
              ),
              destinations: [
                for (final (icon, selected, label) in _dests)
                  NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: Text(label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    _TabNavigator(
                      navKey: _navKeys[i],
                      active: i == _index,
                      initialRoute: _tabRoutes[i],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo (if uploaded) or initials, plus the business name when there's room.
class _BusinessBadge extends StatelessWidget {
  const _BusinessBadge({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingBloc>().state;
    final name = state.profile.name;
    final logo = state.template.hasLogo
        ? Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.ledger.hairline),
            ),
            child: Image.memory(state.template.logoBytes!, fit: BoxFit.contain),
          )
        : InitialsAvatar(name.isEmpty ? '?' : name);
    if (!extended) return Tooltip(message: name, child: logo);
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          logo,
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// A per-tab navigator so pushed pages stay inside the content area.
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navKey,
    required this.active,
    required this.initialRoute,
  });

  final GlobalKey<NavigatorState> navKey;
  final bool active;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      enabled: active,
      onPop: () => navKey.currentState?.maybePop(),
      child: Navigator(
        key: navKey,
        initialRoute: initialRoute,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
