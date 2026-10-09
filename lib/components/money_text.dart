import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../theme/colors.dart';

/// Money typeset like a ledger: the currency and cents are smaller and
/// quieter so the whole amount reads first — "RM 15,240.50".
///
/// IBM Plex digits are tabular, so columns of amounts line up.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.color,
    this.showSign = false,
    this.emphasis = MoneyEmphasis.normal,
  });

  final double amount;
  final TextStyle? style;
  final Color? color;

  /// Prefix with + / − (for money in / out).
  final bool showSign;
  final MoneyEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final base = style ??
        switch (emphasis) {
          MoneyEmphasis.hero => Theme.of(context).textTheme.displaySmall!,
          MoneyEmphasis.large => Theme.of(context).textTheme.titleLarge!,
          MoneyEmphasis.normal => Theme.of(context)
              .textTheme
              .bodyLarge!
              .copyWith(fontWeight: FontWeight.w600),
        };
    final main = base.copyWith(color: color ?? base.color);
    final size = main.fontSize ?? 14;
    final minor = main.copyWith(
      fontSize: size * 0.62,
      fontWeight: FontWeight.w500,
      color: color?.withOpacity(0.7) ?? context.ledger.muted,
    );

    final negative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final whole = _group(fixed.substring(0, dot));
    final cents = fixed.substring(dot);
    final sign = negative ? '−' : (showSign && amount > 0 ? '+' : '');

    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$sign${Constants.currency} ', style: minor),
        TextSpan(text: whole, style: main),
        TextSpan(text: cents, style: minor),
      ]),
      maxLines: 1,
      softWrap: false,
      semanticsLabel: '${negative ? 'minus ' : ''}${Constants.currency} $whole$cents',
    );
  }

  static String _group(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return b.toString();
  }
}

enum MoneyEmphasis { normal, large, hero }
