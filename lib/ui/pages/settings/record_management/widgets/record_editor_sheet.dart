import 'package:flutter/material.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';

/// Opens the shared form for creating or editing a local time record.
Future<TimeRecord?> showRecordEditorSheet(
  BuildContext context, {
  TimeRecord? initialRecord,
  required List<Category> categories,
  DateTime? now,
}) {
  assert(categories.isNotEmpty, 'A record requires at least one category.');
  return showModalBottomSheet<TimeRecord>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => RecordEditorSheet(
      initialRecord: initialRecord,
      categories: categories,
      now: now,
    ),
  );
}

/// Bottom-sheet form for creating or editing one local time record.
class RecordEditorSheet extends StatefulWidget {
  const RecordEditorSheet({
    super.key,
    this.initialRecord,
    required this.categories,
    this.now,
  });

  final TimeRecord? initialRecord;
  final List<Category> categories;
  final DateTime? now;

  @override
  State<RecordEditorSheet> createState() => _RecordEditorSheetState();
}

class _RecordEditorSheetState extends State<RecordEditorSheet> {
  late final TextEditingController _noteController;
  late String _categoryId;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final current = widget.now ?? DateTime.now();
    _start =
        widget.initialRecord?.startTime ??
        current.subtract(const Duration(hours: 1));
    _end = widget.initialRecord?.endTime ?? current;
    _noteController = TextEditingController(
      text: widget.initialRecord?.note ?? '',
    );
    final initialCategoryId = widget.initialRecord?.categoryId;
    _categoryId =
        widget.categories.any((category) => category.id == initialCategoryId)
        ? initialCategoryId!
        : widget.categories.first.id;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = _end.isAfter(_start);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              widget.initialRecord == null ? '新增记录' : '编辑记录',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: '分类'),
            items: widget.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _categoryId = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('record-editor-note'),
            controller: _noteController,
            decoration: const InputDecoration(labelText: '备注（可选）'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          _EndpointFields(
            label: '开始时间',
            value: _start,
            dateKey: const Key('record-editor-start-date'),
            timeKey: const Key('record-editor-start-time'),
            onPickDate: () => _pickDate(isStart: true),
            onPickTime: () => _pickTime(isStart: true),
          ),
          const SizedBox(height: 20),
          _EndpointFields(
            label: '结束时间',
            value: _end,
            dateKey: const Key('record-editor-end-date'),
            timeKey: const Key('record-editor-end-time'),
            onPickDate: () => _pickDate(isStart: false),
            onPickTime: () => _pickTime(isStart: false),
          ),
          if (!isValid) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                '结束时间必须晚于开始时间',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('record-editor-save'),
              onPressed: isValid ? _save : null,
              child: const Text('保存记录'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      initialDate: current,
    );
    if (value == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = _withDate(_start, value);
      } else {
        _end = _withDate(_end, value);
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = _withTime(_start, value);
      } else {
        _end = _withTime(_end, value);
      }
    });
  }

  void _save() {
    Navigator.pop(
      context,
      TimeRecord(
        id: widget.initialRecord?.id ?? '',
        categoryId: _categoryId,
        startTime: _start,
        endTime: _end,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: widget.initialRecord?.createdAt,
      ),
    );
  }
}

class _EndpointFields extends StatelessWidget {
  const _EndpointFields({
    required this.label,
    required this.value,
    required this.dateKey,
    required this.timeKey,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String label;
  final DateTime value;
  final Key dateKey;
  final Key timeKey;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PickerField(
                key: dateKey,
                semanticsLabel: '$label，选择日期',
                value: _formatDate(value),
                onTap: onPickDate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _PickerField(
                key: timeKey,
                semanticsLabel: '$label，选择时间',
                value: _formatTime(value),
                onTap: onPickTime,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.semanticsLabel,
    required this.value,
    required this.onTap,
  });

  final String semanticsLabel;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel,
      value: value,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _withDate(DateTime current, DateTime date) =>
    DateTime(date.year, date.month, date.day, current.hour, current.minute);

DateTime _withTime(DateTime current, TimeOfDay time) =>
    DateTime(current.year, current.month, current.day, time.hour, time.minute);

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatDate(DateTime value) =>
    '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';

String _formatTime(DateTime value) =>
    '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
