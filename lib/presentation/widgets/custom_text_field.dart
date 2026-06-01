// lib/presentation/widgets/custom_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.inputFormatters,
    this.focusNode,
  });

  /// Variante de email con ícono y teclado predefinidos
  const CustomTextField.email({
    super.key,
    this.label = 'Correo electrónico',
    this.hint = 'ejemplo@correo.com',
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
  })  : obscureText = false,
        keyboardType = TextInputType.emailAddress,
        prefixIcon = Icons.email_outlined,
        suffixIcon = null,
        maxLines = 1,
        maxLength = null,
        inputFormatters = null;

  /// Variante de contraseña — muestra/oculta texto internamente
  const CustomTextField.password({
    super.key,
    this.label = 'Contraseña',
    this.hint = '••••••••',
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
  })  : obscureText = true,
        keyboardType = TextInputType.visiblePassword,
        prefixIcon = Icons.lock_outline,
        suffixIcon = null,
        maxLines = 1,
        maxLength = null,
        inputFormatters = null;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  void _toggleObscure() => setState(() => _obscure = !_obscure);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      style: const TextStyle(
        color: AppTheme.textMain,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20, color: AppTheme.textSub)
            : null,
        suffixIcon: _buildSuffixIcon(),
        counterText: '',           // oculta el contador de maxLength
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        fillColor: widget.enabled ? null : AppTheme.surface,
        filled: !widget.enabled,
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    // El campo password gestiona su propio toggle
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: AppTheme.textSub,
        ),
        onPressed: _toggleObscure,
        splashRadius: 18,
      );
    }
    return widget.suffixIcon;
  }
}
