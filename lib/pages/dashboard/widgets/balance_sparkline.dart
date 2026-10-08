import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

/// Running cash balance as a single quiet line with a soft floor fill and
/// a dot on today. No axes: the number above it carries the detail.
class BalanceSparkline extends StatelessWidget {
  const BalanceSparkline({super.key, required this.values, this.height = 80});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Cash balance over the last ${values.length} days',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: values,
            line: color,
            fill: color.withOpacity(0.08),
            baseline: context.ledger.hairline,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.line,
    required this.fill,
    required this.baseline,
  });

  final List<double> values;
  final Color line;
  final Color fill;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
    if (values.length < 2) return;

    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    const top = 6.0;
    final usable = size.height - top - 4;

    Offset at(int i) => Offset(
          size.width * i / (values.length - 1),
          top + usable * (1 - (values[i] - lo) / span),
        );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      // Step chart: balances change on a day, then hold.
      final p = at(i);
      path.lineTo(p.dx, at(i - 1).dy);
      path.lineTo(p.dx, p.dy);
    }

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );

    final end = at(values.length - 1);
    canvas.drawCircle(end, 5, Paint()..color = line.withOpacity(0.18));
    canvas.drawCircle(end, 3, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.line != line || old.fill != fill;
}
