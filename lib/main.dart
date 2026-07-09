import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/blocs/settings/settings.dart';
import 'package:mytime/blocs/timer/timer.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/ui/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(TimeRecordAdapter());
  Hive.registerAdapter(CategoryAdapter());

  final recordsBox = await Hive.openBox<TimeRecord>('records');
  final recordRepo = RecordRepository(recordsBox);
  final settingsRepo = SettingsRepository();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => TimerBloc()),
        BlocProvider(create: (_) => RecordsBloc(recordRepo)..add(RecordsLoaded())),
        BlocProvider(create: (_) => SettingsBloc(settingsRepo)..add(LoadSettings())),
      ],
      child: const AppShell(),
    ),
  );
}