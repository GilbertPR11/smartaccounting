import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../config/layout.dart';
import '../../routes/nav_menu.dart';
import '../../routes/routes.dart';
import '../../theme/colors.dart';
import '../accounting/accounting_page.dart';
import '../dashboard/dashboard_page.dart';
import '../purchases/purchases_page.dart';
import '../sales/sales_page.dart';
import 'app_shell.dart';
import 'create_new_sheet.dart';
import 'widgets/side_menu.dart';

/// Root scaffold with the 4 main categories and the menu (routes/nav_menu.dart).
///
/// * Phone (compact): bottom NavigationBar for the categories, plus a ☰
///   drawer with every page. Detail pages open full-screen.
/// * Tablet and desktop: a sidebar with a dropdown of pages per category.
///   The ☰ hides it down to an icon strip (categories still open their pages
///   from a popup). Each category keeps its own navigator, so the sidebar
///   stays put while you drill into a page.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _trackers = List.generate(4, (_) => _RouteTracker());
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Sidebar hidden? Null until the user taps ☰: then it's open on
  /// desktops and hidden on tablets.
  bool? _hidden;

  // Phone: category pages are built directly; pushes go to the root navigator.
  static const _pages = <Widget>[
    DashboardPage(),
    SalesPage(),
    PurchasesPage(),
    AccountingPage(),
  ];

  static const _bottomLabels = ['Dashboard', 'Sales', 'Purchases', 'Accounting'];

  @override
  void dispose() {
    for (final t in _trackers) {
      t.dispose();
    }
    super.dispose();
  }

  /// Wide layouts: show [route] inside category [section]'s navigator.
  /// Picking the category itself (or its Overview) returns to its main page.
  void _navigateWide(int section, String route) {
    setState(() => _index = section);
    final nav = _navKeys[section].currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    if (route != NavMenu.sections[section].route) nav.pushNamed(route);
  }

  /// Phone: close the drawer, switch category, then open [route] full-screen.
  void _navigatePhone(int section, String route) {
    _scaffoldKey.currentState?.closeDrawer();
    setState(() => _index = section);
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    if (route != NavMenu.sections[section].route) nav.pushNamed(route);
  }

  /// "Create new": pick what, then open it in its own category's tab so
  /// the sidebar shows where it lives.
  Future<void> _createWide() async {
    final action = await showCreateNewSheet(context);
    if (action == null || !mounted) return;
    setState(() => _index = action.section);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navKeys[action.section].currentContext;
      if (ctx != null) runCreateAction(ctx, action);
    });
  }

  Future<void> _createPhone() async {
    _scaffoldKey.currentState?.closeDrawer();
    final action = await showCreateNewSheet(context);
    if (action == null || !mounted) return;
    await runCreateAction(context, action);
  }

  /// The menu page to highlight: the top-most page in the current
  /// category's stack that the menu lists (detail pages are skipped, so
  /// an open invoice keeps "Invoices" highlighted).
  String? _selectedRoute(List<String> stack) {
    final menuRoutes = {for (final item in NavMenu.sections[_index].items) item.route};
    for (final name in stack.reversed) {
      if (menuRoutes.contains(name)) return name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    if (size == WindowSize.compact) return _buildPhone();

    final hidden = _hidden ?? size != WindowSize.expanded;
    final l = context.ledger;

    return AppShell(
      openMenu: null, // the sidebar has its own ☰
      child: Scaffold(
        // Pages inside handle the keyboard themselves; the sidebar keeps
        // its full height.
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Row(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: hidden
                    ? SideMenuRail(
                        selectedSection: _index,
                        onNavigate: _navigateWide,
                        onMenuButton: () => setState(() => _hidden = false),
                        onCreateNew: _createWide,
                      )
                    : ValueListenableBuilder<List<String>>(
                        valueListenable: _trackers[_index].names,
                        builder: (context, stack, _) => SideMenuPanel(
                          selectedSection: _index,
                          selectedRoute: _selectedRoute(stack),
                          onNavigate: _navigateWide,
                          onMenuButton: () => setState(() => _hidden = true),
                          onCreateNew: _createWide,
                        ),
                      ),
              ),
              VerticalDivider(width: 1, color: l.hairline),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      _TabNavigator(
                        navKey: _navKeys[i],
                        tracker: _trackers[i],
                        active: i == _index,
                        initialRoute: NavMenu.sections[i].route,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhone() {
    return AppShell(
      openMenu: () => _scaffoldKey.currentState?.openDrawer(),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          width: SideMenuPanel.width + 16,
          child: SafeArea(
            child: SideMenuPanel(
              selectedSection: _index,
              onNavigate: _navigatePhone,
              onMenuButton: () => _scaffoldKey.currentState?.closeDrawer(),
              menuTooltip: 'Close menu',
              categoryTapOnlyExpands: true,
              onCreateNew: _createPhone,
            ),
          ),
        ),
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (var i = 0; i < NavMenu.sections.length; i++)
              NavigationDestination(
                icon: Icon(NavMenu.sections[i].icon),
                selectedIcon: Icon(NavMenu.sections[i].selectedIcon),
                label: _bottomLabels[i],
              ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the route names of one category's navigator, bottom to top, so
/// the sidebar can highlight the page you're on.
class _RouteTracker extends NavigatorObserver {
  final names = ValueNotifier<List<String>>(const []);
  final _stack = <Route<dynamic>>[];
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    names.dispose();
  }

  void _changed() {
    // Routes of a navigator that was thrown away (e.g. window resized to
    // phone width and back) have no navigator any more.
    _stack.removeWhere((r) => r.navigator == null);
    final snapshot = [for (final r in _stack) r.settings.name ?? ''];
    // Navigator reports pushes while it builds; publish after the frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) names.value = snapshot;
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) _stack[i] = newRoute;
    _changed();
  }
}

/// A per-category navigator so pushed pages stay inside the content area.
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navKey,
    required this.tracker,
    required this.active,
    required this.initialRoute,
  });

  final GlobalKey<NavigatorState> navKey;
  final _RouteTracker tracker;
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
        observers: [tracker],
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
