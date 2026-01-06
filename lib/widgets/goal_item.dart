import 'package:flutter/material.dart';
import '../theme/theme_compat.dart';

/// Goal list item - simple bullet point
class GoalItem extends StatelessWidget {
  final String goal;
  final VoidCallback? onDelete;

  const GoalItem({
    super.key,
    required this.goal,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      margin: const EdgeInsets.only(bottom: AppTheme.space8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        children: [
          // Bullet
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.black,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: AppTheme.space12),

          // Goal text
          Expanded(
            child: Text(
              goal,
              style: AppTheme.bodyMedium,
            ),
          ),

          // Delete button
          if (onDelete != null) ...[
            const SizedBox(width: AppTheme.space8),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 18),
              color: AppTheme.textTertiary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
