import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/settings/settings.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/core/theme/app_theme.dart';
import 'package:mytime/ui/pages/home/home_page.dart';
import 'package:mytime/ui/pages/settings/settings_page.dart';
import 'package:mytime/ui/pages/stats/stats_page.dart';
import 'package:mytime/ui/pages/timeline/timeline_page.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Root app shell with bottom navigation.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final settings = settingsState is SettingsLoaded
            ? settingsState.settings
            : const AppSettings();
        final themeMode = _parseThemeMode(settings.themeMode);

        return MaterialApp(
          title: 'MyTime',
          theme: AppTheme.light(accentColor: settings.accentColor),
          darkTheme: AppTheme.dark(accentColor: settings.accentColor),
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          home: const _MainShell(),
        );
      },
    );
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  final _pages = [
    const HomePage(),
    const TimelinePage(),
    const StatsPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: context.colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: [
            BottomNavigationBarItem(icon: SvgIcons.home(), label: '首页'),
            BottomNavigationBarItem(icon: SvgIcons.timeline(), label: '时间线'),
            BottomNavigationBarItem(icon: SvgIcons.stats(), label: '统计'),
            BottomNavigationBarItem(icon: SvgIcons.profile(), label: '我的'),
          ],
          selectedItemColor: context.colorScheme.primary,
          unselectedItemColor: context.colorScheme.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          backgroundColor: context.colorScheme.surface,
          elevation: 0,
        ),
      ),
    );
  }
}
