#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
flutter build web --release --no-web-resources-cdn "$@"

worker_build=$(mktemp -d)
trap 'rm -rf "$worker_build"' EXIT
dart compile js -O4 --no-source-maps tool/web/planner_worker.dart \
  -o "$worker_build/planner_worker.dart.js"
cp "$worker_build/planner_worker.dart.js" build/web/
