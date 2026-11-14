"""Launch a packaged desktop app and require it to stay alive briefly."""
import argparse
import os
import signal
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path


def running_macos_instances():
    result = subprocess.run(['pgrep', '-x', 'deco_planner'], capture_output=True, text=True)
    return {int(pid) for pid in result.stdout.split()} if result.returncode == 0 else set()


def launch_macos(app):
    # Quarantine may cause App Translocation: identify the new process rather
    # than requiring its executable to remain at the extraction path.
    subprocess.run(['xattr', '-w', 'com.apple.quarantine', '0081;00000000;DecoPlannerCI;', str(app)], check=True)
    existing = running_macos_instances()
    launched = set()
    launcher = subprocess.Popen(['open', '-n', str(app)])
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            launched = running_macos_instances() - existing
            if launched:
                break
            if launcher.poll() not in (None, 0):
                raise RuntimeError('Launch Services rejected the quarantined app')
            time.sleep(1)
        else:
            raise RuntimeError('Quarantined macOS app did not start in 30 seconds')
        for pid in launched:
            subprocess.run(['ps', '-p', str(pid), '-o', 'comm='], check=True)
        time.sleep(10)
        if not launched.issubset(running_macos_instances()):
            raise RuntimeError('Quarantined macOS app exited prematurely')
    finally:
        for pid in launched:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        if launcher.poll() is None:
            launcher.terminate()
            try:
                launcher.wait(timeout=5)
            except subprocess.TimeoutExpired:
                launcher.kill()
                launcher.wait(timeout=5)


def smoke(platform, archive):
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        if platform == 'macos':
            subprocess.run(['ditto', '-x', '-k', archive, str(root)], check=True)
            apps = list(root.glob('*.app'))
            if len(apps) != 1:
                raise ValueError('Expected one macOS application')
            launch_macos(apps[0])
        else:
            with zipfile.ZipFile(archive) as package:
                package.extractall(root)
            process = subprocess.Popen([str(root/'deco_planner.exe')], cwd=root)
            try:
                time.sleep(10)
                if process.poll() is not None:
                    raise RuntimeError(f'Windows app exited prematurely: {process.returncode}')
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=15)
    print(f'{platform} packaged application launch verified')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=['windows', 'macos'])
    parser.add_argument('archive')
    args = parser.parse_args()
    smoke(args.platform, args.archive)
