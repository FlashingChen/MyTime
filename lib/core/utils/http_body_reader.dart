import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Reads the complete HTTP response body, failing with [TimeoutException]
/// when the server does not finish delivering it within [timeout].
///
/// The stream subscription is cancelled on timeout, so a slow or malicious
/// endpoint cannot keep the decoder buffering data after the deadline fires.
Future<String> readHttpBody(HttpClientResponse response, Duration timeout) {
  final completer = Completer<String>();
  final buffer = StringBuffer();
  final subscription = utf8.decoder
      .bind(response)
      .listen(
        buffer.write,
        onDone: () {
          if (!completer.isCompleted) completer.complete(buffer.toString());
        },
        onError: completer.completeError,
      );
  final timer = Timer(timeout, () {
    subscription.cancel();
    if (!completer.isCompleted) {
      completer.completeError(
        TimeoutException('Response body read timed out', timeout),
      );
    }
  });
  return completer.future.whenComplete(timer.cancel);
}
