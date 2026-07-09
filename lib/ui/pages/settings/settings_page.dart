import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/settings/settings_state.dart';
import 'package:mytime/core/constants/app_colors.dart';
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

  Widget _buildContent(BuildContext context, SettingsLoaded state) {
    final isDark = state.settings.themeMode == 'dark';

    return Column(
      children: [
        // Profile
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.accentStart,
                child: Text('M', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              SizedBox(height: 10),
              Text('MyTime', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text('本地账户', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        // Dark mode toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3)]),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.dark_mode_outlined, size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: 10),
                    const Text('深色模式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
                Switch(
                  value: isDark,
                  onChanged: (v) {
                    context.read<SettingsBloc>().add(ThemeModeChanged(v ? 'dark' : 'light'));
                  },
                  activeThumbColor: AppColors.accentStart,
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
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3)]),
            child: Column(
              children: [
                _SettingsItem(icon: Icons.category_outlined, iconColor: AppColors.accentStart, label: '分类管理'),
                _SettingsItem(icon: Icons.palette_outlined, iconColor: AppColors.success, label: '默认主题色'),
                _SettingsItem(icon: Icons.smart_toy_outlined, iconColor: const Color(0xFF8B5CF6), label: 'AI 模型配置'),
                _SettingsItem(icon: Icons.upload_outlined, iconColor: AppColors.accentEnd, label: '数据导入导出'),
                _SettingsItem(icon: Icons.info_outline, iconColor: AppColors.textSecondary, label: '关于 MyTime', isLast: true),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isLast;

  const _SettingsItem({required this.icon, required this.iconColor, required this.label, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ListTile(
        leading: Icon(icon, size: 18, color: iconColor),
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: SvgIcons.chevronRight(),
        onTap: () {},
      ),
    );
  }
}