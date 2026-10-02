import 'package:flutter/material.dart';

enum VeroButtonVariant { primary, secondary, ghost }

class VeroButton extends StatelessWidget {
  const VeroButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = VeroButtonVariant.primary;

  const VeroButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = VeroButtonVariant.secondary;

  const VeroButton.ghost({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = VeroButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final VeroButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      VeroButtonVariant.primary => _buildElevatedButton(),
      VeroButtonVariant.secondary => _buildOutlinedButton(),
      VeroButtonVariant.ghost => _buildTextButton(),
    };
  }

  Widget _buildElevatedButton() {
    if (icon == null) {
      return ElevatedButton(onPressed: onPressed, child: Text(label));
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildOutlinedButton() {
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildTextButton() {
    if (icon == null) {
      return TextButton(onPressed: onPressed, child: Text(label));
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
