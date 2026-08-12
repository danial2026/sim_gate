#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SimGate dev tooling wrapper: analyze / format / run / build.
#
# Usage:
#   scripts/dev.sh analyze     # flutter analyze (must be clean)
#   scripts/dev.sh format      # dart format (idempotent)
#   scripts/dev.sh run         # flutter run (attaches to a device)
#   scripts/dev.sh apk         # flutter build apk --debug
#   scripts/dev.sh release     # flutter build apk --release
# -----------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  analyze)
    echo "==> flutter analyze"
    flutter analyze
    ;;
  format)
    echo "==> dart format --set-exit-if-changed lib test integration_test"
    dart format --set-exit-if-changed lib test integration_test
    ;;
  run)
    echo "==> flutter run"
    flutter run
    ;;
  apk)
    echo "==> flutter build apk --debug"
    flutter build apk --debug
    ;;
  release)
    echo "==> flutter build apk --release"
    flutter build apk --release
    ;;
  *)
    echo "Usage: scripts/dev.sh [analyze|format|run|apk|release]"
    exit 1
    ;;
esac
