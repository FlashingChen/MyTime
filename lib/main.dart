import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/blocs/settings/settings.dart';
import 'package:mytime/blocs/timer/timer.dart';
import 'package:mytime/core/utils/hive_helper.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/ui/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveHelper.init();

  final recordsBox = await HiveHelper.openRecordsBox();
  final categoriesBox = await HiveHelper.openCategoriesBox();
  final recordRepo = RecordRepository(recordsBox);
  final categoryRepo = CategoryRepository(categoriesBox);
  final settingsRepo = SettingsRepository();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => TimerBloc()),
        BlocProvider(
          create: (_) => RecordsBloc(recordRepo)..add(LoadRecords()),
        ),
        BlocProvider(
          create: (_) =>
              CategoriesBloc(categoryRepo, recordRepo)..add(LoadCategories()),
        ),
        BlocProvider(
          create: (_) => SettingsBloc(settingsRepo)..add(LoadSettings()),
        ),
      ],
      child: const AppShell(),
    ),
  );
}
