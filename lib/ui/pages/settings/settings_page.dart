import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/settings/settings_state.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/ui/pages/settings/category_management_page.dart';
import 'package:mytime/ui/pages/settings/record_management/record_management_page.dart';
import 'package:mytime/ui/pages/settings/widgets/color_picker.dart';
import 'package:mytime/ui/pages/settings/widgets/ai_model_config_sheet.dart';
import 'package:mytime/ui/pages/settings/widgets/data_exchange_sheet.dart';
import 'package:mytime/ui/pages/settings/widgets/webdav_sync_sheet.dart';
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
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.message),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.read<SettingsBloc>().add(
                        const LoadSettings(),
                      ),
                      child: const Text('重新加载'),
                    ),
                  ],
                ),
              );
            }
            return _buildContent(context, state as SettingsLoaded);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SettingsLoaded state) {
    final isDark = state.settings.themeMode == 'dark';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          if (state.saveErrorMessage != null)
            Semantics(
              liveRegion: true,
              label: state.saveErrorMessage,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.saveErrorMessage!,
                  style: TextStyle(
                    color: context.colorScheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
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
          // Timer reminder settings
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                            color: context.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '计时提醒',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: state.settings.reminderEnabled,
                        onChanged: (v) {
                          context.read<SettingsBloc>().add(
                            ReminderSettingsChanged(
                              enabled: v,
                              intervalMinutes:
                                  state.settings.reminderIntervalMinutes,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (state.settings.reminderEnabled) ...[
                    const SizedBox(height: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _pickReminderInterval(
                          context,
                          state.settings.reminderIntervalMinutes,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '提醒间隔',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${state.settings.reminderIntervalMinutes} 分钟',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(width: 4),
                                  SvgIcons.chevronRight(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '计时开始后每隔一段时间提醒一次，避免忘记停止计时。',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                    value:
                        state.settings.aiModel == null ||
                            state.settings.aiModel!.isEmpty
                        ? null
                        : Text(
                            state.settings.aiModel!,
                            style: TextStyle(
                              color: context.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                    onTap: () =>
                        AiModelConfigSheet.show(context, state.settings),
                  ),
                  _SettingsItem(
                    icon: Icons.upload_outlined,
                    iconColor: AppColors.accentEnd,
                    label: '数据导入导出',
                    onTap: () => _openDataExchange(context),
                  ),
                  _SettingsItem(
                    icon: Icons.cloud_sync_outlined,
                    iconColor: const Color(0xFF0EA5E9),
                    label: 'WebDAV 同步',
                    value: state.settings.hasWebDavConfiguration
                        ? Text(
                            '已配置',
                            style: TextStyle(
                              color: context.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    onTap: () => WebDavSyncSheet.show(context, state.settings),
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
      builder: (_) => const DataExchangeSheet(),
    );
  }

  /// Preset reminder intervals offered in the picker, in minutes.
  static const _reminderIntervals = [10, 15, 20, 30, 45, 60, 90, 120];

  Future<void> _pickReminderInterval(
    BuildContext context,
    int current,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Material(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    '提醒间隔',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _reminderIntervals
                        .map(
                          (minutes) => ListTile(
                            dense: true,
                            title: Text('$minutes 分钟'),
                            trailing: minutes == current
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Theme.of(
                                      sheetContext,
                                    ).colorScheme.primary,
                                  )
                                : null,
                            onTap: () =>
                                Navigator.of(sheetContext).pop(minutes),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && context.mounted) {
      context.read<SettingsBloc>().add(
        ReminderSettingsChanged(enabled: true, intervalMinutes: picked),
      );
    }
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
