import 'package:flutter/material.dart';

import '../../../../components/centered_list_view.dart';
import '../../../../components/money_text.dart';
import '../../../../theme/colors.dart';

/// Shared layout for every report: controls on top, then the report itself
/// on one card, like a printed page.
class ReportScaffold extends StatelessWidget {
  const ReportScaffold({
    super.key,
    required this.title,
    required this.controls,
    required this.children,
    this.subtitle,
    this.maxWidth = 820,
  });

  final String title;
  final String? subtitle;
  final Widget controls;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('PDF and CSV export come with the backend.'))),
          ),
        ],
      ),
      body: CenteredListView(
        maxWidth: maxWidth,
        children: [
          Card(
            child: Padding(padding: const EdgeInsets.all(Space.lg), child: controls),
          ),
          const SizedBox(height: Space.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: text.titleLarge),
                  if (subtitle != null)
                    Text(subtitle!, style: text.bodySmall?.copyWith(color: context.ledger.muted)),
                  const SizedBox(height: Space.md),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A group heading inside a report ("Income", "Assets").
class ReportHeading extends StatelessWidget {
  const ReportHeading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
      child: Text(label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary, letterSpacing: 0.8)),
    );
  }
}

/// One line: label on the left, amount on the right. Tappable lines show a
/// chevron-free hover and open the account's detail.
class ReportLine extends StatelessWidget {
  const ReportLine(
    this.label,
    this.amount, {
    super.key,
    this.secondary,
    this.onTap,
    this.indent = 0,
  });

  final String label;
  final String? secondary;
  final double amount;
  final VoidCallback? onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final row = Padding(
      padding: EdgeInsets.fromLTRB(indent, 7, 0, 7),
      child: Row(
        children: [
          if (secondary != null)
            SizedBox(
              width: 52,
              child: Text(secondary!, style: text.bodySmall),
            ),
          Expanded(
            child: Text(label,
                style: text.bodyMedium?.copyWith(
                    color: onTap == null ? null : Theme.of(context).colorScheme.primary)),
          ),
          MoneyText(amount, style: text.bodyMedium),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// A bold total with a rule above it.
class ReportTotal extends StatelessWidget {
  const ReportTotal(this.label, this.amount, {super.key, this.color, this.large = false});

  final String label;
  final double amount;
  final Color? color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = (large ? text.titleMedium : text.bodyMedium)
        ?.copyWith(fontWeight: FontWeight.w700, color: color);
    return Container(
      margin: const EdgeInsets.only(top: Space.xs),
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.ledger.hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          MoneyText(amount, style: style),
        ],
      ),
    );
  }
}

/// Muted text for empty sections.
class ReportEmpty extends StatelessWidget {
  const ReportEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Text(message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.ledger.muted)),
    );
  }
}
