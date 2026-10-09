import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/setting/setting_bloc.dart';
import '../../../components/initials_avatar.dart';
import '../../../routes/nav_menu.dart';
import '../../../theme/colors.dart';

/// Called when the user picks a page: which category, and which route in it.
typedef NavigateTo = void Function(int section, String route);

/// The full menu: ☰ + business, "Create new", then each category with a
/// dropdown of its pages. Used as the open sidebar and as the phone drawer.
class SideMenuPanel extends StatefulWidget {
  const SideMenuPanel({
    super.key,
    required this.selectedSection,
    required this.onNavigate,
    required this.onMenuButton,
    required this.onCreateNew,
    this.selectedRoute,
    this.menuTooltip = 'Hide menu',
    this.categoryTapOnlyExpands = false,
  });

  final int selectedSection;

  /// The page to highlight inside the selected category, if known.
  final String? selectedRoute;
  final NavigateTo onNavigate;

  /// The ☰ button: hides the sidebar, or closes the drawer on phones.
  final VoidCallback onMenuButton;
  final String menuTooltip;
  final VoidCallback onCreateNew;

  /// Phone drawer: tapping a category with pages just opens its dropdown
  /// (navigating would close the drawer before you could pick a page).
  final bool categoryTapOnlyExpands;

  static const double width = 264;

  @override
  State<SideMenuPanel> createState() => _SideMenuPanelState();
}

class _SideMenuPanelState extends State<SideMenuPanel> {
  late final Set<int> _open = {widget.selectedSection};

  @override
  void didUpdateWidget(SideMenuPanel old) {
    super.didUpdateWidget(old);
    // Moving to another category opens its dropdown.
    if (old.selectedSection != widget.selectedSection) _open.add(widget.selectedSection);
  }

  void _toggle(int i) {
    setState(() {
      if (!_open.remove(i)) _open.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: SideMenuPanel.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.md, Space.sm),
            child: Row(
              children: [
                IconButton(
                  tooltip: widget.menuTooltip,
                  icon: const Icon(Icons.menu),
                  onPressed: widget.onMenuButton,
                ),
                const SizedBox(width: Space.xs),
                const Expanded(child: BusinessBadge(showName: true)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
            child: FilledButton.icon(
              onPressed: widget.onCreateNew,
              icon: const Icon(Icons.add),
              label: const Text('Create new'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, Space.lg),
              children: [
                for (var i = 0; i < NavMenu.sections.length; i++) ...[
                  _SectionTile(
                    section: NavMenu.sections[i],
                    selected: i == widget.selectedSection,
                    open: _open.contains(i),
                    onTap: () {
                      if (widget.categoryTapOnlyExpands && NavMenu.sections[i].hasItems) {
                        _toggle(i);
                        return;
                      }
                      setState(() => _open.add(i));
                      widget.onNavigate(i, NavMenu.sections[i].route);
                    },
                    onToggle: () => _toggle(i),
                  ),
                  if (NavMenu.sections[i].hasItems && _open.contains(i))
                    for (final item in NavMenu.sections[i].items)
                      _ItemTile(
                        item: item,
                        selected: i == widget.selectedSection &&
                            item.route == (widget.selectedRoute ?? NavMenu.sections[i].route),
                        onTap: () => widget.onNavigate(i, item.route),
                      ),
                  if (i < NavMenu.sections.length - 1) const SizedBox(height: 2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.selected,
    required this.open,
    required this.onTap,
    required this.onToggle,
  });

  final NavSection section;
  final bool selected;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: selected && !section.hasItems ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: Space.lg),
              Icon(selected ? section.selectedIcon : section.icon, color: fg, size: 22),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (section.hasItems)
                IconButton(
                  tooltip: open ? 'Collapse' : 'Expand',
                  visualDensity: VisualDensity.compact,
                  icon: AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(Icons.expand_more, color: fg),
                  ),
                  onPressed: onToggle,
                )
              else
                const SizedBox(width: Space.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: Space.xl),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: Space.lg),
                Icon(item.icon, size: 18, color: fg),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hidden sidebar: just ☰, "+" and the category icons. A category with
/// pages opens them as a dropdown menu, so nothing is more than two taps away.
class SideMenuRail extends StatelessWidget {
  const SideMenuRail({
    super.key,
    required this.selectedSection,
    required this.onNavigate,
    required this.onMenuButton,
    required this.onCreateNew,
  });

  final int selectedSection;
  final NavigateTo onNavigate;
  final VoidCallback onMenuButton;
  final VoidCallback onCreateNew;

  static const double width = 72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: Space.md),
            IconButton(
              tooltip: 'Show menu',
              icon: const Icon(Icons.menu),
              onPressed: onMenuButton,
            ),
            const SizedBox(height: Space.sm),
            FloatingActionButton.small(
              heroTag: null,
              elevation: 0,
              tooltip: 'Create new',
              onPressed: onCreateNew,
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: Space.lg),
            for (var i = 0; i < NavMenu.sections.length; i++) ...[
              _RailIcon(
                section: NavMenu.sections[i],
                selected: i == selectedSection,
                onNavigate: (route) => onNavigate(i, route),
                scheme: scheme,
              ),
              const SizedBox(height: Space.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.section,
    required this.selected,
    required this.onNavigate,
    required this.scheme,
  });

  final NavSection section;
  final bool selected;
  final ValueChanged<String> onNavigate;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 56,
      height: 36,
      decoration: BoxDecoration(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Icon(
        selected ? section.selectedIcon : section.icon,
        color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
      ),
    );

    if (!section.hasItems) {
      return Tooltip(
        message: section.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: () => onNavigate(section.route),
          child: icon,
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: section.label,
      position: PopupMenuPosition.over,
      offset: const Offset(64, 0),
      onSelected: onNavigate,
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 36,
          child: Text(section.label, style: Theme.of(context).textTheme.labelLarge),
        ),
        for (final item in section.items)
          PopupMenuItem<String>(
            value: item.route,
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: Space.md),
                Text(item.label),
              ],
            ),
          ),
      ],
      child: icon,
    );
  }
}

/// Logo (if uploaded) or initials, plus the business name.
class BusinessBadge extends StatelessWidget {
  const BusinessBadge({super.key, this.showName = true});

  final bool showName;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingBloc>().state;
    final name = state.profile.name;
    final logo = state.template.hasLogo
        ? Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.ledger.hairline),
            ),
            child: Image.memory(state.template.logoBytes!, fit: BoxFit.contain),
          )
        : InitialsAvatar(name.isEmpty ? '?' : name, size: 36);
    if (!showName) return Tooltip(message: name, child: logo);
    return Row(
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
    );
  }
}
