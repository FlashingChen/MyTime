import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/webdav_sync_adapter.dart';

void main() {
  test('rejects HTTP before credentials can be sent', () {
    expect(
      () => WebDavSyncAdapter(
        endpoint: Uri.parse('http://example.com/mytime.json'),
        username: 'user',
        password: 'secret',
      ),
      throwsArgumentError,
    );
  });

  test('rejects credentials embedded in an endpoint URL', () {
    expect(
      () => WebDavSyncAdapter(
        endpoint: Uri.parse('https://leaked-password@example.com/mytime.json'),
        username: 'user',
        password: 'secret',
      ),
      throwsArgumentError,
    );
  });

  test('pushes a versioned snapshot with basic authorization', () async {
    late String body;
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (method, _, headers, requestBody) async {
        if (method == 'PUT') {
          expect(headers['authorization'], startsWith('Basic '));
          body = requestBody!;
          return const WebDavResponse(201, '');
        }
        return WebDavResponse(200, body, {'etag': '"v1"'});
      },
    );
    await adapter.push(
      SyncSnapshot(
        updatedAt: DateTime(2026, 7, 12),
        categories: [const Category(id: 'work', name: '工作', color: '#123456')],
        records: [
          TimeRecord(
            id: 'r1',
            startTime: DateTime(2026, 7, 12, 9),
            endTime: DateTime(2026, 7, 12, 10),
          ),
        ],
      ),
      ifMatch: null,
      ifNoneMatch: true,
    );
    expect(jsonDecode(body)['version'], 2);
  });

  test('rejects an invalid snapshot before sending a WebDAV request', () async {
    var requests = 0;
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (_, __, ___, ____) async {
        requests++;
        return const WebDavResponse(201, '');
      },
    );
    final invalidSnapshot = SyncSnapshot(
      updatedAt: DateTime.utc(2026, 7, 12),
      categories: [const Category(id: 'work', name: '工作', color: '#123456')],
      records: [
        TimeRecord(
          id: 'invalid',
          categoryId: 'work',
          startTime: DateTime.utc(2026, 7, 12, 10),
          endTime: DateTime.utc(2026, 7, 12, 9),
        ),
      ],
    );

    await expectLater(
      adapter.push(invalidSnapshot, ifMatch: null, ifNoneMatch: true),
      throwsArgumentError,
    );

    expect(requests, 0);
  });

  test('normalizes malformed remote documents to FormatException', () async {
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (_, __, ___, ____) async => const WebDavResponse(
        200,
        '{"version":1,"updatedAt":"2026-07-12T00:00:00Z",'
        '"categories":[],"records":[{"id":42}]}',
      ),
    );

    await expectLater(adapter.pull(), throwsFormatException);
  });

  test('uses If-None-Match when creating a missing document', () async {
    late Map<String, String> headers;
    late String body;
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (method, _, requestHeaders, requestBody) async {
        if (method == 'PUT') {
          headers = requestHeaders;
          body = requestBody!;
        }
        return method == 'PUT'
            ? const WebDavResponse(201, '')
            : WebDavResponse(200, body, {'etag': '"v1"'});
      },
    );

    await adapter.push(_snapshot(), ifMatch: null, ifNoneMatch: true);

    expect(headers['If-None-Match'], '*');
  });

  test('maps an HTTP 412 response to SyncPreconditionFailed', () async {
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (_, __, ___, ____) async => const WebDavResponse(412, ''),
    );

    await expectLater(
      adapter.push(_snapshot(), ifMatch: '"v1"', ifNoneMatch: false),
      throwsA(isA<SyncPreconditionFailed>()),
    );
  });

  test('rejects a no-ETag PUT confirmation with another document', () async {
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (method, _, __, ___) async => switch (method) {
        'PUT' => const WebDavResponse(204, ''),
        'GET' => WebDavResponse(200, jsonEncode(_differentSnapshotDocument()), {
          'etag': '"other"',
        }),
        _ => throw StateError('Unexpected request: $method'),
      },
    );

    await expectLater(
      adapter.push(_snapshot(), ifMatch: '"v1"', ifNoneMatch: false),
      throwsA(isA<SyncPreconditionFailed>()),
    );
  });

  test('rejects a no-ETag PUT confirmation with a matching snapshot', () async {
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (method, _, __, ___) async => switch (method) {
        'PUT' => const WebDavResponse(204, ''),
        'GET' => WebDavResponse(200, jsonEncode(_snapshotDocument())),
        _ => throw StateError('Unexpected request: $method'),
      },
    );

    await expectLater(
      adapter.push(_snapshot(), ifMatch: '"v1"', ifNoneMatch: false),
      throwsA(isA<SyncPreconditionFailed>()),
    );
  });

  test(
    'rejects a confirmation with a different record creation time',
    () async {
      final adapter = WebDavSyncAdapter(
        endpoint: Uri.parse('https://example.com/mytime.json'),
        username: 'user',
        password: 'secret',
        request: (method, _, __, ___) async => switch (method) {
          'PUT' => const WebDavResponse(204, ''),
          'GET' => WebDavResponse(
            200,
            jsonEncode(_differentCreatedAtSnapshotDocument()),
            {'etag': '"other"'},
          ),
          _ => throw StateError('Unexpected request: $method'),
        },
      );

      await expectLater(
        adapter.push(_snapshot(), ifMatch: '"v1"', ifNoneMatch: false),
        throwsA(isA<SyncPreconditionFailed>()),
      );
    },
  );

  test('uses a supported lock token for PUT and unlocks it', () async {
    final requests = <String, Map<String, String>>{};
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (method, _, headers, __) async {
        requests[method] = headers;
        return switch (method) {
          'LOCK' => const WebDavResponse(200, '', {
            'lock-token': 'opaquelocktoken:token',
          }),
          'PUT' => const WebDavResponse(204, '', {'etag': '"v2"'}),
          _ => const WebDavResponse(204, ''),
        };
      },
    );

    final lock = await adapter.lock();
    await adapter.push(_snapshot(), ifMatch: '"v1"', ifNoneMatch: false);
    await adapter.unlock(lock!);

    expect(requests['PUT']!['If'], '(<opaquelocktoken:token>)');
    expect(requests['UNLOCK']!['Lock-Token'], 'opaquelocktoken:token');
  });

  test('normalizes a bracketed lock token for PUT and unlock', () async {
    final requests = <String, Map<String, String>>{};
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (method, _, headers, __) async {
        requests[method] = headers;
        return switch (method) {
          'LOCK' => const WebDavResponse(200, '', {
            'lock-token': '<opaquelocktoken:token>',
          }),
          'PUT' => const WebDavResponse(204, '', {'etag': '"v2"'}),
          _ => const WebDavResponse(204, ''),
        };
      },
    );

    final lock = await adapter.lock();
    await adapter.push(_snapshot(), ifMatch: '"v1"', ifNoneMatch: false);
    await adapter.unlock(lock!);

    expect(requests['PUT']!['If'], '(<opaquelocktoken:token>)');
    expect(requests['UNLOCK']!['Lock-Token'], 'opaquelocktoken:token');
  });

  test('throws for LOCK contention without sending a PUT', () async {
    var putRequests = 0;
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (method, _, __, ___) async {
        if (method == 'LOCK') return const WebDavResponse(423, '');
        if (method == 'PUT') {
          putRequests++;
          return const WebDavResponse(204, '');
        }
        throw StateError('Unexpected request: $method');
      },
    );

    await expectLater(
      adapter.lock(),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          'WebDAV LOCK failed: 423',
        ),
      ),
    );

    expect(putRequests, 0);
  });
}

SyncSnapshot _snapshot() => SyncSnapshot(
  updatedAt: DateTime.utc(2026, 7, 22),
  categories: const [Category(id: 'work', name: '工作', color: '#123456')],
  records: [
    TimeRecord(
      id: 'record',
      categoryId: 'work',
      startTime: DateTime.utc(2026, 7, 22, 9),
      endTime: DateTime.utc(2026, 7, 22, 10),
    ),
  ],
);

Map<String, Object?> _snapshotDocument() => {
  'version': 2,
  'updatedAt': '2026-07-22T00:00:00.000Z',
  'categories': [
    {'id': 'work', 'name': '工作', 'color': '#123456'},
  ],
  'records': [
    {
      'id': 'record',
      'categoryId': 'work',
      'startTime': '2026-07-22T09:00:00.000Z',
      'endTime': '2026-07-22T10:00:00.000Z',
      'note': null,
      'createdAt': '2026-07-22T09:00:00.000Z',
    },
  ],
  'metadata': {'records': {}, 'categories': {}},
};

Map<String, Object?> _differentSnapshotDocument() => {
  'version': 2,
  'updatedAt': '2026-07-23T00:00:00.000Z',
  'categories': [
    {'id': 'work', 'name': '工作', 'color': '#123456'},
  ],
  'records': [],
  'metadata': {'records': {}, 'categories': {}},
};

Map<String, Object?> _differentCreatedAtSnapshotDocument() => {
  'version': 2,
  'updatedAt': '2026-07-22T00:00:00.000Z',
  'categories': [
    {'id': 'work', 'name': '工作', 'color': '#123456'},
  ],
  'records': [
    {
      'id': 'record',
      'categoryId': 'work',
      'startTime': '2026-07-22T09:00:00.000Z',
      'endTime': '2026-07-22T10:00:00.000Z',
      'note': null,
      'createdAt': '2026-07-23T09:00:00.000Z',
    },
  ],
  'metadata': {'records': {}, 'categories': {}},
};
