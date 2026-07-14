import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Compact record summary with accessible edit and delete actions.
class RecordListCard extends StatelessWidget {
  const RecordListCard({
    super.key,
    required this.record,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final TimeRecord record;
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _parseColor(category.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: categoryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatRecordRange(record),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (record.note != null && record.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          record.note!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 44,
                      child: IconButton(
                        key: ValueKey<String>('record-edit-${record.id}'),
                        tooltip: '编辑记录',
                        onPressed: onEdit,
                        icon: SvgIcons.edit(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox.square(
                      dimension: 44,
                      child: IconButton(
                        key: ValueKey<String>('record-delete-${record.id}'),
                        tooltip: '删除记录',
                        onPressed: onDelete,
                        icon: SvgIcons.delete(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _parseColor(String color) {
  final value = int.tryParse(color.replaceFirst('#', '0xFF'));
  return value != null ? Color(value) : AppColors.accentStart;
}

String _formatRecordRange(TimeRecord record) {
  final startDate = _formatDate(record.startTime);
  final endDate = _formatDate(record.endTime);
  final startTime = _formatTime(record.startTime);
  final endTime = _formatTime(record.endTime);
  if (startDate == endDate) return '$startDate $startTime–$endTime';
  return '$startDate $startTime – $endDate $endTime';
}

String _formatDate(DateTime value) =>
    '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';

String _formatTime(DateTime value) =>
    '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');
