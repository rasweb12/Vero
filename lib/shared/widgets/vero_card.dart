import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

class VeroCard extends StatelessWidget {
  const VeroCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;

    return Card(
      color: cardTheme.color,
      elevation: cardTheme.elevation,
      margin: cardTheme.margin,
      shape: cardTheme.shape,
      child: Padding(padding: padding, child: child),
    );
  }
}
