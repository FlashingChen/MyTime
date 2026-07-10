import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';

/// Full local record manager reached from the settings page.
class RecordManagementPage extends StatelessWidget {
  const RecordManagementPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('记录管理')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _edit(context),
      child: const Icon(Icons.add),
    ),
    body: BlocBuilder<RecordsBloc, RecordsState>(
      builder: (context, state) {
        final records = state is RecordsLoaded ? state.records : <TimeRecord>[];
        if (records.isEmpty) return const Center(child: Text('暂无记录'));
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final category = CategoryLookup.byId(context, record.categoryId);
            return ListTile(
              title: Text(category.name),
              subtitle: Text(
                '${record.startTime} - ${record.endTime}${record.note == null ? '' : '\n${record.note}'}',
              ),
              isThreeLine: record.note != null,
              onTap: () => _edit(context, record),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, record),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _delete(BuildContext context, TimeRecord record) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      context.read<RecordsBloc>().add(RecordDeleted(record.id));
    }
  }

  Future<void> _edit(BuildContext context, [TimeRecord? initial]) async {
    final categories = CategoryLookup.all(context);
    var categoryId = initial?.categoryId ?? categories.first.id;
    final note = TextEditingController(text: initial?.note ?? '');
    final now = DateTime.now();
    var start = initial?.startTime ?? now.subtract(const Duration(hours: 1));
    var end = initial?.endTime ?? now;
    final saved = await showModalBottomSheet<TimeRecord>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                initial == null ? '新增记录' : '编辑记录',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              DropdownButtonFormField(
                initialValue: categoryId,
                items: categories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => categoryId = value!),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: '备注'),
              ),
              ListTile(
                title: Text('开始：$start'),
                onTap: () async {
                  final value = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: start,
                  );
                  if (value != null) {
                    setState(
                      () => start = DateTime(
                        value.year,
                        value.month,
                        value.day,
                        start.hour,
                        start.minute,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                title: Text('结束：$end'),
                onTap: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(end),
                  );
                  if (value != null) {
                    setState(
                      () => end = DateTime(
                        start.year,
                        start.month,
                        start.day,
                        value.hour,
                        value.minute,
                      ),
                    );
                  }
                },
              ),
              ElevatedButton(
                onPressed: end.isAfter(start)
                    ? () => Navigator.pop(
                        context,
                        TimeRecord(
                          id: initial?.id ?? '',
                          categoryId: categoryId,
                          startTime: start,
                          endTime: end,
                          note: note.text.trim().isEmpty
                              ? null
                              : note.text.trim(),
                          createdAt: initial?.createdAt,
                        ),
                      )
                    : null,
                child: const Text('保存记录'),
              ),
            ],
          ),
        ),
      ),
    );
    note.dispose();
    if (saved != null && context.mounted) {
      context.read<RecordsBloc>().add(
        initial == null ? RecordAdded(saved) : RecordUpdated(saved),
      );
    }
  }
}
