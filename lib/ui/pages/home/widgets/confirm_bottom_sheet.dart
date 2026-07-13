import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Bottom sheet for confirming a completed timer session.
class ConfirmBottomSheet extends StatefulWidget {
  final DateTime startTime;
  final DateTime stoppedAt;
  final Duration duration;
  final ValueChanged<TimeRecord> onConfirm;
  final VoidCallback onDiscard;

  const ConfirmBottomSheet({
    super.key,
    required this.startTime,
    required this.stoppedAt,
    required this.duration,
    required this.onConfirm,
    required this.onDiscard,
  });

  @override
  State<ConfirmBottomSheet> createState() => _ConfirmBottomSheetState();
}

class _ConfirmBottomSheetState extends State<ConfirmBottomSheet> {
  Category? _selectedCategory;
  final TextEditingController _noteController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedCategory ??= CategoryLookup.all(context).first;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCategory ?? CategoryLookup.all(context).first;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '记录详情',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text(
              '时间范围',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TimeBlock(
                      label: '开始',
                      text: _formatDuration(
                        Duration(
                          hours: widget.startTime.hour,
                          minutes: widget.startTime.minute,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '→',
                    style: TextStyle(color: AppColors.textHint, fontSize: 14),
                  ),
                  Expanded(
                    child: _TimeBlock(
                      label: '结束',
                      text: _formatDuration(
                        Duration(
                          hours: widget.stoppedAt.hour,
                          minutes: widget.stoppedAt.minute,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '→',
                    style: TextStyle(color: AppColors.textHint, fontSize: 14),
                  ),
                  Expanded(
                    child: _TimeBlock(
                      label: '时长',
                      text: _formatDuration(widget.duration),
                      color: AppColors.accentStart,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '分类',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: CategoryLookup.all(context).map((cat) {
                final isSelected = selected.id == cat.id;
                final catColor = Color(
                  int.parse(cat.color.replaceFirst('#', '0xFF')),
                );
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? catColor : const Color(0xFFE8E8ED),
                        width: 1.5,
                      ),
                      color: isSelected
                          ? catColor.withValues(alpha: 0.06)
                          : Colors.transparent,
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? catColor : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              '备注（可选）',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: '比如写了多少页...',
                hintStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE8E8ED)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE8E8ED)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accentStart),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onConfirm(
                    TimeRecord(
                      id: '',
                      categoryId: selected.id,
                      startTime: widget.startTime,
                      endTime: widget.stoppedAt,
                      note: _noteController.text.trim().isEmpty
                          ? null
                          : _noteController.text.trim(),
                    ),
                  );
                },
                icon: SvgIcons.check(),
                label: const Text(
                  '确认保存',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: widget.onDiscard,
                child: const Text('放弃记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final String label;
  final String text;
  final Color? color;

  const _TimeBlock({required this.label, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
