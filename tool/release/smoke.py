"""Launch a packaged desktop app and require it to stay alive briefly."""
import argparse
import os
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path


def smoke(platform, archive):
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        if platform == 'macos':
            subprocess.run(['ditto', '-x', '-k', archive, str(root)], check=True)
            apps = list(root.glob('*.app'))
            if len(apps) != 1:
                raise ValueError('Expected one macOS application')
            app = apps[0]
            subprocess.run(['xattr', '-w', 'com.apple.quarantine', '0081;00000000;DecoPlannerCI;', str(app)], check=True)
            subprocess.run(['open', '-n', str(app)], check=True)
            time.sleep(10)
            executable = str(app/'Contents/MacOS/deco_planner')
            subprocess.run(['pgrep', '-f', executable], check=True)
            subprocess.run(['pkill', '-f', executable], check=True)
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
