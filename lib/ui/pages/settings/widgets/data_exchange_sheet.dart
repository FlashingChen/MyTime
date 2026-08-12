import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/services/data_transfer_service.dart';
import 'package:share_plus/share_plus.dart';

/// Bottom-sheet workflow for exporting and importing a validated JSON backup.
class DataExchangeSheet extends StatefulWidget {
  const DataExchangeSheet({super.key});

  @override
  State<DataExchangeSheet> createState() => _DataExchangeSheetState();
}

class _DataExchangeSheetState extends State<DataExchangeSheet> {
  bool _exportBusy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '数据导入导出',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exportBusy ? null : _exportJson,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(_exportBusy ? '导出中...' : '导出 JSON 文件'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importJson,
                icon: Icon(
                  Icons.upload_outlined,
                  size: 18,
                  color: context.colorScheme.onSurface,
                ),
                label: Text(
                  '从剪贴板导入 JSON',
                  style: TextStyle(color: context.colorScheme.onSurface),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: context.colorScheme.outline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportJson() async {
    setState(() => _exportBusy = true);
    try {
      final recordsState = context.read<RecordsBloc>().state;
      final categoriesState = context.read<CategoriesBloc>().state;
      final records = recordsState is RecordsLoaded
          ? recordsState.records
          : <TimeRecord>[];
      final categories = categoriesState is CategoriesLoaded
          ? categoriesState.categories
          : <Category>[];
      final payload = <String, Object?>{
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'categories': categories.map(_categoryToJson).toList(),
        'records': records.map(_recordToJson).toList(),
      };

      // Export as a file through the share sheet instead of the clipboard:
      // the full dataset (including notes) must not linger in a system-wide,
      // app-readable clipboard.
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(_formatJson(payload))),
              mimeType: 'application/json',
              name: 'mytime-backup.json',
            ),
          ],
          // XFile.fromData ignores `name` on iOS/Android; the override keeps
          // the backup filename in the share sheet.
          fileNameOverrides: const ['mytime-backup.json'],
          subject: 'MyTime 数据备份',
        ),
      );
      if (!mounted ||
          result.status == ShareResultStatus.dismissed ||
          result.status == ShareResultStatus.unavailable) {
        return;
      }
      _showResultDialog(
        '导出成功',
        '已生成包含 ${records.length} 条记录、${categories.length} 个分类的 JSON 备份文件。',
      );
    } catch (_) {
      if (mounted) {
        _showResultDialog('导出失败', '无法生成备份文件，请稍后重试。', isError: true);
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _importJson() async {
    final dataTransferService = context.read<DataTransferService>();
    final categoriesBloc = context.read<CategoriesBloc>();
    final recordsBloc = context.read<RecordsBloc>();
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        _showResultDialog('无法导入', '剪贴板为空，请先复制 JSON 数据。', isError: true);
      }
      return;
    }

    try {
      final result = await dataTransferService.importJson(text);
      if (!mounted) return;
      categoriesBloc.add(const LoadCategories());
      recordsBloc.add(LoadRecords());
      _showResultDialog(
        '导入成功',
        '成功导入 ${result.recordCount} 条记录、${result.categoryCount} 个分类。',
      );
    } on FormatException catch (error) {
      if (mounted) _showResultDialog('导入失败', error.message, isError: true);
    } catch (_) {
      if (mounted) {
        _showResultDialog('导入失败', '导入未完成，原有数据保持不变。请检查备份后重试。', isError: true);
      }
    }
  }

  void _showResultDialog(String title, String message, {bool isError = false}) {
    final color = isError ? Theme.of(context).colorScheme.error : null;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            if (isError) ...[
              Icon(Icons.error_outline, color: color),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Map<String, Object?> _categoryToJson(Category category) => {
    'id': category.id,
    'name': category.name,
    'color': category.color,
  };

  Map<String, Object?> _recordToJson(TimeRecord record) => {
    'id': record.id,
    'categoryId': record.categoryId,
    'startTime': record.startTime.toIso8601String(),
    'endTime': record.endTime.toIso8601String(),
    'note': record.note,
    'createdAt': record.createdAt.toIso8601String(),
  };

  String _formatJson(Map<String, Object?> payload) =>
      const JsonEncoder.withIndent('  ').convert(payload);
}
