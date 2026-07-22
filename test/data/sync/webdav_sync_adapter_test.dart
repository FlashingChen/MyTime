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
        expect(method, 'PUT');
        expect(headers['authorization'], startsWith('Basic '));
        body = requestBody!;
        return const WebDavResponse(201, '');
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
}
