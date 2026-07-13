import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

/// Dialog for picking an accent color from a preset palette.
class ColorPickerDialog extends StatelessWidget {
  final String initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  /// Shows the color picker and returns the selected hex color string.
  static Future<String?> show(
    BuildContext context, {
    required String initialColor,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: initialColor),
    );
  }

  static const List<String> _presetColors = [
    '#6366F1',
    '#8B5CF6',
    '#10B981',
    '#F59E0B',
    '#EC4899',
    '#6B7280',
    '#3B82F6',
    '#9CA3AF',
    '#EF4444',
    '#14B8A6',
    '#F97316',
    '#84CC16',
    '#06B6D4',
    '#A855F7',
    '#64748B',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        '选择主题色',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _presetColors.map((color) {
          final isSelected = color.toUpperCase() == initialColor.toUpperCase();
          final value = int.tryParse(color.replaceFirst('#', '0xFF'));
          final catColor = value != null ? Color(value) : AppColors.accentStart;
          return Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, color),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(18),
                      border: isSelected
                          ? Border.all(color: AppColors.primaryDark, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '取消',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
