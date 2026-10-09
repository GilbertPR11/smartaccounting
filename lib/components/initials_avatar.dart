import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../utils/format.dart';

/// Quiet initials avatar for customers. Same name → same tint.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  static const _tints = [
    Color(0xFF0F5D4C), Color(0xFF2F5D8A), Color(0xFF6A4C93),
    Color(0xFF8A5A2B), Color(0xFF2E6B6B), Color(0xFF5B6B2F),
  ];

  @override
  Widget build(BuildContext context) {
    // Deterministic across app restarts (String.hashCode is not).
    final tint = _tints[name.codeUnits.fold<int>(0, (a, b) => a + b) % _tints.length];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withOpacity(dark ? 0.28 : 0.10),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: dark ? Color.lerp(tint, Colors.white, 0.55) : tint,
        ),
      ),
    );
  }
}

/// Small square icon badge used at the start of list rows.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 40});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.ledger.muted;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: c),
    );
  }
}
