import 'package:flutter/material.dart';

/// Puts hairline dividers between list rows (not around them).
/// [indent] lines the divider up with the row text, past the leading badge.
List<Widget> divided(List<Widget> items, Color color, {double indent = 72}) => [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) Divider(height: 1, indent: indent, color: color),
        items[i],
      ],
    ];
