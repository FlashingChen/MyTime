import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/foreground_sync_ownership.dart';
import 'package:mytime/data/sync/sync_execution_lock_port.dart';
import 'package:mytime/main.dart';

void main() {
  test('treats a recent heartbeat as an active foreground owner', () async {
    final store = _MemoryPreferences();
    final ownership = ForegroundSyncOwnership(
      preferences: store,
      clock: () => DateTime.utc(2026, 7, 24, 9),
    );

    await ownership.activate();

    expect(await ownership.isForegroundActive(), isTrue);
  });

  test('treats a heartbeat older than 90 seconds as inactive', () async {
    final store = _MemoryPreferences()
      ..values['webdav.foreground.heartbeat'] = DateTime.utc(
        2026,
        7,
        24,
        8,
        58,
        29,
      ).toIso8601String();
    final ownership = ForegroundSyncOwnership(
      preferences: store,
      clock: () => DateTime.utc(2026, 7, 24, 9),
    );

    expect(await ownership.isForegroundActive(), isFalse);
  });

  test(
    'treats a heartbeat dated after the current clock as inactive',
    () async {
      final store = _MemoryPreferences()
        ..values[ForegroundSyncOwnership.heartbeatKey] = DateTime.utc(
          2026,
          7,
          24,
          9,
          0,
          1,
        ).toIso8601String();
      final ownership = ForegroundSyncOwnership(
        preferences: store,
        clock: () => DateTime.utc(2026, 7, 24, 9),
      );

      expect(await ownership.isForegroundActive(), isFalse);
    },
  );

  test('removes its heartbeat when deactivated', () async {
    final store = _MemoryPreferences();
    final ownership = ForegroundSyncOwnership(preferences: store);
    await ownership.activate();

    await ownership.deactivate();

    expect(store.values['webdav.foreground.heartbeat'], isNull);
  });

  test(
    'activates foreground ownership before initializing local storage',
    () async {
      final order = <String>[];
      final allowActivation = Completer<void>();
      final startup = initializeForegroundOwnedStorage(
        lock: _OrderingLock(order),
        activateForegroundOwnership: () async {
          order.add('activate-started');
          await allowActivation.future;
          order.add('activate-completed');
        },
        initializeHive: () async => order.add('hive'),
        initializeWorkmanager: () async => order.add('workmanager'),
        openBoxes: () async {
          order.add('boxes');
          return null;
        },
      );

      await Future<void>.delayed(Duration.zero);
      expect(order, ['activate-started']);

      allowActivation.complete();
      await startup;

      expect(order, [
        'activate-started',
        'activate-completed',
        'lock-acquire:null',
        'hive',
        'workmanager',
        'boxes',
        'lock-release:startup-token',
      ]);
    },
  );

  test(
    'removes the heartbeat after a pending refresh is deactivated',
    () async {
      final store = _DelayedPreferences();
      final owner = ForegroundSyncLifecycleOwner(
        ForegroundSyncOwnership(preferences: store),
      );

      owner.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await store.refreshStarted.future;
      owner.didChangeAppLifecycleState(AppLifecycleState.paused);
      store.allowRefresh.complete();

      await store.deactivated.future;

      expect(store.values[ForegroundSyncOwnership.heartbeatKey], isNull);
    },
  );

  test('deactivates after a failed lifecycle refresh', () async {
    final store = _FailingRefreshPreferences();
    final owner = ForegroundSyncLifecycleOwner(
      ForegroundSyncOwnership(preferences: store),
    );

    owner.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await store.refreshAttempted.future;
    owner.didChangeAppLifecycleState(AppLifecycleState.paused);

    await store.deactivated.future;

    expect(store.values[ForegroundSyncOwnership.heartbeatKey], isNull);
  });
}

class _OrderingLock implements SyncExecutionLockPort {
  _OrderingLock(this.order);

  final List<String> order;

  @override
  Future<String> acquire({int? timeoutMillis}) async {
    order.add('lock-acquire:$timeoutMillis');
    return 'startup-token';
  }

  @override
  Future<bool> release(String token) async {
    order.add('lock-release:$token');
    return true;
  }
}

class _MemoryPreferences implements PreferencesStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _DelayedPreferences extends _MemoryPreferences {
  final refreshStarted = Completer<void>();
  final allowRefresh = Completer<void>();
  final deactivated = Completer<void>();

  @override
  Future<void> setString(String key, String value) async {
    refreshStarted.complete();
    await allowRefresh.future;
    await super.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await super.remove(key);
    deactivated.complete();
  }
}

class _FailingRefreshPreferences extends _MemoryPreferences {
  final refreshAttempted = Completer<void>();
  final deactivated = Completer<void>();
  bool _hasFailedRefresh = false;

  @override
  Future<void> setString(String key, String value) async {
    if (!_hasFailedRefresh) {
      _hasFailedRefresh = true;
      refreshAttempted.complete();
      throw StateError('refresh failed');
    }
    await super.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await super.remove(key);
    deactivated.complete();
  }
}
