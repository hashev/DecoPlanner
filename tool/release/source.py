"""Require the exact tag commit to belong to protected main history."""
import os
import subprocess
from version import resolve


def verify(tag, sha):
    resolve(tag)
    if len(sha) != 40 or any(c not in '0123456789abcdef' for c in sha):
        raise ValueError('Invalid source SHA')
    subprocess.run(['git', 'fetch', 'origin', '+refs/heads/main:refs/remotes/origin/main'], check=True)
    actual = subprocess.check_output(['git', 'rev-parse', f'refs/tags/{tag}^{{commit}}'], text=True).strip()
    if actual != sha:
        raise ValueError('Tag and checkout SHA differ')
    subprocess.run(['git', 'merge-base', '--is-ancestor', sha, 'origin/main'], check=True)


if __name__ == '__main__':
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    verify(os.environ['GITHUB_REF_NAME'], sha)
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'sha={sha}\n')
