const usesBrowserWorkers = false;

Future<void> prepareBrowserWorkers() async {}

final class BrowserWorker {
  BrowserWorker({
    required void Function(Object?) onMessage,
    required void Function(String) onError,
  }) {
    throw UnsupportedError('Browser workers require a web client.');
  }

  void send(Map<String, Object?> message) {}
  void close() {}
}
