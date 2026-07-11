import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ActiveTimerRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = ActiveTimerRepository();
  });

  group('ActiveTimerRepository', () {
    test('getStartTime returns null when nothing is saved', () async {
      expect(await repo.getStartTime(), isNull);
    });

    test('saveStartTime persists the timestamp', () async {
      final start = DateTime(2026, 7, 11, 14, 30);
      await repo.saveStartTime(start);
      final result = await repo.getStartTime();
      expect(result, isNotNull);
      expect(result!.toIso8601String(), start.toIso8601String());
    });

    test('clear removes the persisted timestamp', () async {
      await repo.saveStartTime(DateTime(2026, 7, 11, 14, 30));
      await repo.clear();
      expect(await repo.getStartTime(), isNull);
    });

    test('saveStartTime overwrites previous value', () async {
      await repo.saveStartTime(DateTime(2026, 7, 11, 10, 0));
      await repo.saveStartTime(DateTime(2026, 7, 11, 12, 0));
      final result = await repo.getStartTime();
      expect(result, isNotNull);
      expect(result!.hour, 12);
    });
  });
}
