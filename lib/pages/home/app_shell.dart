import 'package:flutter/material.dart';

/// Lets a category's main page show the ☰ button that opens the phone menu.
///
/// On tablets and desktops the sidebar has its own ☰, so [openMenu] is null
/// and [menuButton] returns null (the AppBar then shows nothing there).
class AppShell extends InheritedWidget {
  const AppShell({super.key, required this.openMenu, required super.child});

  final VoidCallback? openMenu;

  /// A ☰ button for an AppBar's `leading`, or null when not needed.
  static Widget? menuButton(BuildContext context) {
    final open = context.dependOnInheritedWidgetOfExactType<AppShell>()?.openMenu;
    if (open == null) return null;
    return IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu), onPressed: open);
  }

  @override
  bool updateShouldNotify(AppShell oldWidget) =>
      (openMenu == null) != (oldWidget.openMenu == null);
}
