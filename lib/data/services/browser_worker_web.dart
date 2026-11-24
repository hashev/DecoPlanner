import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const usesBrowserWorkers = true;
const _script = 'planner_worker.dart.js';
String? _workerUrl;

Future<void> prepareBrowserWorkers() async {
  if (_workerUrl != null) return;
  try {
    final response = await web.window
        .fetch(_script.toJS)
        .toDart
        .timeout(const Duration(seconds: 5));
    if (!response.ok) return;
    final script = await response.text().toDart.timeout(
      const Duration(seconds: 5),
    );
    _workerUrl = web.URL.createObjectURL(
      web.Blob([script].toJS, web.BlobPropertyBag(type: 'text/javascript')),
    );
  } catch (_) {
    // The application can still open documents, and the worker can retry
    // the same-origin URL if the connection later becomes available.
  }
}

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external factory _Worker(JSString url);
  external set onmessage(JSFunction? callback);
  external set onmessageerror(JSFunction? callback);
  external set onerror(JSFunction? callback);
  external void postMessage(JSString message);
  external void terminate();
}

extension type _WorkerEvent._(JSObject _) implements JSObject {
  external JSString get data;
}

final class BrowserWorker {
  BrowserWorker({
    required void Function(Object?) onMessage,
    required void Function(String) onError,
  }) : _worker = _Worker((_workerUrl ?? _script).toJS) {
    _worker.onmessage = ((_WorkerEvent event) {
      Object? payload;
      try {
        payload = jsonDecode(event.data.toDart);
      } catch (_) {
        onError('Malformed browser worker message.');
        return;
      }
      onMessage(payload);
    }).toJS;
    _worker.onmessageerror = ((JSObject _) {
      onError('Cannot read browser worker message.');
    }).toJS;
    _worker.onerror = ((JSObject _) {
      onError('Browser worker failed.');
    }).toJS;
  }

  final _Worker _worker;

  void send(Map<String, Object?> message) =>
      _worker.postMessage(jsonEncode(message).toJS);

  void close() {
    _worker.onmessage = null;
    _worker.onmessageerror = null;
    _worker.onerror = null;
    _worker.terminate();
  }
}
