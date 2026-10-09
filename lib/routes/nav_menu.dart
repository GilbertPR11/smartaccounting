import 'package:flutter/material.dart';

import 'routes.dart';

// The app's menu: the 4 main categories and the pages inside each.
// The sidebar (tablet/desktop) and the drawer (phone) are both built from
// this list, so adding a page to the menu is a one-line change here.

class NavItem {
  const NavItem(this.label, this.route, this.icon);

  final String label;
  final String route;
  final IconData icon;
}

class NavSection {
  const NavSection({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    this.items = const [],
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// The category's own page (its "Overview").
  final String route;

  /// Pages inside the category, shown as a dropdown. Empty = no dropdown.
  final List<NavItem> items;

  bool get hasItems => items.isNotEmpty;
}

class NavMenu {
  NavMenu._();

  static const sections = <NavSection>[
    NavSection(
      label: 'Dashboard',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      route: PageRoutes.dashboard,
    ),
    NavSection(
      label: 'Sales & payments',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      route: PageRoutes.sales,
      items: [
        NavItem('Overview', PageRoutes.sales, Icons.space_dashboard_outlined),
        NavItem('Estimates', PageRoutes.estimates, Icons.request_quote_outlined),
        NavItem('Invoices', PageRoutes.invoices, Icons.description_outlined),
        NavItem('Recurring invoices', PageRoutes.recurring, Icons.autorenew_rounded),
        NavItem('Customer statements', PageRoutes.statements, Icons.summarize_outlined),
        NavItem('Customers', PageRoutes.customers, Icons.people_outline),
        NavItem('Products & services', PageRoutes.products, Icons.inventory_2_outlined),
        NavItem('Invoice design', PageRoutes.invoiceTemplate, Icons.palette_outlined),
      ],
    ),
    NavSection(
      label: 'Purchases',
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag,
      route: PageRoutes.purchases,
      items: [
        NavItem('Overview', PageRoutes.purchases, Icons.space_dashboard_outlined),
        NavItem('Bills', PageRoutes.bills, Icons.description_outlined),
        NavItem('Receipts', PageRoutes.receipts, Icons.document_scanner_outlined),
        NavItem('Vendors', PageRoutes.vendors, Icons.storefront_outlined),
        NavItem('Products you buy', PageRoutes.purchaseProducts, Icons.shopping_cart_outlined),
      ],
    ),
    NavSection(
      label: 'Accounting',
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance,
      route: PageRoutes.accounting,
      items: [
        NavItem('Overview', PageRoutes.accounting, Icons.space_dashboard_outlined),
        NavItem('Transactions', PageRoutes.transactions, Icons.swap_horiz_rounded),
        NavItem('Reconciliation', PageRoutes.reconciliation, Icons.fact_check_outlined),
        NavItem('Chart of accounts', PageRoutes.chartOfAccounts, Icons.account_tree_outlined),
        NavItem('Reports', PageRoutes.reports, Icons.bar_chart_rounded),
      ],
    ),
  ];
}
