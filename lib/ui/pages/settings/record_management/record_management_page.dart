import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/settings/record_management/widgets/record_editor_sheet.dart';
import 'package:mytime/ui/pages/settings/record_management/widgets/record_list_card.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Full local record manager reached from the settings page.
class RecordManagementPage extends StatelessWidget {
  const RecordManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<RecordsBloc, RecordsState>(
          listenWhen: (_, state) => state is RecordsError,
          listener: (context, state) {
            final error = state as RecordsError;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('记录操作失败：${error.message}')));
          },
          child: Column(
            children: [
              _PageHeader(onAdd: () => _edit(context)),
              Expanded(
                child: BlocBuilder<RecordsBloc, RecordsState>(
                  builder: (context, state) => _buildContent(context, state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, RecordsState state) {
    if (state is RecordsInitial || state is RecordsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is RecordsError) {
      return const Center(child: Text('记录加载失败'));
    }
    final records = (state as RecordsLoaded).records;
    if (records.isEmpty) return const Center(child: Text('暂无记录'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return RecordListCard(
          record: record,
          category: CategoryLookup.byId(context, record.categoryId),
          onEdit: () => _edit(context, record),
          onDelete: () => _delete(context, record),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, TimeRecord record) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
    final saved = await showRecordEditorSheet(
      context,
      initialRecord: initial,
      categories: CategoryLookup.all(context),
    );
    if (saved != null && context.mounted) {
      context.read<RecordsBloc>().add(
        initial == null ? RecordAdded(saved) : RecordUpdated(saved),
      );
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                tooltip: '返回',
                onPressed: () => Navigator.maybePop(context),
                icon: SvgIcons.chevronLeft(color: color),
              ),
            ),
            const Expanded(
              child: Text(
                '记录管理',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                key: const Key('record-management-add'),
                tooltip: '新增记录',
                onPressed: onAdd,
                icon: SvgIcons.add(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
