import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../utils/validators.dart';

/// Numeric port input with built-in validation.
class PortInput extends StatelessWidget {
  const PortInput({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PORT',
          style: TextStyle(
            color: AppTheme.of(context).textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          style: TextStyle(
            color: AppTheme.of(context).textPrimary,
            fontFamily: AppTheme.monoFamily,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: '3000',
            suffixText: '1024 - 65535',
            suffixStyle: TextStyle(
              color: AppTheme.of(context).textSecondary,
              fontSize: 10,
            ),
          ),
          onChanged: onChanged,
          validator: (value) {
            final port = int.tryParse(value ?? '');
            return PortValidator.errorMessage(port);
          },
        ),
      ],
    );
  }
}
