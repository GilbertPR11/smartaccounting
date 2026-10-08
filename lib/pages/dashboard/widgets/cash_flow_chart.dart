import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/money_text.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';

/// Paired monthly bars: money in (accent) and money out (muted).
/// Tap a month to see its exact figures below the chart.
class CashFlowChart extends StatefulWidget {
  const CashFlowChart({super.key, required this.months});

  /// (month start, money in, money out), oldest first.
  final List<(DateTime, double, double)> months;

  @override
  State<CashFlowChart> createState() => _CashFlowChartState();
}

class _CashFlowChartState extends State<CashFlowChart> {
  int? _selected;

  static const double _chartHeight = 140;

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    if (months.isEmpty) return const SizedBox.shrink();
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final inColor = Theme.of(context).colorScheme.primary;
    final outColor = l.muted.withOpacity(0.45);
    final maxV = months.fold<double>(1, (m, e) => math.max(m, math.max(e.$2, e.$3)));
    final sel = _selected ?? months.length - 1;
    final (selMonth, selIn, selOut) = months[sel];

    Widget bar(double v, Color c, bool dim) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 10,
          height: math.max(2, _chartHeight * v / maxV),
          decoration: BoxDecoration(
            color: dim ? c.withOpacity(c.opacity * 0.45) : c,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selected month figures.
        Text(fmtMonthYear(selMonth), style: text.titleSmall),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: _Figure(
                label: 'Money in',
                swatch: inColor,
                child: MoneyText(selIn),
              ),
            ),
            Expanded(
              child: _Figure(
                label: 'Money out',
                swatch: l.muted.withOpacity(0.45),
                child: MoneyText(selOut),
              ),
            ),
            Expanded(
              child: _Figure(
                label: 'Net',
                child: MoneyText(selIn - selOut,
                    showSign: true, color: selIn - selOut >= 0 ? l.moneyIn : l.moneyOut),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        SizedBox(
          height: _chartHeight + 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < months.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == sel,
                    label: '${fmtMonthYear(months[i].$1)}: in ${money(months[i].$2)}, '
                        'out ${money(months[i].$3)}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.control),
                      onTap: () => setState(() => _selected = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              bar(months[i].$2, inColor, i != sel),
                              const SizedBox(width: 3),
                              bar(months[i].$3, outColor, i != sel),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            monthShort(months[i].$1),
                            style: text.labelSmall?.copyWith(
                              color: i == sel ? Theme.of(context).colorScheme.onSurface : null,
                              fontWeight: i == sel ? FontWeight.w600 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.child, this.swatch});

  final String label;
  final Widget child;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (swatch != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: child),
      ],
    );
  }
}
