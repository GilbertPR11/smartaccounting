import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../utils/format.dart';

/// Common report periods. [custom] asks for a date range.
enum PeriodPreset { thisMonth, lastMonth, thisQuarter, thisYear, lastYear, custom }

extension PeriodPresetInfo on PeriodPreset {
  String get label => switch (this) {
        PeriodPreset.thisMonth => 'This month',
        PeriodPreset.lastMonth => 'Last month',
        PeriodPreset.thisQuarter => 'This quarter',
        PeriodPreset.thisYear => 'This year',
        PeriodPreset.lastYear => 'Last year',
        PeriodPreset.custom => 'Custom',
      };

  /// The range for this preset, relative to [today]. Null for [custom].
  DateTimeRange? rangeFor(DateTime today) {
    final t = dateOnly(today);
    return switch (this) {
      PeriodPreset.thisMonth => DateTimeRange(start: DateTime(t.year, t.month, 1), end: t),
      PeriodPreset.lastMonth => DateTimeRange(
          start: DateTime(t.year, t.month - 1, 1), end: DateTime(t.year, t.month, 0)),
      PeriodPreset.thisQuarter =>
        DateTimeRange(start: DateTime(t.year, ((t.month - 1) ~/ 3) * 3 + 1, 1), end: t),
      PeriodPreset.thisYear => DateTimeRange(start: DateTime(t.year, 1, 1), end: t),
      PeriodPreset.lastYear =>
        DateTimeRange(start: DateTime(t.year - 1, 1, 1), end: DateTime(t.year - 1, 12, 31)),
      PeriodPreset.custom => null,
    };
  }
}

/// A row of period chips plus the chosen dates. Reports own the state;
/// this only shows it and reports changes.
class PeriodPicker extends StatelessWidget {
  const PeriodPicker({
    super.key,
    required this.preset,
    required this.range,
    required this.today,
    required this.onChanged,
  });

  final PeriodPreset preset;
  final DateTimeRange range;
  final DateTime today;
  final void Function(PeriodPreset preset, DateTimeRange range) onChanged;

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: range,
    );
    if (picked != null) {
      onChanged(PeriodPreset.custom,
          DateTimeRange(start: dateOnly(picked.start), end: dateOnly(picked.end)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final p in PeriodPreset.values)
              ChoiceChip(
                label: Text(p.label),
                selected: preset == p,
                onSelected: (_) {
                  final r = p.rangeFor(today);
                  if (r == null) {
                    _pickCustom(context);
                  } else {
                    onChanged(p, r);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text('${fmtDate(range.start)} – ${fmtDate(range.end)}',
            style: text.bodyMedium?.copyWith(color: context.ledger.muted)),
      ],
    );
  }
}

/// "As of" date for point-in-time reports (balance sheet, trial balance).
class AsOfPicker extends StatelessWidget {
  const AsOfPicker({super.key, required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(dateOnly(picked));
      },
      icon: const Icon(Icons.event_outlined, size: 18),
      label: Text('As of ${fmtDate(date)}'),
    );
  }
}
