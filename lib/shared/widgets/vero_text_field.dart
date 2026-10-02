import 'package:flutter/material.dart';

class VeroTextField extends StatelessWidget {
  const VeroTextField({
    required this.labelText,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.obscureText = false,
    this.onChanged,
    this.validator,
    this.autofillHints,
    super.key,
  });

  final String labelText;
  final TextEditingController? controller;
  final String? hintText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      validator: validator,
      autofillHints: autofillHints,
      autocorrect: !obscureText,
      enableSuggestions: !obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}
