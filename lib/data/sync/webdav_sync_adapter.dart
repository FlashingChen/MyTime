import 'dart:convert';
import 'dart:io';

import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_metadata.dart';

/// Normalized response returned by an injectable WebDAV transport.
class WebDavResponse {
  const WebDavResponse(this.statusCode, this.body, [this.headers = const {}]);
  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

/// Injectable HTTP transport used to isolate WebDAV protocol tests.
typedef WebDavRequest =
    Future<WebDavResponse> Function(
      String method,
      Uri uri,
      Map<String, String> headers,
      String? body,
    );

/// HTTPS WebDAV implementation storing one versioned MyTime JSON document.
class WebDavSyncAdapter implements SyncPort {
  WebDavSyncAdapter({
    required Uri endpoint,
    required String username,
    required String password,
    WebDavRequest? request,
  }) : _endpoint = _validateEndpoint(endpoint),
       _authorization = _basicAuthorization(username, password),
       _request = request ?? _httpRequest;

  final Uri _endpoint;
  final String _authorization;
  final WebDavRequest _request;
  String? _activeLockToken;

  @override
  Future<RemoteSyncDocument?> pull() async {
    final response = await _request('GET', _endpoint, _headers, null);
    if (response.statusCode == HttpStatus.notFound) {
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('WebDAV GET failed: ${response.statusCode}');
    }
    return RemoteSyncDocument(
      snapshot: _decode(response.body),
      eTag: response.headers['etag'],
    );
  }

  @override
  Future<String?> push(
    SyncSnapshot snapshot, {
    required String? ifMatch,
    required bool ifNoneMatch,
  }) async {
    snapshot.validate();
    final response = await _request('PUT', _endpoint, {
      ..._headers,
      if (ifMatch != null) 'If-Match': ifMatch,
      if (ifNoneMatch) 'If-None-Match': '*',
      if (_activeLockToken != null) 'If': '(<$_activeLockToken>)',
    }, jsonEncode(_encode(snapshot)));
    if (response.statusCode == HttpStatus.preconditionFailed) {
      throw const SyncPreconditionFailed();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('WebDAV PUT failed: ${response.statusCode}');
    }
    return response.headers['etag'];
  }

  @override
  Future<SyncLock?> lock() async {
    final response = await _request(
      'LOCK',
      _endpoint,
      {..._headers, 'Timeout': 'Second-30'},
      '''<?xml version="1.0" encoding="utf-8"?><D:lockinfo xmlns:D="DAV:"><D:lockscope><D:exclusive/></D:lockscope><D:locktype><D:write/></D:locktype><D:owner>MyTime</D:owner></D:lockinfo>''',
    );
    if (response.statusCode == HttpStatus.notImplemented ||
        response.statusCode == HttpStatus.methodNotAllowed) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('WebDAV LOCK failed: ${response.statusCode}');
    }
    final token = response.headers['lock-token'];
    if (token == null || token.isEmpty) {
      throw const FormatException(
        'WebDAV LOCK response did not include Lock-Token',
      );
    }
    _activeLockToken = token;
    return SyncLock(token);
  }

  @override
  Future<void> unlock(SyncLock lock) async {
    final response = await _request('UNLOCK', _endpoint, {
      ..._headers,
      'Lock-Token': lock.token,
    }, null);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('WebDAV UNLOCK failed: ${response.statusCode}');
    }
    if (_activeLockToken == lock.token) {
      _activeLockToken = null;
    }
  }

  Map<String, String> get _headers => {
    HttpHeaders.authorizationHeader: _authorization,
    HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
  };

  static Future<WebDavResponse> _httpRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null) request.write(body);
      final response = await request.close().timeout(
        const Duration(minutes: 2),
      );
      return WebDavResponse(
        response.statusCode,
        await utf8.decoder.bind(response).join(),
        _responseHeaders(response.headers),
      );
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, String> _responseHeaders(HttpHeaders headers) {
    final values = <String, String>{};
    headers.forEach((name, entries) {
      values[name.toLowerCase()] = entries.join(',');
    });
    return values;
  }

  static Uri _validateEndpoint(Uri endpoint) {
    if (endpoint.scheme != 'https' ||
        !endpoint.hasAuthority ||
        endpoint.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'must be an HTTPS WebDAV URL without embedded credentials',
      );
    }
    return endpoint;
  }

  static String _basicAuthorization(String username, String password) {
    if (username.trim().isEmpty) {
      throw ArgumentError.value(username, 'username', 'must not be blank');
    }
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be blank');
    }
    return 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  static Map<String, Object?> _encode(SyncSnapshot snapshot) => {
    'version': 2,
    'updatedAt': snapshot.updatedAt.toIso8601String(),
    'categories': snapshot.categories
        .map((item) => {'id': item.id, 'name': item.name, 'color': item.color})
        .toList(),
    'records': snapshot.records
        .map(
          (item) => {
            'id': item.id,
            'categoryId': item.categoryId,
            'startTime': item.startTime.toIso8601String(),
            'endTime': item.endTime.toIso8601String(),
            'note': item.note,
            'createdAt': item.createdAt.toIso8601String(),
          },
        )
        .toList(),
    'metadata': {
      'records': _metadata(snapshot.metadata.records),
      'categories': _metadata(snapshot.metadata.categories),
    },
  };

  static Map<String, Object?> _metadata(
    Map<String, SyncEntityMetadata> values,
  ) => {
    for (final entry in values.entries)
      entry.key: {
        'updatedAt': entry.value.updatedAt?.toUtc().toIso8601String(),
        'deletedAt': entry.value.deletedAt?.toUtc().toIso8601String(),
      },
  };

  static SyncSnapshot _decode(String source) {
    try {
      final root = _map(jsonDecode(source), 'document');
      final version = root['version'];
      if (version != 1 && version != 2) {
        throw const FormatException('Unsupported MyTime sync document version');
      }
      final updatedAt = _date(root, 'updatedAt');
      final records = _list(root, 'records').map(_record).toList();
      final categories = _list(root, 'categories').map(_category).toList();
      final snapshot = SyncSnapshot(
        updatedAt: updatedAt,
        categories: categories,
        records: records,
        metadata: version == 1
            ? SyncMetadata(
                records: {
                  for (final item in records)
                    item.id: SyncEntityMetadata(
                      kind: SyncEntityKind.record,
                      id: item.id,
                      updatedAt: updatedAt,
                    ),
                },
                categories: {
                  for (final item in categories)
                    item.id: SyncEntityMetadata(
                      kind: SyncEntityKind.category,
                      id: item.id,
                      updatedAt: updatedAt,
                    ),
                },
              )
            : _decodeMetadata(_map(root['metadata'], 'metadata')),
      );
      snapshot.validate();
      return snapshot;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid MyTime sync document');
    }
  }

  static SyncMetadata _decodeMetadata(Map<String, Object?> root) =>
      SyncMetadata(
        records: _decodeMetadataEntries(
          _map(root['records'], 'metadata.records'),
          SyncEntityKind.record,
        ),
        categories: _decodeMetadataEntries(
          _map(root['categories'], 'metadata.categories'),
          SyncEntityKind.category,
        ),
      );

  static Map<String, SyncEntityMetadata> _decodeMetadataEntries(
    Map<String, Object?> root,
    SyncEntityKind kind,
  ) => {
    for (final entry in root.entries)
      entry.key: SyncEntityMetadata(
        kind: kind,
        id: entry.key,
        updatedAt: entry.value == null
            ? null
            : _nullableDate(_map(entry.value, 'metadata entry'), 'updatedAt'),
        deletedAt: entry.value == null
            ? null
            : _nullableDate(_map(entry.value, 'metadata entry'), 'deletedAt'),
      ),
  };

  static DateTime? _nullableDate(Map<String, Object?> source, String name) {
    final value = source[name];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$name must be a string or null');
    }
    return DateTime.parse(value).toUtc();
  }

  static Map<String, Object?> _map(Object? value, String name) {
    if (value is! Map) {
      throw FormatException('$name must be an object');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$name contains a non-string key');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static List<Object?> _list(Map<String, Object?> source, String name) {
    final value = source[name];
    if (value is! List) {
      throw FormatException('$name must be an array');
    }
    return List<Object?>.from(value);
  }

  static Category _category(Object? source) {
    final value = _map(source, 'category');
    return Category(
      id: _requiredString(value, 'id'),
      name: _requiredString(value, 'name'),
      color: _requiredString(value, 'color'),
    );
  }

  static TimeRecord _record(Object? source) {
    final value = _map(source, 'record');
    return TimeRecord(
      id: _requiredString(value, 'id'),
      categoryId: _nullableString(value, 'categoryId'),
      startTime: _date(value, 'startTime'),
      endTime: _date(value, 'endTime'),
      note: _nullableString(value, 'note'),
      createdAt: _date(value, 'createdAt'),
    );
  }

  static String _requiredString(Map<String, Object?> source, String name) {
    final value = source[name];
    if (value is! String) {
      throw FormatException('$name must be a string');
    }
    return value;
  }

  static String? _nullableString(Map<String, Object?> source, String name) {
    if (!source.containsKey(name)) {
      throw FormatException('$name is required');
    }
    final value = source[name];
    if (value != null && value is! String) {
      throw FormatException('$name must be a string or null');
    }
    return value as String?;
  }

  static DateTime _date(Map<String, Object?> source, String name) {
    final value = _requiredString(source, name);
    try {
      return DateTime.parse(value);
    } on FormatException {
      throw FormatException('$name must be an ISO-8601 timestamp');
    }
  }
}
