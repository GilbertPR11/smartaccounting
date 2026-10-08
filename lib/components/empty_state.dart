import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// What to show when a list is empty: what's missing and what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Smaller version for use inside a section rather than a whole page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ledger = context.ledger;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? Space.xl : Space.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 44 : 56,
                height: compact ? 44 : 56,
                decoration: BoxDecoration(
                  color: ledger.subtleFill,
                  borderRadius: BorderRadius.circular(Radii.container),
                ),
                child: Icon(icon, color: ledger.muted, size: compact ? 22 : 26),
              ),
              const SizedBox(height: Space.lg),
              Text(title, style: text.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: Space.xs),
                Text(message!,
                    style: text.bodyMedium?.copyWith(color: ledger.muted),
                    textAlign: TextAlign.center),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Space.lg),
                FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
