import 'package:flutter/material.dart';
import '../theme/theme_compat.dart';

/// Status badge showing W/L/P - monochrome design
class StatusBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;

  const StatusBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
  });

  /// Factory for WIN badge
  factory StatusBadge.win() {
    return const StatusBadge(
      label: 'W',
      backgroundColor: AppTheme.black,
      textColor: AppTheme.white,
    );
  }

  /// Factory for LOSS badge
  factory StatusBadge.loss() {
    return const StatusBadge(
      label: 'L',
      backgroundColor: AppTheme.gray300,
      textColor: AppTheme.gray700,
    );
  }

  /// Factory for PENDING badge
  factory StatusBadge.pending() {
    return const StatusBadge(
      label: 'P',
      backgroundColor: AppTheme.white,
      textColor: AppTheme.gray400,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.white,
        border: Border.all(
          color: backgroundColor == AppTheme.black
              ? AppTheme.black
              : AppTheme.border,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTheme.labelLarge.copyWith(
          color: textColor ?? AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
