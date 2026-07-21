import 'package:flutter/material.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/data/models/category.dart';

/// Bottom sheet for multi-selecting categories in click-order.
///
/// [selectedIds] is ordered by selection: first clicked = first in list = bottom of stack.
/// [onChanged] receives the new ordered list when the user taps a row.
class CategoryFilterSheet extends StatelessWidget {
  final List<Category> categories;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const CategoryFilterSheet({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '选择分类（点击顺序决定堆叠顺序）',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '已选 ${selectedIds.length} 个分类',
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...categories.map((cat) => _buildRow(context, cat)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, Category cat) {
    final selected = selectedIds.contains(cat.id);
    return InkWell(
      onTap: () {
        if (selected) {
          if (selectedIds.length <= 1) return;
          onChanged(selectedIds.where((id) => id != cat.id).toList());
        } else {
          onChanged([...selectedIds, cat.id]);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Color(int.parse(cat.color.replaceFirst('#', '0xFF')))
                      : context.colorScheme.outline,
                  width: 2,
                ),
                color: selected
                    ? Color(int.parse(cat.color.replaceFirst('#', '0xFF')))
                        .withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
              child: selected
                  ? Center(
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: Color(int.parse(cat.color.replaceFirst('#', '0xFF'))),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(int.parse(cat.color.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? context.colorScheme.onSurface
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '#${selectedIds.indexOf(cat.id) + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
