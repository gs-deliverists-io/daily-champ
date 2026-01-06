import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../theme/theme_compat.dart';

/// Task list tile with checkbox and swipe actions
class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onCopyToTomorrow;

  const TaskTile({
    super.key,
    required this.task,
    this.onToggle,
    this.onTap,
    this.onDelete,
    this.onCopyToTomorrow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Slidable(
      key: Key(task.id),
      // Swipe left: Edit & Delete
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.4,
        children: [
          // Edit action
          CustomSlidableAction(
            onPressed: (context) {
              if (onTap != null) onTap!();
            },
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppTheme.radius12),
            ),
            child: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
          // Delete action
          CustomSlidableAction(
            onPressed: (context) async {
              if (onDelete != null) {
                final confirmed = await _showDeleteConfirmation(context);
                if (confirmed) {
                  onDelete!();
                }
              }
            },
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(AppTheme.radius12),
            ),
            child: const Icon(
              Icons.delete_outline,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
      // Swipe right: Copy to tomorrow
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.25,
        children: [
          CustomSlidableAction(
            onPressed: (context) {
              if (onCopyToTomorrow != null) {
                onCopyToTomorrow!();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Task copied to tomorrow'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                  ),
                );
              }
            },
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            child: const Icon(
              Icons.copy_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.space8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: task.isCompleted
                ? theme.colorScheme.outline.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: task.isCompleted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                  ),
                  child: task.isCompleted
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
              ),

              const SizedBox(width: AppTheme.space12),

              // Task content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with markdown support
                    MarkdownBody(
                      data: task.title,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyLarge?.copyWith(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6)
                              : theme.colorScheme.onSurface,
                        ),
                        a: theme.textTheme.bodyLarge?.copyWith(
                          color: task.isCompleted
                              ? theme.colorScheme.primary.withValues(alpha: 0.6)
                              : theme.colorScheme.primary,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.underline,
                        ),
                      ),
                      onTapLink: (text, href, title) async {
                        if (href != null) {
                          final uri = Uri.parse(href);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }
                      },
                    ),

                    // Time display (smart formatting)
                    if (task.estimatedHours > 0) ...[
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        _formatDuration(task.estimatedHours),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: task.isCompleted
                              ? theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4)
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: const Text('Are you sure you want to delete this task?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Format duration for display
  /// Shows minutes if < 1 hour, hours otherwise
  /// Examples: "30m", "1.5h", "2h"
  String _formatDuration(double hours) {
    if (hours < 1.0) {
      // Less than 1 hour - show as minutes
      final minutes = (hours * 60).round();
      return '${minutes}m';
    } else if (hours == hours.toInt()) {
      // Whole hours - no decimal
      return '${hours.toInt()}h';
    } else {
      // Fractional hours - show one decimal
      return '${hours.toStringAsFixed(1)}h';
    }
  }
}
