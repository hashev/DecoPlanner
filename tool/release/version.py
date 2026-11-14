"""Resolve a stable release tag without evaluating shell input."""
import argparse
import json
import os
import re


def resolve(tag):
    match = re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)
    if not match:
        raise ValueError("Expected vMAJOR.MINOR.PATCH without leading zeros")
    major, minor, patch = map(int, match.groups())
    code = major * 1_000_000 + minor * 1_000 + patch
    if minor > 999 or patch > 999 or not 1 <= code <= 2_100_000_000:
        raise ValueError("Version exceeds supported Android versionCode range")
    return {"tag": tag, "name": tag[1:], "code": code}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--github-output", action="store_true")
    args = parser.parse_args()
    try:
        version = resolve(args.tag)
    except ValueError as error:
        parser.error(str(error))
    if args.github_output:
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            for key, value in version.items():
                output.write(f"{key}={value}\n")
    print(json.dumps(version))


if __name__ == "__main__":
    main()
