import 'package:flutter/material.dart';
import '../theme/theme_compat.dart';

/// Note list item - simple text item
class NoteItem extends StatelessWidget {
  final String note;
  final VoidCallback? onDelete;

  const NoteItem({
    super.key,
    required this.note,
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
        color: AppTheme.white,
        border: Border.all(color: AppTheme.border, width: 1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        children: [
          // Note text
          Expanded(
            child: Text(
              note,
              style: AppTheme.bodySmall,
            ),
          ),

          // Delete button
          if (onDelete != null) ...[
            const SizedBox(width: AppTheme.space8),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 16),
              color: AppTheme.textTertiary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
