import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'initials_avatar.dart';

/// A feature row that isn't built yet. Honest about it, still tappable.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconBadge(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.ledger.subtleFill,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text('Planned', style: Theme.of(context).textTheme.labelSmall),
      ),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title is planned for a later version.')),
      ),
    );
  }
}
