import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/settings/settings.dart';
import 'package:mytime/core/constants/app_colors.dart';
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
        final themeMode = settingsState is SettingsLoaded
            ? (settingsState.settings.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light)
            : ThemeMode.light;

        return MaterialApp(
          title: 'MyTime',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          home: const _MainShell(),
        );
      },
    );
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
          border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5))),
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
          selectedItemColor: AppColors.primaryDark,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}