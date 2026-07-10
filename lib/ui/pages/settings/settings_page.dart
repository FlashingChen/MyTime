import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/settings/settings_state.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/settings/category_management_page.dart';
import 'package:mytime/ui/pages/settings/record_management_page.dart';
import 'package:mytime/ui/pages/settings/widgets/color_picker.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Settings page with profile, dark mode toggle, and settings list.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            if (state is SettingsLoading || state is SettingsInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is SettingsError) {
              return Center(child: Text(state.message));
            }
            return _buildContent(context, state as SettingsLoaded);
          },
        ),
      ),
    );
  }

  void _onSettingTap(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 功能即将上线'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SettingsLoaded state) {
    final isDark = state.settings.themeMode == 'dark';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          // Profile
          Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.accentStart,
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'MyTime',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2),
                Text(
                  '本地账户',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Dark mode toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDark ? 0.22 : 0.04,
                    ),
                    blurRadius: 3,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dark_mode_outlined,
                        size: 18,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '深色模式',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: isDark,
                    onChanged: (v) {
                      context.read<SettingsBloc>().add(
                        ThemeModeChanged(v ? 'dark' : 'light'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Settings list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDark ? 0.22 : 0.04,
                    ),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsItem(
                    icon: Icons.list_alt_outlined,
                    iconColor: AppColors.primaryDark,
                    label: '记录管理',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecordManagementPage(),
                      ),
                    ),
                  ),
                  _SettingsItem(
                    icon: Icons.category_outlined,
                    iconColor: AppColors.accentStart,
                    label: '分类管理',
                    onTap: () => _openCategoryManagement(context),
                  ),
                  _SettingsItem(
                    icon: Icons.palette_outlined,
                    iconColor: AppColors.success,
                    label: '默认主题色',
                    value: _colorPreview(state.settings.accentColor),
                    onTap: () =>
                        _pickAccentColor(context, state.settings.accentColor),
                  ),
                  _SettingsItem(
                    icon: Icons.smart_toy_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'AI 模型配置',
                    onTap: () => _onSettingTap(context, 'AI 模型配置'),
                  ),
                  _SettingsItem(
                    icon: Icons.upload_outlined,
                    iconColor: AppColors.accentEnd,
                    label: '数据导入导出',
                    onTap: () => _openDataExchange(context),
                  ),
                  _SettingsItem(
                    icon: Icons.info_outline,
                    iconColor: AppColors.textSecondary,
                    label: '关于 MyTime',
                    isLast: true,
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorPreview(String color) {
    final value = int.tryParse(color.replaceFirst('#', '0xFF'));
    final preview = value != null ? Color(value) : AppColors.accentStart;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: preview,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _openCategoryManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryManagementPage()),
    );
  }

  Future<void> _pickAccentColor(BuildContext context, String current) async {
    final picked = await ColorPickerDialog.show(context, initialColor: current);
    if (picked != null && context.mounted) {
      context.read<SettingsBloc>().add(AccentColorChanged(picked));
    }
  }

  void _openDataExchange(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DataExchangeSheet(),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'MyTime',
      applicationVersion: '1.0.0',
      applicationIcon: const CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.accentStart,
        child: Text(
          'M',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      applicationLegalese: '开源免费、纯本地、跨端的时间记录 APP。',
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? value;
  final bool isLast;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.value,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: context.colorScheme.outline)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, size: 18, color: iconColor),
          title: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) ...[value!, const SizedBox(width: 8)],
              SvgIcons.chevronRight(),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _DataExchangeSheet extends StatefulWidget {
  const _DataExchangeSheet();

  @override
  State<_DataExchangeSheet> createState() => _DataExchangeSheetState();
}

class _DataExchangeSheetState extends State<_DataExchangeSheet> {
  bool _exportBusy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                label: Text(_exportBusy ? '导出中...' : '导出 JSON 到剪贴板'),
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
    final records = context.read<RecordsBloc>().state is RecordsLoaded
        ? (context.read<RecordsBloc>().state as RecordsLoaded).records
        : <TimeRecord>[];
    final categories = context.read<CategoriesBloc>().state is CategoriesLoaded
        ? (context.read<CategoriesBloc>().state as CategoriesLoaded).categories
        : <Category>[];

    final payload = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => _categoryToJson(c)).toList(),
      'records': records.map((r) => _recordToJson(r)).toList(),
    };

    final jsonString = _formatJson(payload);
    await Clipboard.setData(ClipboardData(text: jsonString));
    if (mounted) {
      setState(() => _exportBusy = false);
      _showResultDialog(
        '导出成功',
        '已将数据以 JSON 格式复制到剪贴板，包含 ${records.length} 条记录、${categories.length} 个分类。',
      );
    }
  }

  Future<void> _importJson() async {
    final recordsBloc = context.read<RecordsBloc>();
    final categoriesBloc = context.read<CategoriesBloc>();

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        _showResultDialog('无法导入', '剪贴板为空，请先复制 JSON 数据。', isError: true);
      }
      return;
    }

    try {
      final payload = _parseJson(text);
      final recordsJson = payload['records'] as List<dynamic>? ?? [];
      final categoriesJson = payload['categories'] as List<dynamic>? ?? [];

      var importedCategories = 0;
      for (final c in categoriesJson) {
        final category = _categoryFromJson(c as Map<String, dynamic>);
        if (category != null) {
          categoriesBloc.add(CategoryAdded(category));
          importedCategories++;
        }
      }

      var importedRecords = 0;
      for (final r in recordsJson) {
        final record = _recordFromJson(r as Map<String, dynamic>);
        if (record != null) {
          recordsBloc.add(RecordAdded(record));
          importedRecords++;
        }
      }

      if (mounted) {
        _showResultDialog(
          '导入成功',
          '成功导入 $importedRecords 条记录、$importedCategories 个分类。',
        );
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog('导入失败', e.toString(), isError: true);
      }
    }
  }

  void _showResultDialog(String title, String message, {bool isError = false}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
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

  Map<String, dynamic> _categoryToJson(Category c) {
    return {'id': c.id, 'name': c.name, 'color': c.color};
  }

  Category? _categoryFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final color = json['color'] as String?;
    if (id == null || name == null || color == null) return null;
    return Category(id: id, name: name, color: color);
  }

  Map<String, dynamic> _recordToJson(TimeRecord r) {
    return {
      'id': r.id,
      'categoryId': r.categoryId,
      'startTime': r.startTime.toIso8601String(),
      'endTime': r.endTime.toIso8601String(),
      'note': r.note,
    };
  }

  TimeRecord? _recordFromJson(Map<String, dynamic> json) {
    final categoryId = json['categoryId'] as String?;
    final start = json['startTime'] as String?;
    final end = json['endTime'] as String?;
    if (start == null || end == null) return null;
    return TimeRecord(
      id: json['id'] as String? ?? '',
      categoryId: categoryId,
      startTime: DateTime.parse(start),
      endTime: DateTime.parse(end),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> _parseJson(String text) {
    // Minimal JSON parser: strip whitespace and parse manually to avoid adding dart:convert? No, dart:convert is built-in.
    // We use dart:convert via jsonDecode which is available.
    // ignore: avoid_dynamic_calls
    return jsonDecode(text) as Map<String, dynamic>;
  }

  String _formatJson(Map<String, dynamic> payload) {
    // ignore: avoid_dynamic_calls
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
