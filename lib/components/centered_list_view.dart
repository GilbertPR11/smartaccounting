import 'package:flutter/material.dart';

import '../config/layout.dart';

/// A ListView whose content is centred and capped at [maxWidth].
class CenteredListView extends StatelessWidget {
  const CenteredListView({
    super.key,
    required this.children,
    this.maxWidth = 960,
    this.top = 8,
    this.bottom = 24,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final pad = sidePadding(c.maxWidth, maxWidth: maxWidth);
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, top, pad, bottom),
        children: children,
      );
    });
  }
}
