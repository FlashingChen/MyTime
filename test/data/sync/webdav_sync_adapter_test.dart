import 'dart:convert';

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
        return const WebDavResponse(200, '{}', {'etag': '"v1"'});
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
    final adapter = WebDavSyncAdapter(
      endpoint: Uri.parse('https://example.com/mytime.json'),
      username: 'user',
      password: 'secret',
      request: (method, _, requestHeaders, ___) async {
        if (method == 'PUT') headers = requestHeaders;
        return method == 'PUT'
            ? const WebDavResponse(201, '')
            : const WebDavResponse(200, '{}', {'etag': '"v1"'});
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
