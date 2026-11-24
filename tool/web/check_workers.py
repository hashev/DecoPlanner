"""Run reference checks against the actual Dart Web Worker in Chromium."""

import argparse
import functools
import http.server
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading


ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", default=os.environ.get("CHROME_EXECUTABLE", "google-chrome"))
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        site = root / "DecoPlanner"
        site.mkdir()
        for entry, output in (
            ("tool/web/planner_worker.dart", "planner_worker.dart.js"),
            ("test/web/worker_reference_check.dart", "check.js"),
        ):
            subprocess.run(
                ["dart", "compile", "js", "-O4", entry, "-o", str(site / output)],
                cwd=ROOT,
                check=True,
            )
        subprocess.run(
            ["dart", "run", "test/web/document_exchange_fixture.dart",
             "write", str(site / "native-plan.json")],
            cwd=ROOT,
            check=True,
        )
        fixtures = ROOT / "packages/deco_core/test/fixtures"
        for name in ("legacy_baseline/oc-air-30m-20min.json",
                     "independent/buhlmann-bailout-normalized.json",
                     "independent/vpmb-normalized-schedules.json"):
            shutil.copy(fixtures / name, site)
        (site / "index.html").write_text(
            '''<!doctype html><base href="/DecoPlanner/">
<script>
function failNextDocumentWrite() {
  const put = IDBObjectStore.prototype.put;
  IDBObjectStore.prototype.put = function (...args) {
    IDBObjectStore.prototype.put = put;
    const request = put.apply(this, args);
    request.addEventListener('success', () => this.transaction.abort());
    return request;
  };
}
</script>
<script src="check.js" defer></script>''',
            encoding="utf-8",
        )

        complete = threading.Event()
        results = []
        fail_worker = threading.Event()

        class Handler(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def end_headers(self):
                self.send_header("Cache-Control", "no-store")
                super().end_headers()

            def do_GET(self):
                if self.path == "/fail-next-worker":
                    fail_worker.set()
                    self.send_response(204)
                    self.end_headers()
                    return
                if self.path == "/DecoPlanner/planner_worker.dart.js" and fail_worker.is_set():
                    fail_worker.clear()
                    self.send_error(404)
                    return
                super().do_GET()

            def do_POST(self):
                if self.path not in ("/result", "/web-plan"):
                    self.send_error(404)
                    return
                length = int(self.headers["Content-Length"])
                data = self.rfile.read(length)
                if self.path == "/web-plan":
                    (root / "web-plan.json").write_bytes(data)
                    self.send_response(204)
                    self.end_headers()
                    return
                results.append(data.decode("utf-8"))
                self.send_response(204)
                self.end_headers()
                complete.set()

        with http.server.ThreadingHTTPServer(
            ("127.0.0.1", 0), functools.partial(Handler, directory=directory)
        ) as server, (root / "chrome.log").open("w+") as chrome_log:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            chrome = subprocess.Popen(
                [args.chrome, "--headless", "--no-first-run",
                 f"--user-data-dir={root / 'chrome-profile'}",
                 f"http://127.0.0.1:{server.server_port}/DecoPlanner/"],
                stdout=chrome_log,
                stderr=subprocess.STDOUT,
            )
            try:
                if not complete.wait(45):
                    chrome_log.seek(0)
                    raise SystemExit(f"Browser check timed out.\n{chrome_log.read()}")
                print(results[0])
                if not results[0].startswith("PASS:"):
                    return 1
                subprocess.run(
                    ["dart", "run", "test/web/document_exchange_fixture.dart",
                     "verify", str(root / "web-plan.json")],
                    cwd=ROOT,
                    check=True,
                )
                print("PASS: native app decoded the browser export")
                return 0
            finally:
                chrome.terminate()
                chrome.wait(timeout=10)
                server.shutdown()
                thread.join()


if __name__ == "__main__":
    raise SystemExit(main())
