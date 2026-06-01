// lib/presentation/widgets/custom_button.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum CustomButtonVariant { primary, outlined, ghost }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final double height;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.height = 50,
  });

  /// Variante outlined lista para usar directamente
  const CustomButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.height = 50,
  }) : variant = CustomButtonVariant.outlined;

  /// Variante ghost (solo texto + color primario)
  const CustomButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.height = 50,
  }) : variant = CustomButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    switch (variant) {
      case CustomButtonVariant.primary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: disabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: disabled ? AppTheme.border : AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.border,
              disabledForegroundColor: AppTheme.textSub,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _buildChild(Colors.white),
          ),
        );

      case CustomButtonVariant.outlined:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: OutlinedButton(
            onPressed: disabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textMain,
              disabledForegroundColor: AppTheme.textSub,
              side: const BorderSide(color: AppTheme.border, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _buildChild(AppTheme.textMain),
          ),
        );

      case CustomButtonVariant.ghost:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: TextButton(
            onPressed: disabled ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              disabledForegroundColor: AppTheme.textSub,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _buildChild(AppTheme.primary),
          ),
        );
    }
  }

  Widget _buildChild(Color spinnerColor) {
    if (loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}
