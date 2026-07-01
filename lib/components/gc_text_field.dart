import 'package:flutter/material.dart';

class GCTextField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;

  const GCTextField({
    super.key,
    required this.label,
    this.initialValue,
    this.controller,
    this.validator,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? (initialValue ?? '') : null,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}
