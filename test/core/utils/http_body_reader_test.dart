import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/core/utils/http_body_reader.dart';

void main() {
  test('readHttpBody returns the full body once the server finishes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('hello');
      await request.response.close();
    });

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/'),
    );
    final response = await request.close();

    expect(await readHttpBody(response, const Duration(seconds: 5)), 'hello');
  });

  test(
    'readHttpBody fails with TimeoutException when the body stalls',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      // Send response headers plus one chunk, then never finish the body:
      // a slow stream must not hold the reader forever.
      server.listen((request) {
        request.response.write('partial');
        request.response.flush();
      });

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/'),
      );
      final response = await request.close();

      await expectLater(
        readHttpBody(response, const Duration(milliseconds: 300)),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
