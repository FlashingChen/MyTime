import 'dart:convert';
import 'dart:io';

import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_port.dart';

/// Normalized response returned by an injectable WebDAV transport.
class WebDavResponse {
  const WebDavResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
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

  @override
  Future<SyncSnapshot?> pull() async {
    final response = await _request('GET', _endpoint, _headers, null);
    if (response.statusCode == HttpStatus.notFound) {
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('WebDAV GET failed: ${response.statusCode}');
    }
    return _decode(response.body);
  }

  @override
  Future<void> push(SyncSnapshot snapshot) async {
    snapshot.validate();
    final response = await _request(
      'PUT',
      _endpoint,
      _headers,
      jsonEncode(_encode(snapshot)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('WebDAV PUT failed: ${response.statusCode}');
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
      final response = await request.close();
      return WebDavResponse(
        response.statusCode,
        await utf8.decoder.bind(response).join(),
      );
    } finally {
      client.close(force: true);
    }
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
    'version': 1,
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
  };

  static SyncSnapshot _decode(String source) {
    try {
      final root = _map(jsonDecode(source), 'document');
      if (root['version'] != 1) {
        throw const FormatException('Unsupported MyTime sync document version');
      }
      final snapshot = SyncSnapshot(
        updatedAt: _date(root, 'updatedAt'),
        categories: _list(root, 'categories').map(_category).toList(),
        records: _list(root, 'records').map(_record).toList(),
      );
      snapshot.validate();
      return snapshot;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid MyTime sync document');
    }
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
